import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/local_library.dart';
import 'prefs_storage.dart';

/// 自建书单域：书单的内存快照与持久化。
/// 仅 `PreferencesRepository.load()` 负责调用 `loadUserLists`。
mixin UserListsPrefs {
  PrefsStorage get storage;

  static const _keyUserLists = 'user_lists_v1';

  final List<UserList> _userLists = [];

  void loadUserLists(SharedPreferences prefs) {
    _userLists
      ..clear()
      ..addAll(
        (prefs.getStringList(_keyUserLists) ?? const []).map(
          (r) => decodePrefsEntry(r, UserList.fromJson),
        ),
      );
  }

  // ── 自建书单 ─────────────────────────────────────────────────

  List<UserList> get userLists => List.unmodifiable(_userLists);

  UserList userList(String id) {
    for (final l in _userLists) {
      if (l.id == id) return l;
    }
    return UserList(id: id, name: '', createdAt: DateTime.now());
  }

  UserList createUserList(String name) {
    final list = UserList(
      id: 'list-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? '未命名书单' : name.trim(),
      createdAt: DateTime.now(),
    );
    _userLists.insert(0, list);
    return list;
  }

  void renameUserList(String id, String name) {
    final i = _userLists.indexWhere((l) => l.id == id);
    if (i >= 0) _userLists[i] = _userLists[i].copyWith(name: name);
  }

  void deleteUserList(String id) => _userLists.removeWhere((l) => l.id == id);

  /// 把条目加进书单（已存在则移除，返回「现在是否在单里」）。
  bool toggleUserListItem(String listId, FavoriteEntry entry) {
    final i = _userLists.indexWhere((l) => l.id == listId);
    if (i < 0) return false;
    final list = _userLists[i];
    final existed = list.items.any(
      (e) => e.kind == entry.kind && e.id == entry.id,
    );
    final items = [...list.items];
    if (existed) {
      items.removeWhere((e) => e.kind == entry.kind && e.id == entry.id);
    } else {
      items.add(entry);
    }
    _userLists[i] = list.copyWith(items: items);
    return !existed;
  }

  Future<void> persistUserLists() async {
    await storage.instance?.setStringList(
      _keyUserLists,
      _userLists.map((l) => jsonEncode(l.toJson())).toList(),
    );
  }
}
