import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts the user's Light / Dark mode preference.
class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _keyDarkMode = 'ddart_dark_mode';

  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  ThemeMode get themeMode => themeModeNotifier.value;

  bool get isDark => themeModeNotifier.value == ThemeMode.dark;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDark = prefs.getBool(_keyDarkMode) ?? false;
      themeModeNotifier.value = savedDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      themeModeNotifier.value = ThemeMode.light;
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    themeModeNotifier.value = enabled ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDarkMode, enabled);
    } catch (_) {}
  }

  Future<void> toggle() => setDarkMode(!isDark);

  void resetForTest() {
    themeModeNotifier.value = ThemeMode.light;
  }
}
