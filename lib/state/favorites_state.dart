import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repository/preferences_repository.dart';

/// 收藏状态（四类：漫画期 / 系列 / 指南）+ 自建书单。
///
/// 内存改动与广播都是同步的，落盘在后台进行——滑动删除 + 撤销需要列表
/// 在同一帧内变化，否则 `Dismissible` 会报"已 dismiss 的组件仍在树里"。
class FavoritesState extends ChangeNotifier {
  FavoritesState(this._prefs);

  final PreferencesRepository _prefs;

  List<FavoriteEntry> get entries => _prefs.favorites;

  List<UserList> get lists => _prefs.userLists;

  bool get isReady => _prefs.isReady;

  // ── 判断 ─────────────────────────────────────────────────────

  bool isFavorite(FavoriteKind kind, String id) =>
      _prefs.isFavorite(kind, id);

  bool containsInList(String listId, FavoriteKind kind, String id) {
    final list = _prefs.userList(listId);
    return list.items.any((e) => e.kind == kind && e.id == id);
  }

  // ── 收藏 ─────────────────────────────────────────────────────

  /// 返回「现在是否已收藏」。
  bool toggle(FavoriteEntry entry) {
    final now = _prefs.toggleFavorite(entry);
    unawaited(_prefs.persistFavorites());
    notifyListeners();
    return now;
  }

  /// 移除并返回它原来的下标，供撤销时复位。
  int remove(FavoriteEntry entry) {
    final index = _prefs.removeFavorite(entry.kind, entry.id);
    unawaited(_prefs.persistFavorites());
    notifyListeners();
    return index;
  }

  void restore(FavoriteEntry entry, int index) {
    _prefs.insertFavorite(entry, index < 0 ? 0 : index);
    unawaited(_prefs.persistFavorites());
    notifyListeners();
  }

  // ── 自建书单 ─────────────────────────────────────────────────

  UserList createList(String name) {
    final list = _prefs.createUserList(name);
    unawaited(_prefs.persistUserLists());
    notifyListeners();
    return list;
  }

  void renameList(String id, String name) {
    _prefs.renameUserList(id, name);
    unawaited(_prefs.persistUserLists());
    notifyListeners();
  }

  void deleteList(String id) {
    _prefs.deleteUserList(id);
    unawaited(_prefs.persistUserLists());
    notifyListeners();
  }

  /// 返回「现在是否在单里」。
  bool toggleListItem(String listId, FavoriteEntry entry) {
    final now = _prefs.toggleUserListItem(listId, entry);
    unawaited(_prefs.persistUserLists());
    notifyListeners();
    return now;
  }
}