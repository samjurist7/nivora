import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';

import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';
import '../theme/mechanical_theme.dart';
import '../widgets/smoke_background.dart';

/// 模式二级页面（抽烟状态）- 机械风重新设计
class HeatControlPage extends StatefulWidget {
  final String mode;

  const HeatControlPage({super.key, required this.mode});

  @override
  State<HeatControlPage> createState() => _HeatControlPageState();
}

class _HeatControlPageState extends State<HeatControlPage>
    with TickerProviderStateMixin {
  final List<String> _stageNames = [
    'Preheat',
    'Ramp-up',
    'Steady',
    'Boost',
    'Cool down',
  ];

  late AnimationController _rotationController;
  late AnimationController _glowController;
  Timer? _timer;
  bool _isHeating = false;
  int _currentStage = 0;
  int _remainingSeconds = 0;
  List<int> _stageTemps = [];
  List<int> _stageTimes = [];
  bool _loading = true;
  bool _sendingCommand = false;

  FixedExtentScrollController? _tempScrollController;
  FixedExtentScrollController? _timeScrollController;

  static const int _minTemp = 100;
  static const int _maxTemp = 300;
  static const int _tempStep = 1;
  static const int _minTime = 1;
  static const int _maxTime = 30;

  List<int> get _tempValues =>
      List.generate(((_maxTemp - _minTemp) ~/ _tempStep) + 1, (i) => _minTemp + i * _tempStep);
  List<int> get _timeValues =>
      List.generate(_maxTime - _minTime + 1, (i) => _minTime + i);

  Color get _primaryColor =>
      widget.mode == 'classic' ? MechanicalTheme.primaryCyan : MechanicalTheme.coolGreen;

  String get _modeTitle =>
      widget.mode == 'classic' ? 'CLASSIC' : 'HERBAL';

  String get _modeImage =>
      widget.mode == 'classic' ? 'assets/images/Classic.png' : 'assets/images/Herbal.png';

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _loadStageData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bt = Provider.of<BluetoothService>(context, listen: false);
      bt.addListener(_onBluetoothDataChanged);
    });
  }

  void _onBluetoothDataChanged() {
    if (!mounted) return;
    final bt = Provider.of<BluetoothService>(context, listen: false);
    final info = bt.getDeviceInfo();

    List<int>? temps;
    List<int>? times;
    if (widget.mode == 'classic') {
      temps = (info?['classic_temps'] as List?)?.cast<int>();
      times = (info?['classic_times'] as List?)?.cast<int>();
    } else {
      temps = (info?['herbal_temps'] as List?)?.cast<int>();
      times = (info?['herbal_times'] as List?)?.cast<int>();
    }

    if (temps != null && times != null) {
      print('📱 UI Update: ${widget.mode} mode data temps=$temps, times=$times');
      setState(() {
        _stageTemps = temps!;
        _stageTimes = times!;
        if (!_isHeating) {
          _remainingSeconds = _stageTimes.isNotEmpty ? _stageTimes[_currentStage] * 60 : 0;
        }
      });
      _initScrollControllers();
    }
  }

  Future<void> _loadStageData() async {
    await StorageService.init();
    final bt = Provider.of<BluetoothService>(context, listen: false);
    final info = bt.getDeviceInfo();

    List<int>? temps;
    List<int>? times;
    if (widget.mode == 'classic') {
      temps = (info?['classic_temps'] as List?)?.cast<int>();
      times = (info?['classic_times'] as List?)?.cast<int>();
    } else {
      temps = (info?['herbal_temps'] as List?)?.cast<int>();
      times = (info?['herbal_times'] as List?)?.cast<int>();
    }

    temps ??= [180, 200, 220, 240, 200];
    times ??= [3, 5, 10, 5, 3];

    setState(() {
      _stageTemps = temps!;
      _stageTimes = times!;
      _currentStage = 0;
      _remainingSeconds = _stageTimes.isNotEmpty ? _stageTimes[0] * 60 : 0;
      _loading = false;
    });
    _initScrollControllers();
  }

  void _initScrollControllers() {
    if (_stageTemps.isEmpty || _stageTimes.isEmpty) return;

    final currentTemp = _stageTemps[_currentStage];
    final currentTime = _stageTimes[_currentStage];
    final tempIndex = _tempValues.indexOf(currentTemp);
    final timeIndex = _timeValues.indexOf(currentTime);

    _tempScrollController?.dispose();
    _timeScrollController?.dispose();
    _tempScrollController = FixedExtentScrollController(
      initialItem: tempIndex >= 0 ? tempIndex : 0,
    );
    _timeScrollController = FixedExtentScrollController(
      initialItem: timeIndex >= 0 ? timeIndex : 0,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rotationController.dispose();
    _glowController.dispose();
    _tempScrollController?.dispose();
    _timeScrollController?.dispose();
    final bt = Provider.of<BluetoothService>(context, listen: false);
    bt.removeListener(_onBluetoothDataChanged);
    super.dispose();
  }

  Future<void> _startHeating() async {
    if (_isHeating || _stageTimes.isEmpty || _sendingCommand) return;

    final bt = Provider.of<BluetoothService>(context, listen: false);
    if (bt.connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device not connected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isHeating = true;
      _currentStage = 0;
      _remainingSeconds = _stageTimes[0] * 60;
    });
    print('🚀 Start heating: stage0 (${_stageNames[0]}), targetTemp=${_stageTemps[0]}°C');

    _rotationController.repeat();
    _glowController.repeat(reverse: true);
    await _sendStageCommand(0);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _advanceStage();
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  Future<void> _sendStageCommand(int stage) async {
    if (stage < 0 || stage >= _stageTemps.length) return;
    final bt = Provider.of<BluetoothService>(context, listen: false);
    if (bt.connectedDevice == null) return;

    try {
      setState(() => _sendingCommand = true);
      final temp = _stageTemps[stage];
      final minutes = _stageTimes[stage];
      print('➡️ Stage command: stage=$stage (${_stageNames[stage]}), temp=$temp°C, time=$minutes min');
      await bt.sendDeviceParameter(
        StorageService.getLightMode(),
        temp,
        minutes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send heating command: $e'),
          backgroundColor: MechanicalTheme.warningRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingCommand = false);
      }
    }
  }

  Future<void> _advanceStage() async {
    if (_currentStage >= _stageNames.length - 1) {
      _finishHeating();
      return;
    }

    final nextStage = _currentStage + 1;
    print('⏭️ Stage switch: $_currentStage -> $nextStage (${_stageNames[nextStage]})');
    setState(() {
      _currentStage = nextStage;
      _remainingSeconds = _stageTimes[nextStage] * 60;
    });

    await _sendStageCommand(nextStage);
  }

  void _finishHeating() {
    _timer?.cancel();
    _rotationController.stop();
    _glowController.stop();
    setState(() {
      _isHeating = false;
      _remainingSeconds = 0;
    });
    print('✅ All stages completed');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session completed successfully'),
        duration: Duration(seconds: 2),
        backgroundColor: MechanicalTheme.coolGreen,
      ),
    );
  }

  void _onStageSelected(int index) {
    if (index < 0 || index >= _stageNames.length) return;
    if (_stageTimes.isEmpty || _stageTemps.isEmpty) return;

    setState(() {
      _currentStage = index;
      _remainingSeconds = _stageTimes[index] * 60;
    });
    _updateScrollControllers();
    print('👆 Stage selected: $index (${_stageNames[index]}), temp=${_stageTemps[index]}°C');
  }

  void _updateScrollControllers() {
    if (_stageTemps.isEmpty || _stageTimes.isEmpty) return;

    final currentTemp = _stageTemps[_currentStage];
    final currentTime = _stageTimes[_currentStage];

    final tempIndex = _tempValues.indexOf(currentTemp);
    final timeIndex = _timeValues.indexOf(currentTime);

    if (tempIndex >= 0) {
      _tempScrollController?.jumpToItem(tempIndex);
    }
    if (timeIndex >= 0) {
      _timeScrollController?.jumpToItem(timeIndex);
    }
  }

  void _onTempChanged(int index) {
    if (_isHeating) return;
    if (index < 0 || index >= _tempValues.length) return;

    final newTemp = _tempValues[index];
    setState(() {
      _stageTemps[_currentStage] = newTemp;
    });
    print('🌡️ Temp adjusted: stage$_currentStage -> $newTemp°C');
  }

  void _onTimeChanged(int index) {
    if (_isHeating) return;
    if (index < 0 || index >= _timeValues.length) return;

    final newTime = _timeValues[index];
    setState(() {
      _stageTimes[_currentStage] = newTime;
      _remainingSeconds = newTime * 60;
    });
    print('⏱️ Time adjusted: stage$_currentStage -> $newTime min');
  }

  Future<void> _saveSettings() async {
    if (_stageTemps.isEmpty || _stageTimes.isEmpty || _sendingCommand) return;

    final bt = Provider.of<BluetoothService>(context, listen: false);
    if (bt.connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device not connected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _sendingCommand = true);
      print('💾 Save settings: mode=${widget.mode}, temps=$_stageTemps, times=$_stageTimes');

      if (widget.mode == 'classic') {
        await bt.sendClassicTempTime(_stageTemps, _stageTimes);
      } else {
        await bt.sendHerbalTempTime(_stageTemps, _stageTimes);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_modeTitle settings saved'),
          backgroundColor: MechanicalTheme.coolGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: MechanicalTheme.warningRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingCommand = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SmokeBackground(
      smokeColor: _primaryColor,
      particleCount: 10,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : Column(
                  children: [
                    _buildAppBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildModeDisplay(),
                            const SizedBox(height: 30),
                            _buildIntervalsSection(),
                            const SizedBox(height: 30),
                            _buildBottomControls(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: MechanicalTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: widget.mode == 'classic'
                  ? [MechanicalTheme.primaryCyan, MechanicalTheme.coolTeal]
                  : [MechanicalTheme.coolGreen, MechanicalTheme.coolTeal],
            ).createShader(bounds),
            child: Text(
              _modeTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _isHeating || _sendingCommand ? null : _saveSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isHeating || _sendingCommand
                    ? MechanicalTheme.metalDark
                    : _primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isHeating || _sendingCommand
                      ? MechanicalTheme.metalGray.withOpacity(0.5)
                      : _primaryColor.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_sendingCommand)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primaryColor,
                      ),
                    )
                  else
                    Icon(
                      Icons.save_outlined,
                      color: _isHeating ? MechanicalTheme.textDisabled : _primaryColor,
                      size: 18,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    'SAVE',
                    style: TextStyle(
                      color: _isHeating || _sendingCommand
                          ? MechanicalTheme.textDisabled
                          : _primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeDisplay() {
    if (_isHeating) {
      final minutes = (_remainingSeconds / 60).ceil();
      final timeText = '${minutes.toString().padLeft(2, '0')} min';
      final temperatureText = _stageTemps.isNotEmpty
          ? '${_stageTemps[_currentStage]}°C'
          : '--°C';

      return Stack(
        alignment: Alignment.center,
        children: [
          // 机械风外环
          CustomPaint(
            size: const Size(280, 280),
            painter: _ModeDisplayRingPainter(
              color: _primaryColor.withOpacity(0.3),
              stages: _stageNames.length,
              currentStage: _currentStage,
            ),
          ),
          // 旋转的设备图像
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Image.asset(
                _modeImage,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // 中心温度和时间
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                width: 180 * (0.9 + 0.1 * _glowController.value),
                height: 180 * (0.9 + 0.1 * _glowController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _primaryColor.withOpacity(0.15 * _glowController.value),
                      _primaryColor.withOpacity(0.05 * _glowController.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                temperatureText,
                style: const TextStyle(
                  color: MechanicalTheme.textPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: MechanicalTheme.heatOrange,
                      blurRadius: 15,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: MechanicalTheme.bgLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  timeText,
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // 非加热状态显示滚动选择器
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(280, 280),
          painter: _ModeDisplayRingPainter(
            color: _primaryColor.withOpacity(0.25),
            stages: _stageNames.length,
            currentStage: _currentStage,
          ),
        ),
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Image.asset(
            _modeImage,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(
          height: 160,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 60,
                width: 140,
                child: ListWheelScrollView.useDelegate(
                  controller: _tempScrollController,
                  itemExtent: 50,
                  physics: const FixedExtentScrollPhysics(),
                  perspective: 0.002,
                  diameterRatio: 1.2,
                  onSelectedItemChanged: _onTempChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: _tempValues.length,
                    builder: (context, index) {
                      return Center(
                        child: Text(
                          '${_tempValues[index]}°C',
                          style: const TextStyle(
                            color: MechanicalTheme.textPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 45,
                width: 100,
                child: ListWheelScrollView.useDelegate(
                  controller: _timeScrollController,
                  itemExtent: 40,
                  physics: const FixedExtentScrollPhysics(),
                  perspective: 0.002,
                  diameterRatio: 1.2,
                  onSelectedItemChanged: _onTimeChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: _timeValues.length,
                    builder: (context, index) {
                      return Center(
                        child: Text(
                          '${_timeValues[index].toString().padLeft(2, '0')} min',
                          style: TextStyle(
                            color: _primaryColor.withOpacity(0.8),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntervalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _primaryColor.withOpacity(0.3)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'INTERVALS / TIME',
                style: TextStyle(
                  color: MechanicalTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: MechanicalTheme.createMechanicalCardStyle(
            borderRadius: 20,
            borderColor: _primaryColor.withOpacity(0.25),
          ),
          child: Column(
            children: List.generate(_stageNames.length, (index) {
              final isCurrent = index == _currentStage;
              return Column(
                children: [
                  GestureDetector(
                    onTap: () => _onStageSelected(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? _primaryColor.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: index == 0
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              )
                            : index == _stageNames.length - 1
                                ? const BorderRadius.only(
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  )
                                : BorderRadius.zero,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _stageNames[index],
                            style: const TextStyle(
                              color: MechanicalTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: MechanicalTheme.createGlowShadow(_primaryColor, intensity: 0.5),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${_stageTemps[index]}°C',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_stageTimes[index]}min',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              '${_stageTemps[index]}°C / ${_stageTimes[index]}min',
                              style: TextStyle(
                                color: MechanicalTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (index != _stageNames.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Divider(
                        height: 1,
                        color: _primaryColor.withOpacity(0.15),
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Column(
      children: [
        GestureDetector(
          onTap: _startHeating,
          child: Container(
            width: 200,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.mode == 'classic'
                    ? [MechanicalTheme.primaryCyan, MechanicalTheme.coolTeal]
                    : [MechanicalTheme.coolGreen, MechanicalTheme.coolTeal],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: MechanicalTheme.createGlowShadow(_primaryColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isHeating ? Icons.refresh : Icons.local_fire_department,
                  color: Colors.black,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  _isHeating ? 'IN PROGRESS' : 'START SESSION',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _isHeating ? 'Session in progress...' : 'Tap to begin the session',
          style: TextStyle(
            color: MechanicalTheme.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// 模式显示环绘制器
class _ModeDisplayRingPainter extends CustomPainter {
  final Color color;
  final int stages;
  final int currentStage;

  _ModeDisplayRingPainter({
    required this.color,
    required this.stages,
    required this.currentStage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);

    // 绘制同心圆环
    for (int i = 0; i < 3; i++) {
      final radius = 90.0 + i * 30.0;
      paint.strokeWidth = 1.5 - i * 0.3;
      canvas.drawCircle(center, radius, paint);
    }

    // 绘制阶段点
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < stages; i++) {
      final angle = (2 * math.pi / stages) * i - math.pi / 2;
      final x = center.dx + math.cos(angle) * 120;
      final y = center.dy + math.sin(angle) * 120;
      
      if (i == currentStage) {
        paint.color = color.withOpacity(0.8);
        canvas.drawCircle(Offset(x, y), 5, paint);
        
        // 外圈光晕
        paint.color = color.withOpacity(0.3);
        canvas.drawCircle(Offset(x, y), 8, paint);
      } else {
        paint.color = color.withOpacity(0.3);
        canvas.drawCircle(Offset(x, y), 4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ModeDisplayRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.stages != stages ||
        oldDelegate.currentStage != currentStage;
  }
}
