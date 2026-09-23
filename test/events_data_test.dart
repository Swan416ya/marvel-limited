import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marvel_limited/data/models/marvel_event.dart';

/// 静态事件库的数据契约：文件合法、条目齐全、排序规则正确。
/// 直接读文件（不经过 rootBundle），普通 test 环境就能跑。
void main() {
  final raw = File('assets/data/marvel_events.json').readAsStringSync();
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final events = (data['events'] as List)
      .map((e) => MarvelEvent.fromJson(e as Map))
      .toList();

  test('事件数量与分级覆盖', () {
    expect(events.length, greaterThanOrEqualTo(30));
    final tiers = events.map((e) => e.tier).toSet();
    expect(tiers, containsAll(['company', 'cosmic', 'earth', 'spider', 'xmen']));
  });

  test('每条事件都有阅读顺序和一句话介绍', () {
    for (final e in events) {
      expect(e.coreOrder, isNotEmpty, reason: '${e.title} 缺阅读顺序');
      expect(e.oneLiner, isNotEmpty, reason: '${e.title} 缺介绍');
      expect(e.year, greaterThan(1980), reason: '${e.title} 年份异常');
    }
  });

  test('排序：全公司级排在最前', () {
    expect(events.first.isCompanyWide, isTrue, reason: '第一条必须是全公司级');
    // 文件里 company 块必须整体在其它 tier 之前（仓库的 all() 加载时
    // 还会按「tier → 年份倒序」重排一遍，这里只守数据不劣化）。
    final firstNonCompany = events.indexWhere((e) => !e.isCompanyWide);
    if (firstNonCompany > 0) {
      for (final e in events.skip(firstNonCompany)) {
        expect(e.isCompanyWide, isFalse,
            reason: '${e.title} 出现在 company 块之后却又标成 company');
      }
    }
  });

  test('阅读顺序条目能拼出可搜索的标题', () {
    for (final e in events) {
      for (final item in e.coreOrder) {
        expect(item.searchableTitle, contains('#'));
        expect(item.series, isNotEmpty);
      }
    }
  });

  test('逐期导读：条目齐全、日期合法、按发行日期排序', () {
    var withOrder = 0;
    for (final e in events) {
      if (e.readingOrder.isEmpty) continue;
      withOrder++;
      String? prev;
      for (final it in e.readingOrder) {
        expect(it.id, isNotEmpty, reason: '${e.title} 的导读条目缺 id');
        expect(it.series, isNotEmpty, reason: '${e.title} 的导读条目缺系列名');
        expect(it.number, isNotEmpty, reason: '${e.title} 的导读条目缺期号');
        if (it.date.isNotEmpty) {
          expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(it.date), isTrue,
              reason: '${e.title} 日期格式异常: ${it.date}');
          if (prev != null) {
            expect(it.date.compareTo(prev) >= 0, isTrue,
                reason: '${e.title} 的逐期清单没按发行日期排序：'
                    '$prev -> ${it.date}');
          }
          prev = it.date;
        }
      }
    }
    // 官方阅读指南只覆盖一部分事件，剩下的必须由本地逐期清单兜底
    expect(withOrder, greaterThanOrEqualTo(10),
        reason: '带逐期导读的事件太少，缺官方指南的会没有详细阅读顺序');
  });
}
