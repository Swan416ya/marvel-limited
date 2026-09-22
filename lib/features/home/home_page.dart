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
import '../../state/library_state.dart';
import '../../state/theme_state.dart';

/// 综合首页（中间大按钮进来的地方）：瀑布流混排。
///
/// 从每个页面各取一点：继续阅读（在读的期）、大事件、最近更新的系列、
/// 官方指南，交错排进两列瀑布流——像杂志内页而不是分区货架。
/// 纯粹的浏览页在各自 tab。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// 瀑布流里的卡片类型。
enum _FeedKind { continueReading, event, series, guide }

class _FeedCard {
  const _FeedCard({
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.coverUrl,
    this.progress,
    this.series,
    this.event,
    this.guide,
    this.issue,
  });

  final _FeedKind kind;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final ReadingProgress? progress;
  final SeriesSummary? series;
  final MarvelEvent? event;
  final ReadingGuide? guide;
  final ComicIssue? issue;
}

class _HomePageState extends State<HomePage> {
  List<MarvelEvent>? _topEvents;
  List<SeriesSummary>? _latestSeries;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LibraryState>().init();
      context.read<CatalogState>().loadGuides();
      _loadFeed();
    });
  }

  Future<void> _loadFeed() async {
    try {
      final results = await Future.wait([
        context
            .read<EventsRepository>()
            .all()
            .then((all) => all.where((e) => e.isCompanyWide).take(5).toList()),
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
        _topEvents = results[0] as List<MarvelEvent>;
        _latestSeries = results[1] as List<SeriesSummary>?;
      });
    } catch (_) {
      // 单路失败不影响已有内容
    }
  }

  /// 组装瀑布流卡片：四路内容交错。
  List<_FeedCard> _buildFeed(
    List<ReadingProgress> continues,
    List<SeriesSummary> latestSeries,
    List<ReadingGuide> guides,
  ) {
    final events = _topEvents ?? const [];
    final feed = <_FeedCard>[];

    // 在读的期
    for (final p in continues.take(4)) {
      feed.add(_FeedCard(
        kind: _FeedKind.continueReading,
        title: p.issue.title,
        subtitle: '第 ${p.page + 1} / ${p.totalPages} 页',
        coverUrl: p.issue.coverUrl,
        progress: p,
        issue: p.issue,
      ));
    }
    // 大事件 / 系列 / 指南交错
    final seriesIter = latestSeries.take(10).iterator;
    final guideIter = guides.take(8).iterator;
    var eventIdx = 0;
    while (seriesIter.moveNext() ||
        guideIter.moveNext() ||
        eventIdx < events.length) {
      if (eventIdx < events.length) {
        final e = events[eventIdx++];
        feed.add(_FeedCard(
          kind: _FeedKind.event,
          title: e.titleZh.isEmpty ? e.title : e.titleZh,
          subtitle: '${e.tierLabel} · ${e.year}',
          coverUrl: null, // 事件封面在卡片里用渐变兜底
          event: e,
        ));
      }
      if (seriesIter.moveNext()) {
        final s = seriesIter.current;
        feed.add(_FeedCard(
          kind: _FeedKind.series,
          title: s.title,
          subtitle: s.latestIssue != null ? '最新 #${s.latestIssue}' : '系列',
          coverUrl: s.coverUrl,
          series: s,
        ));
      }
      if (guideIter.moveNext()) {
        final g = guideIter.current;
        feed.add(_FeedCard(
          kind: _FeedKind.guide,
          title: g.title,
          subtitle: '官方阅读指南',
          coverUrl: g.coverUrl,
          guide: g,
        ));
      }
    }
    return feed;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogState>();
    final continues = context.watch<LibraryState>().continueReading;
    final guides = catalog.guides ?? const <ReadingGuide>[];
    final latestSeries = _latestSeries ?? const <SeriesSummary>[];

    final feed = _buildFeed(continues, latestSeries, guides);
    // 按奇偶分两列
    final left = <_FeedCard>[];
    final right = <_FeedCard>[];
    for (var i = 0; i < feed.length; i++) {
      (i.isEven ? left : right).add(feed[i]);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<CatalogState>().refresh();
          await _loadFeed();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _brandBar(context),
            if (feed.isEmpty)
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

  final _FeedCard card;

  void _open(BuildContext context) {
    switch (card.kind) {
      case _FeedKind.continueReading:
        final issue = card.issue;
        if (issue != null) AppRouter.openReader(context, issue);
      case _FeedKind.event:
        final event = card.event;
        if (event != null) AppRouter.openEvent(context, event);
      case _FeedKind.series:
        final s = card.series;
        if (s?.seriesId != null) {
          AppRouter.openSeries(context, s!.seriesId!, s.title);
        }
      case _FeedKind.guide:
        final g = card.guide;
        if (g != null) AppRouter.openGuide(context, g);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final isPortrait =
        card.kind == _FeedKind.continueReading || card.kind == _FeedKind.series;
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
                  if (card.kind == _FeedKind.event)
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
      _FeedKind.continueReading => '在读',
      _FeedKind.event => '事件',
      _FeedKind.series => '系列',
      _FeedKind.guide => '指南',
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