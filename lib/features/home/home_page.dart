import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/brand_fade.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/comic_cover.dart';
import '../../data/models/marvel_event.dart';
import '../../data/models/marvel_models.dart';
import '../../data/models/series_summary.dart';
import '../../data/repository/catalog_repository.dart';
import '../../data/repository/events_repository.dart';
import '../../data/repository/preferences_repository.dart';
import '../../state/catalog_state.dart';
import '../../state/favorites_state.dart';
import '../../state/follows_state.dart';
import '../../state/library_state.dart';
import '../../state/theme_state.dart';
import 'feed_engine.dart';

/// 综合首页（默认 tab）：瀑布流混排 + 无限下滑。
///
/// 从每个页面各取一点：继续阅读（在读的期）、大事件、最近更新的系列、
/// 官方指南，由 [FeedEngine] 打分后交错排进两列瀑布流——像杂志内页
/// 而不是分区货架。打分依据是搜索记录 / 收藏 / 追更，再叠随机抖动，
/// 所以**每次打开顺序都不一样**，但也不至于全是无关内容。
///
/// 纯粹的浏览页在各自 tab。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _engine = FeedEngine();
  final _scroll = ScrollController();
  final _cards = <FeedCard>[];

  /// 数据源（本地事件 + 网络系列），两路都到齐了才建池子。
  List<MarvelEvent>? _events;
  List<SeriesSummary>? _series;

  /// 上一次见到的那几路数据，用来判断「变了没有」。
  List<ReadingGuide> _guides = const [];
  List<ReadingProgress> _continues = const [];

  /// 正在重建池子中（避免同一帧里被触发多次）。
  bool _rebuilding = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LibraryState>().init();
      context.read<CatalogState>().loadGuides();
      _loadFeed();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// 快到底就再要一批。池子给完了引擎会自动开新一轮，所以能一直往下翻。
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels < 900) _appendBatch();
  }

  void _appendBatch() {
    final batch = _engine.nextBatch();
    if (batch.isEmpty || !mounted) return;
    setState(() => _cards.addAll(batch));
  }

  Future<void> _loadFeed() async {
    try {
      final results = await Future.wait([
        context.read<EventsRepository>().all(),
        () async {
          try {
            final issues = await context
                .read<CatalogRepository>()
                .latestIssues(limit: 60)
                .timeout(const Duration(seconds: 30));
            return CatalogRepository.distinctSeries(issues);
          } catch (_) {
            return const <SeriesSummary>[];
          }
        }(),
      ]);
      if (!mounted) return;
      setState(() {
        _events = results[0] as List<MarvelEvent>;
        _series = results[1] as List<SeriesSummary>?;
      });
      _rebuildPool();
    } catch (_) {
      // 单路失败不影响已有内容
    }
  }

  /// 重建候选池并铺满首屏。
  ///
  /// 数据是分批到的（本地事件先到、网络系列后到），但每次重建都会重排
  /// 一遍池子——所以只在池子明显变大时才动，避免用户正看着整页跳一下。
  void _rebuildPool({bool force = false}) {
    final pool = _poolCards();
    if (pool.isEmpty || _rebuilding) return;
    // 数据没变就别重排（用户正看着会跳）；下拉刷新走 force，
    // 这样点一下刷新就能换一批推荐。
    final grew = pool.length > _cards.length + _engine.batchSize;
    if (_cards.isNotEmpty && !grew && !force) return;
    _rebuilding = true;
    _engine.reset(pool: pool, signals: _signals());
    _cards.clear();
    // 首屏至少铺满两批，剩下的滚到底再拿
    for (var i = 0; i < 2; i++) {
      _appendBatch();
    }
    _rebuilding = false;
  }

  /// 候选池：在读 > 大事件 > 最近更新系列 > 官方指南。
  List<FeedCard> _poolCards() {
    final repo = context.read<EventsRepository>();
    return [
      for (final p in context.read<LibraryState>().continueReading.take(6))
        FeedPool.fromProgress(p),
      for (final e in _events ?? const <MarvelEvent>[])
        FeedPool.fromEvent(e, repo.coverUrlFor(e, _guides)),
      for (final s in (_series ?? const <SeriesSummary>[]).take(30))
        FeedPool.fromSeries(s),
      for (final g in _guides.take(90)) FeedPool.fromGuide(g),
    ];
  }

  /// 用户信号：搜索记录 + 收藏（含自建书单名）+ 追更。
  FeedSignals _signals() {
    final prefs = context.read<PreferencesRepository>();
    final favorites = context.read<FavoritesState>();
    return FeedSignals(
      searchTerms: FeedSignals.termsFrom(prefs.searchHistory),
      favoriteTerms: FeedSignals.termsFrom([
        for (final e in favorites.entries) e.title,
        for (final l in favorites.lists) l.name,
      ]),
      followTerms: FeedSignals.termsFrom(
        context.read<FollowsState>().series.map((f) => f.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 官方指南和在读列表是异步/可变的，变了就重建池子
    // （放在帧后，避免在 build 里直接 setState）。
    final guides = context.watch<CatalogState>().guides ?? const <ReadingGuide>[];
    final continues = context.watch<LibraryState>().continueReading;
    if (!identical(guides, _guides) || !identical(continues, _continues)) {
      _guides = guides;
      _continues = continues;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildPool();
      });
    }

    // 按奇偶分两列
    final left = <FeedCard>[];
    final right = <FeedCard>[];
    for (var i = 0; i < _cards.length; i++) {
      (i.isEven ? left : right).add(_cards[i]);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<CatalogState>().refresh();
          await _loadFeed();
          if (mounted) _rebuildPool(force: true);
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _brandBar(context),
            if (_cards.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('正在准备你的首页…', style: TextStyle(fontSize: 13)),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.navBarClearance,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            for (final c in left) _FeedCardView(card: c)
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          children: [
                            for (final c in right) _FeedCardView(card: c)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 顶部品牌栏：MARVEL LIMITED + 主题切换 + 搜索。
  Widget _brandBar(BuildContext context) {
    final theme = context.watch<ThemeState>();
    return SliverAppBar(
      pinned: true,
      titleSpacing: AppSpacing.xl,
      backgroundColor: context.p.background,
      flexibleSpace: const BrandFade(intensity: 0.22, stops: [0, 0.85]),
      title: const BrandLogo(height: 22, tail: 'LIMITED'),
      actions: [
        IconButton(
          icon: Icon(switch (theme.mode) {
            ThemeMode.light => Icons.light_mode_outlined,
            ThemeMode.dark => Icons.dark_mode_outlined,
            ThemeMode.system => Icons.brightness_6_outlined,
          }),
          tooltip: '切换深浅色',
          color: context.p.textMuted,
          onPressed: () => theme.cycle(),
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: '搜索',
          onPressed: () => AppRouter.openSearch(context),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

/// 瀑布流卡片：按类型决定比例与样式。
class _FeedCardView extends StatelessWidget {
  const _FeedCardView({required this.card});

  final FeedCard card;

  void _open(BuildContext context) {
    switch (card.kind) {
      case FeedKind.continueReading:
        final issue = card.issue;
        if (issue != null) AppRouter.openReader(context, issue);
      case FeedKind.event:
        final event = card.event;
        if (event != null) AppRouter.openEvent(context, event);
      case FeedKind.series:
        final s = card.series;
        if (s?.seriesId != null) {
          AppRouter.openSeries(context, s!.seriesId!, s.title);
        }
      case FeedKind.guide:
        final g = card.guide;
        if (g != null) AppRouter.openGuide(context, g);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final isPortrait =
        card.kind == FeedKind.continueReading || card.kind == FeedKind.series;
    // 竖版 2:3，事件/指南 16:10
    final aspect = isPortrait ? 2 / 3.0 : 16 / 10.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: aspect,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: card.coverUrl != null
                        ? ComicCover(url: card.coverUrl)
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  p.brand.withValues(alpha: 0.4),
                                  p.surface,
                                ],
                              ),
                            ),
                            child:
                                Icon(Icons.bolt, color: p.iconOnCover, size: 32),
                          ),
                  ),
                  // 事件卡压一层黑渐变放白字
                  if (card.kind == FeedKind.event)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0x33000000),
                            const Color(0xCC000000),
                          ],
                          stops: const [0.4, 1],
                        ),
                      ),
                    ),
                  // 在读进度条
                  if (card.progress != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(AppRadius.md),
                        ),
                        child: LinearProgressIndicator(
                          value: card.progress!.ratio,
                          minHeight: 3,
                          backgroundColor: p.badge,
                          valueColor: AlwaysStoppedAnimation(p.brand),
                        ),
                      ),
                    ),
                  // 类型标签
                  Positioned(
                    left: 6,
                    top: 6,
                    child: _kindBadge(p),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                card.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (card.subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  card.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textFaint, fontSize: 10.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kindBadge(AppPalette p) {
    final label = switch (card.kind) {
      FeedKind.continueReading => '在读',
      FeedKind.event => '事件',
      FeedKind.series => '系列',
      FeedKind.guide => '指南',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: p.badge,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
