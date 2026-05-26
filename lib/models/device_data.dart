/// Device data model
class DeviceData {
  final int id;
  final String deviceId;
  final String? dataType;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  DeviceData({
    required this.id,
    required this.deviceId,
    this.dataType,
    this.data,
    required this.createdAt,
  });

  /// Create DeviceData object from JSON
  factory DeviceData.fromJson(Map<String, dynamic> json) {
    return DeviceData(
      id: json['id'] as int,
      deviceId: json['device_id'] as String,
      dataType: json['data_type'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'data_type': dataType,
      'data': data,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
