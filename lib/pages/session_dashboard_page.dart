import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../theme/shishax_theme.dart';

/// Live session dashboard, rebuilt to the ShishaX brand system and modelled on
/// the Lovable DashboardPage. Drop-in replacement for HeatingPage: same
/// constructor (heatPreset + modeName), so existing navigation keeps working.
///
/// Binds to the real device telemetry exposed by BluetoothService.deviceInfo:
///   battery, realTemp, topTemp, setTemp, countdown_time,
///   startHeating, bPauseState, boostCount, lightMode, setTime,
///   motorLevel, audioSwitch, tempUnit
///
/// Reconciliation notes (firmware truth vs Lovable prototype):
///   * There is NO live "side temp" sensor stream today (0xB9/0xBA expose top +
///     real only; side is a configured curve, not a readout). So the dial shows
///     TOP temp and tiles show CHAMBER (realTemp) + BATTERY + TIME. Add a side
///     tile if/when firmware streams a live side reading.
///   * Boost on the device is a COUNT (0-12), not "+10 minutes". This wires to
///     the real boostCount increment. Confirm whether the firmware treats each
///     boost as a time extension before relabelling it "+10m".
///   * countdown_time unit is assumed to be seconds; confirm against the spec.
class SessionDashboardPage extends StatefulWidget {
  final int heatPreset;
  final String modeName;

  const SessionDashboardPage({
    super.key,
    required this.heatPreset,
    required this.modeName,
  });

  @override
  State<SessionDashboardPage> createState() => _SessionDashboardPageState();
}

