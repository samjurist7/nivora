import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';

/// Set Side 页面 - 设置五个温度和五个时间
class SetSidePage extends StatefulWidget {
  const SetSidePage({super.key});

  @override
  State<SetSidePage> createState() => _SetSidePageState();
}

class _SetSidePageState extends State<SetSidePage> {
  // 温度范围: 60-250°C，步进1
  int _temp1 = 60;
  int _temp2 = 60;
  int _temp3 = 60;
  int _temp4 = 60;
  int _temp5 = 60;

  // 时间范围: 0-120分钟，步进1
  int _time1 = 0;
  int _time2 = 0;
  int _time3 = 0;
  int _time4 = 0;
  int _time5 = 0;

  // 滚轮控制器
  late FixedExtentScrollController _temp1Controller;
  late FixedExtentScrollController _temp2Controller;
  late FixedExtentScrollController _temp3Controller;
  late FixedExtentScrollController _temp4Controller;
  late FixedExtentScrollController _temp5Controller;
  late FixedExtentScrollController _time1Controller;
  late FixedExtentScrollController _time2Controller;
  late FixedExtentScrollController _time3Controller;
  late FixedExtentScrollController _time4Controller;
  late FixedExtentScrollController _time5Controller;

  // 记录上次同步的时间戳，用于判断是否有新的 B5 数据
  String? _lastSyncTimestamp;

