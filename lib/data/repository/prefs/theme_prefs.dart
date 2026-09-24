import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_storage.dart';

/// 主题域：跟随系统 / 浅色 / 深色，选择持久化。
///
/// 对外直接给 [ThemeMode]；存档里是 'system' | 'light' | 'dark'
/// 字符串（持久化细节，不外泄）。
mixin ThemePrefs {
  PrefsStorage get storage;

  static const _keyThemeMode = 'theme_mode_v1';

  ThemeMode _themeMode = ThemeMode.system;

  void loadTheme(SharedPreferences prefs) {
    _themeMode = switch (prefs.getString(_keyThemeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await storage.instance?.setString(_keyThemeMode, mode.name);
  }
}
