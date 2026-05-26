import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User service - manages user login status and user information
class UserService extends ChangeNotifier {
  static const String _keyUsername = 'username';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserAvatar = 'user_avatar';
  static const String _keyTempUnit = 'temp_unit'; // 0: C, 1: F
  static const String _keyJwtToken = 'jwt_token'; // JWT token
  static const String _keySavedEmail = 'saved_email';
  static const String _keySavedPassword = 'saved_password';

  String? _username;
  bool _isLoggedIn = false;
  String? _avatarUrl;
  bool _isFahrenheit = false; // Default to Celsius
  String? _jwtToken; // JWT token
  String? _savedEmail;
  String? _savedPassword;
  bool _initialized = false;

  String? get username => _username;
  bool get isLoggedIn => _isLoggedIn;
  String? get avatarUrl => _avatarUrl;
  bool get isFahrenheit => _isFahrenheit;
  String? get jwtToken => _jwtToken;
  String? get savedEmail => _savedEmail;
  String? get savedPassword => _savedPassword;
  bool get initialized => _initialized;

  UserService() {
    _loadUserInfo();
  }

  /// Load user information
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString(_keyUsername);
    _isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    _avatarUrl = prefs.getString(_keyUserAvatar);
    _isFahrenheit = prefs.getBool(_keyTempUnit) ?? false;
    _jwtToken = prefs.getString(_keyJwtToken);
    _savedEmail = prefs.getString(_keySavedEmail);
    _savedPassword = prefs.getString(_keySavedPassword);
    _initialized = true;
    notifyListeners();
  }

  /// Toggle temperature unit
  Future<void> toggleTempUnit() async {
    final prefs = await SharedPreferences.getInstance();
    _isFahrenheit = !_isFahrenheit;
    await prefs.setBool(_keyTempUnit, _isFahrenheit);
    notifyListeners();
  }

  /// Login
  Future<void> login(String username, {String? avatarUrl, String? token, String? email, String? password}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
    await prefs.setBool(_keyIsLoggedIn, true);
    if (avatarUrl != null) {
      await prefs.setString(_keyUserAvatar, avatarUrl);
    }
    if (token != null) {
      await prefs.setString(_keyJwtToken, token);
    }
    if (email != null) {
      await prefs.setString(_keySavedEmail, email);
      _savedEmail = email;
    }
    if (password != null) {
      await prefs.setString(_keySavedPassword, password);
      _savedPassword = password;
    }
    _username = username;
    _isLoggedIn = true;
    _avatarUrl = avatarUrl;
    _jwtToken = token;
    notifyListeners();
  }

  /// Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyUserAvatar);
    await prefs.remove(_keyJwtToken);
    _username = null;
    _isLoggedIn = false;
    _avatarUrl = null;
    _jwtToken = null;
    notifyListeners();
  }

  /// Update username
  Future<void> updateUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
    _username = username;
    notifyListeners();
  }

  /// Update avatar
  Future<void> updateAvatar(String avatarUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserAvatar, avatarUrl);
    _avatarUrl = avatarUrl;
    notifyListeners();
  }

  /// Check if there is a valid JWT token
  bool hasValidToken() {
    return _jwtToken != null && _jwtToken!.isNotEmpty && _isLoggedIn;
  }

  /// Update JWT token (used for token refresh)
  Future<void> updateToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyJwtToken, token);
    _jwtToken = token;
    notifyListeners();
  }
}

