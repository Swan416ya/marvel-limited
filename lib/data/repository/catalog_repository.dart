import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/marvel_models.dart';
import '../models/series_summary.dart';
import '../sources/bifrost_client.dart';
import 'disk_cache.dart';

/// 官网目录仓库（bifrost）。
///
/// 在原始客户端之上加三件事：
/// 1. 内存缓存——阅读指南列表、指南下的 issue、系列下的 issue 各存一份；
/// 2. 并发去重——同一份数据被两个页面同时要时只发一次请求
///    （首页和详情页同时打开时经常撞车）；
/// 3. 磁盘缓存——官网大响应经常被 CDN 掐断，命中缓存时离线也能秒开。
class CatalogRepository {
  CatalogRepository({BifrostClient? client, DiskCache? cache})
    : _client = client ?? BifrostClient(),
      _cache = cache ?? DiskCache();

  final BifrostClient _client;
  final DiskCache _cache;

  List<ReadingGuide>? _guides;

  /// 打包进应用的目录快照（`tool/build_catalog_snapshot.py` 生成）。
  ///
  /// 用途是 stale-while-revalidate：磁盘缓存还没有的时候先用快照顶上
  /// （页面立即出内容），同时后台拉网络数据写进缓存，下次打开就是新的。
  /// 快照会旧——但它只会在「第一次打开」时被用到，且下拉刷新永远走网络。
  Map<String, dynamic>? _snapshot;
  Future<Map<String, dynamic>?>? _snapshotLoading;

  Future<Map<String, dynamic>?> _loadSnapshot() {
    return _snapshotLoading ??= () async {
      if (_snapshot != null) return _snapshot;
      try {
        final raw = await rootBundle.loadString(
          'assets/data/catalog_snapshot.json',
        );
        final data = json.decode(raw);
        if (data is Map<String, dynamic>) {
          _snapshot = data;
          return data;
        }
      } catch (_) {
        // 快照读不到（老包/损坏）就当没有，走网络
      }
      return null;
    }();
  }

  final Map<String, List<ComicIssue>> _guideIssues = {};
  final Map<String, List<ComicIssue>> _seriesIssues = {};
  final Map<String, SeriesDetail> _seriesDetails = {};
  final Map<String, Future<List<ComicIssue>>> _inflight = {};
  final Map<String, Future<SeriesDetail?>> _detailInflight = {};
  final Map<String, List<SeriesSummary>> _characterSeries = {};
  final Map<String, Future<List<SeriesSummary>>> _characterSeriesInflight = {};
  final Map<String, ({String id, String name, String? image})> _characters = {};
  Map<String, String>? _heroAvatarManifest;
  List<SeriesSummary>? _featured;
  Future<List<SeriesSummary>>? _featuredInflight;

  Future<List<ReadingGuide>> readingGuides({bool force = false}) async {
    if (!force && _guides != null) return _guides!;
    if (!force) {
      final cached = await _cache.read('guides', ttl: const Duration(days: 1));
      if (cached is List) {
        final list = cached
            .map((e) => ReadingGuide.fromJson(e as Map))
            .toList();
        if (list.isNotEmpty) {
          _guides = list;
          return list;
        }
      }
    }
    // 磁盘缓存没有：先看看打包的快照能不能顶上（首次打开秒出），
    // 同时后台拉网络数据进缓存——下次打开就是新的。
    final snapshot = await _loadSnapshot();
    final snapGuides = snapshot?['guides'];
    if (snapGuides is List && snapGuides.isNotEmpty) {
      final seeded = snapGuides
          .map((e) => ReadingGuide.fromJson(e as Map))
          .toList();
      _guides = seeded;
      unawaited(_refreshGuidesInBackground());
      return seeded;
    }

    final list = await _client.fetchReadingGuides();
    _guides = list;
    unawaited(_cache.write('guides', list.map((g) => g.toJson()).toList()));
    return list;
  }

  /// 后台刷新指南列表（快照顶上之后悄悄干，不打扰界面）。
  Future<void> _refreshGuidesInBackground() async {
    try {
      final list = await _client.fetchReadingGuides();
      _guides = list;
      unawaited(_cache.write('guides', list.map((g) => g.toJson()).toList()));
    } catch (_) {
      // 网络不行就算了，快照继续用
    }
  }

