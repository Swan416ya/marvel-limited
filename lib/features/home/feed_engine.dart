import 'dart:math';

import '../../data/models/marvel_event.dart';
import '../../data/models/marvel_models.dart';
import '../../data/models/series_summary.dart';
import '../../data/repository/preferences_repository.dart';

/// 瀑布流里的卡片类型。
enum FeedKind { continueReading, event, series, guide }

/// 首页瀑布流的一张卡。标题/副标题/封面在这里定好，页面只负责画。
class FeedCard {
  const FeedCard({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.coverUrl,
    this.progress,
    this.series,
    this.event,
    this.guide,
    this.issue,
    this.score = 0,
  });

  /// 去重用的稳定标识（同一条内容在两次刷新里 id 相同）。
  final String id;
  final FeedKind kind;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final ReadingProgress? progress;
  final SeriesSummary? series;
  final MarvelEvent? event;
  final ReadingGuide? guide;
  final ComicIssue? issue;

  /// 打分结果，仅用于调试/测试断言。
  final double score;

  /// 换分数用（字段一多，手抄必漏）。
  FeedCard withScore(double value) => FeedCard(
    id: id,
    kind: kind,
    title: title,
    subtitle: subtitle,
    coverUrl: coverUrl,
    progress: progress,
    series: series,
    event: event,
    guide: guide,
    issue: issue,
    score: value,
  );
}

/// 推荐用的用户信号：搜索记录、收藏、追更。
///
/// 都是小写化的英文关键词（中文原样），用来和候选标题做包含匹配——
/// 够用且好解释，不需要任何模型。
class FeedSignals {
  const FeedSignals({
    this.searchTerms = const [],
    this.favoriteTerms = const [],
    this.followTerms = const [],
  });

  final List<String> searchTerms;
  final List<String> favoriteTerms;
  final List<String> followTerms;

  bool get isEmpty =>
      searchTerms.isEmpty && favoriteTerms.isEmpty && followTerms.isEmpty;

  /// 匹配时忽略的英文虚词（出现在标题里也没信息量）。
  static const _stopWords = {
    'the',
    'and',
    'for',
    'with',
    'from',
    'vol',
    'comic',
    'comics',
  };

  /// 从一堆标题里抽出可匹配的关键词：去符号、去无意义的短词。
  static List<String> termsFrom(Iterable<String> titles) {
    final out = <String>{};
    for (final t in titles) {
      final cleaned = t
          .toLowerCase()
          .replaceAll(RegExp(r'[（(].*?[)）]'), ' ')
          .replaceAll(RegExp(r'[#·:：,，.。/\\|]'), ' ')
          .trim();
      if (cleaned.isEmpty) continue;
      out.add(cleaned);
      // 长标题再拆出实词，方便「Amazing Spider-Man」命中别的系列。
      // 只滤掉最没信息量的虚词，3 个字母的实词（war 之类）要留下。
      for (final w in cleaned.split(RegExp(r'\s+'))) {
        if (w.length >= 3 && !_stopWords.contains(w)) out.add(w);
      }
    }
    return out.toList();
  }
}

/// 首页瀑布流的推荐引擎。
///
/// 思路很简单，也刻意保持简单：候选池里每一条先有一个基础分（在读 >
/// 大事件 > 系列 > 指南），再按「和你搜索过/收藏过/在追的东西沾边」
/// 加分，最后叠一点随机抖动——所以**每次打开首页顺序都不一样**，
/// 但也不会离谱到全是无关内容。
///
/// [nextBatch] 按批产出卡片；内部记着这一轮已经给过谁，整个池子给完
/// 之前不会重复（给完了自动开新一轮，于是可以无限往下翻）。
class FeedEngine {
  FeedEngine({Random? random, this.batchSize = 12})
    : _random = random ?? Random(DateTime.now().microsecondsSinceEpoch);

  final Random _random;
  final int batchSize;

  /// 本轮已经发过的 id。
  final Set<String> _served = {};

  /// 打乱后的候选顺序（每轮重排一次，让批次之间也有变化）。
  List<FeedCard> _queue = const [];

  /// 候选池是否为空。
  bool get isEmpty => _queue.isEmpty && _pool.isEmpty;

  List<FeedCard> _pool = const [];

  /// 用新的候选池和信号重置（下拉刷新、数据到达后调用）。
  void reset({required List<FeedCard> pool, required FeedSignals signals}) {
    _pool = _score(pool, signals);
    _served.clear();
    _reshuffle();
  }

  /// 追加候选（数据分批到达时用，例如网络数据晚于本地事件到）。
  void addAll(List<FeedCard> more, FeedSignals signals) {
    if (more.isEmpty) return;
    _pool = _score([..._pool, ...more], signals);
    _reshuffle();
  }

