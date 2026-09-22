import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marvel_limited/data/filename_matcher.dart';
import 'package:marvel_limited/data/models/marvel_models.dart';
import 'package:marvel_limited/data/repository/library_repository.dart';

/// 文件名解析 + 本地导入的集成测试。
///
/// 文件名样例全部来自真实漫画库（E:\Comic Manager Library）的
/// 实际命名格式；导入测试用 7z 从真实 CBR 转出来的 CBZ
/// （build/test_import/civil_war_001.cbz，没有就跳过）。
void main() {
  group('parseComicFilename（真实库文件名）', () {
    test('GetComics 命名：系列 - 子标题 期号 (年份) 标签', () {
      final r = parseComicFilename(
          'Amazing Spider-Man - Renew Your Vows 002 (2015) GetComics.INFO.cbr');
      expect(r.seriesGuess, 'Amazing Spider-Man - Renew Your Vows');
      expect(r.issueNumber, '2');
      expect(r.cleanTitle, 'Amazing Spider-Man - Renew Your Vows #2');
    });

    test('扫描组命名：系列 期号 (年份) (Digital) (组名)', () {
      final r = parseComicFilename(
          'Civil War 001 (2006) (Digital) (Zone-Empire).cbr');
      expect(r.seriesGuess, 'Civil War');
      expect(r.issueNumber, '1');
    });

    test('井号期号', () {
      final r = parseComicFilename('Amazing Spider-Man #300.cbz');
      expect(r.seriesGuess, 'Amazing Spider-Man');
      expect(r.issueNumber, '300');
    });

    test('前导零剥掉', () {
      final r = parseComicFilename('House of M 003 (2005).cbr');
      expect(r.issueNumber, '3');
    });

    test('小数期号保留', () {
      final r = parseComicFilename('Batman 012.5.cbz');
      expect(r.issueNumber, '12.5');
    });

    test('没有期号时不硬造', () {
      final r = parseComicFilename('Some One Shot.cbr');
      expect(r.issueNumber, isNull);
      expect(r.seriesGuess, 'Some One Shot');
    });
  });

  group('matchLocalIssue', () {
    test('系列名包含 + 期号精确', () {
      final local = [
        ComicIssue(
          id: '1',
          title: 'Civil War #1',
          seriesTitle: 'Civil War (2006 - 2007)',
          issueNumber: '1',
          releaseDate: '',
          description: '',
        ),
        ComicIssue(
          id: '2',
          title: 'Civil War #2',
          seriesTitle: 'Civil War (2006 - 2007)',
          issueNumber: '2',
          releaseDate: '',
          description: '',
        ),
      ];
      final parsed = parseComicFilename(
          'Civil War 001 (2006) (Digital) (Zone-Empire).cbr');
      final match = matchLocalIssue(parsed, local);
      expect(match, isNotNull);
      expect(match!.id, '1');
    });
  });

  group('importArchive（真实 CBZ）', () {
    final fixture = File('build/test_import/civil_war_001.cbz');

    test('导入真实转换的 CBZ 并能读出页面', () async {
      if (!fixture.existsSync()) {
        // 仓库里不打包这个 fixture（36MB），本地跑过转换才有
        markTestSkipped('没有 build/test_import/civil_war_001.cbz');
        return;
      }
      final tmp = await Directory.systemTemp.createTemp('library_test_');
      addTearDown(() => tmp.delete(recursive: true));

      final repo = await LibraryRepository.load('${tmp.path}/library');
      final issue = ComicIssue(
        id: 'test-cw-1',
        title: 'Civil War #1',
        seriesTitle: 'Civil War (2006)',
        issueNumber: '1',
        releaseDate: '2006-05-03',
        description: '',
      );

      final saved = await repo.importArchive(issue, fixture.path);
      expect(saved.localPath, isNotNull);
      expect(repo.isImported('test-cw-1'), isTrue);

      final pages = await repo.pagesFor(issue);
      expect(pages.length, 34, reason: '转换的 CBZ 里有 34 页图');
      expect(pages.first.endsWith('.jpg'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}