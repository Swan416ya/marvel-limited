import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/comic_cover.dart';
import '../../core/widgets/shelf_list.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/tab_app_bar.dart';
import '../../data/models/series_summary.dart';
import '../../data/repository/catalog_repository.dart';
import '../../data/repository/preferences_repository.dart';
import '../../state/follows_state.dart';
import 'heroes.dart';

/// 系列 tab。
///
/// 版式：顶部一行可横滑的英雄头像（官网角色头像，点进英雄专属页），
/// 下面默认显示全部「最近更新的系列」——3 列小卡，一屏约 9 个。
/// 「编辑精选」官方书架固定在追更之下。
class SeriesHubPage extends StatefulWidget {
  const SeriesHubPage({super.key});

  @override
  State<SeriesHubPage> createState() => _SeriesHubPageState();
}

class _SeriesHubPageState extends State<SeriesHubPage> {
  List<SeriesSummary>? _latest;
  List<SeriesSummary>? _featured;

  /// 英雄头像（角色详情接口），按 heroes 清单顺序。
  final Map<String, ({String id, String name, String? image})> _avatars = {};

  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<CatalogRepository>();
      final results = await Future.wait([
        repo
            .latestIssues(limit: 100)
            .timeout(const Duration(seconds: 60))
            .then(CatalogRepository.distinctSeries),
        repo.featuredSeries().timeout(const Duration(seconds: 60)),
      ]);
      if (!mounted) return;
      setState(() {
        _latest = results[0];
        _featured = results[1];
        _loading = false;
      });
      // 头像不阻塞首屏，慢慢补
      _loadAvatars();
    } catch (e) {
      debugPrint('[SeriesHub] 加载失败: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// 头像不阻塞首屏，慢慢补——限并发 4 拉取（原来是串行，
  /// 12 个头像要等 12 轮往返）。
  Future<void> _loadAvatars() async {
    final repo = context.read<CatalogRepository>();
    final todo = heroes.where((h) => !_avatars.containsKey(h.id)).toList();
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= todo.length) return;
        try {
          final d = await repo.characterDetail(todo[i].id);
          if (!mounted) return;
          setState(() => _avatars[todo[i].id] = d);
        } catch (_) {
          // 单个头像失败不碍事，用兜底图标
        }
      }
    }

    await Future.wait(
      List.generate(todo.length.clamp(1, 4), (_) => worker()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final follows = context.watch<FollowsState>().series;
    final latest = _latest ?? const <SeriesSummary>[];

    return Scaffold(
      appBar: const TabAppBar(word: 'SERIES'),
      body: _loading
          ? const LoadingView(label: '正在拉最近更新的系列')
          : _error != null
              ? ErrorView(
                  message: '系列加载失败',
                  detail: _error,
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // 英雄头像行
                      SliverToBoxAdapter(
                        child: _HeroAvatarRow(
                          avatars: _avatars,
                          onTap: (hero) => context.pushNamed(
                            RouteNames.hero,
                            pathParameters: {'id': hero.id},
                          ),
                        ),
                      ),
                      if (follows.isNotEmpty) ...[
                        const SliverToBoxAdapter(child: _SectionLabel('我的追更')),
                        SliverToBoxAdapter(
                          child: ShelfList(
                            height: 186,
                            itemCount: follows.length,
                            itemWidth: 118,
                            itemBuilder: (context, i) => _SeriesCard(
                              series: SeriesSummary(
                                title: follows[i].title,
                                seriesId: follows[i].seriesId,
                                coverUrl: follows[i].coverUrl,
                              ),
                              onTap: () => AppRouter.openSeries(
                                context,
                                follows[i].seriesId,
                                follows[i].title,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_featured != null && _featured!.isNotEmpty) ...[
                        const SliverToBoxAdapter(child: _SectionLabel('编辑精选')),
                        SliverToBoxAdapter(
                          child: ShelfList(
                            height: 196,
                            itemCount: _featured!.length,
                            itemWidth: 220,
                            itemBuilder: (context, i) => _WideSeriesCard(
                              series: _featured![i],
                              onTap: () => AppRouter.openSeries(
                                context,
                                _featured![i].seriesId!,
                                _featured![i].title,
                              ),
                            ),
                          ),
                        ),
                      ],
                      SliverToBoxAdapter(child: _SectionLabel('最近更新 · ${latest.length} 个系列')),
                      if (latest.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyView(
                            icon: Icons.auto_stories_outlined,
                            title: '最近没有已上架的新刊',
                            subtitle: '下拉刷新试试',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.navBarClearance,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.52,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.md,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _SeriesCard(series: latest[i]),
                              childCount: latest.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: context.p.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 顶部英雄头像行：横滑，官网角色头像。
class _HeroAvatarRow extends StatelessWidget {
  const _HeroAvatarRow({required this.avatars, required this.onTap});

  final Map<String, ({String id, String name, String? image})> avatars;
  final void Function(HeroEntry) onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: heroes.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final hero = heroes[i];
          final avatar = avatars[hero.id]?.image;
          return InkWell(
            onTap: () => onTap(hero),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: SizedBox(
              width: 68,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: p.border),
                      color: p.fill,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: avatar == null
                          ? Icon(Icons.person, color: p.textGhost, size: 28)
                          : ComicCover(
                              url: avatar,
                              fit: BoxFit.cover,
                              retryOnTap: false,
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    hero.nameZh,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 编辑精选用的横版卡。
class _WideSeriesCard extends StatelessWidget {
  const _WideSeriesCard({required this.series, required this.onTap});

  final SeriesSummary series;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        width: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 220 / (16 / 9),
              child: ComicCover(
                url: series.coverUrl,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                placeholderIcon: Icons.auto_stories,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              series.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3 列网格里的系列小卡：竖版封面 + 标题 + 最新期。
class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.series, this.onTap});

  final SeriesSummary series;
  final VoidCallback? onTap;

  void _defaultOpen(BuildContext context) {
    final id = series.seriesId;
    if (id != null) {
      AppRouter.openSeries(context, id, series.title);
    } else if (series.wikiPageName != null) {
      AppRouter.openWikiSeries(context, series.wikiPageName!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final following = context
        .watch<FollowsState>()
        .isFollowing(series.seriesId ?? series.title);
    return InkWell(
      onTap: onTap ?? () => _defaultOpen(context),
      onLongPress: () => _toggleFollow(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ComicCover(
                  url: series.coverUrl,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  placeholderIcon: Icons.auto_stories,
                ),
                if (following)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Icon(Icons.push_pin, size: 13, color: p.brand),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            series.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 11.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (series.latestIssue != null) ...[
            const SizedBox(height: 1),
            Text(
              '最新 #${series.latestIssue}',
              style: TextStyle(color: p.brand, fontSize: 10.5),
            ),
          ] else if (series.issueCount > 0) ...[
            const SizedBox(height: 1),
            Text(
              '${series.issueCount} 本',
              style: TextStyle(color: p.brand, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleFollow(BuildContext context) {
    final follows = context.read<FollowsState>();
    final now = follows.toggle(
      FollowedSeries(
        seriesId: series.seriesId ?? series.title,
        title: series.title,
        coverUrl: series.coverUrl,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(now ? '已追更《${series.title}》' : '已取消追更《${series.title}》'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }
}