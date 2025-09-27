import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const _themeModeKey = 'themeMode';
  static const _seedColorKey = 'seedColor';
  static const _notificationsKey = 'notificationsEnabled';
  static const _smartRepliesKey = 'smartReplySuggestions';
  static const _autoArchiveKey = 'autoArchiveChats';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _preferences {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('UserPreferences.init() must be called before use.');
    }
    return prefs;
  }

  static ThemeMode get themeMode {
    final value = _preferences.getString(_themeModeKey);
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      _ => 'light',
    };
    await _preferences.setString(_themeModeKey, value);
  }

  static Color get seedColor {
    final storedValue = _preferences.getInt(_seedColorKey);
    if (storedValue == null) {
      return Colors.indigo;
    }
    return Color(storedValue);
  }

  static Future<void> setSeedColor(Color color) async {
    await _preferences.setInt(_seedColorKey, color.value);
  }

  static bool get notificationsEnabled =>
      _preferences.getBool(_notificationsKey) ?? true;

  static Future<void> setNotificationsEnabled(bool value) async {
    await _preferences.setBool(_notificationsKey, value);
  }

  static bool get smartReplySuggestions =>
      _preferences.getBool(_smartRepliesKey) ?? false;

  static Future<void> setSmartReplySuggestions(bool value) async {
    await _preferences.setBool(_smartRepliesKey, value);
  }

  static bool get autoArchiveChats =>
      _preferences.getBool(_autoArchiveKey) ?? true;

  static Future<void> setAutoArchiveChats(bool value) async {
    await _preferences.setBool(_autoArchiveKey, value);
  }
}
