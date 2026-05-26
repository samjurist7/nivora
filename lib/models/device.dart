/// Device model
class Device {
  final int? id;
  final String deviceId;
  final String name;
  final String? deviceType;
  final int? ownerId;
  final String? firmwareVersion;
  final String status; // online/offline
  final DateTime? lastOnline;
  final DateTime? createdAt;
  final RealtimeStatus? realtimeStatus;

  Device({
    this.id,
    required this.deviceId,
    required this.name,
    this.deviceType,
    this.ownerId,
    this.firmwareVersion,
    this.status = 'offline',
    this.lastOnline,
    this.createdAt,
    this.realtimeStatus,
  });

  /// Create Device object from JSON
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int?,
      deviceId: json['device_id'] as String,
      name: json['name'] as String? ?? json['device_id'] as String,
      deviceType: json['device_type'] as String?,
      ownerId: json['owner_id'] as int?,
      firmwareVersion: json['firmware_version'] as String?,
      status: json['status'] as String? ?? 'offline',
      lastOnline: json['last_online'] != null
          ? DateTime.parse(json['last_online'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      realtimeStatus: json['realtime_status'] != null
          ? RealtimeStatus.fromJson(
              json['realtime_status'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'name': name,
      'device_type': deviceType,
      'owner_id': ownerId,
      'firmware_version': firmwareVersion,
      'status': status,
      'last_online': lastOnline?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'realtime_status': realtimeStatus?.toJson(),
    };
  }

  /// Copy object and modify partial fields
  Device copyWith({
    int? id,
    String? deviceId,
    String? name,
    String? deviceType,
    int? ownerId,
    String? firmwareVersion,
    String? status,
    DateTime? lastOnline,
    DateTime? createdAt,
    RealtimeStatus? realtimeStatus,
  }) {
    return Device(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      ownerId: ownerId ?? this.ownerId,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      status: status ?? this.status,
      lastOnline: lastOnline ?? this.lastOnline,
      createdAt: createdAt ?? this.createdAt,
      realtimeStatus: realtimeStatus ?? this.realtimeStatus,
    );
  }
}

/// Device realtime status
class RealtimeStatus {
  final bool? relay;
  final int? ledLevel;
  final int? setTime;
  final int? setTemp;
  final int? rssi;

  RealtimeStatus({
    this.relay,
    this.ledLevel,
    this.setTime,
    this.setTemp,
    this.rssi,
  });

  /// Create RealtimeStatus object from JSON
  factory RealtimeStatus.fromJson(Map<String, dynamic> json) {
    return RealtimeStatus(
      relay: json['relay'] as bool?,
      ledLevel: json['led_level'] as int?,
      setTime: json['set_time'] as int?,
      setTemp: json['set_temp'] as int?,
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
      'rssi': rssi,
    };
  }

  /// Copy object and modify partial fields
  RealtimeStatus copyWith({
    bool? relay,
    int? ledLevel,
    int? setTime,
    int? setTemp,
    int? rssi,
  }) {
    return RealtimeStatus(
      relay: relay ?? this.relay,
      ledLevel: ledLevel ?? this.ledLevel,
      setTime: setTime ?? this.setTime,
      setTemp: setTemp ?? this.setTemp,
      rssi: rssi ?? this.rssi,
    );
  }
}
