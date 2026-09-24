import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/local_library.dart';
import 'prefs_storage.dart';

/// 阅读状态域：阅读进度 + 书签（都只被阅读器/继续阅读消费，一起演化）。
/// 仅 `PreferencesRepository.load()` 负责调用 `loadReadingState`。
mixin ReadingPrefs {
  PrefsStorage get storage;

  static const _keyProgress = 'reading_progress_v1';
  static const _keyBookmarks = 'bookmarks_v1';

  final Map<String, ReadingProgress> _progress = {};
  final Map<String, List<IssueBookmark>> _bookmarks = {};

  void loadReadingState(SharedPreferences prefs) {
    _progress.clear();
    for (final raw in prefs.getStringList(_keyProgress) ?? const []) {
      try {
        final p = ReadingProgress.fromJson(jsonDecode(raw) as Map);
        _progress[p.issue.id] = p;
      } catch (_) {
        // 单条损坏跳过，不影响其它进度
      }
    }

    _bookmarks.clear();
    final bmRaw = prefs.getString(_keyBookmarks);
    if (bmRaw != null) {
      try {
        final map = jsonDecode(bmRaw) as Map<String, dynamic>;
        map.forEach((issueId, list) {
          _bookmarks[issueId] = (list as List? ?? [])
              .map((e) => IssueBookmark.fromJson(issueId, e as Map))
              .toList();
        });
      } catch (_) {
        // 损坏就当没有书签
      }
    }
  }

  // ── 阅读进度 ─────────────────────────────────────────────────

  ReadingProgress? progressFor(String issueId) => _progress[issueId];

  /// 按最近阅读时间倒序。
  List<ReadingProgress> get recentProgress {
    final list = _progress.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(list);
  }

  /// 在「继续阅读」里展示的：翻过页且没读完的。
  List<ReadingProgress> get continueReading =>
      recentProgress.where((p) => p.isReading).toList();

  Future<void> saveProgress(ReadingProgress progress) async {
    _progress[progress.issue.id] = progress;
    await _persistProgress();
  }

  Future<void> clearProgress(String issueId) async {
    _progress.remove(issueId);
    await _persistProgress();
  }

  Future<void> _persistProgress() async {
    await storage.instance?.setStringList(
      _keyProgress,
      _progress.values.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  // ── 书签 ─────────────────────────────────────────────────────

  /// 某期的全部书签，按页码排序。
  List<IssueBookmark> bookmarksFor(String issueId) {
    final list = _bookmarks[issueId] ?? const [];
    return List.unmodifiable(
      [...list]..sort((a, b) => a.page.compareTo(b.page)),
    );
  }

  /// 当前页是否已有书签。
  bool hasBookmark(String issueId, int page) =>
      _bookmarks[issueId]?.any((b) => b.page == page) ?? false;

  /// 加/去书签（同一页再点一次就是删）。返回「现在有没有书签」。
  bool toggleBookmark(String issueId, int page) {
    final list = _bookmarks.putIfAbsent(issueId, () => []);
    final existing = list.indexWhere((b) => b.page == page);
    if (existing >= 0) {
      list.removeAt(existing);
    } else {
      list.add(
        IssueBookmark(issueId: issueId, page: page, createdAt: DateTime.now()),
      );
    }
    unawaited(_persistBookmarks());
    return existing < 0;
  }

  Future<void> _persistBookmarks() async {
    final map = _bookmarks.map(
      (k, v) => MapEntry(k, v.map((b) => b.toJson()).toList()),
    );
    await storage.instance?.setString(_keyBookmarks, jsonEncode(map));
  }
}
