import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_storage.dart';

/// 搜索历史域：联想词与历史记录的持久化。
/// 仅 `PreferencesRepository.load()` 负责调用 `loadSearchHistory`。
mixin SearchHistoryPrefs {
  PrefsStorage get storage;

  static const _keyHistory = 'search_history_v1';

  /// 搜索历史最多留这么多条。
  static const _historyLimit = 12;

  final List<String> _history = [];

  void loadSearchHistory(SharedPreferences prefs) {
    _history
      ..clear()
      ..addAll(prefs.getStringList(_keyHistory) ?? const []);
  }

  // ── 搜索历史 ─────────────────────────────────────────────────

  List<String> get searchHistory => List.unmodifiable(_history);

  Future<void> pushSearchHistory(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _history.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    _history.insert(0, q);
    if (_history.length > _historyLimit) {
      _history.removeRange(_historyLimit, _history.length);
    }
    await storage.instance?.setStringList(_keyHistory, _history);
  }

  Future<void> clearSearchHistory() async {
    _history.clear();
    await storage.instance?.setStringList(_keyHistory, const []);
  }
}
