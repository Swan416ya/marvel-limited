import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/local_library.dart';
import 'prefs_storage.dart';

/// 追更域：追更系列的内存快照与持久化。
/// 仅 `PreferencesRepository.load()` 负责调用 `loadFollows`。
mixin FollowsPrefs {
  PrefsStorage get storage;

  static const _keyFollows = 'followed_series_v1';

  final List<FollowedSeries> _follows = [];

  void loadFollows(SharedPreferences prefs) {
    _follows
      ..clear()
      ..addAll(
        (prefs.getStringList(_keyFollows) ?? const []).map(
          (r) => decodePrefsEntry(r, FollowedSeries.fromJson),
        ),
      );
  }

  // ── 追更 ─────────────────────────────────────────────────────

  List<FollowedSeries> get follows => List.unmodifiable(_follows);

  bool isFollowing(String seriesId) =>
      _follows.any((f) => f.seriesId == seriesId);

  /// 返回「现在是否在追」。
  bool toggleFollow(FollowedSeries series) {
    final existed = isFollowing(series.seriesId);
    _follows.removeWhere((f) => f.seriesId == series.seriesId);
    if (!existed) _follows.insert(0, series);
    return !existed;
  }

  Future<void> persistFollows() async {
    await storage.instance?.setStringList(
      _keyFollows,
      _follows.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }
}
