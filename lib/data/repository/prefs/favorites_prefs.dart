import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/local_library.dart';
import '../../models/marvel_models.dart';
import 'prefs_storage.dart';

/// 收藏域：四类收藏的内存快照与持久化。
///
/// v1 只有 issue 收藏；v2 起四类共存，加载时自动把 v1 迁过来。
/// 仅 `PreferencesRepository.load()` 负责调用 `loadFavorites`。
mixin FavoritesPrefs {
  PrefsStorage get storage;

  static const _keyFavoritesV1 = 'favorites_v1';
  static const _keyFavoritesV2 = 'favorites_v2';

  final List<FavoriteEntry> _favorites = [];

  void loadFavorites(SharedPreferences prefs) {
    _favorites
      ..clear()
      ..addAll(_loadFavoritesV2(prefs));
  }

  /// 读 v2；没有 v2 就把 v1 的 issue 收藏迁过来（迁完写回 v2）。
  List<FavoriteEntry> _loadFavoritesV2(SharedPreferences prefs) {
    final v2Raw = prefs.getStringList(_keyFavoritesV2);
    if (v2Raw != null) {
      return v2Raw
          .map((r) => decodePrefsEntry(r, FavoriteEntry.fromJson))
          .toList();
    }
    final migrated = (prefs.getStringList(_keyFavoritesV1) ?? const [])
        .map((r) => decodePrefsEntry(r, ComicIssue.fromJson))
        .map(FavoriteEntry.fromIssue)
        .toList();
    if (migrated.isNotEmpty) {
      prefs.setStringList(
        _keyFavoritesV2,
        migrated.map((e) => jsonEncode(e.toJson())).toList(),
      );
    }
    return migrated;
  }

  // ── 收藏 ─────────────────────────────────────────────────────

  List<FavoriteEntry> get favorites => List.unmodifiable(_favorites);

  bool isFavorite(FavoriteKind kind, String id) =>
      _favorites.any((e) => e.kind == kind && e.id == id);

  FavoriteEntry? favoriteOf(FavoriteKind kind, String id) {
    for (final e in _favorites) {
      if (e.kind == kind && e.id == id) return e;
    }
    return null;
  }

  /// 同步改内存并返回「现在是否已收藏」，落盘由调用方触发。
  bool toggleFavorite(FavoriteEntry entry) {
    final existed = isFavorite(entry.kind, entry.id);
    _favorites.removeWhere((e) => e.kind == entry.kind && e.id == entry.id);
    if (!existed) _favorites.insert(0, entry);
    return !existed;
  }

  int removeFavorite(FavoriteKind kind, String id) {
    final index = _favorites.indexWhere((e) => e.kind == kind && e.id == id);
    if (index >= 0) _favorites.removeAt(index);
    return index;
  }

  void insertFavorite(FavoriteEntry entry, int at) {
    _favorites.removeWhere((e) => e.kind == entry.kind && e.id == entry.id);
    _favorites.insert(at.clamp(0, _favorites.length), entry);
  }

  Future<void> persistFavorites() async {
    await storage.instance?.setStringList(
      _keyFavoritesV2,
      _favorites.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }
}
