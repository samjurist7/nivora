import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/device.dart';
import '../models/firmware_info.dart';
import '../models/device_data.dart';
import '../models/control_log.dart';

/// API服务类
/// 负责与云服务器进行HTTP通信
class ApiService {
  /// 发送HTTP GET请求
  Future<http.Response> _get(String endpoint, {String? token}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(ApiConfig.timeout);
      _logResponse('GET', endpoint, response);
      return response;
    } catch (e) {
      print('❌ GET $endpoint 失败: $e');
      rethrow;
    }
  }

  /// 发送HTTP POST请求
  Future<http.Response> _post(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(ApiConfig.timeout);
      _logResponse('POST', endpoint, response);
      return response;
    } catch (e) {
      print('❌ POST $endpoint 失败: $e');
      rethrow;
    }
  }

  /// 发送HTTP DELETE请求
  Future<http.Response> _delete(String endpoint, {String? token}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await http
          .delete(url, headers: headers)
          .timeout(ApiConfig.timeout);
      _logResponse('DELETE', endpoint, response);
      return response;
    } catch (e) {
      print('❌ DELETE $endpoint 失败: $e');
      rethrow;
    }
  }

  /// 日志记录
  void _logResponse(String method, String endpoint, http.Response response) {
    print('📡 $method $endpoint - Status: ${response.statusCode}');
    if (response.statusCode >= 400) {
      print('   Response: ${response.body}');
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 处理HTTP响应，检查错误
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw ApiException('解析响应失败: $e');
      }
    } else if (response.statusCode == 401) {
      final body = _tryDecode(response.body);
      final error = body?['error'] ?? 'Incorrect email or password';
      throw ApiException(error, statusCode: 401);
    } else if (response.statusCode == 403) {
      final body = _tryDecode(response.body);
      final error = body?['error'] ?? 'Account not activated. Please check your email.';
      throw ApiException(error, statusCode: 403);
    } else if (response.statusCode == 404) {
      throw ApiException('Not found', statusCode: 404);
    } else if (response.statusCode >= 500) {
      throw ApiException('Server error, please try again later', statusCode: response.statusCode);
    } else {
      final body = _tryDecode(response.body);
      final error = body?['error'] ?? 'Request failed';
      throw ApiException(error, statusCode: response.statusCode);
    }
  }

  // ==================== 用户认证 ====================

  /// 用户登录
  /// 返回 {success: bool, token: String?, name: String?, error: String?}
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _post(
        ApiConfig.loginEndpoint,
        {'email': username, 'password': password},
      );

      final data = _handleResponse(response);

      if (data['success'] == true) {
        return {
          'success': true,
          'token': data['token'],
          'name': data['name'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? '登录失败',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e is ApiException ? e.message : '网络错误: $e',
      };
    }
  }

  /// 忘记密码 - 发送重置邮件
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _post(ApiConfig.forgotPasswordEndpoint, {'email': email});
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': e is ApiException ? e.message : '网络错误: $e',
      };
    }
  }

  /// 获取用户 profile（name, email）
  Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      final response = await _get(ApiConfig.profileEndpoint, token: token);
      return _handleResponse(response);
    } catch (e) {
      return {
        'success': false,
        'error': e is ApiException ? e.message : '网络错误: $e',
      };
    }
  }

  /// 用户注册
  /// 返回 {success: bool, error: String?}
  Future<Map<String, dynamic>> register(
      String email, String password, {String? name}) async {
    try {
      final response = await _post(
        ApiConfig.registerEndpoint,
        {'email': email, 'password': password, if (name != null && name.isNotEmpty) 'name': name},
      );

      final data = _handleResponse(response);

      if (data['success'] == true) {
        return {
          'success': true,
          'userId': data['user_id'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? '注册失败',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e is ApiException ? e.message : '网络错误: $e',
      };
    }
  }

  // ==================== 设备管理 ====================

  /// 获取用户的设备列表
  Future<List<Device>> getDevices(String token) async {
    try {
      final response = await _get(ApiConfig.devicesEndpoint, token: token);
      final data = _handleResponse(response);

      final devicesList = data['devices'] as List<dynamic>? ?? [];
      return devicesList
          .map((json) => Device.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('获取设备列表失败: $e');
      rethrow;
    }
  }

  /// 添加新设备
  Future<Device> addDevice(String token, String deviceId, String name) async {
    try {
      final response = await _post(
        ApiConfig.devicesEndpoint,
        {'device_id': deviceId, 'name': name},
        token: token,
      );

      final data = _handleResponse(response);

      if (data['success'] == true) {
        return Device.fromJson(data['device'] as Map<String, dynamic>);
      } else {
        throw ApiException(data['error'] ?? '添加设备失败');
      }
    } catch (e) {
      print('添加设备失败: $e');
      rethrow;
    }
  }

  /// 删除设备
  Future<void> deleteDevice(String token, String deviceId) async {
    try {
      final response = await _delete(
        ApiConfig.deviceDeleteEndpoint(deviceId),
        token: token,
      );

      final data = _handleResponse(response);

      if (data['success'] != true) {
        throw ApiException(data['error'] ?? '删除设备失败');
      }
    } catch (e) {
      print('删除设备失败: $e');
      rethrow;
    }
  }

  // ==================== 设备控制 ====================

  /// 控制设备
  /// action: relay_on, relay_off, led_level, led_off, set_time, set_temp
  /// level: LED档位 (0-5)，仅在action为led_level时使用
  /// value: 时间或温度值，仅在action为set_time或set_temp时使用
  Future<void> controlDevice(
    String token,
    String deviceId,
    String action, {
    int? level,
    int? value,
  }) async {
    try {
      final body = <String, dynamic>{'action': action};

      if (level != null) {
        body['level'] = level;
      }

      if (value != null) {
        body['value'] = value;
      }

      final response = await _post(
        ApiConfig.deviceControlEndpoint(deviceId),
        body,
        token: token,
      );

      final data = _handleResponse(response);

      if (data['success'] != true) {
        throw ApiException(data['error'] ?? '控制设备失败');
      }
    } catch (e) {
      print('控制设备失败: $e');
      rethrow;
    }
  }

  // ==================== 数据查询 ====================

  /// 获取设备历史数据
  Future<List<DeviceData>> getDeviceData(
    String token,
    String deviceId, {
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (startTime != null) 'start_time': startTime.toIso8601String(),
        if (endTime != null) 'end_time': endTime.toIso8601String(),
      };

      final endpoint = ApiConfig.deviceDataEndpoint(deviceId);
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.timeout);

      final data = _handleResponse(response);

      final dataList = data['data'] as List<dynamic>? ?? [];
      return dataList
          .map((json) => DeviceData.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('获取设备数据失败: $e');
      rethrow;
    }
  }

  /// 获取控制日志
  Future<List<ControlLog>> getControlLogs(
    String token,
    String deviceId, {
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      final endpoint = ApiConfig.deviceLogsEndpoint(deviceId);
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(ApiConfig.timeout);

      final data = _handleResponse(response);

      final logsList = data['logs'] as List<dynamic>? ?? [];
      return logsList
          .map((json) => ControlLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('获取控制日志失败: $e');
      rethrow;
    }
  }

  // ==================== OTA固件升级 ====================

  /// 获取固件信息
  Future<FirmwareInfo> getFirmwareInfo(String token) async {
    try {
      final response =
          await _get(ApiConfig.firmwareInfoEndpoint, token: token);
      final data = _handleResponse(response);

      if (data['success'] == true) {
        return FirmwareInfo.fromJson(data);
      } else {
        throw ApiException(data['error'] ?? '获取固件信息失败');
      }
    } catch (e) {
      print('获取固件信息失败: $e');
      rethrow;
    }
  }

  /// 触发OTA升级
  Future<void> triggerOTA(String token, String deviceId) async {
    try {
      final response = await _post(
        ApiConfig.otaTriggerEndpoint,
        {'device_id': deviceId},
        token: token,
      );

      final data = _handleResponse(response);

      if (data['success'] != true) {
        throw ApiException(data['error'] ?? 'OTA升级触发失败');
      }
    } catch (e) {
      print('触发OTA升级失败: $e');
      rethrow;
    }
  }

  /// 触发SD卡更新
  Future<void> triggerSdcardUpdate(String token, String deviceId) async {
    try {
      final response = await _post(
        ApiConfig.sdcardTriggerEndpoint,
        {'device_id': deviceId},
        token: token,
      );

      final data = _handleResponse(response);

      if (data['success'] != true) {
        throw ApiException(data['error'] ?? 'SD卡更新触发失败');
      }
    } catch (e) {
      print('触发SD卡更新失败: $e');
      rethrow;
    }
  }

  /// 触发SPIFFS OTA升级
  Future<void> triggerSpiffsOta(String token, String deviceId) async {
    try {
      final response = await _post(
        ApiConfig.spiffsTriggerEndpoint,
        {'device_id': deviceId},
        token: token,
      );

      final data = _handleResponse(response);

      if (data['success'] != true) {
        throw ApiException(data['error'] ?? 'SPIFFS OTA触发失败');
      }
    } catch (e) {
      print('触发SPIFFS OTA失败: $e');
      rethrow;
    }
  }

  /// Upload a preset image (358×269 PNG) to the server
  Future<Map<String, dynamic>> uploadPresetImage(
      String token, int presetNum, List<int> imageBytes, String filename) async {
    final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.spiffsFileUploadEndpoint}?preset=$presetNum');
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', imageBytes,
        filename: filename));

    try {
      final streamed = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamed);
      _logResponse('POST', ApiConfig.spiffsFileUploadEndpoint, response);
      return _handleResponse(response);
    } catch (e) {
      print('❌ POST spiffs-file/upload failed: $e');
      rethrow;
    }
  }

  /// Trigger device to pull and write a preset image from server
  Future<void> triggerPresetPush(String token, String deviceId,
      String filename, String spiffsPath) async {
    try {
      final response = await _post(
        ApiConfig.spiffsFileTriggerEndpoint,
        {'device_id': deviceId, 'filename': filename, 'spiffs_path': spiffsPath},
        token: token,
      );
      final data = _handleResponse(response);
      if (data['success'] != true) {
        throw ApiException(data['error'] ?? 'Failed to push preset to device');
      }
    } catch (e) {
      print('❌ triggerPresetPush failed: $e');
      rethrow;
    }
  }

  /// Upload a video and convert it to screensaver GIF on server
  Future<Map<String, dynamic>> uploadAndConvertScreensaver(
      String token, List<int> videoBytes, String filename) async {
    final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.screensaverUploadConvertEndpoint}');
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('video', videoBytes,
        filename: filename));

    try {
      // Video conversion can take a long time, use 3-minute timeout
      final streamed =
          await request.send().timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamed);
      _logResponse('POST', ApiConfig.screensaverUploadConvertEndpoint, response);
      return _handleResponse(response);
    } catch (e) {
      print('❌ POST screensaver/upload-convert failed: $e');
      rethrow;
    }
  }

  // ==================== 旧方法（保留兼容性）====================

  /// 发送命令（保留旧接口）
  @Deprecated('使用 controlDevice 代替')
  Future<http.Response> postCommand(
      String token, Map<String, dynamic> body) {
    final url = Uri.parse("${ApiConfig.baseUrl}/command");
    return http.post(url, headers: {
      'Authorization': "Bearer $token",
      'Content-Type': 'application/json'
    }, body: jsonEncode(body));
  }
}

/// API异常类
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
