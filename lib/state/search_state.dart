import 'package:flutter/foundation.dart';

import '../data/models/marvel_event.dart';
import '../data/models/marvel_models.dart';
import '../data/repository/catalog_repository.dart';
import '../data/repository/events_repository.dart';
import '../data/repository/preferences_repository.dart';
import '../data/repository/wiki_repository.dart';

/// 搜索结果的类型。决定点击后去哪儿、角标显示什么。
enum SearchHitKind {
  /// 本地已知的 issue → 直接进详情。
  issue,

  /// 官网系列（lockjaw 搜到，带 id）→ 进系列页。
  series,

  /// wiki 系列 → 进 wiki 系列页（需要页面名）。
  wikiSeries,

  /// 官网阅读指南 → 进指南详情。
  guide,

  /// 本地事件库的大事件 → 进事件详情。
  event,
}

/// 一条搜索结果。
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.coverUrl,
    this.issue,
    this.seriesId,
    this.guide,
    this.wikiPageName,
    this.event,
  });

  final SearchHitKind kind;
  final String title;
  final String subtitle;
  final String? coverUrl;

  final ComicIssue? issue;
  final String? seriesId;
  final ReadingGuide? guide;
  final String? wikiPageName;
  final MarvelEvent? event;

  /// 类型角标文字。
  String get kindLabel => switch (kind) {
        SearchHitKind.issue => '漫画',
        SearchHitKind.series => '系列',
        SearchHitKind.wikiSeries => 'wiki 系列',
        SearchHitKind.guide => '指南',
        SearchHitKind.event => '事件',
      };

  /// 去重键。
  String get key => switch (kind) {
        SearchHitKind.issue => 'issue:${issue?.id}',
        SearchHitKind.series => 'series:$seriesId',
        SearchHitKind.guide => 'guide:${guide?.id}',
        SearchHitKind.wikiSeries => 'wiki:$wikiPageName',
        SearchHitKind.event => 'event:${event?.id}',
      };
}

/// 搜索状态。
///
/// 结果来自四路并做去重：
/// 1. 本地事件库（标题匹配，秒出）；
/// 2. 本地索引——已导入的、收藏的、以及已经缓存过的目录 issue 和指南；
/// 3. 官网 lockjaw 标题搜索（真正的系列，带官网 id，封面走系列详情）；
/// 4. wiki（Fandom opensearch）的系列页，覆盖官网没有的系列。
class SearchState extends ChangeNotifier {
  SearchState({
    required CatalogRepository catalog,
    required WikiRepository wiki,
    required EventsRepository events,
    required PreferencesRepository prefs,
    required List<ComicIssue> Function() localIssues,
  })  : _catalog = catalog,
        _wiki = wiki,
        _events = events,
        _prefs = prefs,
        _localIssues = localIssues;

  final CatalogRepository _catalog;
  final WikiRepository _wiki;
  final EventsRepository _events;
  final PreferencesRepository _prefs;
  final List<ComicIssue> Function() _localIssues;

  String query = '';
  List<SearchHit> results = const [];
  bool loading = false;
  String? error;

  /// 搜过一次才有结果区可显示。
  bool searched = false;

  List<String> get history => _prefs.searchHistory;

  /// 输入联想：本地标题 + 历史记录，纯同步，不发请求。
  List<String> suggestionsFor(String input) {
    final q = input.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <String>[];
    for (final h in _prefs.searchHistory) {
      if (h.toLowerCase().contains(q) && !out.contains(h)) out.add(h);
      if (out.length >= 4) return out;
    }
    for (final issue in _localIssues()) {
      final title = issue.title;
      if (title.toLowerCase().contains(q) && !out.contains(title)) {
        out.add(title);
      }
      if (out.length >= 6) break;
    }
    for (final g in _catalog.cachedGuides ?? const <ReadingGuide>[]) {
      if (g.title.toLowerCase().contains(q) && !out.contains(g.title)) {
        out.add(g.title);
      }
      if (out.length >= 8) break;
    }
    return out;
  }

