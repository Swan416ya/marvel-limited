import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marvel_limited/features/series_hub/heroes.dart';

/// 英雄清单的数据契约。
///
/// 这里的 id 是官网角色 id，写错了不会编译报错——只会让英雄页空着、或者
/// 点进去变成另一个人。而且头像文件是按 id 命名的，id 与
/// `assets/data/hero_avatars/manifest.json` 必须一一对上。
/// 直接读文件（不经过 rootBundle），普通 test 环境就能跑。
void main() {
  final manifest =
      jsonDecode(File('assets/data/hero_avatars/manifest.json').readAsStringSync())
          as Map<String, dynamic>;

  test('清单规模够铺满平板一行', () {
    // 平板横屏（1194 宽）一屏能看到约 14 个；少于这个数就是「一行填不满」，
    // 那正是当初要求加人的原因。
    expect(heroes.length, greaterThanOrEqualTo(20));
  });

  test('id 唯一', () {
    final ids = heroes.map((h) => h.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('每个英雄都有中文名、英文名、介绍', () {
    for (final h in heroes) {
      expect(h.nameZh, isNotEmpty, reason: '${h.id} 缺中文名');
      expect(h.nameEn, isNotEmpty, reason: '${h.id} 缺英文名');
      expect(h.intro, isNotEmpty, reason: '${h.id} 缺介绍');
    }
  });

  test('每个英雄都有本地头像（否则要联网兜底，离线就是空框）', () {
    for (final h in heroes) {
      expect(manifest.containsKey(h.id), isTrue, reason: '${h.id} 缺头像');
      final file = File('assets/data/hero_avatars/${manifest[h.id]}');
      expect(file.existsSync(), isTrue, reason: '${h.id} 头像文件不在: ${manifest[h.id]}');
      expect(file.lengthSync(), greaterThan(0), reason: '${h.id} 头像是空文件');
    }
  });

  test('manifest 里没有多余条目（改清单时忘了清）', () {
    final ids = heroes.map((h) => h.id).toSet();
    final extra = manifest.keys.where((k) => !ids.contains(k)).toList();
    expect(extra, isEmpty, reason: 'manifest 多出: $extra');
  });

  test('heroById 能查到，查不到返回 null', () {
    expect(heroById(heroes.first.id)?.nameZh, heroes.first.nameZh);
    expect(heroById('not-a-real-id'), isNull);
  });
}
