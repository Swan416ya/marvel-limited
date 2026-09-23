import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/comic_cover.dart';
import '../../core/widgets/cover_grid.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/tab_app_bar.dart';
import '../../data/models/marvel_models.dart';
import '../../data/models/series_summary.dart';
import '../../data/repository/preferences_repository.dart';
import '../../data/repository/wiki_repository.dart';
import '../../state/catalog_state.dart';
import '../../state/favorites_state.dart';
import '../../state/follows_state.dart';
import '../../state/library_state.dart';
import '../../data/repository/catalog_repository.dart';

/// 系列页。两种数据来源：
/// - 官网（bifrost）：系列 ID，顶部用 #1 封面 + 简介，可一键 wiki 补全；
/// - wiki（fandom）：只有页面名，直接整系列拉下来。
/// 主体是 issue 封面网格，本地已导入 / wiki 补全 / 在读进度都有角标区分。
/// 右上角可以收藏系列、追更系列。
class SeriesPage extends StatefulWidget {
  const SeriesPage({
    super.key,
    required this.seriesId,
    required this.seriesTitle,
  }) : fandomName = null;

  const SeriesPage.fandom({super.key, required this.fandomName})
    : seriesId = null,
      seriesTitle = '';

  final String? seriesId;
  final String? fandomName;
  final String seriesTitle;

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage> {
  List<ComicIssue>? _issues;
  List<ComicIssue> _supplement = const [];
  SeriesDetail? _detail;
  String? _error;
  bool _loading = true;
  bool _descExpanded = false;

  /// wiki 补全进度。为空表示没在补。
  ({int done, int total})? _wikiProgress;

  bool get _isFandom => widget.seriesId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _supplement = const [];
    });
    try {
      final futures = <Future<void>>[
        () async {
          final List<ComicIssue> issues;
          if (_isFandom) {
            issues = await context.read<WikiRepository>().seriesIssues(
              widget.fandomName!,
              onProgress: _updateProgress,
            );
          } else {
            issues = await context.read<CatalogState>().seriesIssues(
              widget.seriesId!,
            );
          }
          if (!mounted) return;
          setState(() => _issues = issues);
        }(),
      ];
      // 官网系列顺带拉详情（描述、年份）
      if (!_isFandom) {
        futures.add(() async {
          final detail = await context.read<CatalogRepository>().seriesDetail(
            widget.seriesId!,
          );
          if (!mounted) return;
          if (detail != null) setState(() => _detail = detail);
        }());
      }
      await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _wikiProgress = null;
      });
    } catch (e) {
      debugPrint('[SeriesPage] 加载失败: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _wikiProgress = null;
        _error = e.toString();
      });
    }
  }

  void _updateProgress(int done, int total) {
    if (!mounted) return;
    setState(() => _wikiProgress = (done: done, total: total));
  }

  /// 用 wiki 补齐官网目录里缺的期数（下架或未数字化）。
  Future<void> _fetchSupplement() async {
    final issues = _issues;
    if (issues == null || issues.isEmpty || _wikiProgress != null) return;

    setState(() => _wikiProgress = (done: 0, total: 0));
    try {
      final found = await context.read<WikiRepository>().supplementMissing(
        issues,
        seriesTitle: _title,
        onProgress: _updateProgress,
      );
      if (!mounted) return;
      setState(() {
        _supplement = found;
        _wikiProgress = null;
      });
      if (found.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('wiki 上没有找到缺失的期数')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _wikiProgress = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('补全失败：$e')));
    }
  }

  String get _title {
    if (widget.seriesTitle.isNotEmpty) return widget.seriesTitle;
    if (_detail != null) return _detail!.title;
    final issues = _issues;
    if (issues != null && issues.isNotEmpty) return issues.first.seriesTitle;
    return widget.fandomName ?? '系列';
  }

  /// 系列封面：优先用 #1 的封面（用户指定），其次官方系列图。
  String? get _coverUrl {
    final issues = _issues;
    if (issues != null && issues.isNotEmpty) {
      // issues 已按期号升序排，first 就是 #1
      final first = issues.firstWhere(
        (i) => i.issueNumber == '1',
        orElse: () => issues.first,
      );
      if (first.coverUrl != null) return first.coverUrl;
    }
    return _detail?.coverUrl;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final library = context.watch<LibraryState>();
    final canSupplement = !_isFandom && !_loading && _error == null;
    final detail = _detail;
    final seriesKey = widget.seriesId ?? widget.fandomName ?? '';
    final isFav = context.watch<FavoritesState>().isFavorite(
      FavoriteKind.series,
      seriesKey,
    );
    final isFollowing = context.watch<FollowsState>().isFollowing(seriesKey);

    final issues = [...?_issues, ..._supplement];

    return Scaffold(
      appBar: TabAppBar(word: 'SERIES'),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? AsyncView(
              isLoading: false,
              error: _error,
              isEmpty: false,
              onRetry: _load,
              errorMessage: '系列加载失败',
              builder: (context) => const SizedBox.shrink(),
            )
          : CustomScrollView(
              slivers: [
                // 右上角动作放进 app bar 区（收藏/追更/补全）
                _actionsBar(p, isFav, isFollowing, canSupplement, library),
                // 头部：#1 封面 + 名字 + 简介 + 年份
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 110,
                          height: 165,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: p.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: _coverUrl == null
                                ? ColoredBox(
                                    color: p.fill,
                                    child: Icon(
                                      Icons.auto_stories,
                                      size: 36,
                                      color: p.iconOnCover,
                                    ),
                                  )
                                : ComicCover(url: _coverUrl),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _title,
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                              ),
                              if (detail != null &&
                                  (detail.startYear != null ||
                                      detail.comicsCount > 0)) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  [
                                    if (detail.startYear != null)
                                      '${detail.startYear}'
                                          '${detail.endYear != null ? ' - ${detail.endYear}' : ' - 至今'}',
                                    if (detail.comicsCount > 0)
                                      '${detail.comicsCount} 本',
                                    '${issues.length} 期',
                                  ].join(' · '),
                                  style: TextStyle(
                                    color: p.textFaint,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (detail != null &&
                                  detail.description.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _descExpanded = !_descExpanded,
                                  ),
                                  child: Text(
                                    detail.description,
                                    maxLines: _descExpanded ? null : 4,
                                    overflow: _descExpanded
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: p.textMuted,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_wikiProgress != null && _wikiProgress!.total > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '正在从 wiki 补全 '
                            '${_wikiProgress!.done}/${_wikiProgress!.total}'
                            '（结果会缓存，下次秒开）',
                            style: TextStyle(color: p.textFaint, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                // issue 封面网格
                if (issues.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.library_books_outlined,
                      title: '该系列暂无数据',
                      subtitle: '官网可能已下架，试试右上角从 wiki 补全',
                    ),
                  )
                else
                  CoverGrid(
                    maxCellWidth: 140,
                    itemCount: issues.length,
                    textBlockHeight: 18, // 只有期号一行
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.navBarClearance,
                    ),
                    itemBuilder: (context, i) => _IssueTile(
                      issue: issues[i],
                      imported: library.isImported(issues[i].id),
                      progress: library.progressFor(issues[i].id),
                    ),
                  ),
              ],
            ),
    );
  }

  /// app bar 下的一条动作栏（收藏 / 追更 / wiki 补全）。
  Widget _actionsBar(
    AppPalette p,
    bool isFav,
    bool isFollowing,
    bool canSupplement,
    LibraryState library,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            _ActionButton(
              icon: isFollowing ? Icons.push_pin : Icons.push_pin_outlined,
              label: isFollowing ? '追更中' : '追更',
              highlight: isFollowing,
              onTap: () => _toggleFollow(isFollowing),
            ),
            const SizedBox(width: AppSpacing.sm),
            _ActionButton(
              icon: isFav ? Icons.favorite : Icons.favorite_border,
              label: isFav ? '已收藏' : '收藏',
              highlight: isFav,
              onTap: () => _toggleFavorite(isFav),
            ),
            const Spacer(),
            if (canSupplement && _wikiProgress == null && _supplement.isEmpty)
              _ActionButton(
                icon: Icons.auto_fix_high,
                label: 'wiki 补全',
                highlight: false,
                onTap: _fetchSupplement,
              ),
            if (_wikiProgress != null && _wikiProgress!.total == 0)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleFavorite(bool isFav) {
    final favorites = context.read<FavoritesState>();
    final now = favorites.toggle(
      FavoriteEntry.fromSeries(
        widget.seriesId ?? widget.fandomName ?? '',
        _detail?.title ?? _title,
        coverUrl: _coverUrl,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(now ? '已收藏系列《$_title》' : '已取消收藏《$_title》'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _toggleFollow(bool isFollowing) {
    final follows = context.read<FollowsState>();
    final now = follows.toggle(
      FollowedSeries(
        seriesId: widget.seriesId ?? widget.fandomName ?? '',
        title: _detail?.title ?? _title,
        coverUrl: _coverUrl,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(now ? '已追更《$_title》' : '已取消追更《$_title》'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }
}

/// 动作栏的小按钮。
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.highlight,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: highlight ? p.brand.withValues(alpha: 0.15) : p.fill,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: highlight ? p.brand.withValues(alpha: 0.5) : p.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: highlight ? p.brand : p.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: highlight ? p.brand : p.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// issue 封面格：封面 + 期号，角标区分本地导入 / wiki 补全 / 在读进度。
class _IssueTile extends StatelessWidget {
  const _IssueTile({
    required this.issue,
    required this.imported,
    this.progress,
  });

  final ComicIssue issue;
  final bool imported;
  final ReadingProgress? progress;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final isWiki = issue.id.startsWith('fandom:');
    return InkWell(
      onTap: () => AppRouter.openIssue(context, issue),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 本地已导入的加一圈绿描边，一眼区分
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: imported
                        ? Border.all(color: p.success, width: 1.5)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: ComicCover(
                      url: issue.coverUrl,
                      placeholderIcon: Icons.menu_book,
                    ),
                  ),
                ),
                // 左上角标：wiki 补全 / 在读页码
                Positioned(
                  left: 4,
                  top: 4,
                  child: isWiki
                      ? CoverBadge(label: 'Wiki')
                      : (progress != null && progress!.page > 0)
                      ? CoverBadge(
                          label: progress!.isFinished
                              ? '已读完'
                              : 'P${progress!.page + 1}',
                        )
                      : const SizedBox.shrink(),
                ),
                // 右上角：本地导入打勾
                if (imported)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: p.success,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 11,
                        color: const Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            issue.issueNumber.isEmpty ? issue.title : '#${issue.issueNumber}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: imported ? p.success : p.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
