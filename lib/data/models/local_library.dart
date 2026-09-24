import 'marvel_models.dart';

/// 本地库的数据类：收藏、追更、自建书单、阅读进度、书签。
///
/// 持久化行为在 `lib/data/repository/prefs/` 的各域 mixin 里，
/// 这里只放数据本身——数据形态和存储策略各自独立演化。

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
    this.guideDescription,
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

  /// 指南简介快照，仅 kind == guide 时有（详情页首屏用）。
  final String? guideDescription;

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
    guideDescription: guide.description,
    addedAt: DateTime.now(),
  );

  /// 还原成 ComicIssue（仅 issue 类）。
  ComicIssue? get asIssue =>
      issueJson == null ? null : ComicIssue.fromJson(issueJson!);

  /// 还原成指南的最小快照（够详情页首屏用）。subtitle 是展示用的
  /// 占位文案，简介走 [guideDescription] 快照。
  ReadingGuide get asGuide => ReadingGuide(
    id: id,
    title: title,
    description: guideDescription ?? '',
    coverUrl: coverUrl,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'coverUrl': coverUrl,
    'issueJson': issueJson,
    'guideDescription': guideDescription,
    'addedAt': addedAt?.toIso8601String(),
  };

  factory FavoriteEntry.fromJson(Map json) => FavoriteEntry(
    kind: FavoriteKind.fromName(json['kind']?.toString()),
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    subtitle: json['subtitle']?.toString(),
    coverUrl: json['coverUrl']?.toString(),
    issueJson: json['issueJson'] as Map<String, dynamic>?,
    guideDescription: json['guideDescription']?.toString(),
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
