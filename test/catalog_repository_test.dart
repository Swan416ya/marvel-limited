import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marvel_limited/data/repository/catalog_repository.dart';
import 'package:marvel_limited/data/sources/bifrost_client.dart';

/// 用假的 http client 打桩，测试仓库层的缓存和并发去重。
/// 这些测试不需要网络。
void main() {
  http.Response json(Object body) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Map<String, dynamic> guidesBody() => {
        'data': {
          'results': [
            {
              'id': 42,
              'title': 'Civil War',
              'description': '内有战争',
              'images': [
                {'path': 'https://cdn.example/a', 'extension': 'jpg'},
              ],
            },
          ],
        },
      };

  Map<String, dynamic> seriesBody() => {
        'data': {
          'results': [
            {
              'id': 100,
              'title': 'Amazing Spider-Man #1',
              'issue_number': '1',
              'release_date': '2018-07-11',
              'summary': '开篇',
              'is_variant': '0',
              'image_url': '',
              'creators': ['Nick Spencer'],
              'metadata': {
                'series': {'id': 5, 'title': 'Amazing Spider-Man'},
              },
            },
          ],
          'total': 1,
        },
      };

  test('阅读指南列表命中内存缓存，只发一次请求', () async {
    var calls = 0;
    final repo = CatalogRepository(
      client: BifrostClient(
        client: MockClient((req) async {
          calls++;
          return json(guidesBody());
        }),
      ),
    );

    final first = await repo.readingGuides();
    final second = await repo.readingGuides();

    expect(calls, 1);
    expect(first.length, 1);
    expect(first.first.title, 'Civil War');
    expect(first.first.coverUrl, 'https://cdn.example/a.jpg');
    expect(identical(first, second), isTrue);
  });

  test('同一系列被并发请求时只发一次', () async {
    var calls = 0;
    final repo = CatalogRepository(
      client: BifrostClient(
        client: MockClient((req) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return json(seriesBody());
        }),
      ),
    );

    final results = await Future.wait([
      repo.seriesIssues('5'),
      repo.seriesIssues('5'),
    ]);

    expect(calls, 1);
    expect(results[0].length, 1);
    expect(results[1].length, 1);
  });

  test('系列 issue 解析出系列名、期号与封面', () async {
    final repo = CatalogRepository(
      client: BifrostClient(client: MockClient((_) async => json(seriesBody()))),
    );

    final issues = await repo.seriesIssues('5');
    final issue = issues.single;

    expect(issue.seriesTitle, 'Amazing Spider-Man');
    expect(issue.issueNumber, '1');
    expect(issue.creators, ['Nick Spencer']);
    expect(issue.isVariant, isFalse);
    expect(repo.findCachedIssue(issue.id)?.title, issue.title);
  });

  test('force 会绕过缓存重新请求', () async {
    var calls = 0;
    final repo = CatalogRepository(
      client: BifrostClient(
        client: MockClient((_) async {
          calls++;
          return json(guidesBody());
        }),
      ),
    );

    await repo.readingGuides();
    await repo.readingGuides(force: true);

    expect(calls, 2);
  });
}