class _SessionDashboardPageState extends State<SessionDashboardPage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refresh the countdown display once per second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // ---- Command helpers (reuse the proven 0xA9 device_parameter packet) ------

  void _send({required int startHeating, int? boostCount}) {
    final ble = Provider.of<BluetoothService>(context, listen: false);
    final d = ble.deviceInfo;
    // NOTE: setTemp default is 200 (not 60). The firmware rejects setTemp < 150,
    // so the old `?? 60` default in HeatingPage/MainPage would throw. 200 is the
    // bottom of the authoritative top range (200-320).
    ble.sendDeviceParameter(
      d?['lightMode'] as int? ?? 0,
      d?['setTemp'] as int? ?? 200,
      d?['setTime'] as int? ?? 30,
      heatPreset: widget.heatPreset,
      startHeating: startHeating,
      boostCount: boostCount ?? (d?['boostCount'] as int? ?? 0),
      motorLevel: d?['motorLevel'] as int? ?? 0,
      audioSwitch: d?['audioSwitch'] as int? ?? 0,
      tempUnit: d?['tempUnit'] as int? ?? 0,
    );
  }

  void _onBoost() {
    final d = Provider.of<BluetoothService>(context, listen: false).deviceInfo;
    final current = d?['boostCount'] as int? ?? 0;
    final next = math.min(current + 1, 12);
    if (next == current) return; // already maxed
    _send(startHeating: 1, boostCount: next);
  }

  void _onPauseResume(bool paused) {
    _send(startHeating: paused ? 1 : 0);
  }

  Future<void> _onEndSession() async {
    _send(startHeating: 0);
    if (mounted) Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShishaX.background,
      body: SafeArea(
        child: Consumer<BluetoothService>(
          builder: (context, ble, _) {
            final d = ble.deviceInfo ?? const {};

            final battery = d['battery'] as int? ?? 0;
            final topTemp = d['topTemp'] as int? ?? 0;
            final realTemp = d['realTemp'] as int? ?? 0;
            final setTemp = d['setTemp'] as int? ?? 0;
            final countdown = d['countdown_time'] as int? ?? 0;
            final boost = d['boostCount'] as int? ?? 0;
            final heating = (d['startHeating'] as int? ?? 0) == 1;
            final paused = heating && (d['bPauseState'] as int? ?? 0) == 1;
            final unit = (d['tempUnit'] as int? ?? 0) == 1 ? 'F' : 'C';

            return Column(
              children: [
                _header(heating: heating, paused: paused),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: _gauge(
                      topTemp: topTemp,
                      setTemp: setTemp,
                      unit: unit,
                    ),
                  ),
                ),
                _statRow(
                  realTemp: realTemp,
                  battery: battery,
                  countdown: countdown,
                  unit: unit,
                ),
                const SizedBox(height: 20),
                _actions(heating: heating, paused: paused, boost: boost),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---- Header: back, mode name, live/paused status pill ---------------------

  Widget _header({required bool heating, required bool paused}) {
    final String label;
    final Color color;
    final bool glowing;
    if (paused) {
      label = 'PAUSED';
      color = ShishaX.warning;
      glowing = false;
    } else if (heating) {
      label = 'LIVE';
      color = ShishaX.orange;
      glowing = true;
    } else {
      label = 'IDLE';
      color = ShishaX.muted;
      glowing = false;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.chevron_left, color: ShishaX.foreground, size: 28),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.modeName.isEmpty ? 'Session' : widget.modeName,
              style: ShishaX.display(18, weight: FontWeight.w700, spacing: 1),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.5)),
              boxShadow: glowing ? ShishaX.glow(color, blur: 14, opacity: 0.4) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: ShishaX.body(11, weight: FontWeight.w700, color: color, spacing: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Central heat gauge (top temp, gauge 0..360, target tick at setTemp) --

  Widget _gauge({required int topTemp, required int setTemp, required String unit}) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(260, 260),
            painter: _HeatGaugePainter(
              value: topTemp.toDouble(),
              maxValue: 360,
              target: setTemp > 0 ? setTemp.toDouble() : null,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TOP TEMP',
                style: ShishaX.body(11, weight: FontWeight.w600, color: ShishaX.muted, spacing: 2),
              ),
              const SizedBox(height: 6),
              ShaderMask(
                shaderCallback: (b) => ShishaX.brandGradient.createShader(b),
                child: Text(
                  '$topTemp',
                  style: ShishaX.display(72, weight: FontWeight.w800, color: Colors.white),
                ),
              ),
              Text(
                '°$unit',
                style: ShishaX.display(20, weight: FontWeight.w700, color: ShishaX.muted),
              ),
              if (setTemp > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'target $setTemp°$unit',
                  style: ShishaX.body(12, color: ShishaX.muted),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---- Stat tiles -----------------------------------------------------------

  Widget _statRow({
    required int realTemp,
    required int battery,
    required int countdown,
    required String unit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statTile(
            icon: Icons.thermostat,
            label: 'CHAMBER',
            value: '$realTemp°$unit',
          ),
          const SizedBox(width: 10),
          _statTile(
            icon: Icons.battery_charging_full,
            label: 'BATTERY',
            value: '$battery%',
          ),
          const SizedBox(width: 10),
          _statTile(
            icon: Icons.timer_outlined,
            label: 'TIME LEFT',
            value: _fmtCountdown(countdown),
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: ShishaX.glass(radius: 14),
        child: Column(
          children: [
            Icon(icon, color: ShishaX.orange, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: ShishaX.display(16, weight: FontWeight.w700),
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: ShishaX.body(9, weight: FontWeight.w600, color: ShishaX.muted, spacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Action bar -----------------------------------------------------------

  Widget _actions({required bool heating, required bool paused, required int boost}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _glassButton(
                  icon: Icons.bolt,
                  label: boost > 0 ? 'BOOST ($boost)' : 'BOOST',
                  enabled: heating && !paused && boost < 12,
                  onTap: _onBoost,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _glassButton(
                  icon: paused ? Icons.play_arrow : Icons.pause,
                  label: paused ? 'RESUME' : 'PAUSE',
                  enabled: heating,
                  onTap: () => _onPauseResume(paused),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _gradientButton(
            icon: Icons.stop_circle_outlined,
            label: 'END SESSION',
            onTap: _onEndSession,
          ),
        ],
      ),
    );
  }

  Widget _glassButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 54,
          decoration: ShishaX.glass(radius: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ShishaX.foreground, size: 20),
              const SizedBox(width: 8),
              Text(label, style: ShishaX.body(13, weight: FontWeight.w700, spacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradientButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: ShishaX.brandGradientHorizontal,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ShishaX.glow(ShishaX.orange, opacity: 0.45),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: ShishaX.body(15, weight: FontWeight.w800, color: Colors.white, spacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtCountdown(int seconds) {
    if (seconds <= 0) return '--:--';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// 270-degree arc gauge for the live top temperature, with a target tick.
class _HeatGaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final double? target;

  _HeatGaugePainter({required this.value, required this.maxValue, this.target});

  static const double _start = math.pi * 0.75; // 135 degrees
  static const double _sweep = math.pi * 1.5; // 270 degrees

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.07);
    canvas.drawArc(rect, _start, _sweep, false, track);

    // Progress
    final frac = (value / maxValue).clamp(0.0, 1.0);
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [ShishaX.orange, ShishaX.red],
      ).createShader(rect);
    canvas.drawArc(rect, _start, _sweep * frac, false, progress);

    // Target tick
    final t = target;
    if (t != null) {
      final tf = (t / maxValue).clamp(0.0, 1.0);
      final a = _start + _sweep * tf;
      final p1 = center +
          Offset(math.cos(a) * (radius - 12), math.sin(a) * (radius - 12));
      final p2 = center +
          Offset(math.cos(a) * (radius + 10), math.sin(a) * (radius + 10));
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeatGaugePainter old) =>
      old.value != value || old.target != target || old.maxValue != maxValue;
}
