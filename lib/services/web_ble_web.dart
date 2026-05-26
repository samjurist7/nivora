import 'dart:convert';
import 'dart:js_util' as js_util;

/// 调用JS端的bleLog，在页面上显示调试信息
void _jsLog(String msg) {
  try {
    js_util.callMethod(js_util.globalThis, 'bleLog', ['[Dart] $msg']);
  } catch (_) {}
}

/// 供外部(bluetooth_service.dart)调用的日志接口
class WebBleLogger {
  static void log(String msg) => _jsLog(msg);
}

class WebBle {
  /// Notification callback function
  static Function(List<int>)? onNotificationReceived;

  /// Disconnection callback function
  static Function()? onDisconnected;

  /// Request Bluetooth device
  static Future<Map<String, dynamic>> requestDevice() async {
    try {
      final result = await js_util.promiseToFuture(
          js_util.callMethod(js_util.globalThis, 'webRequestBluetooth', []));
      if (result == null) return {'error': 'null_result'};
      if (result is String) {
        try {
          return jsonDecode(result) as Map<String, dynamic>;
        } catch (_) {
          return {'name': result};
        }
      }
      return {'result': result.toString()};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Connect device
  static Future<Map<String, dynamic>> connectDevice() async {
    try {
      // Set disconnection callback
      js_util.setProperty(js_util.globalThis, 'onBleDisconnected',
          js_util.allowInterop(() {
        if (onDisconnected != null) {
          onDisconnected!();
        }
      }));

      // Set notification callback
      js_util.setProperty(js_util.globalThis, 'onBleNotification',
          js_util.allowInterop((String bytesJson) {
        if (onNotificationReceived != null) {
          try {
            final List<dynamic> bytes = jsonDecode(bytesJson);
            onNotificationReceived!(bytes.cast<int>());
          } catch (_) {}
        }
      }));

      final result = await js_util.promiseToFuture(
          js_util.callMethod(js_util.globalThis, 'webConnectDevice', []));
      if (result == null) return {'error': 'null_result'};
      if (result is String) {
        try {
          return jsonDecode(result) as Map<String, dynamic>;
        } catch (_) {
          return {'error': result};
        }
      }
      return {'result': result.toString()};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Disconnect
  static Future<void> disconnectDevice() async {
    try {
      await js_util.promiseToFuture(
          js_util.callMethod(js_util.globalThis, 'webDisconnectDevice', []));
    } catch (_) {}
  }

  /// Discover services
  static Future<Map<String, dynamic>> discoverServices(String serviceUuid) async {
    try {
      final result = await js_util.promiseToFuture(js_util
          .callMethod(js_util.globalThis, 'webDiscoverServices', [serviceUuid]));
      if (result == null) return {'error': 'null_result'};
      if (result is String) {
        try {
          return jsonDecode(result) as Map<String, dynamic>;
        } catch (_) {
          return {'error': result};
        }
      }
      return {'result': result.toString()};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Write characteristic
  static Future<Map<String, dynamic>> writeCharacteristic(
      String serviceUuid, String charUuid, List<int> bytes) async {
    _jsLog('writeChar called svc=$serviceUuid char=$charUuid len=${bytes.length}');
    try {
      final bytesJson = jsonEncode(bytes);
      final result = await js_util.promiseToFuture(js_util.callMethod(
          js_util.globalThis,
          'webWriteCharacteristic',
          [serviceUuid, charUuid, bytesJson]));
      _jsLog('writeChar result type=${result.runtimeType} val=$result');
      if (result == null) return {'error': 'null_result'};
      if (result is String) {
        try {
          return jsonDecode(result) as Map<String, dynamic>;
        } catch (_) {
          return {'error': result};
        }
      }
      return {'result': result.toString()};
    } catch (e) {
      _jsLog('writeChar EXCEPTION: $e');
      return {'error': e.toString()};
    }
  }

  /// Enable notifications
  static Future<Map<String, dynamic>> enableNotifications(
      String serviceUuid, String charUuid) async {
    try {
      final result = await js_util.promiseToFuture(js_util.callMethod(
          js_util.globalThis,
          'webEnableNotifications',
          [serviceUuid, charUuid]));
      if (result == null) return {'error': 'null_result'};
      if (result is String) {
        try {
          return jsonDecode(result) as Map<String, dynamic>;
        } catch (_) {
          return {'error': result};
        }
      }
      return {'result': result.toString()};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Disable notifications
  static Future<void> disableNotifications() async {
    try {
      await js_util.promiseToFuture(
          js_util.callMethod(js_util.globalThis, 'webDisableNotifications', []));
    } catch (_) {}
  }

  /// Check connection status
  static bool isConnected() {
    try {
      final result =
          js_util.callMethod(js_util.globalThis, 'webIsConnected', []);
      // JS可能返回字符串'true'或boolean true，都要兼容
      return result == true || result == 'true' || result.toString() == 'true';
    } catch (_) {
      return false;
    }
  }
}
