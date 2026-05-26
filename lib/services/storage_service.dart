import 'package:shared_preferences/shared_preferences.dart';

/// Data storage service - manages various settings and data for the application
class StorageService {
  static const String _keyMode = 'device_mode'; // 'classic' or 'herbal'
  static const String _keyCurrentTemp = 'current_temp';
  static const String _keySetTemp = 'set_temp';
  static const String _keyCurrentTime = 'current_time';
  static const String _keySetTime = 'set_time';
  static const String _keyLightMode = 'light_mode';
  static const String _keyAutoSleepTime = 'auto_sleep_time';
  static const String _keyBoostCount = 'boost_count';
  static const String _keyLedEnabled = 'led_enabled';
  static const String _keySoundEnabled = 'sound_enabled';
  static const String _keyLightEnabled = 'light_enabled';

  static SharedPreferences? _prefs;

  static void _log(String message) {
    print('💾 Storage: $message');
  }

  /// Initialize
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // ==================== Mode related ====================

  /// Get current mode ('classic' or 'herbal')
  static String getMode() {
    return prefs.getString(_keyMode) ?? 'classic';
  }

  /// Set mode
  static Future<void> setMode(String mode) async {
    if (mode != 'classic' && mode != 'herbal') {
      throw ArgumentError('Mode must be "classic" or "herbal"');
    }
    _log('setMode -> $mode');
    await prefs.setString(_keyMode, mode);
  }

  // ==================== Temperature related ====================

  /// Get current temperature
  static int getCurrentTemp() {
    return prefs.getInt(_keyCurrentTemp) ?? 199;
  }

  /// Set current temperature
  static Future<void> setCurrentTemp(int temp) async {
    _log('setCurrentTemp -> $temp');
    await prefs.setInt(_keyCurrentTemp, temp);
  }

  /// Get set temperature
  static int getSetTemp() {
    return prefs.getInt(_keySetTemp) ?? 200;
  }

  /// Set set temperature
  static Future<void> setSetTemp(int temp) async {
    _log('setSetTemp -> $temp');
    await prefs.setInt(_keySetTemp, temp);
  }

  // ==================== Time related ====================

  /// Get current time (minutes)
  static int getCurrentTime() {
    return prefs.getInt(_keyCurrentTime) ?? 120;
  }

  /// Set current time (minutes)
  static Future<void> setCurrentTime(int minutes) async {
    _log('setCurrentTime -> $minutes');
    await prefs.setInt(_keyCurrentTime, minutes);
  }

  /// Get set time (minutes)
  static int getSetTime() {
    return prefs.getInt(_keySetTime) ?? 120;
  }

  /// Set set time (minutes)
  static Future<void> setSetTime(int minutes) async {
    _log('setSetTime -> $minutes');
    await prefs.setInt(_keySetTime, minutes);
  }

  // ==================== Light mode related ====================

  /// Get light mode (0-5)
  static int getLightMode() {
    return prefs.getInt(_keyLightMode) ?? 0;
  }

  /// Set light mode (0-5)
  static Future<void> setLightMode(int mode) async {
    if (mode < 0 || mode > 5) {
      throw ArgumentError('Light mode must be between 0-5');
    }
    _log('setLightMode -> $mode');
    await prefs.setInt(_keyLightMode, mode);
  }

  // ==================== Auto sleep time related ====================

  /// Get auto sleep time (minutes)
  static int getAutoSleepTime() {
    return prefs.getInt(_keyAutoSleepTime) ?? 15;
  }

  /// Set auto sleep time (minutes)
  static Future<void> setAutoSleepTime(int minutes) async {
    _log('setAutoSleepTime -> $minutes');
    await prefs.setInt(_keyAutoSleepTime, minutes);
  }

  // ==================== Boost count related ====================

  /// Get Boost count
  static int getBoostCount() {
    return prefs.getInt(_keyBoostCount) ?? 0;
  }

  /// Set Boost count
  static Future<void> setBoostCount(int count) async {
    _log('setBoostCount -> $count');
    await prefs.setInt(_keyBoostCount, count);
  }

  // ==================== Feature switches related ====================

  /// Get LED switch status
  static bool getLedEnabled() {
    return prefs.getBool(_keyLedEnabled) ?? true;
  }

  /// Set LED switch
  static Future<void> setLedEnabled(bool enabled) async {
    _log('setLedEnabled -> $enabled');
    await prefs.setBool(_keyLedEnabled, enabled);
  }

  /// Get sound switch status
  static bool getSoundEnabled() {
    return prefs.getBool(_keySoundEnabled) ?? true;
  }

  /// Set sound switch
  static Future<void> setSoundEnabled(bool enabled) async {
    _log('setSoundEnabled -> $enabled');
    await prefs.setBool(_keySoundEnabled, enabled);
  }

  /// Get light switch status
  static bool getLightEnabled() {
    return prefs.getBool(_keyLightEnabled) ?? true;
  }

  /// Set light switch
  static Future<void> setLightEnabled(bool enabled) async {
    _log('setLightEnabled -> $enabled');
    await prefs.setBool(_keyLightEnabled, enabled);
  }

  // ==================== Clear all data ====================

  /// Clear all stored data
  static Future<void> clearAll() async {
    _log('clearAll');
    await prefs.clear();
  }
}

