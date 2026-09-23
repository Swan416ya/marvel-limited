import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/brand_fade.dart';
import '../../core/widgets/comic_cover.dart';
import '../../core/widgets/cover_grid.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/marvel_models.dart';
import '../../data/repository/preferences_repository.dart';
import '../../state/catalog_state.dart';
import '../../state/favorites_state.dart';

/// 指南详情：按官方推荐顺序列出全部 issue（带阅读顺序角标）。
///
/// 只吃 `guideId`：深链进来时指南列表可能还没加载，会先拉列表再按 id 找，
/// 找不到就是「指南不存在」而不是白屏。
class GuideDetailPage extends StatefulWidget {
  const GuideDetailPage({super.key, required this.guideId, this.initial});

  final String guideId;

  /// 从列表点进来时直接把对象带过来，省一次查找。
  final ReadingGuide? initial;

  @override
  State<GuideDetailPage> createState() => _GuideDetailPageState();
}

class _GuideDetailPageState extends State<GuideDetailPage> {
  ReadingGuide? _guide;
  List<ComicIssue>? _issues;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _guide = widget.initial;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    var guide = _guide;
    try {
      final catalog = context.read<CatalogState>();
      if (guide == null) {
        if (catalog.guides == null) await catalog.loadGuides();
        guide = _findGuide(catalog.guides ?? const [], widget.guideId);
      }
      if (guide == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '找不到这个阅读指南，可能已经下架';
        });
        return;
      }
      final issues = await catalog.guideIssues(guide.id);
      if (!mounted) return;
      setState(() {
        _guide = guide;
        _issues = issues;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  static ReadingGuide? _findGuide(List<ReadingGuide> guides, String id) {
    for (final g in guides) {
      if (g.id == id) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final guide = _guide;
    final issues = _issues;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 标题交给 FlexibleSpaceBar：展开时是大标题，收起时自动落到工具栏位置。
          // 注意别用 SliverAppBar.medium + flexibleSpace：那个组合会把 .medium
          // 内置的标题层顶掉，标题直接不显示（浏览器里实测过）。
          SliverAppBar(
            pinned: true,
            expandedHeight: 136,
            actions: [
              IconButton(
                icon: Icon(
                  context.watch<FavoritesState>()
                          .isFavorite(FavoriteKind.guide, widget.guideId)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: context.watch<FavoritesState>()
                          .isFavorite(FavoriteKind.guide, widget.guideId)
                      ? context.p.like
                      : null,
                ),
                tooltip: '收藏指南',
                onPressed: () {
                  final g = guide;
                  if (g == null) return;
                  final favorites = context.read<FavoritesState>();
                  final now = favorites.toggle(FavoriteEntry.fromGuide(g));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(now ? '已收藏这个指南' : '已取消收藏'),
                      duration: const Duration(milliseconds: 1200),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                end: 16,
                bottom: 14,
              ),
              title: Text(
                guide?.title ?? '阅读指南',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              background: const BrandFade(
                intensity: 0.25,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.6],
              ),
            ),
          ),
          if (guide != null && guide.description.isNotEmpty)
            SliverPadding(
              padding: AppInsets.detailNote,
              sliver: SliverToBoxAdapter(
                child: Text(
                  guide.description,
                  style: TextStyle(
                    color: context.p.textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          SliverAsyncView(
            isLoading: _loading,
            error: _error,
            isEmpty: !_loading && _error == null && (issues?.isEmpty ?? true),
            onRetry: _bootstrap,
            errorMessage: '加载失败',
            empty: const EmptyView(
              icon: Icons.menu_book,
              title: '这个指南下没有可读的期数',
            ),
            builder: (context) => SliverMainAxisGroup(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    AppSpacing.xs,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '${issues!.length} 期 · 官方阅读顺序',
                      style: TextStyle(
                        color: context.p.textFaint,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                CoverGrid(
                  itemCount: issues.length,
                  maxCellWidth: 110,
                  textBlockHeight: 34, // 期号 + 系列名两行
                  crossSpacing: 10,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.navBarClearance,
                  ),
                  itemBuilder: (context, i) => _GuideIssueCard(
                    issue: issues[i],
                    index: i,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 指南里的一期：封面 + 阅读顺序角标 + 标题。
class _GuideIssueCard extends StatelessWidget {
  const _GuideIssueCard({required this.issue, required this.index});

  final ComicIssue issue;
  final int index;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => AppRouter.openIssue(context, issue),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ComicCover(
                  url: issue.coverUrl,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  placeholderIcon: Icons.menu_book,
                ),
                Positioned(
                  left: AppSpacing.xs,
                  top: AppSpacing.xs,
                  child: CoverBadge(label: '${index + 1}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // 期号一行、系列名一行：如果直接把 title 塞进来，窄卡片里会被截成
          // "The Amazing Spider-Man (1999)…"，一整屏卡片看起来一模一样。
          Text(
            issue.issueNumber.isEmpty ? issue.title : '#${issue.issueNumber}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.p.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (issue.issueNumber.isNotEmpty && issue.seriesTitle.isNotEmpty)
            Text(
              issue.seriesTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.p.textGhost,
                fontSize: 10,
                height: 1.3,
              ),
            ),
        ],
      ),
    );
  }
}