  @override
  void initState() {
    super.initState();

    // 使用默认值初始化控制器
    _temp1Controller = FixedExtentScrollController(initialItem: 0);
    _temp2Controller = FixedExtentScrollController(initialItem: 0);
    _temp3Controller = FixedExtentScrollController(initialItem: 0);
    _temp4Controller = FixedExtentScrollController(initialItem: 0);
    _temp5Controller = FixedExtentScrollController(initialItem: 0);
    _time1Controller = FixedExtentScrollController(initialItem: 0);
    _time2Controller = FixedExtentScrollController(initialItem: 0);
    _time3Controller = FixedExtentScrollController(initialItem: 0);
    _time4Controller = FixedExtentScrollController(initialItem: 0);
    _time5Controller = FixedExtentScrollController(initialItem: 0);

    // 监听蓝牙数据更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
      bluetoothService.addListener(_updateFromBluetoothData);
      // 初始加载数据
      _updateFromBluetoothData();

      // 延迟更新滚轮位置，确保所有滚轮都已经渲染
      // 第一次尝试 - 100ms后
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          print('📍 First attempt to update scroll controllers (100ms)');
          _updateScrollControllers();
        }
      });

      // 第二次尝试 - 500ms后（给第5行更多时间渲染）
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          print('📍 Second attempt to update scroll controllers (500ms)');
          _updateScrollControllers();
        }
      });

      // 第三次尝试 - 1000ms后（最后一次尝试）
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          print('📍 Final attempt to update scroll controllers (1000ms)');
          _updateScrollControllers();
        }
      });
    });
  }

  /// 更新所有滚轮控制器的位置
  void _updateScrollControllers() {
    print('🔄 Updating scroll controllers...');
    print('Current values: temp5=$_temp5, time5=$_time5');

    // 温度范围 60-250，索引 = temp - 60
    if (_temp1Controller.hasClients) {
      _temp1Controller.jumpToItem(_temp1 - 60);
    }
    if (_temp2Controller.hasClients) {
      _temp2Controller.jumpToItem(_temp2 - 60);
    }
    if (_temp3Controller.hasClients) {
      _temp3Controller.jumpToItem(_temp3 - 60);
    }
    if (_temp4Controller.hasClients) {
      print("✅ _temp4Controller.hasClients");
      _temp4Controller.jumpToItem(_temp4 - 60);
    }
    if (_temp5Controller.hasClients) {
      print("✅ _temp5Controller.hasClients - updating to index ${_temp5 - 60}");
      _temp5Controller.jumpToItem(_temp5 - 60);
    } else {
      print("⚠️ _temp5Controller has NO clients - Row 5 not rendered!");
    }

    // 时间范围 0-120，索引 = time
    if (_time1Controller.hasClients) {
      _time1Controller.jumpToItem(_time1);
    }
    if (_time2Controller.hasClients) {
      _time2Controller.jumpToItem(_time2);
    }
    if (_time3Controller.hasClients) {
      _time3Controller.jumpToItem(_time3);
    }
    if (_time4Controller.hasClients) {
      print("✅ _time4Controller.hasClients");
      _time4Controller.jumpToItem(_time4);
    }
    if (_time5Controller.hasClients) {
      print("✅ _time5Controller.hasClients - updating to index $_time5");
      _time5Controller.jumpToItem(_time5);
    } else {
      print("⚠️ _time5Controller has NO clients - Row 5 not rendered!");
    }
  }

  @override
  void dispose() {
    // 移除蓝牙数据监听器
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    bluetoothService.removeListener(_updateFromBluetoothData);

    _temp1Controller.dispose();
    _temp2Controller.dispose();
    _temp3Controller.dispose();
    _temp4Controller.dispose();
    _temp5Controller.dispose();
    _time1Controller.dispose();
    _time2Controller.dispose();
    _time3Controller.dispose();
    _time4Controller.dispose();
    _time5Controller.dispose();
    super.dispose();
  }

  /// 从蓝牙数据更新界面（仅在收到新的 B5 数据时同步一次）
  void _updateFromBluetoothData() {
    if (!mounted) return;

    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final deviceInfo = bluetoothService.getDeviceInfo();

    if (deviceInfo == null) return;

    // 检查是否有 side 温度时间数据
    if (deviceInfo.containsKey('side_temp1')) {
      // 使用专门的 side_lastUpdate 时间戳，只在收到 B5 命令时更新
      final currentTimestamp = deviceInfo['side_lastUpdate'] as String?;

      // 只有当 B5 时间戳变化时才更新（说明收到了新的 B5 数据）
      if (currentTimestamp != null && currentTimestamp != _lastSyncTimestamp) {
        // 检查确实有 side 数据的所有字段（5个温度 + 5个时间）
        if (deviceInfo.containsKey('side_temp1') &&
            deviceInfo.containsKey('side_temp2') &&
            deviceInfo.containsKey('side_temp3') &&
            deviceInfo.containsKey('side_temp4') &&
            deviceInfo.containsKey('side_temp5') &&
            deviceInfo.containsKey('side_time1') &&
            deviceInfo.containsKey('side_time2') &&
            deviceInfo.containsKey('side_time3') &&
            deviceInfo.containsKey('side_time4') &&
            deviceInfo.containsKey('side_time5')) {

          final newTemp1 = deviceInfo['side_temp1'] as int;
          final newTemp2 = deviceInfo['side_temp2'] as int;
          final newTemp3 = deviceInfo['side_temp3'] as int;
          final newTemp4 = deviceInfo['side_temp4'] as int;
          final newTemp5 = deviceInfo['side_temp5'] as int;
          final newTime1 = deviceInfo['side_time1'] as int;
          final newTime2 = deviceInfo['side_time2'] as int;
          final newTime3 = deviceInfo['side_time3'] as int;
          final newTime4 = deviceInfo['side_time4'] as int;
          final newTime5 = deviceInfo['side_time5'] as int;

          // 只有当至少有一个值发生变化时才更新
          if (newTemp1 != _temp1 || newTemp2 != _temp2 || newTemp3 != _temp3 || newTemp4 != _temp4 || newTemp5 != _temp5 ||
              newTime1 != _time1 || newTime2 != _time2 || newTime3 != _time3 || newTime4 != _time4 || newTime5 != _time5) {

            _lastSyncTimestamp = currentTimestamp;

            setState(() {
              _temp1 = newTemp1;
              _temp2 = newTemp2;
              _temp3 = newTemp3;
              _temp4 = newTemp4;
              _temp5 = newTemp5;
              _time1 = newTime1;
              _time2 = newTime2;
              _time3 = newTime3;
              _time4 = newTime4;
              _time5 = newTime5;
            });

            // 更新滚轮控制器位置
            _updateScrollControllers();

            print('Synced from Bluetooth B5 command: temp1=$_temp1, temp2=$_temp2, temp3=$_temp3, temp4=$_temp4, temp5=$_temp5, time1=$_time1, time2=$_time2, time3=$_time3, time4=$_time4, time5=$_time5');
          }
        }
      }
    }
  }

  /// 点击 Set 按钮，发送蓝牙命令
  void _onSetButtonPressed() async {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);

    try {
      // 构建命令：C1 0D temp1 temp2 temp3 temp4 temp5 time1 time2 time3 time4 time5 C1
      List<int> command = [
        0xC1, // Type
        0x0D, // Length (13 bytes)
        _temp1,
        _temp2,
        _temp3,
        _temp4,
        _temp5,
        _time1,
        _time2,
        _time3,
        _time4,
        _time5,
        0xC1, // Check byte
      ];

      print('Sending Set Side command: ${command.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(' ')}');
      print('Values: temp1=$_temp1, temp2=$_temp2, temp3=$_temp3, temp4=$_temp4, temp5=$_temp5, time1=$_time1, time2=$_time2, time3=$_time3, time4=$_time4, time5=$_time5');

      await bluetoothService.sendCommand(
        command,
        serviceUuid: BluetoothService.targetServiceUuid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set Side command sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Failed to send Set Side command: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send command: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_main.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部标题和返回按钮
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Set Side',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // 占位，保持标题居中
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 5行，每行显示一个temp和time
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  children: [
                    _buildRowWidget(
                      '1',
                      _temp1Controller,
                      _time1Controller,
                      (index) => setState(() => _temp1 = 60 + index),
                      (index) => setState(() => _time1 = index),
                      _temp1,
                      _time1,
                    ),
                    const SizedBox(height: 8),
                    _buildRowWidget(
                      '2',
                      _temp2Controller,
                      _time2Controller,
                      (index) => setState(() => _temp2 = 60 + index),
                      (index) => setState(() => _time2 = index),
                      _temp2,
                      _time2,
                    ),
                    const SizedBox(height: 8),
                    _buildRowWidget(
                      '3',
                      _temp3Controller,
                      _time3Controller,
                      (index) => setState(() => _temp3 = 60 + index),
                      (index) => setState(() => _time3 = index),
                      _temp3,
                      _time3,
                    ),
                    const SizedBox(height: 8),
                    _buildRowWidget(
                      '4',
                      _temp4Controller,
                      _time4Controller,
                      (index) => setState(() => _temp4 = 60 + index),
                      (index) => setState(() => _time4 = index),
                      _temp4,
                      _time4,
                    ),
                    const SizedBox(height: 8),
                    _buildRowWidget(
                      '5',
                      _temp5Controller,
                      _time5Controller,
                      (index) => setState(() => _temp5 = 60 + index),
                      (index) => setState(() => _time5 = index),
                      _temp5,
                      _time5,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Set 按钮
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: GestureDetector(
                  onTap: _onSetButtonPressed,
                  child: Container(
                    width: 200,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3DD6F5), Color(0xFF66FF7F)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3DD6F5).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Set',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建每一行的widget，包含temp和time
  Widget _buildRowWidget(
    String rowLabel,
    FixedExtentScrollController tempController,
    FixedExtentScrollController timeController,
    Function(int) onTempChanged,
    Function(int) onTimeChanged,
    int currentTemp,
    int currentTime,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 行号标签
          SizedBox(
            width: 40,
            child: Text(
              rowLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 温度滚轮
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Temp (°C)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3DD6F5).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ListWheelScrollView.useDelegate(
                    controller: tempController,
                    itemExtent: 40,
                    diameterRatio: 1.5,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: onTempChanged,
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, index) {
                        if (index < 0 || index > 190) return null;
                        final value = 60 + index;
                        return Center(
                          child: Text(
                            '$value°C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                      childCount: 191,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$currentTemp°C',
                  style: const TextStyle(
                    color: Color(0xFF3DD6F5),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 时间滚轮
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Time (min)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFB347).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: ListWheelScrollView.useDelegate(
                    controller: timeController,
                    itemExtent: 40,
                    diameterRatio: 1.5,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: onTimeChanged,
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, index) {
                        if (index < 0 || index > 120) return null;
                        return Center(
                          child: Text(
                            '$index min',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                      childCount: 121,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$currentTime min',
                  style: const TextStyle(
                    color: Color(0xFFFFB347),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建温度滚轮 (60-250)
  Widget _buildTempWheel(
    String label,
    FixedExtentScrollController controller,
    Function(int) onSelectedItemChanged,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 100,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF3DD6F5).withOpacity(0.3),
              width: 2,
            ),
          ),
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 40,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onSelectedItemChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index > 190) return null; // 60-250 = 191个值
                final value = 60 + index;
                return Center(
                  child: Text(
                    '$value°C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
              childCount: 191, // 60-250 共191个值
            ),
          ),
        ),
      ],
    );
  }

  /// 构建时间滚轮 (0-30)
  Widget _buildTimeWheel(
    String label,
    FixedExtentScrollController controller,
    Function(int) onSelectedItemChanged,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 100,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFB347).withOpacity(0.3),
              width: 2,
            ),
          ),
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 40,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onSelectedItemChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index > 120) return null; // 0-120 = 121个值
                return Center(
                  child: Text(
                    '$index min',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
              childCount: 121, // 0-120 共121个值
            ),
          ),
        ),
      ],
    );
  }
}
