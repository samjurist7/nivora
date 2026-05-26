import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import 'userName_page.dart';

class UserHeatPage extends StatefulWidget {
  final int optionIndex;

  const UserHeatPage({super.key, required this.optionIndex});

  @override
  State<UserHeatPage> createState() => _UserHeatPageState();
}

class _UserHeatPageState extends State<UserHeatPage> {
  // 5 stages: temp (°C) and time (min)
  final List<int> _temps = [0, 320, 310, 285, 270];
  final List<int> _times = [3, 9, 5, 18, 25];

  final List<String> _stages = ['Stage 1', 'Stage 2', 'Stage 3', 'Stage 4', 'Stage 5'];

  final Map<String, FixedExtentScrollController> _tempControllers = {};
  final Map<String, FixedExtentScrollController> _timeControllers = {};

  String? _lastSyncedUpdate;

  static const int _tempMin = 0;
  static const int _tempMax = 350;
  static const int _tempStep = 5;
  static const int _timeMin = 0;
  static const int _timeMax = 120;

  int get _totalTime => _times.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _stages.length; i++) {
      _tempControllers['stage$i'] = FixedExtentScrollController(
        initialItem: (_temps[i] / _tempStep).round(),
      );
      _timeControllers['stage$i'] = FixedExtentScrollController(
        initialItem: _times[i],
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromDevice());
  }

  @override
  void dispose() {
    for (var c in _tempControllers.values) c.dispose();
    for (var c in _timeControllers.values) c.dispose();
    super.dispose();
  }

  void _syncFromDevice() {
    final bt = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bt.deviceInfo;
    if (deviceInfo == null) return;

    final classicIndex = widget.optionIndex - 1;
    final classicData = deviceInfo['classic'] as Map<String, dynamic>?;
    if (classicData == null) return;

    final indexData = classicData['$classicIndex'] as Map<String, dynamic>?;
    if (indexData == null) return;

    final updatedAt = indexData['updatedAt'] as String?;
    if (updatedAt != null && updatedAt == _lastSyncedUpdate) return;

    final temps = indexData['temps'] as List<dynamic>?;
    final times = indexData['times'] as List<dynamic>?;
    if (temps == null || times == null || temps.length < 5 || times.length < 5) return;

    _lastSyncedUpdate = updatedAt;
    setState(() {
      for (int i = 0; i < 5; i++) {
        _temps[i] = _clampTemp(temps[i] as int);
        _times[i] = (times[i] as int).clamp(_timeMin, _timeMax);
      }
    });
    _jumpWheels();
  }

  int _clampTemp(int v) {
    final clamped = v.clamp(_tempMin, _tempMax);
    return ((clamped / _tempStep).round() * _tempStep).clamp(_tempMin, _tempMax);
  }

  void _jumpWheels() {
    for (int i = 0; i < _stages.length; i++) {
      final tc = _tempControllers['stage$i'];
      final wc = _timeControllers['stage$i'];
      if (tc != null && tc.hasClients) {
        tc.jumpToItem((_temps[i] / _tempStep).round());
      }
      if (wc != null && wc.hasClients) {
        wc.jumpToItem(_times[i]);
      }
    }
  }

  Future<void> _onSave() async {
    final bt = Provider.of<BluetoothService>(context, listen: false);
    final index = widget.optionIndex - 1;
    try {
      await bt.sendClassicTempTime(index, List.from(_temps), List.from(_times));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved'), duration: Duration(seconds: 1)),
        );
        Navigator.push(context,
          MaterialPageRoute(builder: (_) => UserNamePage(optionIndex: widget.optionIndex)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothService>(
      builder: (context, bt, _) {
        final deviceInfo = bt.deviceInfo;
        if (deviceInfo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncFromDevice();
          });
        }
        return _buildContent(bt);
      },
    );
  }

  Widget _buildContent(BluetoothService bt) {
    String optionName = 'Option ${widget.optionIndex}';
    final btIndex = widget.optionIndex - 1;
    if (bt.optionNames.containsKey(btIndex)) {
      optionName = bt.optionNames[btIndex]!;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildOptionPill(optionName),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildSessionOverview(),
                    const SizedBox(height: 12),
                    for (int i = 0; i < _stages.length; i++) ...[
                      _buildStageRow(i),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: _buildSaveButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Text(
              'Presets',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildOptionPill(String name) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionOverview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: label + total time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session Overview',
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$_totalTime',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6, left: 4),
                    child: Text(
                      'min',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Right: per-stage time + temp
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: [
                  for (int i = 0; i < _stages.length; i++)
                    TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
                          ).createShader(b),
                          child: Text(
                            '${_times[i]}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('min  ',
                          style: TextStyle(color: Color(0xFFFF6B35), fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
                          ).createShader(b),
                          child: Text(
                            '${_temps[i]}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text('°C',
                          style: TextStyle(color: Color(0xFFFF6B35), fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStageRow(int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              _stages[index],
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: _buildWheel(
            value: _times[index],
            min: _timeMin,
            max: _timeMax,
            step: 1,
            unit: 'min',
            controller: _timeControllers['stage$index']!,
            onChanged: (v) => setState(() => _times[index] = v),
          )),
          const SizedBox(width: 8),
          Expanded(child: _buildWheel(
            value: _temps[index],
            min: _tempMin,
            max: _tempMax,
            step: _tempStep,
            unit: '°C',
            controller: _tempControllers['stage$index']!,
            onChanged: (v) => setState(() => _temps[index] = v),
          )),
        ],
      ),
    );
  }

  Widget _buildWheel({
    required int value,
    required int min,
    required int max,
    required int step,
    required String unit,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onChanged,
  }) {
    final itemCount = ((max - min) ~/ step) + 1;
    return SizedBox(
      height: 84,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 28,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 1.4,
        perspective: 0.002,
        onSelectedItemChanged: (i) => onChanged(min + i * step),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, i) {
            final v = min + i * step;
            final isSelected = v == value;
            if (isSelected) {
              return Center(
                child: ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
                  ).createShader(b),
                  child: Text(
                    '$v$unit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }
            return Center(
              child: Text(
                '$v$unit',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _onSave,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF512F), Color(0xFFFF6B35)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Center(
          child: Text(
            'SAVE SETTING',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
