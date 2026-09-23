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

  /// 换封面用（字段一多，手抄必漏）。
  SearchHit withCover(String? url) => SearchHit(
    kind: kind,
    title: title,
    subtitle: subtitle,
    coverUrl: url,
    issue: issue?.copyWith(coverUrl: url),
    seriesId: seriesId,
    guide: guide,
    wikiPageName: wikiPageName,
    event: event,
  );

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
  }) : _catalog = catalog,
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

    // 四路来源**并行**拉（之前是串行等完一路再下一路，网络慢时
    // 每一路的耗时累加，搜索要转好几秒）。本地两路是同步的，
    // 网络两路并发；每路各自 try/catch，谁挂了都不拖累别人。
    final futures = await Future.wait([
      _searchLocalEvents(q),
      _searchLocalIndex(q),
      _searchOfficial(q),
      _searchWiki(q),
    ]);

    for (final source in futures) {
      for (final h in source) {
        hits.putIfAbsent(h.key, () => h);
      }
    }

    // 先把结果亮出来（无封面版），封面在后台补——搜索的「快」
    // 主要就卡在给前几个结果补封面的那几次系列请求上。
    results = hits.values.toList();
    notifyListeners();

    final enriched = await _enrichCovers(hits);
    if (enriched != null) {
      results = enriched;
      notifyListeners();
    }
    loading = false;
    notifyListeners();
  }

  /// 本地事件库（同步，秒出）。
  Future<List<SearchHit>> _searchLocalEvents(String q) async {
    try {
      final events = await _events.all();
      final lower = q.toLowerCase();
      return [
        for (final e in events)
          if (e.title.toLowerCase().contains(lower) || e.titleZh.contains(q))
            SearchHit(
              kind: SearchHitKind.event,
              title: e.titleZh.isEmpty ? e.title : e.titleZh,
              subtitle: '事件 · ${e.tierLabel} · ${e.year}',
              event: e,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 本地索引：已导入/收藏/缓存过的 issue 与指南（同步）。
  Future<List<SearchHit>> _searchLocalIndex(String q) async {
    final out = <SearchHit>[];
    for (final issue in _localIssues()) {
      if (!_matches(q, [issue.title, issue.seriesTitle])) continue;
      out.add(
        SearchHit(
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
      out.add(
        SearchHit(
          kind: SearchHitKind.guide,
          title: guide.title,
          subtitle: '官方阅读指南',
          coverUrl: guide.coverUrl,
          guide: guide,
        ),
      );
    }
    return out;
  }

  /// 官网 lockjaw：系列 + 单期。
  Future<List<SearchHit>> _searchOfficial(String q) async {
    try {
      final official = await _catalog
          .searchOfficial(q)
          .timeout(const Duration(seconds: 8));
      return [
        for (final h in official.take(20))
          if (h.kind == 'series')
            SearchHit(
              kind: SearchHitKind.series,
              title: h.title,
              subtitle: '官网系列',
              seriesId: h.id,
            )
          else
            SearchHit(
              kind: SearchHitKind.issue,
              title: h.title,
              subtitle: _issueSubtitleOfTitle(h.title),
              issue: _issueFromTitle(h.id, h.title),
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// wiki（Fandom opensearch）的系列页。
  Future<List<SearchHit>> _searchWiki(String q) async {
    try {
      final wiki = await _wiki.searchSeries(q);
      return [
        for (final s in wiki)
          SearchHit(
            kind: SearchHitKind.wikiSeries,
            title: s['title'] ?? '',
            subtitle: 'Marvel Database',
            wikiPageName: s['title'] ?? '',
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 后台补封面：给系列结果取系列封面，给单期取所在系列的期数封面。
  /// 返回 null 表示没什么可补的（结果原样保留）。
  Future<List<SearchHit>?> _enrichCovers(Map<String, SearchHit> hits) async {
    final seriesIds = <String>[];
    for (final h in hits.values) {
      if (h.kind == SearchHitKind.series && h.seriesId != null) {
        seriesIds.add(h.seriesId!);
      }
    }
    if (seriesIds.isEmpty &&
        !hits.values.any((h) => h.kind == SearchHitKind.issue)) {
      return null;
    }
    final topSeries = seriesIds.take(3).toList();

    final seriesCovers = <String, String>{};
    final issueCoverById = <String, String>{};
    await Future.wait([
      ...topSeries.map(
        (sid) => _catalog
            .seriesDetail(sid)
            .timeout(const Duration(seconds: 8))
            .catchError((_) => null)
            .then((d) {
              final c = d?.coverUrl;
              if (c != null) seriesCovers[sid] = c;
            }),
      ),
      ...topSeries.map(
        (sid) => _catalog
            .seriesIssues(sid)
            .timeout(const Duration(seconds: 8))
            .catchError((_) => const <ComicIssue>[])
            .then((list) {
              for (final i in list) {
                final c = i.coverUrl;
                if (c != null) issueCoverById[i.id] = c;
              }
            }),
      ),
    ]);

    var changed = false;
    for (final h in hits.values.toList()) {
      if (h.kind == SearchHitKind.series &&
          h.seriesId != null &&
          seriesCovers[h.seriesId!] != null) {
        hits[h.key] = h.withCover(seriesCovers[h.seriesId!]);
        changed = true;
      } else if (h.kind == SearchHitKind.issue &&
          h.issue != null &&
          issueCoverById[h.issue!.id] != null) {
        hits[h.key] = h.withCover(issueCoverById[h.issue!.id]);
        changed = true;
      }
    }
    return changed ? hits.values.toList() : null;
  }

  /// "Ultimate Invasion (2023) #1" → "漫画期 · #1"。
  static String _issueSubtitleOfTitle(String title) {
    final m = RegExp(r'^(.*)\s+#([^#]+)$').firstMatch(title);
    return '漫画期${m == null ? '' : ' · #${m.group(2)!.trim()}'}';
  }

  /// 把官网标题拆成系列名 + 期号，凑一个可点的 issue。
  static ComicIssue _issueFromTitle(String id, String title) {
    final m = RegExp(r'^(.*)\s+#([^#]+)$').firstMatch(title);
    return ComicIssue(
      id: id,
      title: title,
      seriesTitle: m?.group(1)?.trim() ?? title,
      issueNumber: m?.group(2)?.trim() ?? '',
      releaseDate: '',
      description: '',
    );
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
