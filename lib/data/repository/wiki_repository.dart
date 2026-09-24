import 'dart:async';

import '../../core/async/concurrent.dart';
import '../models/marvel_models.dart';
import '../models/series_summary.dart';
import '../series_naming.dart';
import '../sources/fandom_client.dart';
import 'disk_cache.dart';

/// Marvel Database (fandom wiki) 仓库。
///
/// 职责：官网目录里缺失/下架的 issue 在这里补齐，并提供系列搜索。
/// wiki 拉一个系列要发几十个请求（限并发 6 也要转一两分钟），所以
/// **磁盘缓存是标配**：命中后同一系列秒开，TTL 两周。
class WikiRepository {
  WikiRepository({FandomClient? client, DiskCache? cache})
      : _client = client ?? FandomClient(),
        _cache = cache ?? DiskCache();

  final FandomClient _client;
  final DiskCache _cache;

  static const _concurrency = 6;

  final Map<String, List<ComicIssue>> _seriesCache = {};

  Future<List<WikiSeriesHit>> searchSeries(String query,
          {int limit = 50}) =>
      _client.searchSeries(query, limit: limit);

  /// 按英雄/关键词拿系列列表（wiki 来源），用于系列页的分类。
  Future<List<SeriesSummary>> heroSeries(String query) async {
    final hits = await searchSeries(query);
    return hits
        .map((h) => SeriesSummary(
              title: h.title,
              wikiPageName: h.title,
            ))
        .toList();
  }

  /// 某系列在 wiki 上的全部 issue（内存 + 磁盘缓存，TTL 两周）。
  Future<List<ComicIssue>> seriesIssues(
    String seriesPageName, {
    int limit = 100,
    void Function(int done, int total)? onProgress,
    bool force = false,
  }) async {
    if (!force) {
      final cachedMem = _seriesCache[seriesPageName];
      if (cachedMem != null) return cachedMem;
      final key = 'wikiSeries:$seriesPageName';
      final cached = await _cache.read(key,
          ttl: const Duration(days: 14));
      if (cached is List) {
        final list =
            cached.map((e) => ComicIssue.fromJson(e as Map)).toList();
        if (list.isNotEmpty) {
          _seriesCache[seriesPageName] = list;
          return list;
        }
      }
    }
    final list = await _client.fetchSeriesIssues(
      seriesPageName,
      limit: limit,
      concurrency: _concurrency,
      onProgress: onProgress,
    );
    _seriesCache[seriesPageName] = list;
    if (list.isNotEmpty) {
      unawaited(_cache.write('wikiSeries:$seriesPageName',
          list.map((i) => i.toJson()).toList()));
    }
    return list;
  }

  /// 补齐官网目录里缺的期数（带磁盘缓存，TTL 两周——补全一次很贵）。
  ///
  /// 规则沿用原实现：从 1 号扫到「官网最大期号 + 1」，跳过官网已有的号，
  /// 在 wiki 上找得到的就补进来。返回按（补到的）顺序排列。
  Future<List<ComicIssue>> supplementMissing(
    List<ComicIssue> official, {
    String? seriesTitle,
    void Function(int done, int total)? onProgress,
  }) async {
    if (official.isEmpty) return const [];

    final title = seriesTitle ?? official.first.seriesTitle;
    final pageName = SeriesNaming.wikiPageName(title);
    final cacheKey = 'wikiSupplement:$pageName';

    final cached = await _cache.read(cacheKey,
        ttl: const Duration(days: 14));
    if (cached is List) {
      return cached.map((e) => ComicIssue.fromJson(e as Map)).toList();
    }

    final known = official.map((i) => i.issueNumber).toSet();
    var maxNumber = 0;
    for (final i in official) {
      final n = double.tryParse(i.issueNumber);
      if (n != null && n > maxNumber) maxNumber = n.toInt();
    }

    final missing = <String>[];
    for (var n = 1; n <= maxNumber + 1; n++) {
      if (known.contains(n.toString())) continue;
      missing.add(n.toString());
    }
    if (missing.isEmpty) return const [];

    final found = await mapConcurrent<String, ComicIssue>(
      missing,
      (n) => _client.fetchIssue(pageName, n),
      concurrency: _concurrency,
      onProgress: onProgress,
    );
    if (found.isNotEmpty) {
      unawaited(_cache.write(
          cacheKey, found.map((i) => i.toJson()).toList()));
    }
    return found;
  }

  /// 按 wiki 页面名直接取一期（深链兜底用）。
  Future<ComicIssue?> issueByPageName(String pageName) async {
    final cached = _seriesCache.values
        .expand((list) => list)
        .where((i) => i.id == 'fandom:$pageName');
    if (cached.isNotEmpty) return cached.first;
    // 页面名形如 "Amazing Spider-Man Vol 2 500"：系列名 + 空格 + 期号
    final m = RegExp(r'^(.*) (\d+)$').firstMatch(pageName);
    if (m == null) return null;
    return _client.fetchIssue(m.group(1)!, m.group(2)!);
  }
}