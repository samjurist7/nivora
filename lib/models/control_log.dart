/// Control log model
class ControlLog {
  final int id;
  final String deviceId;
  final int userId;
  final String action;
  final String result;
  final DateTime createdAt;
  final String? username;

  ControlLog({
    required this.id,
    required this.deviceId,
    required this.userId,
    required this.action,
    required this.result,
    required this.createdAt,
    this.username,
  });

  /// Create ControlLog object from JSON
  factory ControlLog.fromJson(Map<String, dynamic> json) {
    return ControlLog(
      id: json['id'] as int,
      deviceId: json['device_id'] as String,
      userId: json['user_id'] as int,
      action: json['action'] as String,
      result: json['result'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: json['username'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'user_id': userId,
      'action': action,
      'result': result,
      'created_at': createdAt.toIso8601String(),
      'username': username,
    };
  }
}
