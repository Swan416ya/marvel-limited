import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/marvel_models.dart';
import '../models/series_summary.dart';
import '../series_naming.dart';
import 'http_retry.dart';

/// 漫威官网目录（bifrost）的原始 HTTP 客户端。
///
/// 只负责取数和解析，不做缓存——缓存与去重交给 `CatalogRepository`。
class BifrostClient {
  static const _origin = 'https://bifrost.marvel.com';
  static const _proxy = 'http://127.0.0.1:8322/proxy/';

  final http.Client _client;

  /// 每次重试前的退避时长（列表长度即重试次数）。测试里传空列表，
  /// 重试即时完成、不产生 Timer，widget 测试才不会被挂起的定时器绊倒。
  final List<Duration> retryDelays;

  BifrostClient({
    http.Client? client,
    this.retryDelays = const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
    ],
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => const {
        'User-Agent': chromeMobileUserAgent,
        'Referer': 'https://www.marvel.com/',
        'Accept': 'application/json',
      };

  Future<Map<String, dynamic>> _getJson(String path,
      [Map<String, String>? query]) async {
    final url = '$_origin$path';
    // 浏览器跨域被 bifrost 拒绝，开发时走本地代理
    final target = kIsWeb ? '$_proxy${Uri.encodeFull(url)}' : url;
    final uri = Uri.parse(target).replace(queryParameters: query ?? const {});
    // CDN 会随机掐断长连接（实测 IncompleteRead），不带重试的话
    // 大响应（日历/指南列表 400KB+）失败率很高——系列页「一直加载失败」
    // 的根因就是它。
    return withRetry(
      retryDelays: retryDelays,
      failureMessage: 'bifrost $path',
      run: () async {
        final resp = await _client.get(uri, headers: _headers);
        if (resp.statusCode != 200) {
          throw Exception('bifrost $path failed: ${resp.statusCode}');
        }
        return json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      },
    );
  }

  /// 官网标题联想搜索（lockjaw typeahead）。注意 host 是 www.marvel.com
  /// 而不是 bifrost，而且是 POST 表单。系列和单期都会返回，
  /// [kind] 见 [OfficialSearchKind]（链接分别是 /comics/series/ 和
  /// /comics/issue/）。
  Future<List<({String id, String title, OfficialSearchKind kind})>>
      searchOfficial(String query) async {
    final url = 'https://www.marvel.com/v1/typeahead';
    final target = kIsWeb ? '$_proxy${Uri.encodeFull(url)}' : url;
    final uri = Uri.parse(target);
    return withRetry(
      retryDelays: retryDelays,
      failureMessage: 'typeahead',
      run: () async {
        final resp = await _client.post(
          uri,
          headers: {
            ..._headers,
            'Content-Type':
                'application/x-www-form-urlencoded;charset=UTF-8',
          },
          body: {
            'query': query,
            'field': 'headline_suggest',
            'content_type': 'comics',
          },
        );
        if (resp.statusCode != 200) {
          throw Exception('typeahead failed: ${resp.statusCode}');
        }
        final body =
            json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final results = (body['data']?['results'] as List? ?? const []);
        final out = <({String id, String title, OfficialSearchKind kind})>[];
        for (final r in results) {
          final map = r as Map;
          final link =
              ((map['link'] as Map?)?['link'] ?? '').toString();
          // 系列链接形如 /comics/series/<id>/<slug>，单期是 /comics/issue/<id>/<slug>
          final ms = RegExp(r'/comics/series/(\d+)').firstMatch(link);
          final mi = RegExp(r'/comics/issue/(\d+)').firstMatch(link);
          final kind = ms != null
              ? OfficialSearchKind.series
              : mi != null
                  ? OfficialSearchKind.issue
                  : null;
          if (kind == null) continue;
          final title = ((map['link'] as Map?)?['title'] ??
                  map['headline'] ??
                  '')
              .toString();
          if (title.isNotEmpty) {
            out.add((
              id: (ms ?? mi)!.group(1)!,
              title: title,
              kind: kind
            ));
          }
        }
        return out;
      },
    );
  }

  /// 角色详情（方形头像）。注意无 /v1 前缀。
  Future<({String id, String name, String? image})> fetchCharacterDetail(
      String characterId) async {
    final body = await _getJson('/catalog/characters/$characterId');
    final data = body['data'] as Map?;
    if (data == null) {
      throw Exception('character $characterId not found');
    }
    final base = data['image_url']?.toString() ?? '';
    final ext = data['image_extension']?.toString() ?? 'jpg';
    final image =
        base.isEmpty ? null : 'https://cdn.marvel.com/u/prod/marvel$base/standard_fantastic.$ext';
    return (
      id: data['id'].toString(),
      name: data['name']?.toString() ?? '',
      image: image,
    );
  }

  /// 官方阅读指南列表（大事件专题）。
  Future<List<ReadingGuide>> fetchReadingGuides() async {
    final body = await _getJson('/v1/catalog/reading-lists/platform/web');
    final results =
        (body['data']['results'] as List).cast<Map<String, dynamic>>();
    return results.map(ReadingGuide.fromBifrostList).toList();
  }

  /// 某个阅读指南下的全部 issue，顺序即官方推荐阅读顺序。
  Future<List<ComicIssue>> fetchReadingGuideIssues(String guideId) async {
    final body = await _getJson('/v1/catalog/reading-lists/$guideId',
        {'limit': '1000', 'offset': '0'});
    final lists = (body['data']['results'] as List).cast<Map<String, dynamic>>();
    if (lists.isEmpty) return [];
    final contents =
        (lists.first['contents'] as List).cast<Map<String, dynamic>>();
    return contents.map((c) {
      final thumb = c['thumbnail'] as Map<String, dynamic>?;
      final title = (c['title'] ?? '') as String;
      return ComicIssue(
        id: c['id'].toString(),
        title: title,
        seriesTitle: SeriesNaming.seriesFromTitle(title),
        issueNumber: SeriesNaming.issueFromTitle(title),
        releaseDate: (c['release_date'] ?? '') as String,
        description: (c['description'] ?? '') as String,
        coverUrl: thumb == null
            ? null
            : '${thumb['path']}/portrait_uncanny.${thumb['extension']}',
        creators: ((c['creators_short'] ?? '') as String)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );
    }).toList();
  }

  /// 某系列的全部单行本（分页拉完，变体封面剔除，按期号排序）。
  Future<List<ComicIssue>> fetchSeriesIssues(String seriesId) async {
    final all = <ComicIssue>[];
    var offset = 0;
    const limit = 50;
    while (true) {
      final body = await _getJson('/v1/catalog/comics/', {
        'byId': seriesId,
        'byZone': 'marvel_site_zone',
        'byType': 'comic_series',
        'orderBy': 'release_date+desc',
        'formatType': 'issue,digitalcomic,collection,digitalverticalcomic',
        'limit': limit.toString(),
        'offset': offset.toString(),
        'variants': 'false',
        'getThumb': '1',
      });
      final data = body['data'] as Map<String, dynamic>;
      final results = (data['results'] as List).cast<Map<String, dynamic>>();
      all.addAll(results.map(ComicIssue.fromBifrost).where((i) => !i.isVariant));
      final total = looseInt(data['total']) ?? 0;
      offset += limit;
      if (offset >= total || results.isEmpty) break;
    }
    all.sort((a, b) => SeriesNaming.issueSortKey(a.issueNumber)
        .compareTo(SeriesNaming.issueSortKey(b.issueNumber)));
    return all;
  }

  /// 全站最新**已上架**的 issue。
  ///
  /// 关键点是日期窗口：官网「New This Week」用「上周一 → 今天」的窄窗
  /// （实测公式：今天回退 (weekday+6)%7 + 7 天）。窗口一宽，
  /// `release_date+desc` 会把最远未来的预售刊（几乎全是新创刊系列）排到
  /// 最前面，进行中的老系列就被挤没了。这里再往前多拉两周，给瀑布流
  /// 留足量，同时仍然排除预售。
  Future<List<ComicIssue>> fetchLatestIssues(
      {int limit = 100, int offset = 0}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: (now.weekday + 6) % 7 + 21));
    final body = await _getJson('/v1/catalog/comics/calendar', {
      'byType': 'date',
      'offset': offset.toString(),
      'limit': limit.toString(),
      'orderBy': 'release_date+desc',
      'variants': 'false',
      'formatType': 'issue',
      'dateStart': _dateString(start),
      'dateEnd': _dateString(now),
    });
    final data = body['data'] as Map<String, dynamic>;
    final results = (data['results'] as List).cast<Map<String, dynamic>>();
    return results.map(ComicIssue.fromBifrost).where((i) => !i.isVariant).toList();
  }

  /// 角色相关系列（官网角色页同款）。条目自带封面/描述/comics_count，
  /// `type == 'ongoing'` 表示进行中。orderBy 在这个端点上被忽略（实测），
  /// 默认序大致新系列在前。limit 给大点一次拉全（实测 1000 可用）。
  Future<List<SeriesSummary>> fetchCharacterSeries(String characterId,
      {int limit = 1000}) async {
    final body = await _getJson('/catalog/characters/$characterId/related/series', {
      'limit': limit.toString(),
    });
    final data = body['data'] as Map<String, dynamic>;
    final results = (data['results'] as List).cast<Map<String, dynamic>>();
    return results
        .map((s) => SeriesSummary(
              seriesId: s['id']?.toString(),
              title: s['title']?.toString() ?? '',
              coverUrl: _seriesCover(s, preferLandscape: false),
              issueCount: looseInt(s['comics_count']) ?? 0,
            ))
        .where((s) => s.seriesId != null && s.title.isNotEmpty)
        .toList();
  }

  /// 官方编辑精选系列（静态小列表，不轮换）。
  Future<List<SeriesSummary>> fetchFeaturedSeries() async {
    final body = await _getJson('/v1/catalog/series/featured');
    final results = (body['data']['results'] as List).cast<Map<String, dynamic>>();
    if (results.isEmpty) return const [];
    final contents =
        (results.first['listContents'] as List? ?? const []).cast<Map<String, dynamic>>();
    return contents
        .map((s) => SeriesSummary(
              seriesId: s['id']?.toString(),
              title: s['title']?.toString() ?? '',
              coverUrl: _seriesCover(s, preferLandscape: true),
            ))
        .where((s) => s.seriesId != null && s.title.isNotEmpty)
        .toList();
  }

  /// 系列资产的封面 URL。输入形如 {image_url, image_extension}，
  /// image_url 是相对路径（/i/mg/...），系列资产支持全变体。
  static String? _seriesCover(Map s, {required bool preferLandscape}) {
    final base = s['image_url']?.toString() ?? '';
    if (base.isEmpty || base.contains('image_not_available')) return null;
    final ext = s['image_extension']?.toString() ??
        s['thumb_ext']?.toString() ??
        'jpg';
    final variant = preferLandscape ? 'landscape_incredible' : 'portrait_uncanny';
    return 'https://cdn.marvel.com/u/prod/marvel$base/$variant.$ext';
  }

  static String _dateString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 系列详情（封面、描述、起止年份）。注意这个端点**没有** `/v1` 前缀
  /// （带 /v1 会 403）。很多新系列没有封面（image_not_available），调用方要兜底。
  Future<SeriesDetail?> fetchSeriesDetail(String seriesId) async {
    final body = await _getJson('/catalog/series/$seriesId');
    final data = body['data'];
    if (data is! Map) return null;
    return SeriesDetail.fromBifrost(data);
  }
}