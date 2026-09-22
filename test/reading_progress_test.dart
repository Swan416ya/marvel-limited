import 'package:flutter_test/flutter_test.dart';
import 'package:marvel_limited/data/models/marvel_models.dart';
import 'package:marvel_limited/data/repository/preferences_repository.dart';

ComicIssue issue() => ComicIssue(
      id: '100',
      title: 'Amazing Spider-Man #1',
      seriesTitle: 'Amazing Spider-Man',
      issueNumber: '1',
      releaseDate: '2018-07-11',
      description: '开篇',
      coverUrl: 'https://cdn.example/a.jpg',
    );

void main() {
  group('ReadingProgress', () {
    test('没翻过页时不算在读', () {
      final p = ReadingProgress(
        issue: issue(),
        page: 0,
        totalPages: 20,
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(p.isReading, isFalse);
      expect(p.isFinished, isFalse);
    });

    test('翻过页但没到最后一页算在读', () {
      final p = ReadingProgress(
        issue: issue(),
        page: 3,
        totalPages: 20,
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(p.isReading, isTrue);
      expect(p.ratio, closeTo(4 / 20, 0.001));
    });

    test('翻到最后一页算读完', () {
      final p = ReadingProgress(
        issue: issue(),
        page: 19,
        totalPages: 20,
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(p.isFinished, isTrue);
      expect(p.isReading, isFalse);
      expect(p.ratio, 1.0);
    });

    test('总页数为 0 时不会除以零', () {
      final p = ReadingProgress(
        issue: issue(),
        page: 0,
        totalPages: 0,
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(p.ratio, 0);
      expect(p.isFinished, isFalse);
    });

    test('JSON 往返保留 issue 快照与页码', () {
      final p = ReadingProgress(
        issue: issue(),
        page: 7,
        totalPages: 24,
        updatedAt: DateTime(2026, 3, 4, 5, 6, 7),
      );

      final restored = ReadingProgress.fromJson(p.toJson());

      expect(restored.issue.id, '100');
      expect(restored.issue.title, 'Amazing Spider-Man #1');
      expect(restored.issue.coverUrl, 'https://cdn.example/a.jpg');
      expect(restored.page, 7);
      expect(restored.totalPages, 24);
      expect(restored.updatedAt, DateTime(2026, 3, 4, 5, 6, 7));
    });

    test('缺少字段时给安全默认值', () {
      final restored = ReadingProgress.fromJson({
        'issue': issue().toJson(),
        'page': null,
        'totalPages': null,
        'updatedAt': 'not a date',
      });
      expect(restored.page, 0);
      expect(restored.totalPages, 0);
      expect(restored.updatedAt.millisecondsSinceEpoch, 0);
    });
  });
}