import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marvel_limited/data/models/marvel_models.dart';
import 'package:marvel_limited/data/repository/catalog_repository.dart';
import 'package:marvel_limited/data/sources/bifrost_client.dart';

/// 「最近更新的系列」这条链路的解析测试。
///
/// 日历端点（/v1/catalog/comics/calendar）和系列端点（byId=comic_series）
/// 返回的 issue 结构相同但字段可能缺省，这里用假 HTTP 把解析钉住。
void main() {
  http.Response json(Object body) => http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  /// 日历端点的条目形状（实测样例的精简版）。
  Map<String, dynamic> calendarItem({
    Object? id = 900,
    String title = 'Venom (2026) #2',
    Object? issueNumber = '2',
    String releaseDate = '2026-09-16',
    Object? creators = const ['Mackay, Jed', 'Larraz, Pepe'],
    String imageUrl = '/i/mg/f/60/69bb591daec5a',
    bool isVariant = false,
  }) =>
      {
        'id': id,
        'title': title,
        'issue_number': issueNumber,
        'release_date': releaseDate,
        'summary': '简介',
        'creators': creators,
        'image_url': imageUrl,
        'thumb_ext': 'jpg',
        'is_variant': isVariant ? '1' : '0',
        'metadata': {
          'series': {'id': 46047, 'title': 'Venom (2026 - Present)'},
          'digital_comic': {'in_mu': true},
        },
      };

  test('日历端点：解析出 issue 并保留系列归属', () async {
    final repo = CatalogRepository(
      client: BifrostClient(
        client: MockClient((req) async => json({
              'data': {
                'results': [calendarItem()],
                'total': 1,
              }
            })),
      ),
    );

    final issues = await repo.latestIssues(limit: 1);
    final issue = issues.single;

    expect(issue.id, '900');
    expect(issue.seriesId, '46047');
    expect(issue.seriesTitle, 'Venom (2026 - Present)');
    expect(issue.issueNumber, '2');
    expect(issue.inMu, isTrue);
    expect(
      issue.coverUrl,
      'https://cdn.marvel.com/u/prod/marvel/i/mg/f/60/69bb591daec5a/portrait_uncanny.jpg',
    );
  });

  test('日历端点：变体封面被剔除、缺失字段不炸', () async {
    final repo = CatalogRepository(
      client: BifrostClient(
        client: MockClient((req) async => json({
              'data': {
                'results': [
                  calendarItem(isVariant: true),
                  calendarItem(
                    id: 901,
                    issueNumber: null,
                    creators: null,
                    imageUrl: '',
                  ),
                ],
                'total': 2,
              }
            })),
      ),
    );

    final issues = await repo.latestIssues(limit: 2);
    // 变体被过滤，只剩一条
    expect(issues.length, 1);
    expect(issues.first.issueNumber, 'null');
    expect(issues.first.coverUrl, isNull);
  });

  test('distinctSeries：同系列合并、保留最新期号与封面', () async {
    final issues = [
      ComicIssue(
        id: '1',
        title: 'Venom (2026) #2',
        seriesTitle: 'Venom (2026 - Present)',
        seriesId: '46047',
        issueNumber: '2',
        releaseDate: '2026-09-16',
        description: '',
        coverUrl: 'https://cdn.example/venom2.jpg',
      ),
      ComicIssue(
        id: '2',
        title: 'Venom (2026) #1',
        seriesTitle: 'Venom (2026 - Present)',
        seriesId: '46047',
        issueNumber: '1',
        releaseDate: '2026-08-19',
        description: '',
        coverUrl: 'https://cdn.example/venom1.jpg',
      ),
      ComicIssue(
        id: '3',
        title: 'Iron Man #1',
        seriesTitle: 'Iron Man',
        seriesId: '39289',
        issueNumber: '1',
        releaseDate: '2026-09-10',
        description: '',
      ),
    ];

    final series = CatalogRepository.distinctSeries(issues);

    expect(series.length, 2);
    final venom = series.first;
    expect(venom.seriesId, '46047');
    expect(venom.issueCount, 2);
    // 日历数据是倒序的，第一条就是最新一期
    expect(venom.latestIssue, '2');
    expect(venom.coverUrl, 'https://cdn.example/venom2.jpg');
  });

  test('distinctSeries：seriesId 缺失时按系列名归组', () {
    final issues = [
      ComicIssue(
        id: 'a',
        title: 'A #1',
        seriesTitle: 'Wiki Series',
        issueNumber: '1',
        releaseDate: '',
        description: '',
      ),
      ComicIssue(
        id: 'b',
        title: 'A #2',
        seriesTitle: 'Wiki Series',
        issueNumber: '2',
        releaseDate: '',
        description: '',
      ),
    ];
    final series = CatalogRepository.distinctSeries(issues);
    expect(series.length, 1);
    expect(series.first.title, 'Wiki Series');
    expect(series.first.issueCount, 2);
  });
}