  /// 取下一批。池子给完会自动开新一轮，所以可以一直取下去。
  List<FeedCard> nextBatch([int? size]) {
    final n = size ?? batchSize;
    if (_pool.isEmpty) return const [];
    final out = <FeedCard>[];
    var guard = 0;
    while (out.length < n && guard < _pool.length * 2) {
      guard++;
      final rest = _queue.where((c) => !_served.contains(c.id)).toList();
      if (rest.isEmpty) {
        // 一轮走完：清空已发记录、重排，继续下一轮
        _served.clear();
        _reshuffle();
        if (_queue.isEmpty) break;
        continue;
      }
      final pick = rest.first;
      _served.add(pick.id);
      out.add(pick);
    }
    return out;
  }

  void _reshuffle() {
    final list = [..._pool];
    // 打乱时保留一点「高分更靠前」的倾向：先按分数分档，再档内打乱，
    // 最后整体做一次轻微抖动，避免每轮顺序完全一致。
    list.sort((a, b) => b.score.compareTo(a.score));
    final jittered = <FeedCard>[];
    var i = 0;
    while (i < list.length) {
      final tier = (list[i].score * 2).floor();
      final bucket = <FeedCard>[];
      while (i < list.length && (list[i].score * 2).floor() == tier) {
        bucket.add(list[i]);
        i++;
      }
      bucket.shuffle(_random);
      jittered.addAll(bucket);
    }
    // 档与档之间再小概率交换，制造「偶尔冒出个冷门」的手感
    for (var k = 0; k + 1 < jittered.length; k++) {
      // 「在读」那几张钉在最前面，不参与跨档交换
      if (jittered[k].kind == FeedKind.continueReading) continue;
      if (_random.nextDouble() < 0.32) {
        final swapWith =
            k + 1 + _random.nextInt(min(6, jittered.length - k - 1));
        if (jittered[swapWith].kind == FeedKind.continueReading) continue;
        final tmp = jittered[k];
        jittered[k] = jittered[swapWith];
        jittered[swapWith] = tmp;
      }
    }
    _queue = jittered;
  }

  /// 打分：基础分 + 关键词命中 + 随机抖动。
  List<FeedCard> _score(List<FeedCard> pool, FeedSignals signals) {
    final seen = <String>{};
    final out = <FeedCard>[];
    for (final c in pool) {
      if (!seen.add(c.id)) continue;
      final haystack = c.title.toLowerCase();
      // 基础分只差一点点，主要靠「用户信号 + 抖动」决定顺序。
      // 事件/指南的底分刻意压低（它们本来数量最多、又是横图），
      // 不然首页前几屏全是横版大卡，看着太整齐。
      var score = switch (c.kind) {
        FeedKind.continueReading => 8.0, // 在读的永远最前
        FeedKind.series => 1.6,
        FeedKind.event => 1.1,
        FeedKind.guide => 1.0,
      };
      if (c.progress != null) score += 1.0;
      score += _hits(haystack, signals.followTerms) * 3.0;
      score += _hits(haystack, signals.favoriteTerms) * 2.0;
      score += _hits(haystack, signals.searchTerms) * 1.5;
      // 抖动 ±1.4：和基础分同量级，让横图/竖图交错出现，
      // 两列高度自然就不齐——要的就是这种不整齐
      score += _random.nextDouble() * 1.4;
      out.add(c.withScore(score));
    }
    return out;
  }

  double _hits(String haystack, List<String> terms) {
    if (terms.isEmpty || haystack.isEmpty) return 0;
    var hits = 0.0;
    for (final t in terms) {
      if (t.length < 3) continue;
      if (haystack.contains(t) || t.contains(haystack)) {
        hits += 1;
        // 命中多个词衰减，避免「蜘蛛侠」这种大词把榜单全占了
        if (hits >= 3) break;
      }
    }
    return hits;
  }
}

/// 把数据源转成候选卡片的小工具（页面调用，逻辑留在这里便于单测）。
class FeedPool {
  const FeedPool._();

  static FeedCard fromEvent(MarvelEvent e, String? coverUrl) => FeedCard(
    id: 'event:${e.id}',
    kind: FeedKind.event,
    title: e.title,
    subtitle: '${e.tierLabel} · ${e.year}',
    coverUrl: coverUrl,
    event: e,
  );

  static FeedCard fromSeries(SeriesSummary s) => FeedCard(
    id: 'series:${s.seriesId ?? s.title}',
    kind: FeedKind.series,
    title: s.title,
    subtitle: s.latestIssue != null ? '最新 #${s.latestIssue}' : '系列',
    coverUrl: s.coverUrl,
    series: s,
  );

  static FeedCard fromGuide(ReadingGuide g) => FeedCard(
    id: 'guide:${g.id}',
    kind: FeedKind.guide,
    title: g.title,
    subtitle: '官方阅读指南',
    coverUrl: g.coverUrl,
    guide: g,
  );

  static FeedCard fromProgress(ReadingProgress p) => FeedCard(
    id: 'issue:${p.issue.id}',
    kind: FeedKind.continueReading,
    title: p.issue.title,
    subtitle: '第 ${p.page + 1} / ${p.totalPages} 页',
    coverUrl: p.issue.coverUrl,
    progress: p,
    issue: p.issue,
  );
}
