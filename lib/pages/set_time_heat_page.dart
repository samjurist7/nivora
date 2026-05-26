import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';

/// 设置时间的加热页面
class SetTimeHeatPage extends StatefulWidget {
  final Duration initialDuration;
  final bool initialLightEnabled;
  final Color accentColor;

  const SetTimeHeatPage({
    Key? key,
    required this.initialDuration,
    required this.initialLightEnabled,
    required this.accentColor,
  }) : super(key: key);

  @override
  State<SetTimeHeatPage> createState() => _SetTimeHeatPageState();
}

class _SetTimeHeatPageState extends State<SetTimeHeatPage> {
  late Duration _duration;
  late bool _lightEnabled;
  bool _sending = false;
  int _boostCount = 0; // boost 计数，初始值为 0

  @override
  void initState() {
    super.initState();
    _duration = widget.initialDuration;
    _lightEnabled = widget.initialLightEnabled;
    _setupBluetoothListener();
  }

  /// 设置蓝牙数据监听
  void _setupBluetoothListener() {
    final bt = Provider.of<BluetoothService>(context, listen: false);
    bt.addListener(_onBluetoothDataChanged);
  }

  void _onBluetoothDataChanged() {
    final bt = Provider.of<BluetoothService>(context, listen: false);
    final info = bt.getDeviceInfo();
    if (info != null && info['setTime'] != null) {
      final newTime = info['setTime'] as int;
      // 只在时间有变化时更新
      if (newTime != _duration.inMinutes && mounted) {
        setState(() {
          _duration = Duration(minutes: newTime);
        });
        print('⏱️ SetTimeHeatPage: 收到设备时间更新 -> $newTime 分钟');
      }
    }
  }

  @override
  void dispose() {
    final bt = Provider.of<BluetoothService>(context, listen: false);
    bt.removeListener(_onBluetoothDataChanged);
    super.dispose();
  }

  int get _minutes => _duration.inMinutes;

  String get _formattedTime => '${_minutes.toString().padLeft(2, '0')} min';

  Color get _accent => widget.accentColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_main.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildTopGlow(),
                      const SizedBox(height: 16),
                      _buildTimeDisplay(),
                      const SizedBox(height: 16),
                      Text(
                        'Remaining\nTime',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 18,
                          height: 1.2,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildControlRow(),
                      const SizedBox(height: 40),
                      _buildBoostButton(),
                      const SizedBox(height: 40),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Set Time',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48), // 占位，保持标题居中
        ],
      ),
    );
  }

  Widget _buildTopGlow() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        _accent.withOpacity(0.8),
        BlendMode.modulate,
      ),
      child: Image.asset(
        'assets/images/icon_set_time_line.png',
        height: 120,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildTimeDisplay() {
    return GestureDetector(
      onTap: _openDurationPicker,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/bg_set_time_main.png',
            width: 260,
            height: 260,
            fit: BoxFit.contain,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formattedTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCircleOption(
          asset: 'assets/images/icon_light.png',
          isActive: _lightEnabled,
          onTap: () {
            setState(() {
              _lightEnabled = !_lightEnabled;
            });
          },
        ),
        _buildCircleOption(
          asset: 'assets/images/icon_total_duration.png',
          isActive: true,
          onTap: _openDurationPicker,
        ),
      ],
    );
  }

  Widget _buildCircleOption({
    required String asset,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          isActive ? Colors.white : Colors.white.withOpacity(0.35),
          BlendMode.modulate,
        ),
        child: Image.asset(
          asset,
          width: 150,
          height: 150,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildBoostButton() {
    return GestureDetector(
      onTap: _sending ? null : _handleBoost,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              _accent.withOpacity(0.9),
              BlendMode.modulate,
            ),
            child: Image.asset(
              'assets/images/bg_btn_boost.png',
              width: 220,
              height: 92,
              fit: BoxFit.contain,
            ),
          ),
          const Text(
            'BOOST',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
          if (_sending)
            const Positioned(
              bottom: 14,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openDurationPicker() async {
    const int minMinutes = 30;
    const int maxMinutes = 120;
    int selectedMinutes = _clampInt(_minutes, minMinutes, maxMinutes);

    final minuteController =
        FixedExtentScrollController(initialItem: selectedMinutes - minMinutes);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 320,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const Text(
                      'Select Duration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _duration = Duration(minutes: selectedMinutes);
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Confirm',
                        style: TextStyle(color: _accent),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 120,
                    child: _buildPickerColumn(
                      title: 'MIN',
                      controller: minuteController,
                      itemCount: maxMinutes - minMinutes + 1, // 91项: 30-120
                      displayBuilder: (index) =>
                          (minMinutes + index).toString().padLeft(2, '0'),
                      onSelected: (index) =>
                          selectedMinutes = minMinutes + index,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickerColumn({
    required String title,
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int) displayBuilder,
    required ValueChanged<int> onSelected,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            letterSpacing: 1.5,
          ),
        ),
        Expanded(
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 36,
            diameterRatio: 1.2,
            squeeze: 1.2,
            onSelectedItemChanged: onSelected,
            looping: false,
            selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
              background: _accent.withOpacity(0.15),
            ),
            children: List.generate(
              itemCount,
              (index) => Center(
                child: Text(
                  displayBuilder(index),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleBoost() async {
    // boost 值加 1，最大值为 12
    if (_boostCount >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Boost 已达到最大值 12'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _boostCount = _boostCount + 1;
      _sending = true;
    });

    final int minutes = _clampInt(_minutes, 30, 120);

    print(
        '⚙️ BOOST 操作 -> boostCount=$_boostCount, duration=${minutes}分钟, lightEnabled=$_lightEnabled | 准备发送 device_parameter (0xA9) (参照@蓝牙命令.xlsx)');

    await StorageService.setSetTime(minutes);
    await StorageService.setLightEnabled(_lightEnabled);

    final bt = Provider.of<BluetoothService>(context, listen: false);
    final lightMode = StorageService.getLightMode();
    final setTemp = StorageService.getSetTemp();

    try {
      if (bt.connectedDevice != null) {
        // 发送 0xA9 指令，使用最新的 boost 值
        await bt.sendDeviceParameter(
          lightMode,
          setTemp,
          minutes,
          heatPreset: 0,
          startHeating: 1, // 启动加热
          boostCount: _boostCount, // 使用最新的 boost 值
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Boost +1 (当前: $_boostCount), 加热时间已更新为 $minutes 分钟'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设备未连接, 已保存设置'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('发送失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
      // 如果发送失败，回退 boost 计数
      if (mounted) {
        setState(() {
          _boostCount = _boostCount - 1;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

