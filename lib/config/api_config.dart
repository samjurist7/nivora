import 'package:flutter/foundation.dart';

/// API configuration class
/// Stores API endpoint and WebSocket address for cloud server
class ApiConfig {
  // Web uses relative path (proxied by Vercel), native uses direct URL
  static String get baseUrl =>
      kIsWeb ? '/api' : 'http://43.138.237.99/api';

  // WebSocket address
  static String get wsUrl =>
      kIsWeb ? 'wss://${Uri.base.host}/api/ws' : 'ws://43.138.237.99/api/ws';

  // Firmware download URL prefix
  static String get firmwareBaseUrl =>
      kIsWeb ? '/firmware' : 'http://43.138.237.99/firmware';

  // Request timeout
  static const Duration timeout = Duration(seconds: 30);

  // Production environment configuration (for future use when HTTPS is enabled)
  // static const String baseUrl = 'https://yourdomain.com/api';
  // static const String wsUrl = 'wss://yourdomain.com/api/ws';

  /// API endpoints
  static const String loginEndpoint = '/login';
  static const String registerEndpoint = '/register';
  static const String profileEndpoint = '/profile';
  static const String forgotPasswordEndpoint = '/forgot-password';
  static const String devicesEndpoint = '/devices';
  static const String firmwareInfoEndpoint = '/firmware/info';
  static const String firmwareUploadEndpoint = '/firmware/upload';
  static const String otaTriggerEndpoint = '/ota/trigger';
  static const String sdcardTriggerEndpoint = '/sdcard/trigger';
  static const String spiffsTriggerEndpoint = '/spiffs-ota/trigger';
  static const String spiffsFileUploadEndpoint = '/spiffs-file/upload';
  static const String spiffsFileTriggerEndpoint = '/spiffs-file/trigger';
  static const String screensaverUploadConvertEndpoint = '/screensaver/upload-convert';

  /// Get device control endpoint
  static String deviceControlEndpoint(String deviceId) =>
      '/devices/$deviceId/control';

  /// Get device data endpoint
  static String deviceDataEndpoint(String deviceId) =>
      '/devices/$deviceId/data';

  /// Get device logs endpoint
  static String deviceLogsEndpoint(String deviceId) =>
      '/devices/$deviceId/logs';

  /// Get device delete endpoint
  static String deviceDeleteEndpoint(String deviceId) =>
      '/devices/$deviceId';
}