  Future<List<ComicIssue>> readingGuideIssues(
    String guideId, {
    bool force = false,
  }) async {
    if (!force) {
      final cached = _guideIssues[guideId];
      if (cached != null) return cached;
      // 磁盘缓存（7 天）：指南详情是用户反复进的页面，别每次都走网络
      final disk = await _cache.read(
        'guideIssues:$guideId',
        ttl: const Duration(days: 7),
      );
      if (disk is List && disk.isNotEmpty) {
        final list = disk.map((e) => ComicIssue.fromJson(e as Map)).toList();
        _guideIssues[guideId] = list;
        return list;
      }
      // 预取过的指南：打包快照里有逐期清单，直接用
      final snapshot = await _loadSnapshot();
      final snapIssues =
          (snapshot?['guideIssues'] as Map<String, dynamic>?)?[guideId];
      if (snapIssues is List && snapIssues.isNotEmpty) {
        final list = snapIssues
            .map((e) => ComicIssue.fromJson(e as Map))
            .toList();
        _guideIssues[guideId] = list;
        unawaited(
          _cache.write(
            'guideIssues:$guideId',
            list.map((i) => i.toJson()).toList(),
          ),
        );
        return list;
      }
    }
    return _inflight.putIfAbsent('guide:$guideId', () async {
      try {
        final list = await _client.fetchReadingGuideIssues(guideId);
        _guideIssues[guideId] = list;
        unawaited(
          _cache.write(
            'guideIssues:$guideId',
            list.map((i) => i.toJson()).toList(),
          ),
        );
        return list;
      } finally {
        _inflight.remove('guide:$guideId');
      }
    });
  }

  Future<List<ComicIssue>> seriesIssues(String seriesId, {bool force = false}) {
    if (!force) {
      final cached = _seriesIssues[seriesId];
      if (cached != null) return Future.value(cached);
    }
    return _inflight.putIfAbsent('series:$seriesId', () async {
      try {
        final list = await _client.fetchSeriesIssues(seriesId);
        _seriesIssues[seriesId] = list;
        return list;
      } finally {
        _inflight.remove('series:$seriesId');
      }
    });
  }

  /// 已经加载过的指南列表，没加载过返回 null（不触发请求）。
  List<ReadingGuide>? get cachedGuides => _guides;

  /// 所有缓存过的 issue（指南里的 + 系列里的），供本地搜索用。
  List<ComicIssue> get cachedIssues => [
    for (final list in _guideIssues.values) ...list,
    for (final list in _seriesIssues.values) ...list,
  ];

  /// 全站最新**已上架**的 issue。「最近更新的系列」从这里聚合（带磁盘缓存）。
  Future<List<ComicIssue>> latestIssues({
    int limit = 50,
    int offset = 0,
  }) async {
    final key = 'latest:$limit:$offset';
    final cached = await _cache.read(key, ttl: const Duration(hours: 12));
    if (cached is List) {
      final list = cached.map((e) => ComicIssue.fromJson(e as Map)).toList();
      if (list.isNotEmpty) return list;
    }
    return _inflight.putIfAbsent(key, () async {
      try {
        final list = await _client.fetchLatestIssues(
          limit: limit,
          offset: offset,
        );
        unawaited(_cache.write(key, list.map((i) => i.toJson()).toList()));
        return list;
      } finally {
        _inflight.remove(key);
      }
    });
  }

  /// 角色相关系列（英雄分类用），带内存 + 磁盘缓存。
  Future<List<SeriesSummary>> characterSeries(String characterId) async {
    final cachedMem = _characterSeries[characterId];
    if (cachedMem != null) return cachedMem;
    final key = 'characterSeries:$characterId';
    final cached = await _cache.read(key, ttl: const Duration(days: 7));
    if (cached is List) {
      final list = cached.map((e) => SeriesSummary.fromJson(e as Map)).toList();
      if (list.isNotEmpty) {
        _characterSeries[characterId] = list;
        return list;
      }
    }
    return _characterSeriesInflight.putIfAbsent(characterId, () async {
      try {
        final list = await _client.fetchCharacterSeries(characterId);
        _characterSeries[characterId] = list;
        unawaited(_cache.write(key, list.map((s) => s.toJson()).toList()));
        return list;
      } finally {
        _characterSeriesInflight.remove(characterId);
      }
    });
  }

