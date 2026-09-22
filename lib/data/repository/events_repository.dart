import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/marvel_event.dart';
import '../models/marvel_models.dart';

/// 静态大事件仓库：从打包进应用的 JSON 里读，不联网。
///
/// 数据文件是编译期外整理的（`assets/data/marvel_events.json`），
/// 所以打开事件页是即时的；图片 URL 是外链，走 `resolveImage` 的规则。
class EventsRepository {
  static const _assetPath = 'assets/data/marvel_events.json';

  /// 本地打包的事件封面目录（`tool/fetch_event_covers.py` 生成）。
  static const _coverDir = 'assets/data/event_covers';

  List<MarvelEvent>? _events;
  Future<List<MarvelEvent>>? _loading;

  /// 本地封面清单（id → 文件名），没有跑过打包脚本时为空。
  Map<String, String>? _localCovers;

  /// tier 的固定展示顺序：全公司级永远最前。
  static const tierOrder = ['company', 'cosmic', 'earth', 'spider', 'xmen'];

  /// 加载并缓存。并发调用只读一次资产。
  Future<List<MarvelEvent>> all() {
    final cached = _events;
    if (cached != null) return Future.value(cached);
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<List<MarvelEvent>> _load() async {
    // 顺手读封面 manifest（不存在就当没有本地封面）
    try {
      final manifest =
          await rootBundle.loadString('$_coverDir/manifest.json');
      final map = json.decode(manifest) as Map<String, dynamic>;
      _localCovers = map.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      _localCovers = const {};
    }

    final raw = await rootBundle.loadString(_assetPath);
    final data = json.decode(raw) as Map<String, dynamic>;
    final list = (data['events'] as List? ?? [])
        .map((e) => MarvelEvent.fromJson(e as Map))
        .toList();
    _events = _sorted(list);
    return _events!;
  }

  /// 全公司级在前，同级按年份倒序（新的先看）。
  List<MarvelEvent> _sorted(List<MarvelEvent> list) {
    int tierRank(String tier) {
      final i = tierOrder.indexOf(tier);
      return i < 0 ? tierOrder.length : i;
    }

    list.sort((a, b) {
      final byTier = tierRank(a.tier).compareTo(tierRank(b.tier));
      if (byTier != 0) return byTier;
      return b.year.compareTo(a.year);
    });
    return list;
  }

  Future<MarvelEvent?> byId(String id) async {
    final all = await this.all();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// 给事件找配图，优先级：
  /// 1. 本地打包的封面（`tool/fetch_event_covers.py`，离线可用）；
  /// 2. 数据集里的 `imageUrl`；
  /// 3. 官方指南列表里同名指南的封面；
  /// 4. null → UI 的品牌渐变兜底。
  String? coverUrlFor(MarvelEvent event, List<ReadingGuide> guides) {
    final local = _localCovers?[event.id];
    if (local != null) return '$_coverDir/$local';
    if (event.imageUrl != null && event.imageUrl!.isNotEmpty) {
      return event.imageUrl;
    }
    final key = event.title.toLowerCase();
    for (final g in guides) {
      final t = g.title.toLowerCase();
      if (t.contains(key) || key.contains(t)) return g.coverUrl;
    }
    return null;
  }

  /// 按 tier 分组（保持 all() 的排序）。
  Future<Map<String, List<MarvelEvent>>> grouped() async {
    final all = await this.all();
    final groups = <String, List<MarvelEvent>>{};
    for (final e in all) {
      groups.putIfAbsent(e.tier, () => []).add(e);
    }
    return groups;
  }
}