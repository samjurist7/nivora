import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../theme/mechanical_theme.dart';
import '../widgets/smoke_background.dart';

/// Custom heat page - Mechanical style redesign
class CustomHeatPage extends StatefulWidget {
  const CustomHeatPage({super.key});

  @override
  State<CustomHeatPage> createState() => _CustomHeatPageState();
}

class _CustomHeatPageState extends State<CustomHeatPage> {
  int _selectedTime = 30;
  int _selectedTemp = 60;

  late FixedExtentScrollController _timeController;
  late FixedExtentScrollController _tempController;

  DateTime? _lastTimeInteraction;
  DateTime? _lastTempInteraction;

  static const Duration _syncDelay = Duration(seconds: 2);

  bool _isProgrammaticTimeScroll = false;
  bool _isProgrammaticTempScroll = false;

  bool _isUserScrollingTime = false;
  bool _isUserScrollingTemp = false;

  int? _lastSyncedTemp;
  int? _lastSyncedTime;

  @override
  void initState() {
    super.initState();
    _timeController = FixedExtentScrollController(initialItem: 0);
    _tempController = FixedExtentScrollController(initialItem: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromDevice();
    });
  }

  @override
  void dispose() {
    _timeController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  void _syncFromDevice() {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bluetoothService.deviceInfo;
    if (deviceInfo != null) {
      _updateFromDeviceInfo(deviceInfo);
    }
  }

  bool _canSyncTime() {
    if (_isUserScrollingTime) return false;
    if (_lastTimeInteraction == null) return true;
    return DateTime.now().difference(_lastTimeInteraction!) > _syncDelay;
  }

  bool _canSyncTemp() {
    if (_isUserScrollingTemp) return false;
    if (_lastTempInteraction == null) return true;
    return DateTime.now().difference(_lastTempInteraction!) > _syncDelay;
  }

  void _updateFromDeviceInfo(Map<String, dynamic> deviceInfo) {
    final setTemp = deviceInfo['setTemp'] as int?;
    final setTime = deviceInfo['setTime'] as int?;

    bool needsUpdate = false;

    if (_canSyncTemp() &&
        setTemp != null &&
        setTemp >= 60 &&
        setTemp <= 300 &&
        setTemp != _selectedTemp &&
        setTemp != _lastSyncedTemp) {
      _selectedTemp = setTemp;
      _lastSyncedTemp = setTemp;
      final tempIndex = _selectedTemp - 60;
      if (_tempController.hasClients) {
        _isProgrammaticTempScroll = true;
        _tempController.jumpToItem(tempIndex);
      }
      needsUpdate = true;
    }

    if (_canSyncTime() &&
        setTime != null &&
        setTime >= 30 &&
        setTime <= 120 &&
        setTime != _selectedTime &&
        setTime != _lastSyncedTime) {
      _selectedTime = setTime;
      _lastSyncedTime = setTime;
      final timeIndex = _selectedTime - 30;
      if (_timeController.hasClients) {
        _isProgrammaticTimeScroll = true;
        _timeController.jumpToItem(timeIndex);
      }
      needsUpdate = true;
    }

    if (needsUpdate) {
      setState(() {});
    }
  }

  Future<void> _sendDeviceParameter({
    int? newSetTemp,
    int? newSetTime,
    int? newStartHeating,
    int? newBoostCount,
  }) async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bluetoothService.deviceInfo;

    final lightMode = deviceInfo?['lightMode'] as int? ?? 0;
    final setTemp = newSetTemp ?? (deviceInfo?['setTemp'] as int? ?? _selectedTemp);
    final setTime = newSetTime ?? (deviceInfo?['setTime'] as int? ?? _selectedTime);
    final heatPreset = deviceInfo?['heatPreset'] as int? ?? 0;
    final startHeating = newStartHeating ?? (deviceInfo?['startHeating'] as int? ?? 0);
    final boostCount = newBoostCount ?? (deviceInfo?['boostCount'] as int? ?? 0);
    final motorLevel = deviceInfo?['motorLevel'] as int? ?? 0;
    final audioSwitch = deviceInfo?['audioSwitch'] as int? ?? 0;
    final tempUnit = deviceInfo?['tempUnit'] as int? ?? 0;

    try {
      await bluetoothService.sendDeviceParameter(
        lightMode,
        setTemp,
        setTime,
        heatPreset: heatPreset,
        startHeating: startHeating,
        boostCount: boostCount,
        motorLevel: motorLevel,
        audioSwitch: audioSwitch,
        tempUnit: tempUnit,
      );
      print('Custom Heat - Parameters sent: setTemp=$setTemp, setTime=$setTime, startHeating=$startHeating');
    } catch (e) {
      print('Custom Heat - Failed to send parameters: $e');
    }
  }

  void _onTimeScrollEnd() {
    if (_isProgrammaticTimeScroll) {
      _isProgrammaticTimeScroll = false;
      return;
    }
    _sendDeviceParameter(newSetTime: _selectedTime);
  }

  void _onTempScrollEnd() {
    if (_isProgrammaticTempScroll) {
      _isProgrammaticTempScroll = false;
      return;
    }
    _sendDeviceParameter(newSetTemp: _selectedTemp);
  }

  void _onStartHeating() {
    print('Custom Heat - Start Heating: Time=$_selectedTime min, Temp=$_selectedTemp°C');
    _sendDeviceParameter(newStartHeating: 1);
  }

  void _onPause() {
    print('Custom Heat - Pause');
    _sendDeviceParameter(newStartHeating: 0);
  }

  void _onBoost() {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final currentBoostCount = bluetoothService.deviceInfo?['boostCount'] as int? ?? 0;
    final newBoostCount = currentBoostCount + 1;
    print('Custom Heat - Boost: $currentBoostCount -> $newBoostCount');
    _sendDeviceParameter(newBoostCount: newBoostCount);
  }

  String _formatCountdown(int seconds) {
    if (seconds <= 0) return '0min0s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}min${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothService>(
      builder: (context, bluetoothService, child) {
        final deviceInfo = bluetoothService.deviceInfo;
        if (deviceInfo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateFromDeviceInfo(deviceInfo);
            }
          });
        }

        final countdownTime = deviceInfo?['countdown_time'] as int? ?? 0;
        final realTemp = deviceInfo?['realTemp'] as int? ?? 0;
        final startHeating = deviceInfo?['startHeating'] as int? ?? 0;
        final bPauseState = deviceInfo?['bPauseState'] as int? ?? 0;
        final bTempReady = deviceInfo?['bTempReady'] as int? ?? 0;

        return _buildContent(
          countdownTime: countdownTime,
          realTemp: realTemp,
          startHeating: startHeating,
          bPauseState: bPauseState,
          bTempReady: bTempReady,
        );
      },
    );
  }

  String _getStatusText(int startHeating, int bTempReady) {
    if (startHeating == 0) {
      return 'Pause';
    } else if (bTempReady == 0) {
      return 'Pre-heating';
    } else {
      return 'Enjoy Your Session';
    }
  }

  Widget _buildContent({
    required int countdownTime,
    required int realTemp,
    required int startHeating,
    required int bPauseState,
    required int bTempReady,
  }) {
    return SmokeBackground(
      smokeColor: const Color(0xFFFF6B35),
      particleCount: 8,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 30),
              // "0" label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: MechanicalTheme.bgLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MechanicalTheme.primaryCyan.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Text(
                  '0',
                  style: TextStyle(
                    color: MechanicalTheme.primaryCyan,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Status label
              Text(
                _getStatusText(startHeating, bTempReady),
                style: const TextStyle(
                  color: MechanicalTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 30),
              // Wheel selector area
              _buildWheelSelectors(),
              const SizedBox(height: 20),
              // Real-time data label row
              _buildRealTimeLabels(countdownTime: countdownTime, realTemp: realTemp),
              const Spacer(),
              // Bottom button area
              _buildBottomButtons(startHeating: startHeating, bPauseState: bPauseState),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealTimeLabels({required int countdownTime, required int realTemp}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: MechanicalTheme.createMechanicalCardStyle(
          borderRadius: 16,
          borderColor: MechanicalTheme.primaryCyan.withOpacity(0.25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildInfoLabel(
              icon: Icons.timer_outlined,
              label: 'Countdown',
              value: _formatCountdown(countdownTime),
            ),
            Container(
              width: 1,
              height: 50,
              color: MechanicalTheme.primaryCyan.withOpacity(0.2),
            ),
            _buildInfoLabel(
              icon: Icons.thermostat_outlined,
              label: 'Real Temp',
              value: '$realTemp°C',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLabel({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: MechanicalTheme.primaryCyan.withOpacity(0.7),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: MechanicalTheme.textSecondary,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: MechanicalTheme.primaryCyan,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MechanicalTheme.bgLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MechanicalTheme.primaryCyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: MechanicalTheme.primaryCyan,
                size: 18,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'CUSTOM HEAT',
                style: TextStyle(
                  color: MechanicalTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildWheelSelectors() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: MechanicalTheme.createMechanicalCardStyle(
          borderRadius: 20,
          borderColor: MechanicalTheme.primaryCyan.withOpacity(0.25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildWheelColumn(
              label: 'TIME',
              value: '$_selectedTime m',
              minValue: 30,
              maxValue: 120,
              step: 1,
              controller: _timeController,
              onChanged: (value) {
                _lastTimeInteraction = DateTime.now();
                _lastSyncedTime = value;
                setState(() {
                  _selectedTime = value;
                });
              },
              onScrollEnd: _onTimeScrollEnd,
            ),
            Container(
              width: 1,
              height: 150,
              color: MechanicalTheme.primaryCyan.withOpacity(0.2),
            ),
            _buildWheelColumn(
              label: 'TEMP',
              value: '$_selectedTemp°C',
              minValue: 60,
              maxValue: 300,
              step: 1,
              controller: _tempController,
              onChanged: (value) {
                _lastTempInteraction = DateTime.now();
                _lastSyncedTemp = value;
                setState(() {
                  _selectedTemp = value;
                });
              },
              onScrollEnd: _onTempScrollEnd,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheelColumn({
    required String label,
    required String value,
    required int minValue,
    required int maxValue,
    required int step,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onChanged,
    VoidCallback? onScrollEnd,
  }) {
    final itemCount = ((maxValue - minValue) ~/ step) + 1;

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: MechanicalTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 100,
          height: 150,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                if (label == 'TIME') {
                  _isUserScrollingTime = true;
                  _isProgrammaticTimeScroll = false;
                } else {
                  _isUserScrollingTemp = true;
                  _isProgrammaticTempScroll = false;
                }
              } else if (notification is ScrollEndNotification) {
                if (label == 'TIME') {
                  _isUserScrollingTime = false;
                } else {
                  _isUserScrollingTemp = false;
                }
                onScrollEnd?.call();
              }
              return false;
            },
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: 50,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.5,
              perspective: 0.005,
              onSelectedItemChanged: (index) {
                onChanged(minValue + (index * step));
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: itemCount,
                builder: (context, index) {
                  final itemValue = minValue + (index * step);
                  final isSelected = (label == 'TIME' && itemValue == _selectedTime) ||
                      (label == 'TEMP' && itemValue == _selectedTemp);
                  return Center(
                    child: Text(
                      label == 'TIME' ? '$itemValue m' : '$itemValue°C',
                      style: TextStyle(
                        color: isSelected ? MechanicalTheme.primaryCyan : MechanicalTheme.textSecondary.withOpacity(0.5),
                        fontSize: isSelected ? 24 : 18,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons({required int startHeating, required int bPauseState}) {
    if (startHeating == 1) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(
            text: 'PAUSE',
            onTap: _onPause,
            colors: [MechanicalTheme.warningRed, const Color(0xFFFF8E53)],
          ),
          const SizedBox(width: 20),
          _buildActionButton(
            text: 'BOOST',
            onTap: _onBoost,
            colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
          ),
        ],
      );
    }

    final buttonText = bPauseState == 1 ? 'RESTART' : 'START HEATING';
    return _buildActionButton(
      text: buttonText,
      onTap: _onStartHeating,
      colors: [MechanicalTheme.heatOrange, MechanicalTheme.heatRed],
      width: 220,
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onTap,
    required List<Color> colors,
    double width = 160,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: MechanicalTheme.createGlowShadow(colors.first),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
