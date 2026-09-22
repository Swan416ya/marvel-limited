import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../core/async/concurrent.dart';
import '../models/marvel_models.dart';

/// Marvel Database (fandom wiki) 的原始 HTTP 客户端。
///
/// 官网目录里被下架/未数字化的 issue 在这里找。只负责取数和解析，
/// 缓存与「补齐缺失期数」的策略交给 `WikiRepository`。
class FandomClient {
  static const _base = 'https://marvel.fandom.com/api.php';

  final http.Client _client;

  /// 每次重试前的退避时长（列表长度即重试次数）。测试里传空列表。
  final List<Duration> retryDelays;

  FandomClient({
    http.Client? client,
    this.retryDelays = const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 800),
    ],
  }) : _client = client ?? http.Client();

  Future<void> _backoff(int attempt) async {
    if (attempt < retryDelays.length) {
      await Future<void>.delayed(retryDelays[attempt]);
    }
  }

  Map<String, String> get _headers => const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
        'Accept': 'application/json',
      };

/// MediaWiki 的返回体有时是对象（parse / query 接口），有时是数组
  /// （opensearch 接口），所以这里不做强制转型，由调用方按接口形状取。
  /// 带重试：fandom 偶尔掐连接，wiki 补全动辄几十个请求，不重试必挂。
  Future<Object?> _apiRaw(Map<String, String> params) async {
    final target = kIsWeb
        ? 'http://127.0.0.1:8322/proxy/${Uri.encodeFull(_base)}'
        : _base;
    final uri = Uri.parse(target).replace(queryParameters: params);
    Object lastError =
        Exception('fandom ${params['action']} failed after retries');
    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      try {
        final resp = await _client.get(uri, headers: _headers);
        if (resp.statusCode != 200) {
          throw Exception(
              'fandom ${params['action']} failed: ${resp.statusCode}');
        }
        return json.decode(utf8.decode(resp.bodyBytes));
      } catch (e) {
        lastError = e;
        await _backoff(attempt);
      }
    }
    throw lastError;
  }

  /// 需要对象形状的接口（parse / query）用这个。
  Future<Map<String, dynamic>?> _api(Map<String, String> params) async {
    final body = await _apiRaw(params);
    return body is Map<String, dynamic> ? body : null;
  }

  /// 系列名搜索（Fandom opensearch）。
  /// 只保留 "XXX Vol N" 形式的系列主页面，过滤 issue 页与合集页。
  /// `limit` 默认给足：系列页按英雄筛选用（opensearch 上限 100）。
  Future<List<Map<String, String>>> searchSeries(String query,
      {int limit = 50}) async {
    // opensearch 返回数组：["词", [标题…], [描述…], [链接…]]
    final body = await _apiRaw({
      'action': 'opensearch',
      'search': query,
      'limit': limit.toString(),
      'format': 'json',
    });
    if (body is! List) return const [];
    final results =
        body.length > 1 && body[1] is List ? body[1] as List : const [];
    final urls = body.length > 3 && body[3] is List ? body[3] as List : const [];
    final out = <Map<String, String>>[];
    for (var i = 0; i < results.length && i < urls.length; i++) {
      final title = results[i].toString();
      if (RegExp(r' Vol \d+$').hasMatch(title)) {
        out.add({'title': title, 'url': urls[i].toString()});
      }
    }
    return out;
  }

  /// 某系列在 wiki 上的全部 issue 号（用 allpages 前缀枚举），已排序。
  ///
  /// 页面名形如 "Amazing Spider-Man Vol 2 500"，期号就是去掉前缀的部分。
  Future<List<String>> listIssueNumbers(String seriesPageName) async {
    final body = await _api({
      'action': 'query',
      'list': 'allpages',
      'apprefix': '$seriesPageName ',
      'aplimit': '500',
      'format': 'json',
    });
    final allpages = (body?['query']?['allpages'] as List?) ?? const [];
    final prefix = '$seriesPageName ';
    final numbers = <String>[];
    for (final p in allpages) {
      final title = (p as Map)['title'].toString();
      if (!title.startsWith(prefix)) continue;
      final num = title.substring(prefix.length);
      // 纯数字才是 issue 页；"500A" 这类变体跳过
      if (!RegExp(r'^\d+$').hasMatch(num)) continue;
      numbers.add(num);
    }
    numbers.sort(
        (a, b) => (double.tryParse(a) ?? 0).compareTo(double.tryParse(b) ?? 0));
    return numbers;
  }

  /// 批量取详情（封面/日期）。受 `limit` 限制，默认取前 100 期。
  ///
  /// 原先是一期一次串行请求，几百期要等很久；现在限并发 6，并回报进度。
  Future<List<ComicIssue>> fetchSeriesIssues(
    String seriesPageName, {
    int limit = 100,
    int concurrency = 6,
    void Function(int done, int total)? onProgress,
  }) async {
    final numbers = await listIssueNumbers(seriesPageName);
    final targets = numbers.length > limit ? numbers.sublist(0, limit) : numbers;
    return mapConcurrent<String, ComicIssue>(
      targets,
      (n) => fetchIssue(seriesPageName, n),
      concurrency: concurrency,
      onProgress: onProgress,
    );
  }

  /// 某系列某号的详情。`seriesPageName` 如 "Amazing Spider-Man Vol 2"。
  Future<ComicIssue?> fetchIssue(
          String seriesPageName, String issueNumber) =>
      _fetchByPage(
          '$seriesPageName $issueNumber', seriesPageName, issueNumber);

  Future<ComicIssue?> _fetchByPage(
      String pageName, String seriesTitle, String issueNumber) async {
    final body = await _api({
      'action': 'parse',
      'page': pageName,
      'prop': 'wikitext',
      'format': 'json',
    });
    final parse = body?['parse'] as Map<String, dynamic>?;
    if (parse == null) return null;
    final wikitext = (parse['wikitext'] as Map<String, dynamic>)['*'] as String;
    if (wikitext.startsWith('#REDIRECT')) {
      final m = RegExp(r'\[\[([^\]|]+)').firstMatch(wikitext);
      if (m != null) {
        return _fetchByPage(m.group(1)!, seriesTitle, issueNumber);
      }
      return null;
    }
    return _parseWikitext(pageName, wikitext, seriesTitle, issueNumber);
  }

  Future<ComicIssue?> _parseWikitext(String pageName, String wikitext,
      String seriesTitle, String issueNumber) async {
    String field(String name) {
      final pattern = RegExp(r'\|\s*' + name + r'\s*=([^\n|]*)');
      final m = pattern.firstMatch(wikitext);
      return m?.group(1)?.trim() ?? '';
    }

    final releaseDate = field('ReleaseDate');
    if (releaseDate.isEmpty) return null;
    final imageFile = field('Image1');
    String? coverUrl;
    if (imageFile.isNotEmpty) {
      coverUrl = await fetchImageUrl(imageFile);
    }
    return ComicIssue(
      id: 'fandom:$pageName',
      title: '$seriesTitle #$issueNumber',
      seriesTitle: seriesTitle,
      issueNumber: issueNumber,
      releaseDate: releaseDate,
      description: field('Solicit'),
      coverUrl: coverUrl,
      creators: const [],
    );
  }

  Future<String?> fetchImageUrl(String fileName) async {
    final body = await _api({
      'action': 'query',
      'titles': 'File:$fileName',
      'prop': 'imageinfo',
      'iiprop': 'url',
      'format': 'json',
    });
    final pages = body?['query']?['pages'] as Map<String, dynamic>?;
    if (pages == null) return null;
    for (final p in pages.values) {
      final infos = p['imageinfo'] as List?;
      if (infos != null && infos.isNotEmpty) {
        return (infos.first as Map<String, dynamic>)['url'] as String;
      }
    }
    return null;
  }
}