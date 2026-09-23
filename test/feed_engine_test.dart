import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:marvel_limited/features/home/feed_engine.dart';
import 'package:marvel_limited/data/models/marvel_models.dart';
import 'package:marvel_limited/data/repository/preferences_repository.dart';

FeedCard card(String id, {FeedKind kind = FeedKind.guide, String? title}) =>
    FeedCard(id: id, kind: kind, title: title ?? id);

void main() {
  test('固定种子下结果可复现', () {
    final pool = [for (var i = 0; i < 40; i++) card('g$i')];
    final a = FeedEngine(random: Random(7))..reset(pool: pool, signals: const FeedSignals());
    final b = FeedEngine(random: Random(7))..reset(pool: pool, signals: const FeedSignals());
    expect(a.nextBatch(10).map((c) => c.id).toList(),
        b.nextBatch(10).map((c) => c.id).toList());
  });

  test('不同种子会给出不同顺序（每次打开不一样）', () {
    final pool = [for (var i = 0; i < 40; i++) card('g$i')];
    final a = FeedEngine(random: Random(1))..reset(pool: pool, signals: const FeedSignals());
    final b = FeedEngine(random: Random(2))..reset(pool: pool, signals: const FeedSignals());
    expect(a.nextBatch(10).map((c) => c.id).toList(),
        isNot(b.nextBatch(10).map((c) => c.id).toList()));
  });

  test('一轮之内不重复，取完会自动开新一轮', () {
    final pool = [for (var i = 0; i < 10; i++) card('g$i')];
    final engine = FeedEngine(random: Random(3), batchSize: 4)
      ..reset(pool: pool, signals: const FeedSignals());

    final first = <String>[];
    for (var i = 0; i < 3; i++) {
      first.addAll(engine.nextBatch(4).map((c) => c.id));
    }
    // 前三批 12 张要覆盖全部 10 条，且第 11、12 张是新一轮的开始
    expect(first.take(10).toSet().length, 10, reason: '一轮内不该重复');
    expect(engine.nextBatch(4), isNotEmpty, reason: '给完一轮要能继续给');
  });

  test('在读的永远排在最前', () {
    final pool = [
      for (var i = 0; i < 20; i++) card('g$i'),
      FeedCard(
        id: 'issue:1',
        kind: FeedKind.continueReading,
        title: '在读的一期',
        progress: ReadingProgress(
          issue: ComicIssue(
            id: '1',
            title: '在读的一期',
            seriesTitle: 'S',
            issueNumber: '1',
            releaseDate: '2024-01-01',
            description: '',
          ),
          page: 3,
          totalPages: 20,
          updatedAt: DateTime(2026, 1, 1),
        ),
      ),
    ];
    final engine = FeedEngine(random: Random(5))
      ..reset(pool: pool, signals: const FeedSignals());
    expect(engine.nextBatch(5).first.id, 'issue:1');
  });

  test('搜索记录/收藏能加权：命中的排在前面', () {
    final pool = [
      for (var i = 0; i < 30; i++) card('g$i', title: 'Unrelated Book $i'),
      card('hit', title: 'Amazing Spider-Man Vol 5'),
    ];
    // 同一批里对比：命中项应当出现在更前面（抖动 ±0.9 < 命中加权 1.5+）
    final engine = FeedEngine(random: Random(11))
      ..reset(
        pool: pool,
        signals: const FeedSignals(searchTerms: ['amazing spider-man']),
      );
    final batch = engine.nextBatch(30);
    expect(batch.map((c) => c.id).toList().indexOf('hit') < 5, isTrue,
        reason: '命中的应该落在很前面');
  });

  test('关键词提取：去掉括号与符号、拆出实词', () {
    final terms = FeedSignals.termsFrom(['Civil War (2006 - 2007)', '#300']);
    expect(terms, contains('civil war'));
    expect(terms, contains('civil'));
    expect(terms, contains('war'));
    // 太短的词不进池子（避免噪音）
    expect(terms.any((t) => t.length < 3), isFalse);
  });

  test('空池子不会崩，也不会给卡片', () {
    final engine = FeedEngine(random: Random(1))
      ..reset(pool: const [], signals: const FeedSignals());
    expect(engine.nextBatch(), isEmpty);
  });

  test('同 id 的候选会去重', () {
    final engine = FeedEngine(random: Random(2))
      ..reset(
        pool: [card('dup'), card('dup'), card('other')],
        signals: const FeedSignals(),
      );
    final ids = engine.nextBatch(10).map((c) => c.id).toList();
    expect(ids.where((id) => id == 'dup').length, 1);
  });
}
