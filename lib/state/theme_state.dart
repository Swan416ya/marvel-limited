import 'package:flutter/material.dart';

import '../data/repository/preferences_repository.dart';

/// 主题模式：跟随系统 / 浅色 / 深色，选择持久化（ThemeMode 直存直取）。
class ThemeState extends ChangeNotifier {
  ThemeState(this._prefs);

  final PreferencesRepository _prefs;

  ThemeMode get mode => _prefs.themeMode;

  /// 循环切换：system → light → dark → system。
  Future<void> cycle() async {
    final next = switch (mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setMode(next);
  }

  Future<void> setMode(ThemeMode mode) async {
    await _prefs.setThemeMode(mode);
    notifyListeners();
  }
}
