import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';
import 'web_ble.dart';

// Web端调试日志，输出到页面BLE调试面板
void _webLog(String msg) {
  print(msg);
  if (kIsWeb) {
    try {
      // 动态导入避免非Web平台报错，通过web_ble_web.dart中的_jsLog实现
      WebBleLogger.log(msg);
    } catch (_) {}
  }
}

/// Bluetooth service class
/// Responsible for handling Bluetooth device connection, scanning, command sending, and data reception
class BluetoothService extends ChangeNotifier {
  bool scanning = false;
  List<Map<String, dynamic>> devices = [];
  dynamic connectedDevice;

  // Device info cache
  Map<String, dynamic>? deviceInfo;

  // Option name cache (Key: index 0-4, Value: name)
  final Map<int, String> _optionNames = {};
  // Option name buffer (Key: index 0-4, Value: 32 bytes)
  final Map<int, List<int>> _optionNameBuffers = {};
  // Option description cache (Key: index 0-4, Value: description) - stored locally
  final Map<int, String> _optionDescriptions = {};

  BluetoothService() {
    _loadDescriptions();
  }

  Future<void> _loadDescriptions() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < 5; i++) {
      final desc = prefs.getString('option_desc_$i');
      if (desc != null) _optionDescriptions[i] = desc;
    }
    notifyListeners();
  }

  String getOptionDescription(int btIndex) {
    return _optionDescriptions[btIndex] ?? '';
  }

  Future<void> saveOptionDescription(int btIndex, String description) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('option_desc_$btIndex', description);
    _optionDescriptions[btIndex] = description;
    notifyListeners();
  }
  
  StreamSubscription? _notificationSub;

  StreamSubscription? _scanSub;
  StreamSubscription? _stateSub;

  // Target device configuration
  static const String targetServiceUuid = '59462f12-9543-9999-12c8-58b459a2712d';
  static const String receiveCharacteristicUuid = '33333333-2222-2222-1111-111100000000';  // 接收特征 (notify) - 收发同一特征
  static const List<String> targetDeviceNames = ['JW203', 'JW302', 'NIVORA', 'MOBIKE']; // All uppercase names
  static const List<String> targetDevicePrefixes = ['ESP32_','VOLTA_']; // Prefix match

  static const Map<int, String> _appToDeviceCommandNames = {
    0xA1: 'classic_temp_time (APP->Device)',
    0xA2: 'herbal_temp_time (APP->Device)',
    0xA3: 'wifi_ssid_part1 (APP->Device)',
    0xA4: 'wifi_ssid_part2 (APP->Device)',
    0xA5: 'wifi_password (APP->Device)',
    0xA6: 'ota_start (APP->Device)',
    0xAB: 'ota_sd_card (APP->Device)',
    0xA7: 'option_name_part1 (APP->Device)',
    0xA8: 'option_name_part2 (APP->Device)',
    0xA9: 'device_parameter (APP->Device)',
    0xAA: 'sync_time (APP->Device)',
    0xC2: 'reset_command (APP->Device)',
  };

  static const Map<int, String> _deviceToAppCommandNames = {
    0xB1: 'classic_temp_time (Device->APP)',
    0xB2: 'herbal_temp_time (Device->APP)',
    0xB3: 'option_name_part1 (Device->APP)',
    0xB4: 'option_name_part2 (Device->APP)',
    0xB5: 'side_temp_time (Device->APP)',
    0xB6: 'tcr_init (Device->APP)',
    0xB9: 'device_parameter (Device->APP)',
    0xBA: 'top_temp (Device->APP)',
  };

  // ==================== Basic Connection Methods ====================

  /// Scan for devices, filter using target Service UUID and device name
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    devices.clear();
    scanning = true;
    notifyListeners();
    if (kIsWeb) {
      scanning = false;
      notifyListeners();
      return;
    }
    _scanSub?.cancel();
    try {
      // Filter using target Service UUID
      final serviceUuid = fb.Guid(targetServiceUuid);
      print('🔍 开始扫描，过滤条件: Service UUID=$targetServiceUuid, 设备名称=${targetDeviceNames.join("或")}, 前缀=${targetDevicePrefixes.join("或")}');
      
      await fb.FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: [],
      );
      
      _scanSub = fb.FlutterBluePlus.scanResults.listen((results) {
        for (var r in results) {
          final id = r.device.remoteId.str;
          final name = r.device.platformName.isNotEmpty 
              ? r.device.platformName 
              : (r.advertisementData.advName.isNotEmpty 
                  ? r.advertisementData.advName 
                  : 'Unknown');
          
          // Filter device names: exact match or prefix match
          final upperName = name.toUpperCase();
          final isExactMatch = targetDeviceNames.contains(upperName);
          final isPrefixMatch = targetDevicePrefixes.any((prefix) => upperName.startsWith(prefix));
          if (!isExactMatch && !isPrefixMatch) {
            print('⏭️  跳过设备: $name (不符合目标设备名称或前缀)');
            continue;
          }
          
          print('✅ 找到目标设备: $name (ID: $id, RSSI: ${r.rssi})');
          
          final entry = {
            'id': id, 
            'name': name, 
            'rssi': r.rssi, 
            'device': r.device
          };
          
          final idx = devices.indexWhere((d) => d['id'] == id);
          if (idx >= 0) {
            devices[idx] = entry;
          } else {
            devices.add(entry);
          }
        }
        notifyListeners();
      });
      
      Future.delayed(timeout, () {
        stopScan();
        print('⏹️  Scan completed, found ${devices.length} target devices');
      });
    } catch (e) {
      scanning = false;
      notifyListeners();
      print('❌ startScan error: $e');
    }
  }

  Future<void> stopScan() async {
    if (!kIsWeb) {
      await _scanSub?.cancel();
      await fb.FlutterBluePlus.stopScan();
    }
    scanning = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> requestDeviceWeb() async {
    if (!kIsWeb) return {'error': 'not_web'};
    final res = await WebBle.requestDevice();
    return res;
  }

  Future<void> connect(dynamic device) async {
    if (kIsWeb) {
      try {
        _webLog('[connect] 1. 开始连接...');
        final result = await WebBle.connectDevice();
        if (result['error'] != null) {
          _webLog('[connect] 1. FAILED: ${result['error']}');
          throw Exception(result['error']);
        }
        _webLog('[connect] 1. GATT连接成功');

        _webLog('[connect] 2. 发现服务...');
        final serviceResult = await WebBle.discoverServices(targetServiceUuid);
        if (serviceResult['error'] != null) {
          _webLog('[connect] 2. 服务发现失败: ${serviceResult['error']}');
        } else {
          _webLog('[connect] 2. 服务发现成功');
        }

        // Set disconnect callback
        WebBle.onDisconnected = () {
          _webLog('[connect] 设备断开连接');
          connectedDevice = null;
          notifyListeners();
        };

        _webLog('[connect] 3. 启用通知...');
        await _startListeningNotificationsWeb();
        _webLog('[connect] 3. 通知已启用');
        
        // iOS 特殊处理：启用通知后等待 200ms 再写入，避免 iOS 丢弃写入请求
        _webLog('[connect] 等待 200ms 后写入...');
        await Future.delayed(const Duration(milliseconds: 200));

        connectedDevice = device ?? 'web_device';
        _webLog('[connect] 4. connectedDevice=$connectedDevice');
        notifyListeners();

        // Sync time after connection (失败不影响连接)
        _webLog('[connect] 5. syncTime...');
        try {
          await syncTime().timeout(const Duration(seconds: 3));
          _webLog('[connect] 5. syncTime成功');
        } catch (e) {
          _webLog('[connect] 5. syncTime失败(non-fatal): $e');
        }

        _webLog('[connect] 完成!');
        return;
      } catch (e) {
        _webLog('[connect] EXCEPTION: $e');
        rethrow;
      }
    }
    try {
      print('🔌 正在连接设备: ${device.platformName}...');
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));
      connectedDevice = device;
      print('✅ Device connected successfully');
      
      _stateSub?.cancel();
      _stateSub = device.state.listen((s) {
        print('📡 设备状态变化: $s');
        if (s == fb.BluetoothConnectionState.disconnected) {
          print('⚠️  Device disconnected');
          connectedDevice = null;
          _notificationSub?.cancel();
        }
        notifyListeners();
      });
      
      // Start listening for data after connection
      await _startListeningNotifications();

      // Sync time after connection
      await syncTime();

      // Send test commands after connection
      await _sendTestCommands();
      
      notifyListeners();
    } catch (e) {
      print('❌ connect error: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (kIsWeb) {
      try {
        print('🔌 [Web] Disconnecting...');
        await WebBle.disableNotifications();
        await WebBle.disconnectDevice();
        print('✅ [Web] Disconnected');
      } catch (e) {
        print('⚠️ [Web] disconnect error: $e');
      }
      connectedDevice = null;
      notifyListeners();
      return;
    }
    try {
      await _notificationSub?.cancel();
      await connectedDevice?.disconnect();
    } catch (e) {}
    connectedDevice = null;
    await _stateSub?.cancel();
    notifyListeners();
  }

  /// 发送原始命令数据
  /// @param bytes 要发送的字节数组
  /// @param serviceUuid 可选的服务UUID，如果为null则自动查找
  /// @param characteristicUuid 可选的特征UUID，如果为null则自动查找
  Future<void> sendCommand(
    List<int> bytes, {
    String? serviceUuid,
    String? characteristicUuid,
  }) async {
    if (kIsWeb) {
      final isConn = WebBle.isConnected();
      final cmdByte = bytes.isNotEmpty ? bytes[0].toRadixString(16).toUpperCase() : "??";
      _webLog('[sendCmd] isConnected=$isConn, bytes=${bytes.length} cmd=0x$cmdByte');
      if (!isConn) {
        _webLog('[sendCmd] BLOCKED: isConnected=false');
        throw Exception('[Web] Device not connected');
      }
      try {
        // iOS Web: UUID 统一转小写，避免大小写不匹配
        final writeCharUuid = (characteristicUuid ?? receiveCharacteristicUuid).toLowerCase();
        final targetService = (serviceUuid ?? targetServiceUuid).toLowerCase();
        _webLog('[sendCmd] target service=$targetService char=$writeCharUuid');
        final result = await WebBle.writeCharacteristic(
          targetService,
          writeCharUuid,
          bytes,
        );
        _webLog('[sendCmd] result type=${result.runtimeType} keys=${result.keys.join(",")}');
        if (result['error'] != null) {
          _webLog('[sendCmd] FAILED: ${result['error']}');
          throw Exception(result['error']);
        }
        _webLog('[sendCmd] OK');
        return;
      } catch (e) {
        _webLog('[sendCmd] EXCEPTION: $e');
        rethrow;
      }
    }
    if (connectedDevice == null) {
      throw Exception('Device not connected');
    }
    try {
      _logAppToDevice(bytes,
          note:
              'serviceUuid=${serviceUuid ?? "auto"} characteristicUuid=${characteristicUuid ?? "auto"}');
      final services = await connectedDevice.discoverServices();

      // 如果指定了服务UUID和特征UUID，优先使用
      if (serviceUuid != null && characteristicUuid != null) {
        final targetServiceGuid = fb.Guid(serviceUuid);
        final targetCharGuid = fb.Guid(characteristicUuid);
        
        for (var s in services) {
          if (s.uuid == targetServiceGuid) {
            for (var c in s.characteristics) {
              if (c.uuid == targetCharGuid) {
                if (c.properties.write || c.properties.writeWithoutResponse) {
                  await c.write(
                    Uint8List.fromList(bytes),
                    withoutResponse: c.properties.writeWithoutResponse,
                  );
                  print('✅ 命令已发送到指定特征: $characteristicUuid');
                  return;
                }
              }
            }
          }
        }
        print('⚠️  Specified service or characteristic not found, trying auto-search...');
      }
      
      // 如果指定了服务UUID但没有指定特征UUID，只在目标服务中查找可写特征
      if (serviceUuid != null) {
        final targetServiceGuid = fb.Guid(serviceUuid);
        print('🔍 Searching for writable characteristic in target service $serviceUuid...');

        // Print all discovered services first for debugging
        print('📋 List of discovered services:');
        for (var s in services) {
          print('  - 服务: ${s.uuid} (${s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase() ? "✅ 目标服务" : ""})');
        }
        
        for (var s in services) {
          if (s.uuid == targetServiceGuid) {
            print('✅ 找到目标服务: ${s.uuid}');
            print('📋 该服务中的特征列表:');
            for (var c in s.characteristics) {
              print('  - 特征: ${c.uuid}, 属性: ${c.properties}');
            }
            
            // Prioritize searching for writeWithoutResponse characteristic (usually more reliable)
            for (var c in s.characteristics) {
              if (c.properties.writeWithoutResponse) {
                try {
                  print('🔄 Trying to use characteristic ${c.uuid} (writeWithoutResponse)...');
                  await c.write(
                    Uint8List.fromList(bytes),
                    withoutResponse: true,
                  );
                  print('✅ 命令已成功发送到特征: ${c.uuid}');
                  return;
                } catch (e) {
                  print('⚠️  特征 ${c.uuid} 写入失败: $e，尝试下一个特征...');
                  continue;
                }
              }
            }
            
            // If no writeWithoutResponse, try write
            for (var c in s.characteristics) {
              if (c.properties.write) {
                try {
                  print('🔄 Trying to use characteristic ${c.uuid} (write)...');
                  await c.write(
                    Uint8List.fromList(bytes),
                    withoutResponse: false,
                  );
                  print('✅ 命令已成功发送到特征: ${c.uuid}');
                  return;
                } catch (e) {
                  print('⚠️  特征 ${c.uuid} 写入失败: $e，尝试下一个特征...');
                  continue;
                }
              }
            }
            
            throw Exception('No writable characteristic found in target service');
          }
        }
        
        // 如果目标服务未找到，打印详细信息
        print('❌ 未找到目标服务: $serviceUuid');
        print('📋 请检查设备是否支持该服务，或服务UUID是否正确');
        throw Exception('未找到目标服务: $serviceUuid');
      }
      
      // 如果没有指定服务UUID，自动查找所有服务中的可写特征（最后备选方案）
      print('⚠️  未指定服务UUID，在所有服务中查找可写特征...');
      for (var s in services) {
        print('🔍 服务: ${s.uuid}');
        for (var c in s.characteristics) {
          print('  - 特征: ${c.uuid}, 属性: ${c.properties}');
          if (c.properties.write || c.properties.writeWithoutResponse) {
            try {
              await c.write(
                Uint8List.fromList(bytes),
                withoutResponse: c.properties.writeWithoutResponse,
              );
              print('✅ 命令已发送到特征: ${c.uuid}');
              return;
            } catch (e) {
              print('⚠️  特征 ${c.uuid} 写入失败: $e，尝试下一个特征...');
              continue; // 尝试下一个特征
            }
          }
        }
      }
      throw Exception('No writable characteristic found');
    } catch (e) {
      print('❌ sendCommand error: $e');
      rethrow;
    }
  }

  /// 开始监听设备通知数据
  /// 使用指定的接收特征UUID: 33333333-2222-2222-1111-111100000000
  Future<void> _startListeningNotifications() async {
    if (kIsWeb || connectedDevice == null) return;
    
    try {
      print('📡 Start listening for device notification data...');
      final services = await connectedDevice.discoverServices();
      
      final receiveCharGuid = fb.Guid(receiveCharacteristicUuid);
      
      // 优先查找指定的接收特征UUID
      for (var s in services) {
        print('🔍 检查服务: ${s.uuid}');
        for (var c in s.characteristics) {
          print('  - 特征: ${c.uuid}, 属性: ${c.properties}');
          if (c.uuid == receiveCharGuid) {
            if (c.properties.notify || c.properties.indicate) {
              await c.setNotifyValue(true);
              print('✅ 已启用通知监听: ${c.uuid}');
              _notificationSub = c.onValueReceived.listen((data) {
                print('📥 收到数据通知: [${data.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(', ')}]');
                _handleReceivedData(data);
              });
              return;
            }
          }
        }
      }
      
      // 如果没找到指定的特征，尝试自动查找
      print('⚠️  未找到指定的接收特征UUID，尝试自动查找...');
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.notify || c.properties.indicate) {
            await c.setNotifyValue(true);
            print('✅ 已启用通知监听（自动查找）: ${c.uuid}');
            _notificationSub = c.onValueReceived.listen((data) {
              print('📥 收到数据通知: [${data.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(', ')}]');
              _handleReceivedData(data);
            });
            return;
          }
        }
      }
      
      print('⚠️  No available notification characteristic found');
    } catch (e) {
      print('❌ _startListeningNotifications error: $e');
    }
  }

  /// [Web] Start listening for device notification data
  Future<void> _startListeningNotificationsWeb() async {
    try {
      print('📡 [Web] Start listening for device notification data...');

      // Set notification callback
      WebBle.onNotificationReceived = (List<int> data) {
        print('📥 [Web] 收到数据通知: [${data.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(', ')}]');
        _handleReceivedData(Uint8List.fromList(data));
      };

      // Enable notifications
      final result = await WebBle.enableNotifications(
        targetServiceUuid,
        receiveCharacteristicUuid,
      );

      if (result['error'] != null) {
        print('⚠️ [Web] 启用通知失败: ${result['error']}');
      } else {
        print('✅ [Web] Notification listening enabled');
      }
    } catch (e) {
      print('❌ [Web] _startListeningNotificationsWeb error: $e');
    }
  }

  /// Send test commands
  Future<void> _sendTestCommands() async {
    if (connectedDevice == null) return;
    
    print('\n🧪 ========== Starting to send test commands ==========');

    // Wait a moment to ensure service discovery is complete
    await Future.delayed(const Duration(milliseconds: 1000));
    
    try {
      // 测试1: 发送设备参数设置命令 (0xA9)
      // 使用默认值：灯光模式=0, 设置温度=200, 设置时间=60
      // print('\n📤 测试1: 发送设备参数设置命令 (0xA9)');
      // print('   参数: 灯光模式=0, 设置温度=200°C, 设置时间=60分钟');
      // await sendDeviceParameter(0, 200, 60);
      // await Future.delayed(const Duration(milliseconds: 500));
      
      // // 测试2: 发送简单的测试命令（使用指定的服务UUID和特征UUID）
      // print('\n📤 测试2: 发送简单测试命令 [0x01, 0x02, 0x03]');
      // print('   使用服务UUID: $targetServiceUuid');
      // await sendCommand(
      //   [0x01, 0x02, 0x03],
      //   serviceUuid: targetServiceUuid,
      //   characteristicUuid: null, // 自动查找可写特征
      // );
      // await Future.delayed(const Duration(milliseconds: 500));
      
      // // 测试3: 发送另一个测试命令
      // print('\n📤 测试3: 发送测试命令 [0xFF, 0xFE, 0xFD]');
      // await sendCommand([0xFF, 0xFE, 0xFD]);
      // await Future.delayed(const Duration(milliseconds: 500));
      
      // // 测试4: 发送Classic模式温度时间设置 (0xA1)
      // print('\n📤 测试4: 发送Classic模式温度时间设置 (0xA1)');
      // print('   温度: [200, 220, 240, 260, 280], 时间: [10, 20, 30, 40, 50]');
      // await sendClassicTempTime([200, 220, 240, 260, 280], [10, 20, 30, 40, 50]);
      
      print('\n✅ 所有测试指令已发送，等待设备响应...\n');
      print('📡 请观察设备响应数据...\n');
      print('💡 提示: 设备数据会通过特征UUID $receiveCharacteristicUuid 接收\n');
    } catch (e) {
      print('❌ 发送测试指令失败: $e');
      print('   错误详情: ${e.toString()}');
    }
  }

  /// Sync phone time to device (0xAA command)
  Future<void> syncTime() async {
    final now = DateTime.now();
    final year = now.year;
    final yearHigh = (year >> 8) & 0xFF;
    final yearLow = year & 0xFF;
    final tzOffset = now.timeZoneOffset;
    final tzHours = tzOffset.inHours;                          // 有符号，如 +8 / -5
    final tzMinutes = tzOffset.inMinutes.abs() % 60;           // 无符号，如 0 / 30 / 45
    final cmd = [
      0xAA,       // 命令头
      0x0C,       // 包长度=12
      yearHigh,   // 年份高字节
      yearLow,    // 年份低字节
      now.month,  // 月
      now.day,    // 日
      now.hour,   // 时
      now.minute, // 分
      now.second, // 秒
      tzHours & 0xFF,  // 时区小时偏移 (int8)
      tzMinutes,       // 时区分钟偏移 (uint8)
      0xAA,       // 命令尾
    ];
    final tzSign = tzHours >= 0 ? '+' : '';
    final tzStr = tzMinutes > 0 ? '$tzSign$tzHours:${tzMinutes.toString().padLeft(2, '0')}' : '$tzSign$tzHours';
    print('🕐 同步时间: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} '
        'UTC$tzStr');
    await sendCommand(cmd, serviceUuid: targetServiceUuid);
  }

  /// 处理接收到的数据
  void _handleReceivedData(Uint8List data) {
    if (data.isEmpty) {
      print('⚠️  收到空数据');
      return;
    }
    
    _logDeviceToApp(data);

    final commandType = data[0];
    switch (commandType) {
      case 0xB1:
        print('📝 解析为: Classic温度时间数据 (0xB1)');
        _parseClassicTempTime(data);
        break;
      case 0xB2:
        print('📝 解析为: Herbal温度时间数据 (0xB2)');
        _parseHerbalTempTime(data);
        break;
      case 0xB3:
        print('📝 解析为: Option名称第一部分 (0xB3)');
        _parseOptionNamePart1(data);
        break;
      case 0xB4:
        print('📝 解析为: Option名称第二部分 (0xB4)');
        _parseOptionNamePart2(data);
        break;
      case 0xB5:
        print('📝 解析为: Side温度时间数据 (0xB5)');
        _parseSideTempTime(data);
        break;
      case 0xB6:
        print('📝 解析为: TCR Init数据 (0xB6)');
        _parseTcrInit(data);
        break;
      case 0xB9:
        print('📝 解析为: 设备参数数据 (0xB9)');
        _parseDeviceParameter(data);
        break;
      case 0xBA:
        print('📝 解析为：Top 温度数据 (0xBA)');
        _parseTopTemp(data);
        break;
            default:
        print('⚠️  未知命令类型: 0x${commandType.toRadixString(16).toUpperCase()}');
        print('📄 完整数据内容:');
        for (int i = 0; i < data.length; i++) {
          print('  Byte[$i]: 0x${data[i].toRadixString(16).toUpperCase().padLeft(2, '0')} (${data[i]})');
        }
    }
    print('=====================================\n');
  }

  // ==================== 数据解析方法（Device->APP）====================

  /// 解析 Classic 模式温度时间数据 (0xB1)
  /// 数据格式: [Type(0xB1), Length(0x13), index, temp[0]high, temp[0]low, ..., temp[4]high, temp[4]low, time[0], time[1], time[2], time[3], time[4], check(0xB1)]
  /// index: 0-4 表示哪个配置 (对应选项 1-5)
  /// 温度范围: 60-300 (高字节+低字节)
  /// 时间范围: 0-120 (分钟)
  void _parseClassicTempTime(Uint8List data) {
    if (data.length < 0x13) {
      print('Invalid classic_temp_time data length: ${data.length}');
      return;
    }

    // data[2] 是 index (0-4)
    int index = data[2];

    List<int> temps = [];
    List<int> times = [];

    // 解析5个温度值 (每个2字节)，从 data[3] 开始
    for (int i = 0; i < 5; i++) {
      int tempHigh = data[3 + i * 2];
      int tempLow = data[4 + i * 2];
      int temp = (tempHigh << 8) | tempLow;
      temps.add(temp);
    }

    // 解析5个时间值 (每个1字节)，从 data[13] 开始
    for (int i = 0; i < 5; i++) {
      times.add(data[13 + i]);
    }

    // 获取现有的 classic 数据，按 index 存储
    Map<String, dynamic> classicData = Map<String, dynamic>.from(
      deviceInfo?['classic'] as Map<String, dynamic>? ?? {}
    );

    // 存储当前 index 的数据（包含时间戳）
    classicData['$index'] = {
      'temps': temps,
      'times': times,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // 合并更新
    deviceInfo = {
      ...?deviceInfo,
      'classic': classicData,
      'lastUpdate': DateTime.now().toIso8601String(),
    };

    notifyListeners();
    print('Classic temp time received: index=$index, temps=$temps, times=$times');
  }

  /// 获取选项名称列表
  Map<int, String> get optionNames => _optionNames;

  /// 解析 Option 名称第一部分 (0xB3)
  /// 数据格式: [Type(0xB3), Length(0x14), Index, Char[0]...Char[15], Check]
  void _parseOptionNamePart1(Uint8List data) {
    if (data.length < 0x14) {
      print('Invalid option_name_part1 data length: ${data.length}');
      return;
    }
    
    int index = data[2];
    if (index < 0 || index > 4) {
      print('Invalid option index: $index');
      return;
    }

    // 确保缓冲区存在
    if (!_optionNameBuffers.containsKey(index)) {
      _optionNameBuffers[index] = List.filled(32, 0);
    }
    
    // 复制前16个字节
    List<int> part1 = data.sublist(3, 19);
    for (int i = 0; i < 16; i++) {
      _optionNameBuffers[index]![i] = part1[i];
    }
    
    _updateOptionName(index);
  }

  /// 解析 Option 名称第二部分 (0xB4)
  /// 数据格式: [Type(0xB4), Length(0x14), Index, Char[16]...Char[31], Check]
  void _parseOptionNamePart2(Uint8List data) {
    if (data.length < 0x14) {
      print('Invalid option_name_part2 data length: ${data.length}');
      return;
    }
    
    int index = data[2];
    if (index < 0 || index > 4) {
      print('Invalid option index: $index');
      return;
    }

    // 确保缓冲区存在
    if (!_optionNameBuffers.containsKey(index)) {
      _optionNameBuffers[index] = List.filled(32, 0);
    }
    
    // 复制后16个字节
    List<int> part2 = data.sublist(3, 19);
    for (int i = 0; i < 16; i++) {
      _optionNameBuffers[index]![16 + i] = part2[i];
    }
    
    _updateOptionName(index);
  }

  void _updateOptionName(int index) {
    if (!_optionNameBuffers.containsKey(index)) return;
    
    List<int> buffer = _optionNameBuffers[index]!;
    // 移除 null 字节 (0x00) 并解码
    List<int> validBytes = buffer.where((b) => b != 0).toList();
    try {
      String name = utf8.decode(validBytes, allowMalformed: true);
      _optionNames[index] = name;
      print('Updated option name for index $index: $name');
      notifyListeners();
    } catch (e) {
      print('Error decoding option name for index $index: $e');
    }
  }

  /// 解析 Herbal 模式温度时间数据 (0xB2)
  /// 数据格式: [Type(0xB2), Length(0x12), temp[0]high, temp[0]low, ..., temp[4]high, temp[4]low, time[0], time[1], time[2], time[3], time[4], check(0xB2)]
  /// 温度范围: 60-300 (高字节+低字节)
  /// 时间范围: 0-120 (分钟)
  void _parseHerbalTempTime(Uint8List data) {
    if (data.length < 0x12) {
      print('Invalid herbal_temp_time data length: ${data.length}');
      return;
    }
    
    List<int> temps = [];
    List<int> times = [];
    
    // 解析5个温度值 (每个2字节)
    for (int i = 0; i < 5; i++) {
      int tempHigh = data[2 + i * 2];
      int tempLow = data[3 + i * 2];
      int temp = (tempHigh << 8) | tempLow;
      temps.add(temp);
    }
    
    // 解析5个时间值 (每个1字节)
    for (int i = 0; i < 5; i++) {
      times.add(data[12 + i]);
    }
    
    // 合并更新，而不是覆盖整个 deviceInfo
    deviceInfo = {
      ...?deviceInfo,
      'herbal_temps': temps,
      'herbal_times': times,
      'lastUpdate': DateTime.now().toIso8601String(),
    };

    notifyListeners();
    print('Herbal temp time received: temps=$temps, times=$times');
  }

  /// 解析 Side 温度时间数据 (0xB5)
  /// 新格式: [Type(0xB5), Length(0x0D), temp1, temp2, temp3, temp4, temp5, time1, time2, time3, time4, time5, check(0xB5)]
  /// 旧格式(兼容): [Type(0xB5), Length(0x0B), temp1, temp2, temp3, temp4, time1, time2, time3, time4, check(0xB5)]
  /// 温度范围: 60-250 (单字节)
  /// 时间范围: 0-120 (分钟)
  void _parseSideTempTime(Uint8List data) {
    print('📊 Side temp time data length: ${data.length} (0x${data.length.toRadixString(16).toUpperCase()})');

    // 检查是新格式(5个点)还是旧格式(4个点)
    if (data.length >= 0x0D) {
      // 新格式：5个温度 + 5个时间
      print('✅ Using NEW format (5 points)');
      int temp1 = data[2];
      int temp2 = data[3];
      int temp3 = data[4];
      int temp4 = data[5];
      int temp5 = data[6];
      int time1 = data[7];
      int time2 = data[8];
      int time3 = data[9];
      int time4 = data[10];
      int time5 = data[11];

      // 合并更新，而不是覆盖整个 deviceInfo
      deviceInfo = {
        ...?deviceInfo,
        'side_temp1': temp1,
        'side_temp2': temp2,
        'side_temp3': temp3,
        'side_temp4': temp4,
        'side_temp5': temp5,
        'side_time1': time1,
        'side_time2': time2,
        'side_time3': time3,
        'side_time4': time4,
        'side_time5': time5,
        'side_lastUpdate': DateTime.now().toIso8601String(), // 专门的 B5 数据更新时间戳
        'lastUpdate': DateTime.now().toIso8601String(),
      };

      notifyListeners();
      print('Side temp time received (5 points): temp1=$temp1, temp2=$temp2, temp3=$temp3, temp4=$temp4, temp5=$temp5, time1=$time1, time2=$time2, time3=$time3, time4=$time4, time5=$time5');
    } else if (data.length >= 0x0B) {
      // 旧格式：4个温度 + 4个时间（向后兼容）
      print('⚠️  Using OLD format (4 points) - Please update device firmware to support 5 points');
      int temp1 = data[2];
      int temp2 = data[3];
      int temp3 = data[4];
      int temp4 = data[5];
      int time1 = data[6];
      int time2 = data[7];
      int time3 = data[8];
      int time4 = data[9];

      // 合并更新，第5个点使用默认值
      deviceInfo = {
        ...?deviceInfo,
        'side_temp1': temp1,
        'side_temp2': temp2,
        'side_temp3': temp3,
        'side_temp4': temp4,
        'side_temp5': 60, // 默认值
        'side_time1': time1,
        'side_time2': time2,
        'side_time3': time3,
        'side_time4': time4,
        'side_time5': 0, // 默认值
        'side_lastUpdate': DateTime.now().toIso8601String(),
        'lastUpdate': DateTime.now().toIso8601String(),
      };

      notifyListeners();
      print('Side temp time received (4 points, OLD format): temp1=$temp1, temp2=$temp2, temp3=$temp3, temp4=$temp4, time1=$time1, time2=$time2, time3=$time3, time4=$time4');
      print('⚠️  temp5 and time5 set to default values (60°C, 0min). Device firmware needs update to support 5 points.');
    } else {
      print('❌ Invalid side_temp_time data length: ${data.length}, expected 0x0B (11) or 0x0D (13)');
      return;
    }
  }

  /// 解析 TCR Init 数据 (0xB6)
  /// 数据格式: [Type(0xB6), Length(0x05), tcr_init(high), tcr_init(low), check(0xB6)]
  void _parseTcrInit(Uint8List data) {
    if (data.length < 0x05) {
      print('Invalid tcr_init data length: ${data.length}');
      return;
    }

    int tcrInitHigh = data[2];
    int tcrInitLow = data[3];
    int tcrInit = (tcrInitHigh << 8) | tcrInitLow;

    // 合并更新，而不是覆盖整个 deviceInfo
    deviceInfo = {
      ...?deviceInfo,
      'tcr_init': tcrInit,
      'lastUpdate': DateTime.now().toIso8601String(),
    };

    notifyListeners();
    print('TCR Init received: $tcrInit (0x${tcrInit.toRadixString(16).toUpperCase()})');
  }

  /// 解析设备参数数据 (0xB9)
  /// 数据格式: [Type(0xB9), Length(0x0C), 电池电量, 实时温度(高), 实时温度(低), 设置温度(高), 设置温度(低), 灯光模式, 设定时间, 倒计时(高), 倒计时(低), heat_preset, 增强次数boost, check(0xB9)]
  /// 电池范围: 0-100 (%)
  /// 温度范围: 60-300 (实时), 150-300 (设置)
  /// 灯光模式: 0-5
  /// 设定时间: 30-120 (分钟)
  /// heat_preset: 0-5 (预设模式，对应主页选择器)
  /// 增强次数boost: 0-12
  /// byte 16: motor_level (0-5)
  /// byte 17: audio_switch (0/1)
  /// byte 18: temp_unit (0:C, 1:F)
  void _parseDeviceParameter(Uint8List data) {
    if (data.length < 0x0C) {
      print('Invalid device_parameter data length: ${data.length}');
      return;
    }
    
    int battery = data[2]; // 电池电量 0-100
    int realTempHigh = data[3];
    int realTempLow = data[4];
    int realTemp = (realTempHigh << 8) | realTempLow;
    int setTempHigh = data[5];
    int setTempLow = data[6];
    int setTemp = (setTempHigh << 8) | setTempLow;
    int lightMode = data[7]; // 灯光模式 0-5
    int setTime = data[8]; // 设定时间 30-120
    int countdown_time = (data[9] << 8) | data[10]; 
    int heatPreset = data[11]; // 预设模式 0-5 (对应主页选择器)
    int boostCount = data[12]; // 增强次数boost 0-12
    int startHeating = data[13]; // 是否正在加热 0/1
    int bPauseState = data[14]; // 暂停状态 0/1 (保留字段，暂不使用)
    int bTempReady = data[15]; // 温度锁定 0/1 (保留字段，暂不使用)
    
    // New fields
    int motorLevel = 0;
    int audioSwitch = 0;
    int tempUnit = 0;

    if (data.length > 16) {
      motorLevel = data[16];
    }
    if (data.length > 17) {
      audioSwitch = data[17];
    }
    if (data.length > 18) {
      tempUnit = data[18];
    }

    deviceInfo = {
      ...?deviceInfo,
      'battery': battery,
      'realTemp': realTemp,
      'setTemp': setTemp,
      'lightMode': lightMode,
      'setTime': setTime,
      'countdown_time': countdown_time,
      'heatPreset': heatPreset,
      'boostCount': boostCount,
      'startHeating': startHeating,
      'bPauseState': bPauseState,
      'bTempReady': bTempReady,
      'motorLevel': motorLevel,
      'audioSwitch': audioSwitch,
      'tempUnit': tempUnit,
      'lastUpdate': DateTime.now().toIso8601String(),
    };

    notifyListeners();
    print('Device parameter received: battery=$battery%, realTemp=$realTemp, setTemp=$setTemp, lightMode=$lightMode, setTime=$setTime, countdown_time=$countdown_time, heatPreset=$heatPreset, boostCount=$boostCount, startHeating=$startHeating, bPauseState=$bPauseState, bTempReady=$bTempReady, motorLevel=$motorLevel, audioSwitch=$audioSwitch, tempUnit=$tempUnit');
  }

  /// 解析 Top 温度数据 (0xBA)
  /// 数据格式：[Type(0xBA), Length(0x05), temp_high, temp_low, check(0xBA)]
  /// 温度范围：0-65535 (高字节 + 低字节)
  void _parseTopTemp(Uint8List data) {
    if (data.length < 0x05) {
      print('Invalid top_temp data length: ${data.length}');
      return;
    }

    int tempHigh = data[2];
    int tempLow = data[3];
    int topTemp = (tempHigh << 8) | tempLow;

    // 更新 deviceInfo 中的 topTemp
    deviceInfo = {
      ...?deviceInfo,
      'topTemp': topTemp,
      'lastUpdate': DateTime.now().toIso8601String(),
    };

    notifyListeners();
    print('Top temp received: $topTemp (0x${topTemp.toRadixString(16).toUpperCase()})');
  }

  // ==================== 命令发送方法（APP->Device）====================

  String _formatBytes(List<int> bytes) {
    return bytes
        .map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}')
        .join(' ');
  }

  void _logAppToDevice(List<int> bytes, {String? note}) {
    if (bytes.isEmpty) {
      print('📤 [APP->Device] 空命令，已忽略');
      return;
    }
    final cmd = bytes.first;
    final cmdName = _appToDeviceCommandNames[cmd] ?? '未知命令';
    final hex = _formatBytes(bytes);
    final detail = note != null ? ' | $note' : '';
    print(
        '📤 [APP->Device] $cmdName (0x${cmd.toRadixString(16).toUpperCase().padLeft(2, '0')}, len=${bytes.length}) => $hex$detail  (参照@蓝牙命令.xlsx)');
  }

  void _logDeviceToApp(List<int> bytes) {
    final cmd = bytes.first;
    final cmdName = _deviceToAppCommandNames[cmd] ?? '未知命令';
    final hex = _formatBytes(bytes);
    print(
        '\n📥 [Device->APP] $cmdName (0x${cmd.toRadixString(16).toUpperCase().padLeft(2, '0')}, len=${bytes.length}) => $hex  (参照@蓝牙命令.xlsx)');
    print('📊 十进制: [${bytes.join(', ')}]');
  }

  /// 发送 Classic 模式温度时间设置 (0xA1)
  /// [Type(0xA1), Length(0x13), index, temp[0]high, temp[0]low, ..., temp[4]high, temp[4]low, time[0], time[1], time[2], time[3], time[4], check(0xA1)]
  /// @param index 配置索引 (0-4，对应选项 1-5)
  /// @param temps 5个温度值列表，范围60-300
  /// @param times 5个时间值列表，范围0-120 (分钟)
  Future<void> sendClassicTempTime(int index, List<int> temps, List<int> times) async {
    if (index < 0 || index > 4) {
      throw ArgumentError('Index must be between 0-4, got: $index');
    }
    if (temps.length != 5 || times.length != 5) {
      throw ArgumentError('temps and times must have 5 elements each');
    }
    print(
        '🛠 准备发送 classic_temp_time (0xA1) -> index=$index, temps=$temps, times=$times (参照@蓝牙命令.xlsx)');

    List<int> command = [0xA1, 0x13, index];

    // 添加5个温度值 (每个2字节)
    for (int temp in temps) {
      if (temp < 0 || temp > 350) {
        throw ArgumentError('Temperature must be between 0-350, got: $temp');
      }
      command.add((temp >> 8) & 0xFF); // 高字节
      command.add(temp & 0xFF); // 低字节
    }

    // 添加5个时间值 (每个1字节)
    for (int time in times) {
      if (time < 0 || time > 120) {
        throw ArgumentError('Time must be between 0-120, got: $time');
      }
      command.add(time);
    }
    
    // 添加校验字节
    command.add(0xA1);
    
    await sendCommand(
      command,
      serviceUuid: targetServiceUuid,
    );
    print('✅ Sent classic_temp_time: index=$index, temps=$temps, times=$times');
  }

  /// 发送 Herbal 模式温度时间设置 (0xA2)
  /// [Type(0xA2), Length(0x12), temp[0]high, temp[0]low, ..., temp[4]high, temp[4]low, time[0], time[1], time[2], time[3], time[4], check(0xA2)]
  /// @param temps 5个温度值列表，范围60-300
  /// @param times 5个时间值列表，范围0-120 (分钟)
  Future<void> sendHerbalTempTime(List<int> temps, List<int> times) async {
    if (temps.length != 5 || times.length != 5) {
      throw ArgumentError('temps and times must have 5 elements each');
    }
    print(
        '🛠 准备发送 herbal_temp_time (0xA2) -> temps=$temps, times=$times (参照@蓝牙命令.xlsx)');
    
    List<int> command = [0xA2, 0x12];
    
    // 添加5个温度值 (每个2字节)
    for (int temp in temps) {
      if (temp < 0 || temp > 350) {
        throw ArgumentError('Temperature must be between 0-350, got: $temp');
      }
      command.add((temp >> 8) & 0xFF); // 高字节
      command.add(temp & 0xFF); // 低字节
    }
    
    // 添加5个时间值 (每个1字节)
    for (int time in times) {
      if (time < 0 || time > 120) {
        throw ArgumentError('Time must be between 0-120, got: $time');
      }
      command.add(time);
    }
    
    // 添加校验字节
    command.add(0xA2);
    
    await sendCommand(
      command,
      serviceUuid: targetServiceUuid,
    );
    print('✅ Sent herbal_temp_time: temps=$temps, times=$times');
  }

  /// 发送 Option 名称设置 (0xA7, 0xA8)
  /// 分两包发送，每包16字节
  /// 0xA7: [Type(0xA7), Length(0x14), Index, Char[0]...Char[15], Check]
  /// 0xA8: [Type(0xA8), Length(0x14), Index, Char[16]...Char[31], Check]
  Future<void> sendOptionName(int index, String name) async {
    if (index < 0 || index > 4) {
      throw ArgumentError('Index must be between 0-4, got: $index');
    }
    
    // 转换字符串为 bytes，并截断/填充到 32 字节
    List<int> nameBytes = utf8.encode(name);
    List<int> paddedBytes = List.filled(32, 0);
    for (int i = 0; i < nameBytes.length && i < 32; i++) {
      paddedBytes[i] = nameBytes[i];
    }
    
    // 发送第一部分 (0xA7)
    List<int> cmd1 = [0xA7, 0x14, index];
    cmd1.addAll(paddedBytes.sublist(0, 16));
    cmd1.add(0xA7);
    
    await sendCommand(cmd1, serviceUuid: targetServiceUuid);
    print('✅ Sent option_name_part1 (0xA7) for index $index: "${name.substring(0, name.length > 16 ? 16 : name.length)}"');
    
    // 稍微延迟一下，确保设备处理
    await Future.delayed(const Duration(milliseconds: 100));
    
    // 发送第二部分 (0xA8)
    List<int> cmd2 = [0xA8, 0x14, index];
    cmd2.addAll(paddedBytes.sublist(16, 32));
    cmd2.add(0xA8);
    
    await sendCommand(cmd2, serviceUuid: targetServiceUuid);
    print('✅ Sent option_name_part2 (0xA8) for index $index');
    
    // 更新本地缓存
    _optionNames[index] = name;
    _optionNameBuffers[index] = paddedBytes;
    notifyListeners();
  }

  /// 发送设备参数设置 (0xA9)
  /// [Type(0xA9), Length(0x0D), 灯光模式, 设置温度(高), 设置温度(低), 设置时间, 自动休眠时间, 开始/停止加热, boost次数, motorLevel, audioSwitch, tempUnit, check(0xA9)]
  /// @param lightMode 灯光模式，范围0-5
  /// @param setTemp 设置温度，范围150-300
  /// @param setTime 设置时间，范围30-120 (分钟)
  /// @param autoSleepTime 自动休眠时间，范围0-60 (分钟)
  /// @param startHeating 开始/停止加热，0=停止，1=开始
  /// @param boostCount boost次数，范围0-12，每次+1，设备加热时间+10分钟
  /// @param motorLevel 马达等级，范围0-5
  /// @param audioSwitch 声音开关，0/1
  /// @param tempUnit 温度单位，0:C, 1:F
  Future<void> sendDeviceParameter(
    int lightMode,
    int setTemp,
    int setTime, {
    int heatPreset = 0,
    int startHeating = 0,
    int boostCount = 0,
    int motorLevel = 0,
    int audioSwitch = 0,
    int tempUnit = 0,
  }) async {
    if (lightMode < 0 || lightMode > 5) {
      throw ArgumentError('Light mode must be between 0-5, got: $lightMode');
    }
    if (setTemp < 150 || setTemp > 350) {
      throw ArgumentError('Set temperature must be between 150-350, got: $setTemp');
    }
    if (setTime < 30 || setTime > 120) {
      throw ArgumentError('Set time must be between 30-120, got: $setTime');
    }
    if (heatPreset < 0 || heatPreset > 5) {
      throw ArgumentError('Heat preset must be between 0-5, got: $heatPreset');
    }
    if (startHeating < 0 || startHeating > 1) {
      throw ArgumentError('Start heating must be 0 or 1, got: $startHeating');
    }
    if (boostCount < 0 || boostCount > 12) {
      throw ArgumentError('Boost count must be between 0-12, got: $boostCount');
    }
    
    print(
        '🛠 准备发送 device_parameter (0xA9) -> lightMode=$lightMode, setTemp=$setTemp, setTime=$setTime, heatPreset=$heatPreset, startHeating=$startHeating, boostCount=$boostCount, motorLevel=$motorLevel, audioSwitch=$audioSwitch, tempUnit=$tempUnit (参照@蓝牙命令.xlsx)');
    
    List<int> command = [
      0xA9, 0x0D, // Length = 13 (包括后续所有字段)
      lightMode,
      (setTemp >> 8) & 0xFF, // 温度高字节
      setTemp & 0xFF, // 温度低字节
      setTime,
      heatPreset,
      startHeating,
      boostCount,
      motorLevel,
      audioSwitch,
      tempUnit,
      0xA9, // 校验字节
    ];
    
    await sendCommand(
      command,
      serviceUuid: targetServiceUuid,
    );
    print('✅ Sent device_parameter: lightMode=$lightMode, setTemp=$setTemp, setTime=$setTime, heatPreset=$heatPreset, startHeating=$startHeating, boostCount=$boostCount, motorLevel=$motorLevel, audioSwitch=$audioSwitch, tempUnit=$tempUnit');
  }

  /// 发送 WiFi SSID 第一部分 (0xA3)
  /// [Type(0xA3), Length(0x14), SSID前17字节(ASCII), check(0xA3)]
  /// @param ssidPart1 SSID的前17个字节（ASCII字符串）
  Future<void> sendWifiSsidPart1(String ssidPart1) async {
    if (ssidPart1.length > 17) {
      throw ArgumentError('SSID part1 must be 17 bytes or less, got: ${ssidPart1.length}');
    }
    print('🛠 准备发送 wifi_ssid_part1 (0xA3) -> "$ssidPart1"');
    
    List<int> command = [0xA3, 0x14];
    
    // 转换为ASCII字节，补齐到17字节
    List<int> ssidBytes = ssidPart1.codeUnits;
    for (int i = 0; i < 17; i++) {
      command.add(i < ssidBytes.length ? ssidBytes[i] : 0);
    }
    
    // 添加校验字节
    command.add(0xA3);
    
    await sendCommand(
      command,
      serviceUuid: targetServiceUuid,
    );
    print('✅ Sent wifi_ssid_part1: ${ssidPart1.substring(0, ssidPart1.length > 17 ? 17 : ssidPart1.length)}');
  }

  /// 发送 WiFi SSID 第二部分 (0xA4)
  /// [Type(0xA4), Length(0x14), SSID后17字节(ASCII), check(0xA4)]
  /// @param ssidPart2 SSID的后17个字节（ASCII字符串），SSID最长34字节
  Future<void> sendWifiSsidPart2(String ssidPart2) async {
    if (ssidPart2.length > 17) {
      throw ArgumentError('SSID part2 must be 17 bytes or less, got: ${ssidPart2.length}');
    }
    print('🛠 准备发送 wifi_ssid_part2 (0xA4) -> "$ssidPart2"');
    
    List<int> command = [0xA4, 0x14];
    
    // 转换为ASCII字节，补齐到17字节
    List<int> ssidBytes = ssidPart2.codeUnits;
    for (int i = 0; i < 17; i++) {
      command.add(i < ssidBytes.length ? ssidBytes[i] : 0);
    }
    
    // 添加校验字节
    command.add(0xA4);
    
    await sendCommand(
      command,
      serviceUuid: targetServiceUuid,
    );
    print('✅ Sent wifi_ssid_part2: ${ssidPart2.substring(0, ssidPart2.length > 17 ? 17 : ssidPart2.length)}');
  }

  /// 发送 WiFi 密码 (0xA5)
  /// [Type(0xA5), Length(0x14), Password 17字节(ASCII), check(0xA5)]
  /// @param password WiFi密码字符串（最多17字节ASCII）
  /// 注意：WiFi Start 会发送 A3、A4、A5 命令，必须一起发送，发送完后设备会连接WiFi
  Future<void> sendWifiPassword(String password) async {
    if (password.length > 17) {
      throw ArgumentError('Password must be 17 bytes or less, got: ${password.length}');
    }
    print('🛠 准备发送 wifi_password (0xA5) -> 长度=${password.length}');
    
    List<int> command = [0xA5, 0x14];
    
    // 转换为ASCII字节，补齐到17字节
    List<int> passwordBytes = password.codeUnits;
    for (int i = 0; i < 17; i++) {
      command.add(i < passwordBytes.length ? passwordBytes[i] : 0);
    }
    
    // 添加校验字节
    command.add(0xA5);
    
    await sendCommand(
      command,
      serviceUuid: targetServiceUuid,
    );
    print('✅ Sent wifi_password: ${password.substring(0, password.length > 17 ? 17 : password.length)}');
  }

  /// 发送 WiFi 配置（一次性发送SSID和密码）
  /// 会自动分割SSID为两部分（如果需要）
  /// @param ssid WiFi SSID（最长34字节）
  /// @param password WiFi密码（最长17字节）
  Future<void> sendWifiConfig(String ssid, String password) async {
    if (ssid.length > 34) {
      throw ArgumentError('SSID must be 34 bytes or less, got: ${ssid.length}');
    }
    if (password.length > 17) {
      throw ArgumentError('Password must be 17 bytes or less, got: ${password.length}');
    }
    
    // 分割SSID为两部分
    String part1 = ssid.length > 17 ? ssid.substring(0, 17) : ssid;
    String part2 = ssid.length > 17 ? ssid.substring(17) : '';
    
    // 按顺序发送：A3、A4、A5
    await sendWifiSsidPart1(part1);
    await Future.delayed(const Duration(milliseconds: 100)); // 短暂延迟
    await sendWifiSsidPart2(part2);
    await Future.delayed(const Duration(milliseconds: 100));
    await sendWifiPassword(password);
    
    print('Sent wifi_config: ssid=$ssid, password=***');
  }

  /// 发送 OTA 开始更新命令 (0xA6)
  /// [Type(0xA6), Length(0x03), check(0xA6)]
  Future<void> sendOtaStart() async {
    List<int> command = [0xA6, 0x03, 0xA6];

    await sendCommand(
      command,
      serviceUuid: targetServiceUuid,
    );
    print('✅ Sent OTA start command');
  }

  /// 发送 OTA SD 卡更新命令 (0xAB)
  /// [Type(0xAB), Length(0x03), check(0xAB)]
  Future<void> sendOtaSdCard() async {
    List<int> command = [0xAB, 0x03, 0xAB];

    await sendCommand(
      command,
      serviceUuid: targetServiceUuid,
    );
    print('✅ Sent OTA SD card command');
  }

  /// 发送重置命令 (0xC2)
  /// [Type(0xC2), Length(0x03), check(0xC2)]
  Future<void> sendResetCommand() async {
    List<int> command = [0xC2, 0x03, 0xC2];

    print('🛠 准备发送 reset command (0xC2)');
    await sendCommand(
      command,
      serviceUuid: targetServiceUuid,
    );
    print('✅ Sent reset command');
  }

  // ==================== 工具方法 ====================
  //keytool -genkey -v -keystore C:\Users\70451\shishax-upload-key.jks ` -keyalg RSA -keysize 2048 -validity 10000 ` -alias shishax
  /// 获取所有服务和特征的信息
  /// 返回包含所有服务及其特征的详细信息
  Future<Map<String, dynamic>> getAllServicesInfo() async {
    Map<String, dynamic> allServicesInfo = {};

    if (kIsWeb) {
      print('⚠️ [Web] Getting all services info not implemented yet');
      return allServicesInfo;
    }

    if (connectedDevice == null) {
      print('❌ No device connected');
      return allServicesInfo;
    }

    try {
      print('📖 Getting all services information...');
      final services = await connectedDevice.discoverServices();

      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();
        List<Map<String, dynamic>> characteristics = [];

        for (var characteristic in service.characteristics) {
          final charUuid = characteristic.uuid.toString().toLowerCase();

          characteristics.add({
            'uuid': charUuid,
            'read': characteristic.properties.read,
            'write': characteristic.properties.write,
            'notify': characteristic.properties.notify,
          });
        }

        allServicesInfo[serviceUuid] = {
          'characteristics': characteristics,
        };
      }

      print('✅ Found ${allServicesInfo.length} services');
    } catch (e) {
      print('❌ Error getting services info: $e');
    }

    return allServicesInfo;
  }

  /// 读取设备信息服务的特征值
  /// 返回包含各种设备信息的 Map
  Future<Map<String, String>> readDeviceInfoCharacteristics() async {
    Map<String, String> deviceInfoMap = {};

    // 设备信息服务 UUID (支持短格式和长格式)
    const String deviceInfoServiceUuid = '0000180a-0000-1000-8000-00805f9b34fb';

    // 设备信息特征 UUID (使用短格式和长格式)
    const Map<String, String> characteristicNames = {
      '2a24': 'Model Number',
      '2a25': 'Serial Number',
      '2a26': 'Firmware Revision',
      '2a27': 'Hardware Revision',
      '2a28': 'Software Revision',
      '2a29': 'Manufacturer Name',
      '00002a24-0000-1000-8000-00805f9b34fb': 'Model Number',
      '00002a25-0000-1000-8000-00805f9b34fb': 'Serial Number',
      '00002a26-0000-1000-8000-00805f9b34fb': 'Firmware Revision',
      '00002a27-0000-1000-8000-00805f9b34fb': 'Hardware Revision',
      '00002a28-0000-1000-8000-00805f9b34fb': 'Software Revision',
      '00002a29-0000-1000-8000-00805f9b34fb': 'Manufacturer Name',
    };

    if (kIsWeb) {
      // Web 平台暂不支持读取设备信息服务
      print('⚠️ [Web] Reading device info service not implemented yet');
      return deviceInfoMap;
    }

    if (connectedDevice == null) {
      print('❌ No device connected');
      return deviceInfoMap;
    }

    try {
      print('\n📖 ========== Reading device information ==========');
      final services = await connectedDevice.discoverServices();

      print('📋 Total services found: ${services.length}');
      print('📋 All available services:');
      for (var service in services) {
        print('  • Service UUID: ${service.uuid}');
      }

      final deviceInfoServiceGuid = fb.Guid(deviceInfoServiceUuid);
      bool foundDeviceInfoService = false;

      for (var service in services) {
        // 比较 UUID，支持短格式 (180a) 和长格式
        final serviceUuidStr = service.uuid.toString().toLowerCase();
        final isDeviceInfoService = serviceUuidStr == '180a' ||
                                   serviceUuidStr == '0000180a-0000-1000-8000-00805f9b34fb' ||
                                   service.uuid == deviceInfoServiceGuid;

        if (isDeviceInfoService) {
          foundDeviceInfoService = true;
          print('\n✅ Found Device Information Service: ${service.uuid}');
          print('📋 Characteristics in this service: ${service.characteristics.length}');

          for (var characteristic in service.characteristics) {
            final charUuidStr = characteristic.uuid.toString().toLowerCase();
            print('  • Characteristic UUID: $charUuidStr');
            print('    Properties: read=${characteristic.properties.read}, write=${characteristic.properties.write}, notify=${characteristic.properties.notify}');

            if (characteristicNames.containsKey(charUuidStr)) {
              try {
                if (characteristic.properties.read) {
                  print('    🔄 Reading ${characteristicNames[charUuidStr]}...');
                  final value = await characteristic.read();
                  print('    📥 Raw bytes: ${value.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
                  final stringValue = utf8.decode(value, allowMalformed: true);
                  final name = characteristicNames[charUuidStr]!;
                  deviceInfoMap[name] = stringValue;
                  print('    ✓ $name: $stringValue');
                } else {
                  print('    ⚠️ ${characteristicNames[charUuidStr]} is not readable');
                }
              } catch (e) {
                print('    ❌ Failed to read ${characteristicNames[charUuidStr]}: $e');
              }
            }
          }
          break;
        }
      }

      if (!foundDeviceInfoService) {
        print('\n⚠️ Device Information Service (UUID: $deviceInfoServiceUuid) not found');
        print('💡 The device may not support the standard Device Information Service');
      }

      if (deviceInfoMap.isEmpty && foundDeviceInfoService) {
        print('\n⚠️ Device Information Service found but no readable characteristics');
      }

      print('========================================\n');
    } catch (e) {
      print('❌ Error reading device info: $e');
      print('Stack trace: ${StackTrace.current}');
    }

    return deviceInfoMap;
  }

  /// 获取设备信息
  Map<String, dynamic>? getDeviceInfo() {
    return deviceInfo;
  }

  /// 清除设备信息
  void clearDeviceInfo() {
    deviceInfo = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _stateSub?.cancel();
    _notificationSub?.cancel();
    super.dispose();
  }
}