  /// 角色详情（方形头像），带内存缓存。
  ///
  /// 头像图床直连经常被 CDN 掐断（实测连接重置），所以优先用
  /// `assets/data/hero_avatars/` 里打包的本地图（`tool/fetch_hero_avatars.py`
  /// 生成），没有本地图才走网络。
  Future<({String id, String name, String? image})> characterDetail(
    String characterId,
  ) async {
    final cached = _characters[characterId];
    if (cached != null) return cached;

    var image = await _localAvatar(characterId);
    if (image == null) {
      try {
        final d = await _client.fetchCharacterDetail(characterId);
        image = d.image;
      } catch (_) {
        image = null;
      }
    }
    final result = (
      id: characterId,
      name: _characters[characterId]?.name ?? characterId,
      image: image,
    );
    _characters[characterId] = result;
    return result;
  }

  /// 本地打包的英雄头像（manifest 存在且有条目时返回资产路径）。
  Future<String?> _localAvatar(String characterId) async {
    _heroAvatarManifest ??= await () async {
      try {
        final raw = await rootBundle.loadString(
          'assets/data/hero_avatars/manifest.json',
        );
        final map = json.decode(raw) as Map<String, dynamic>;
        return map.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        return const <String, String>{};
      }
    }();
    final file = _heroAvatarManifest![characterId];
    if (file == null) return null;
    return 'assets/data/hero_avatars/$file';
  }

  /// 系列详情（头图 / 描述 / 起止年份），带内存缓存。
  Future<SeriesDetail?> seriesDetail(String seriesId) {
    final cached = _seriesDetails[seriesId];
    if (cached != null) return Future.value(cached);
    return _detailInflight.putIfAbsent(seriesId, () async {
      try {
        final detail = await _client.fetchSeriesDetail(seriesId);
        if (detail != null) _seriesDetails[seriesId] = detail;
        return detail;
      } finally {
        _detailInflight.remove(seriesId);
      }
    });
  }

  /// 官网标题联想（lockjaw）：系列与单期都返回，kind 见 [OfficialSearchKind]。
  Future<List<({String id, String title, OfficialSearchKind kind})>>
      searchOfficial(String query) => _client.searchOfficial(query);

  /// 兼容旧调用：只取系列结果。
  Future<List<({String id, String title})>> searchOfficialSeries(
    String query,
  ) async => [
    for (final h in await _client.searchOfficial(query))
      if (h.kind == OfficialSearchKind.series) (id: h.id, title: h.title),
  ];

  /// 官方编辑精选系列，带缓存。
  Future<List<SeriesSummary>> featuredSeries() {
    final cached = _featured;
    if (cached != null) return Future.value(cached);
    return _featuredInflight ??= () async {
      try {
        _featured = await _client.fetchFeaturedSeries();
        return _featured!;
      } finally {
        _featuredInflight = null;
      }
    }();
  }

  /// 把 issue 流聚合成「系列」视图：同系列合并，保留最新一期与期数。
  static List<SeriesSummary> distinctSeries(List<ComicIssue> issues) {
    final order = <String>[];
    final bySeries = <String, List<ComicIssue>>{};
    for (final issue in issues) {
      final key = issue.seriesId ?? issue.seriesTitle;
      if (key.isEmpty) continue;
      if (!bySeries.containsKey(key)) {
        order.add(key);
        bySeries[key] = [];
      }
      bySeries[key]!.add(issue);
    }
    return [
      for (final key in order)
        () {
          final list = bySeries[key]!;
          final first = list.first;
          return SeriesSummary(
            title: first.seriesTitle.isEmpty ? first.title : first.seriesTitle,
            seriesId: first.seriesId,
            coverUrl: first.coverUrl,
            issueCount: list.length,
            latestIssue: first.issueNumber,
          );
        }(),
    ];
  }

  /// 已缓存的 issue，用于详情页/深链的兜底查找（不触发请求）。
  ComicIssue? findCachedIssue(String issueId) {
    for (final list in _guideIssues.values) {
      for (final i in list) {
        if (i.id == issueId) return i;
      }
    }
    for (final list in _seriesIssues.values) {
      for (final i in list) {
        if (i.id == issueId) return i;
      }
    }
    return null;
  }

  /// 清掉指南列表缓存（下拉刷新）。
  void evictGuides() => _guides = null;
}
