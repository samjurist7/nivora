/// WebSocket device update message model
class DeviceUpdate {
  final String type;
  final String deviceId;
  final DeviceUpdateData data;

  DeviceUpdate({
    required this.type,
    required this.deviceId,
    required this.data,
  });

  /// Create DeviceUpdate object from JSON
  factory DeviceUpdate.fromJson(Map<String, dynamic> json) {
    return DeviceUpdate(
      type: json['type'] as String,
      deviceId: json['device_id'] as String,
      data: DeviceUpdateData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'device_id': deviceId,
      'data': data.toJson(),
    };
  }
}

/// Device update data
class DeviceUpdateData {
  final bool? relay;
  final int? ledLevel;
  final int? setTime;
  final int? setTemp;
  final String? status;
  final int? rssi;

  DeviceUpdateData({
    this.relay,
    this.ledLevel,
    this.setTime,
    this.setTemp,
    this.status,
    this.rssi,
  });

  /// Create DeviceUpdateData object from JSON
  factory DeviceUpdateData.fromJson(Map<String, dynamic> json) {
    return DeviceUpdateData(
      relay: json['relay'] as bool?,
      ledLevel: json['led_level'] as int?,
      setTime: json['set_time'] as int?,
      setTemp: json['set_temp'] as int?,
      status: json['status'] as String?,
      rssi: json['rssi'] as int?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'relay': relay,
      'led_level': ledLevel,
      'set_time': setTime,
      'set_temp': setTemp,
      'status': status,
      'rssi': rssi,
    };
  }
}