  Future<void> search(String input) async {
    final q = input.trim();
    if (q.isEmpty) return;

    query = q;
    loading = true;
    error = null;
    searched = true;
    results = const [];
    notifyListeners();

    await _prefs.pushSearchHistory(q);

    final hits = <String, SearchHit>{};

    // 1) 本地事件库（秒出）
    try {
      final events = await _events.all();
      final lower = q.toLowerCase();
      for (final e in events) {
        if (!e.title.toLowerCase().contains(lower) &&
            !e.titleZh.contains(q)) {
          continue;
        }
        hits.putIfAbsent(
          'event:${e.id}',
          () => SearchHit(
            kind: SearchHitKind.event,
            title: e.titleZh.isEmpty ? e.title : e.titleZh,
            subtitle: '事件 · ${e.tierLabel} · ${e.year}',
            event: e,
          ),
        );
      }
    } catch (_) {
      // 事件库读失败不影响其它来源
    }
    notifyListeners();

    // 2) 本地索引
    for (final issue in _localIssues()) {
      if (!_matches(q, [issue.title, issue.seriesTitle])) continue;
      hits.putIfAbsent(
        'issue:${issue.id}',
        () => SearchHit(
          kind: SearchHitKind.issue,
          title: issue.title,
          subtitle: _issueSubtitle(issue),
          coverUrl: issue.coverUrl,
          issue: issue,
        ),
      );
    }
    for (final guide in _catalog.cachedGuides ?? const <ReadingGuide>[]) {
      if (!_matches(q, [guide.title, guide.description])) continue;
      hits.putIfAbsent(
        'guide:${guide.id}',
        () => SearchHit(
          kind: SearchHitKind.guide,
          title: guide.title,
          subtitle: '官方阅读指南',
          coverUrl: guide.coverUrl,
          guide: guide,
        ),
      );
    }
    notifyListeners();

    // 3) 官网 lockjaw 系列搜索（带封面）
    try {
      final official =
          await _catalog.searchOfficialSeries(q).timeout(const Duration(seconds: 15));
      for (final s in official.take(8)) {
        hits.putIfAbsent(
          'series:${s.id}',
          () => SearchHit(
            kind: SearchHitKind.series,
            title: s.title,
            subtitle: '官网系列',
            seriesId: s.id,
          ),
        );
      }
      // 给前 4 个官网系列补封面（并发走系列详情，命中缓存很快）
      final seriesHits = hits.values
          .where((h) => h.kind == SearchHitKind.series)
          .take(4)
          .toList();
      final details = await Future.wait(
        seriesHits.map((h) => _catalog
            .seriesDetail(h.seriesId!)
            .timeout(const Duration(seconds: 10))
            .catchError((_) => null)),
      );
      for (var i = 0; i < seriesHits.length; i++) {
        final cover = details[i]?.coverUrl;
        if (cover != null) {
          final h = seriesHits[i];
          hits[h.key] = SearchHit(
            kind: SearchHitKind.series,
            title: h.title,
            subtitle: h.subtitle,
            coverUrl: cover,
            seriesId: h.seriesId,
          );
        }
      }
    } catch (_) {
      // lockjaw 挂了不影响其它来源
    }
    notifyListeners();

    // 4) wiki 系列
    try {
      final wiki = await _wiki.searchSeries(q);
      for (final s in wiki) {
        final title = s['title'] ?? '';
        hits.putIfAbsent(
          'wiki:$title',
          () => SearchHit(
            kind: SearchHitKind.wikiSeries,
            title: title,
            subtitle: 'Marvel Database',
            wikiPageName: title,
          ),
        );
      }
    } catch (e) {
      // wiki 挂了不影响本地结果，只是少一块
      if (hits.isEmpty) error = e.toString();
    }

    loading = false;
    results = hits.values.toList();
    notifyListeners();
  }

  Future<void> retry() => search(query);

  Future<void> clearHistory() async {
    await _prefs.clearSearchHistory();
    notifyListeners();
  }

  void clear() {
    query = '';
    results = const [];
    searched = false;
    loading = false;
    error = null;
    notifyListeners();
  }

  static bool _matches(String q, List<String> fields) {
    final needle = q.toLowerCase();
    for (final f in fields) {
      if (f.toLowerCase().contains(needle)) return true;
    }
    return false;
  }

  static String _issueSubtitle(ComicIssue issue) {
    final parts = <String>[
      if (issue.seriesTitle.isNotEmpty) issue.seriesTitle,
      if (issue.releaseDate.isNotEmpty) issue.releaseDate,
    ];
    return parts.join(' · ');
  }
}