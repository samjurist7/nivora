import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/web_ble.dart';
import 'main_page.dart';

class DeviceConnectPage extends StatefulWidget {
  const DeviceConnectPage({super.key});

  @override
  State<DeviceConnectPage> createState() => _DeviceConnectPageState();
}

class _DeviceConnectPageState extends State<DeviceConnectPage>
    with TickerProviderStateMixin {
  late final AnimationController _radarController;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(); // 始终旋转，不依赖扫描状态
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanning());
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  void _startScanning() async {
    final bt = Provider.of<BluetoothService>(context, listen: false);
    if (kIsWeb) {
      await _requestWebDevice(bt);
    } else {
      setState(() => _isScanning = true);
      await bt.startScan(timeout: const Duration(seconds: 10));
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _requestWebDevice(BluetoothService bt) async {
    void log(String msg) {
      if (kIsWeb) { try { WebBleLogger.log('[page] $msg'); } catch (_) {} }
    }
    try {
      log('requestDeviceWeb...');
      final res = await bt.requestDeviceWeb();
      if (res.containsKey('error')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Device selection failed: ${res['error']}'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }
      _radarController.stop();
      await bt.connect('web_device');
      await Future.delayed(const Duration(milliseconds: 500));
      if (bt.connectedDevice != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainPage()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _connectDevice(BluetoothService bt, dynamic device, String deviceName) async {
    try {
      await bt.connect(device);
      await Future.delayed(const Duration(milliseconds: 500));
      if (bt.connectedDevice != null && mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainPage()));
      } else {
        HapticFeedback.lightImpact();
        _startScanning();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to connect $deviceName, please try again'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      _startScanning();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Connection error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bt = Provider.of<BluetoothService>(context);
    final hasDevices = bt.devices.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildLogoSection(),
            const SizedBox(height: 40),
            Expanded(
              child: hasDevices
                  ? _buildDeviceList(bt)
                  : _buildRadar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
          ).createShader(bounds),
          child: const Text(
            'ShishaX',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 50,
          height: 3,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'UPGRADE YOUR SESSION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRadar() {
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: AnimatedBuilder(
          animation: _radarController,
          builder: (context, child) {
            return CustomPaint(
              painter: _RadarPainter(_radarController.value),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeviceList(BluetoothService bt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: bt.devices.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Colors.white.withOpacity(0.08),
            ),
            itemBuilder: (context, idx) {
              final d = bt.devices[idx];
              final deviceName = d['name'] ?? 'Unknown Device';
              final deviceId = d['id'] ?? '';
              return _DeviceRow(
                deviceName: deviceName,
                deviceId: deviceId,
                onTap: () => _connectDevice(bt, d['device'], deviceName),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final String deviceName;
  final String deviceId;
  final VoidCallback onTap;

  const _DeviceRow({
    required this.deviceName,
    required this.deviceId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bluetooth, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deviceName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deviceId,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.4), size: 22),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  _RadarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final sweepAngle = progress * 2 * math.pi - math.pi / 2;

    // Concentric circles
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, circlePaint);
    }

    // Cross lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius),
        Offset(center.dx, center.dy + maxRadius), linePaint);
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy),
        Offset(center.dx + maxRadius, center.dy), linePaint);

    // Sweep sector (trailing fade using multiple arcs)
    const trailAngle = math.pi * 0.8;
    const steps = 24;
    for (int i = 0; i < steps; i++) {
      final t = i / steps;
      final startA = sweepAngle - trailAngle * (1 - t);
      const segAngle = trailAngle / steps;
      final sectorPath = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: maxRadius),
          startA,
          segAngle,
          false,
        )
        ..close();
      canvas.drawPath(
        sectorPath,
        Paint()
          ..color = const Color(0xFFFF512F).withOpacity(t * 0.25)
          ..style = PaintingStyle.fill,
      );
    }

    // Sweep line
    final lineEnd = Offset(
      center.dx + maxRadius * math.cos(sweepAngle),
      center.dy + maxRadius * math.sin(sweepAngle),
    );
    canvas.drawLine(
      center,
      lineEnd,
      Paint()
        ..color = const Color(0xFFFF6B35).withOpacity(0.9)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Center dot
    canvas.drawCircle(
      center,
      5,
      Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}
