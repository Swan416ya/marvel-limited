import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marvel_limited/data/models/marvel_models.dart';
import 'package:marvel_limited/data/repository/wiki_repository.dart';
import 'package:marvel_limited/data/sources/fandom_client.dart';

/// 「从 wiki 补全官网缺失期数」的逻辑原先是塞在 SeriesPage 的 State 里的，
/// 现在挪到仓库层，这里用假 http 把它钉住。
void main() {
  ComicIssue official(String number) => ComicIssue(
        id: 'official-$number',
        title: 'Amazing Spider-Man #$number',
        seriesTitle: 'Amazing Spider-Man (2018)',
        issueNumber: number,
        releaseDate: '2018-01-01',
        description: '',
      );

  /// 只对指定期号返回可解析的 wikitext，其它期号当作 wiki 上没有。
  MockClient wiki({required Set<String> available}) {
    return MockClient((request) async {
      final page = request.url.queryParameters['page'] ?? '';
      final number = page.split(' ').last;
      if (!available.contains(number)) {
        return http.Response(jsonEncode({}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response(
        jsonEncode({
          'parse': {
            'wikitext': {
              '*': '{{Comic\n'
                  '|ReleaseDate=2018-02-01\n'
                  '|Solicit=补全的一期\n'
                  '}}',
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

  test('只去 wiki 找官网缺的期号', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.queryParameters['page'] ?? '');
      return http.Response(jsonEncode({}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    final repo = WikiRepository(client: FandomClient(client: client));
    // 官网有 1、2、4，最大期号 4 → 应该只去找 3 和 5
    await repo.supplementMissing(
      [official('1'), official('2'), official('4')],
    );

    expect(requested.toSet(),
        {'Amazing Spider-Man Vol 4 3', 'Amazing Spider-Man Vol 4 5'});
  });

  test('wiki 上找得到的期号会被补进来，其余丢弃', () async {
    final repo = WikiRepository(
      client: FandomClient(client: wiki(available: {'3'})),
    );

    final found = await repo.supplementMissing(
      [official('1'), official('2'), official('4')],
      onProgress: null,
    );

    expect(found.length, 1);
    expect(found.single.issueNumber, '3');
    expect(found.single.id, 'fandom:Amazing Spider-Man Vol 4 3');
    expect(found.single.releaseDate, '2018-02-01');
  });

  test('官网目录为空时不发请求', () async {
    var calls = 0;
    final repo = WikiRepository(
      client: FandomClient(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      ),
    );

    final found = await repo.supplementMissing(const []);
    expect(found, isEmpty);
    expect(calls, 0);
  });

  test('并发补全时会回报进度', () async {
    final seen = <int>[];
    final repo = WikiRepository(
      client: FandomClient(client: wiki(available: <String>{})),
    );

    await repo.supplementMissing(
      [official('1'), official('4'), official('7')],
      onProgress: (done, total) {
        seen.add(done);
        expect(total, greaterThan(0));
      },
    );

    expect(seen, isNotEmpty);
  });
}