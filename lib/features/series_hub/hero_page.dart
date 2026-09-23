import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/comic_cover.dart';
import '../../core/widgets/cover_grid.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/tab_app_bar.dart';
import '../../data/models/series_summary.dart';
import '../../data/repository/catalog_repository.dart';
import '../../data/repository/preferences_repository.dart';
import '../../state/follows_state.dart';
import '../series_hub/heroes.dart';

/// 英雄专属页：顶部大头像 + 一句话介绍，下面是这个英雄的系列瀑布流。
///
/// 「系列」tab 顶部的英雄头像点进来就是这里。
class HeroPage extends StatefulWidget {
  const HeroPage({super.key, required this.heroId});

  final String heroId;

  @override
  State<HeroPage> createState() => _HeroPageState();
}

class _HeroPageState extends State<HeroPage> {
  HeroEntry get _hero => heroById(widget.heroId) ??
      HeroEntry(widget.heroId, '英雄', '', '');

  ({String id, String name, String? image})? _detail;
  List<SeriesSummary>? _series;
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
        repo.characterDetail(_hero.id),
        repo
            .characterSeries(_hero.id)
            .timeout(const Duration(seconds: 60)),
      ]);
      if (!mounted) return;
      setState(() {
        _detail = results[0] as ({String id, String name, String? image});
        _series = results[1] as List<SeriesSummary>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[HeroPage] 加载失败: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Scaffold(
      appBar: TabAppBar(word: _hero.nameEn.isEmpty ? 'SERIES' : _hero.nameEn.toUpperCase()),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? AsyncView(
                  isLoading: false,
                  error: _error,
                  isEmpty: false,
                  onRetry: _load,
                  errorMessage: '英雄数据加载失败',
                  builder: (context) => const SizedBox.shrink(),
                )
              : CustomScrollView(
                  slivers: [
                    // 头部：大头像 + 名字 + 介绍
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.lg,
                          AppSpacing.xl,
                          0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                                border: Border.all(color: p.border),
                              ),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                                child: ComicCover(
                                  url: _detail?.image,
                                  fit: BoxFit.cover,
                                  placeholderIcon: Icons.person,
                                  retryOnTap: false,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _hero.nameZh,
                                    style: TextStyle(
                                      color: p.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  if (_hero.nameEn.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _hero.nameEn,
                                      style: TextStyle(
                                        color: p.textMuted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    _hero.intro,
                                    style: TextStyle(
                                      color: p.textMuted,
                                      fontSize: 13,
                                      height: 1.55,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '${_series?.length ?? 0} 个系列',
                                    style: TextStyle(
                                      color: p.brand,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.lg),
                    ),
                    // 系列网格
                    if (_series == null || _series!.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptySeries(),
                      )
                    else
                      CoverGrid(
                        itemCount: _series!.length,
                        textBlockHeight: 32, // 只有标题（两行），没有副标题
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.navBarClearance,
                        ),
                        itemBuilder: (context, i) => _HeroSeriesTile(
                          series: _series![i],
                        ),
                      ),                  ],
                ),
    );
  }
}

class _EmptySeries extends StatelessWidget {
  const _EmptySeries();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '这个英雄暂时没有系列数据',
        style: TextStyle(color: context.p.textFaint, fontSize: 13),
      ),
    );
  }
}

/// 英雄页的系列小卡：竖版封面 + 标题。
class _HeroSeriesTile extends StatelessWidget {
  const _HeroSeriesTile({required this.series});

  final SeriesSummary series;

  void _open(BuildContext context) {
    if (series.seriesId != null) {
      AppRouter.openSeries(context, series.seriesId!, series.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final following = context
        .watch<FollowsState>()
        .isFollowing(series.seriesId ?? series.title);
    return InkWell(
      onTap: () => _open(context),
      onLongPress: () => _toggleFollow(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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