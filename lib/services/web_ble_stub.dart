/// Stub logger for non-web platforms
class WebBleLogger {
  static void log(String msg) {}
}

/// Stub implementation for non-web platforms
class WebBle {
  /// Notification callback function
  static Function(List<int>)? onNotificationReceived;

  /// Disconnection callback function
  static Function()? onDisconnected;

  /// Request Bluetooth device
  static Future<Map<String, dynamic>> requestDevice() async {
    return {'error': 'not_web'};
  }

  /// Connect device
  static Future<Map<String, dynamic>> connectDevice() async {
    return {'error': 'not_web'};
  }

  /// Disconnect
  static Future<void> disconnectDevice() async {}

  /// Discover services
  static Future<Map<String, dynamic>> discoverServices(String serviceUuid) async {
    return {'error': 'not_web'};
  }

  /// Write characteristic
  static Future<Map<String, dynamic>> writeCharacteristic(
      String serviceUuid, String charUuid, List<int> bytes) async {
    return {'error': 'not_web'};
  }

  /// Enable notifications
  static Future<Map<String, dynamic>> enableNotifications(
      String serviceUuid, String charUuid) async {
    return {'error': 'not_web'};
  }

  /// Disable notifications
  static Future<void> disableNotifications() async {}

  /// Check connection status
  static bool isConnected() {
    return false;
  }
}
