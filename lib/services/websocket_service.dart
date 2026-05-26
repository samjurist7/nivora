import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/device_update.dart';

/// WebSocket connection status
enum WebSocketStatus {
  disconnected, // Disconnected
  connecting, // Connecting
  connected, // Connected
  reconnecting, // Reconnecting
}

/// WebSocket service class
/// Responsible for WebSocket real-time communication with cloud server
class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  WebSocketStatus _status = WebSocketStatus.disconnected;

  // Device update stream controller
  final _deviceUpdateController = StreamController<DeviceUpdate>.broadcast();

  // Auto reconnect delay
  static const Duration _reconnectDelay = Duration(seconds: 5);

  // Connection status
  WebSocketStatus get status => _status;
  bool get isConnected => _status == WebSocketStatus.connected;

  // Device update stream
  Stream<DeviceUpdate> get deviceUpdates => _deviceUpdateController.stream;

  /// Connect to WebSocket server
  void connect() {
    if (_status == WebSocketStatus.connected ||
        _status == WebSocketStatus.connecting) {
      print('⚠️  WebSocket already connected or connecting');
      return;
    }

    _updateStatus(WebSocketStatus.connecting);
    print('🔌 Connecting to WebSocket: ${ApiConfig.wsUrl}');

    try {
      final uri = Uri.parse(ApiConfig.wsUrl);
      _channel = WebSocketChannel.connect(uri);

      // Listen to WebSocket messages
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: false,
      );

      _updateStatus(WebSocketStatus.connected);
      print('✅ WebSocket connection successful');
    } catch (e) {
      print('❌ WebSocket connection failed: $e');
      _updateStatus(WebSocketStatus.disconnected);
      _scheduleReconnect();
    }
  }

  /// Handle received messages
  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        final json = jsonDecode(message) as Map<String, dynamic>;
        _processMessage(json);
      } else {
        print('⚠️  Received non-string message: ${message.runtimeType}');
      }
    } catch (e) {
      print('❌ Failed to parse WebSocket message: $e');
      print('   Original message: $message');
    }
  }

  /// Process message content
  void _processMessage(Map<String, dynamic> json) {
    final type = json['type'] as String?;

    if (type == 'device_update') {
      try {
        final update = DeviceUpdate.fromJson(json);
        _deviceUpdateController.add(update);
        print('📨 Received device update: ${update.deviceId} - ${update.data.toJson()}');
      } catch (e) {
        print('❌ Failed to parse device update: $e');
      }
    } else {
      print('⚠️  Unknown message type: $type');
      print('   Message content: $json');
    }
  }

  /// Handle WebSocket errors
  void _handleError(error) {
    print('❌ WebSocket error: $error');
    _updateStatus(WebSocketStatus.disconnected);
    _scheduleReconnect();
  }

  /// Handle WebSocket disconnection
  void _handleDisconnect() {
    print('⚠️  WebSocket connection disconnected');
    _updateStatus(WebSocketStatus.disconnected);
    _scheduleReconnect();
  }

  /// Update connection status
  void _updateStatus(WebSocketStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  /// Schedule auto reconnect
  void _scheduleReconnect() {
    // Cancel existing reconnect timer
    _reconnectTimer?.cancel();

    // If already reconnecting, don't schedule again
    if (_status == WebSocketStatus.reconnecting) {
      return;
    }

    _updateStatus(WebSocketStatus.reconnecting);
    print('⏰ Retrying connection in ${_reconnectDelay.inSeconds} seconds...');

    _reconnectTimer = Timer(_reconnectDelay, () {
      print('🔄 Starting WebSocket reconnect...');
      _reconnect();
    });
  }

  /// Reconnect
  void _reconnect() {
    _cleanup();
    connect();
  }

  /// Disconnect
  void disconnect() {
    print('🔌 Disconnecting WebSocket');
    _reconnectTimer?.cancel();
    _cleanup();
    _updateStatus(WebSocketStatus.disconnected);
  }

  /// Cleanup resources
  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  /// Send message (extended feature, currently not used)
  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && isConnected) {
      try {
        _channel!.sink.add(jsonEncode(message));
        print('📤 Sending WebSocket message: $message');
      } catch (e) {
        print('❌ Failed to send WebSocket message: $e');
      }
    } else {
      print('⚠️  WebSocket not connected, cannot send message');
    }
  }

  /// Get connection status description
  String get statusDescription {
    switch (_status) {
      case WebSocketStatus.disconnected:
        return 'Disconnected';
      case WebSocketStatus.connecting:
        return 'Connecting...';
      case WebSocketStatus.connected:
        return 'Connected';
      case WebSocketStatus.reconnecting:
        return 'Reconnecting...';
    }
  }

  @override
  void dispose() {
    print('🗑️  WebSocketService disposed');
    _reconnectTimer?.cancel();
    _deviceUpdateController.close();
    _cleanup();
    super.dispose();
  }
}
