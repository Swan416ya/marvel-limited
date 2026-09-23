import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/marvel_models.dart';

/// 一条阅读进度。带上 issue 快照，这样「继续阅读」不联网也能画出来。
class ReadingProgress {
  final ComicIssue issue;

  /// 当前页（0 基）。
  final int page;
  final int totalPages;
  final DateTime updatedAt;

  const ReadingProgress({
    required this.issue,
    required this.page,
    required this.totalPages,
    required this.updatedAt,
  });

  /// 读到哪（0~1），用于进度条。
  double get ratio =>
      totalPages <= 0 ? 0 : ((page + 1) / totalPages).clamp(0.0, 1.0);

  /// 是否已经翻到最后一页。
  bool get isFinished => totalPages > 0 && page >= totalPages - 1;

  /// 是否算「在读」：翻过页但没读完。
  bool get isReading => !isFinished && page > 0;

  Map<String, dynamic> toJson() => {
    'issue': issue.toJson(),
    'page': page,
    'totalPages': totalPages,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ReadingProgress.fromJson(Map json) => ReadingProgress(
    issue: ComicIssue.fromJson(json['issue'] as Map),
    page: (json['page'] as num?)?.toInt() ?? 0,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    updatedAt:
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// 收藏条目的种类。
enum FavoriteKind {
  issue('漫画期'),
  series('系列'),
  guide('阅读指南');

  const FavoriteKind(this.label);
  final String label;

  static FavoriteKind fromName(String? name) => switch (name) {
    'series' => FavoriteKind.series,
    'guide' => FavoriteKind.guide,
    _ => FavoriteKind.issue,
  };
}

/// 一条收藏。不同种类共用这个壳，点击行为由 kind 决定：
/// - issue → 详情页（带 issueJson 快照，离线可开）
/// - series → 系列页
/// - guide → 指南详情（带最小快照）
class FavoriteEntry {
  const FavoriteEntry({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    this.coverUrl,
    this.issueJson,
    this.addedAt,
  });

  final FavoriteKind kind;
  final String id;
  final String title;

  /// 副标题：issue 用系列名，series 用年份等。
  final String? subtitle;
  final String? coverUrl;

  /// `ComicIssue.toJson()` 的快照，仅 kind == issue 时有。
  final Map<String, dynamic>? issueJson;

  final DateTime? addedAt;

  factory FavoriteEntry.fromIssue(ComicIssue issue) => FavoriteEntry(
    kind: FavoriteKind.issue,
    id: issue.id,
    title: issue.title,
    subtitle: issue.seriesTitle,
    coverUrl: issue.coverUrl,
    issueJson: issue.toJson(),
    addedAt: DateTime.now(),
  );

  factory FavoriteEntry.fromSeries(
    String seriesId,
    String title, {
    String? coverUrl,
  }) => FavoriteEntry(
    kind: FavoriteKind.series,
    id: seriesId,
    title: title,
    coverUrl: coverUrl,
    addedAt: DateTime.now(),
  );

  factory FavoriteEntry.fromGuide(ReadingGuide guide) => FavoriteEntry(
    kind: FavoriteKind.guide,
    id: guide.id,
    title: guide.title,
    subtitle: '官方阅读指南',
    coverUrl: guide.coverUrl,
    addedAt: DateTime.now(),
  );

  /// 还原成 ComicIssue（仅 issue 类）。
  ComicIssue? get asIssue =>
      issueJson == null ? null : ComicIssue.fromJson(issueJson!);

  /// 还原成指南的最小快照（够详情页首屏用）。
  ReadingGuide get asGuide => ReadingGuide(
    id: id,
    title: title,
    description: subtitle == '官方阅读指南' ? '' : (subtitle ?? ''),
    coverUrl: coverUrl,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'coverUrl': coverUrl,
    'issueJson': issueJson,
    'addedAt': addedAt?.toIso8601String(),
  };

  factory FavoriteEntry.fromJson(Map json) => FavoriteEntry(
    kind: FavoriteKind.fromName(json['kind']?.toString()),
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString(),
    coverUrl: json['coverUrl']?.toString(),
    issueJson: json['issueJson'] as Map<String, dynamic>?,
    addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? ''),
  );
}

/// 用户自建书单。
class UserList {
  const UserList({
    required this.id,
    required this.name,
    required this.createdAt,
    this.items = const [],
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<FavoriteEntry> items;

  UserList copyWith({String? name, List<FavoriteEntry>? items}) => UserList(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    items: items ?? this.items,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
  };

  factory UserList.fromJson(Map json) => UserList(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '未命名书单',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now(),
    items: (json['items'] as List? ?? [])
        .map((e) => FavoriteEntry.fromJson(e as Map))
        .toList(),
  );
}

/// 追更的系列快照。
class FollowedSeries {
  const FollowedSeries({
    required this.seriesId,
    required this.title,
    this.coverUrl,
    this.followedAt,
  });

  final String seriesId;
  final String title;
  final String? coverUrl;
  final DateTime? followedAt;

  Map<String, dynamic> toJson() => {
    'seriesId': seriesId,
    'title': title,
    'coverUrl': coverUrl,
    'followedAt': followedAt?.toIso8601String(),
  };

  factory FollowedSeries.fromJson(Map json) => FollowedSeries(
    seriesId: json['seriesId']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    coverUrl: json['coverUrl']?.toString(),
    followedAt: DateTime.tryParse(json['followedAt']?.toString() ?? ''),
  );
}

/// 一枚书签（在某期的某一页）。
class IssueBookmark {
  const IssueBookmark({
    required this.issueId,
    required this.page,
    required this.createdAt,
  });

  final String issueId;

  /// 0 基页码。
  final int page;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'page': page,
    'createdAt': createdAt.toIso8601String(),
  };

  factory IssueBookmark.fromJson(String issueId, Map json) => IssueBookmark(
    issueId: issueId,
    page: (json['page'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// 本地偏好仓库：收藏（四类）、追更、自建书单、搜索历史、阅读进度、主题。
///
/// 全应用唯一碰 SharedPreferences 的地方。内存里留一份同步快照，
/// UI 不用 await 就能读到当前状态（这是收藏能即时同步的前提）。
class PreferencesRepository {
  // v1 只有 issue 收藏；v2 起四类共存。加载时自动把 v1 迁过来。
  static const _keyFavoritesV1 = 'favorites_v1';
  static const _keyFavoritesV2 = 'favorites_v2';
  static const _keyFollows = 'followed_series_v1';
  static const _keyUserLists = 'user_lists_v1';
  static const _keyHistory = 'search_history_v1';
  static const _keyProgress = 'reading_progress_v1';
  static const _keyThemeMode = 'theme_mode_v1';
  static const _keyBookmarks = 'bookmarks_v1';
  static const _keyLlmBaseUrl = 'llm_base_url_v1';
  static const _keyLlmApiKey = 'llm_api_key_v1';
  static const _keyLlmModel = 'llm_model_v1';

  /// 搜索历史最多留这么多条。
  static const _historyLimit = 12;

  SharedPreferences? _prefs;

  final List<FavoriteEntry> _favorites = [];
  final List<FollowedSeries> _follows = [];
  final List<UserList> _userLists = [];
  final List<String> _history = [];
  final Map<String, ReadingProgress> _progress = {};
  final Map<String, List<IssueBookmark>> _bookmarks = {};
  String _themeMode = 'system';
  String _llmBaseUrl = '';
  String _llmApiKey = '';
  String _llmModel = '';

  bool get isReady => _prefs != null;

  /// 翻译模型配置（阅读器里长按「翻译」进入填写）。
  String get llmBaseUrl => _llmBaseUrl;
  String get llmApiKey => _llmApiKey;
  String get llmModel => _llmModel;
  bool get llmConfigured =>
      _llmBaseUrl.isNotEmpty && _llmApiKey.isNotEmpty && _llmModel.isNotEmpty;

  Future<void> saveLlmConfig({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    _llmBaseUrl = baseUrl.trim();
    _llmApiKey = apiKey.trim();
    _llmModel = model.trim();
    await _prefs?.setString(_keyLlmBaseUrl, _llmBaseUrl);
    await _prefs?.setString(_keyLlmApiKey, _llmApiKey);
    await _prefs?.setString(_keyLlmModel, _llmModel);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    _favorites
      ..clear()
      ..addAll(_loadFavoritesV2(prefs));

    _follows
      ..clear()
      ..addAll(
        (prefs.getStringList(_keyFollows) ?? const []).map(
          (r) => _decode(r, FollowedSeries.fromJson),
        ),
      );

    _userLists
      ..clear()
      ..addAll(
        (prefs.getStringList(_keyUserLists) ?? const []).map(
          (r) => _decode(r, UserList.fromJson),
        ),
      );

    _history
      ..clear()
      ..addAll(prefs.getStringList(_keyHistory) ?? const []);

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

    _themeMode = prefs.getString(_keyThemeMode) ?? 'system';
    _llmBaseUrl = prefs.getString(_keyLlmBaseUrl) ?? '';
    _llmApiKey = prefs.getString(_keyLlmApiKey) ?? '';
    _llmModel = prefs.getString(_keyLlmModel) ?? '';
  }

  /// 读 v2；没有 v2 就把 v1 的 issue 收藏迁过来（迁完写回 v2）。
  List<FavoriteEntry> _loadFavoritesV2(SharedPreferences prefs) {
    final v2Raw = prefs.getStringList(_keyFavoritesV2);
    if (v2Raw != null) {
      return v2Raw.map((r) => _decode(r, FavoriteEntry.fromJson)).toList();
    }
    final migrated = (prefs.getStringList(_keyFavoritesV1) ?? const [])
        .map((r) => _decode(r, ComicIssue.fromJson))
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

  T _decode<T>(String raw, T Function(Map) fromJson) {
    try {
      return fromJson(jsonDecode(raw) as Map);
    } catch (_) {
      // 损坏条目按空对象兜底，别让一条坏数据拖垮整个列表
      return fromJson(const {});
    }
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
    await _prefs?.setStringList(
      _keyFavoritesV2,
      _favorites.map((e) => jsonEncode(e.toJson())).toList(),
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
    await _prefs?.setStringList(
      _keyFollows,
      _follows.map((f) => jsonEncode(f.toJson())).toList(),
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
    await _prefs?.setStringList(
      _keyUserLists,
      _userLists.map((l) => jsonEncode(l.toJson())).toList(),
    );
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
    await _prefs?.setStringList(_keyHistory, _history);
  }

  Future<void> clearSearchHistory() async {
    _history.clear();
    await _prefs?.setStringList(_keyHistory, const []);
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
    await _prefs?.setStringList(
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

  Future<void> removeBookmark(String issueId, int page) async {
    _bookmarks[issueId]?.removeWhere((b) => b.page == page);
    await _persistBookmarks();
  }

  Future<void> _persistBookmarks() async {
    final map = _bookmarks.map(
      (k, v) => MapEntry(k, v.map((b) => b.toJson()).toList()),
    );
    await _prefs?.setString(_keyBookmarks, jsonEncode(map));
  }

  // ── 主题 ─────────────────────────────────────────────────────

  /// 'system' | 'light' | 'dark'。
  String get themeMode => _themeMode;

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _prefs?.setString(_keyThemeMode, mode);
  }
}
