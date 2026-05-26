/// Firmware information model
class FirmwareInfo {
  final bool exists;
  final int? size;
  final String? uploadTime;

  FirmwareInfo({
    required this.exists,
    this.size,
    this.uploadTime,
  });

  /// Create FirmwareInfo object from JSON
  factory FirmwareInfo.fromJson(Map<String, dynamic> json) {
    return FirmwareInfo(
      exists: json['exists'] as bool? ?? false,
      size: json['size'] as int?,
      uploadTime: json['upload_time'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'exists': exists,
      'size': size,
      'upload_time': uploadTime,
    };
  }

  /// Get formatted file size (KB)
  String get formattedSize {
    if (size == null) return 'N/A';
    return '${(size! / 1024).toStringAsFixed(2)} KB';
  }
}
