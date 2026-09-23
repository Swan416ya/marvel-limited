import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/comic_cover.dart';
import '../../core/widgets/cover_grid.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models/marvel_event.dart';
import '../../data/models/marvel_models.dart';
import '../../data/repository/events_repository.dart';
import '../../state/catalog_state.dart';

/// 大事件详情：主视觉 + 一句话介绍 + 官方阅读指南。
///
/// 数据是打包进应用的静态集（见 `assets/data/marvel_events.json`），
/// 打开即看。重点：会自动去找官方的「XXX: The Complete Event」阅读指南
/// （官网 767 个指南里基本都有），找到就直接展示指南里逐期的官方顺序，
/// 每期可点进详情——不再跳搜索。找不到指南的事件退回静态顺序。
class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  MarvelEvent? _event;
  String? _error;

  /// 匹配到的官方指南。
  ReadingGuide? _guide;

  /// 指南的 issue 列表（官方顺序）。
  List<ComicIssue>? _guideIssues;
  bool _guideLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final event = await context.read<EventsRepository>().byId(widget.eventId);
    if (!mounted) return;
    setState(() {
      _event = event;
      if (event == null) _error = '找不到这个事件';
    });
    if (event != null) {
      _loadOfficialGuide(event);
    }
  }

  /// 找官方的 Complete Event 指南并拉它的 issue 列表。
  ///
  /// 同名事件很多（1984 和 2015 都叫 Secret Wars，Civil War 和
  /// Civil War II 也互相包含），光比标题必然张冠李戴。所以候选按标题
  /// 评分排好后，逐个拉它的期数、用**发行年份**验明正身，第一个年份
  /// 对得上的才采纳；全都不对上就退回本地静态顺序，宁可不显示也不能
  /// 显示错的。
  Future<void> _loadOfficialGuide(MarvelEvent event) async {
    setState(() => _guideLoading = true);
    try {
      final catalog = context.read<CatalogState>();
      if (catalog.guides == null) await catalog.loadGuides();
      if (!mounted) return;
      final candidates = _candidates(catalog.guides ?? const [], event);
      for (final guide in candidates) {
        final issues = await catalog.guideIssues(guide.id);
        if (!mounted) return;
        if (issues.isEmpty) continue;
        if (!_yearFits(issues, event.year)) {
          debugPrint('[EventDetail] 跳过年份不符的指南：'
              '${guide.title}（事件 ${event.year}）');
          continue;
        }
        setState(() {
          _guide = guide;
          _guideIssues = issues;
          _guideLoading = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() => _guideLoading = false);
    } catch (e) {
      debugPrint('[EventDetail] 官方指南加载失败: $e');
      if (!mounted) return;
      setState(() => _guideLoading = false);
    }
  }

  /// 标题候选：必须按词边界完整包含事件名，再按「像不像这个事件的正传」
  /// 排序。返回的是**待验证**列表，年份由 [_yearFits] 说了算。
  static List<ReadingGuide> _candidates(
      List<ReadingGuide> guides, MarvelEvent event) {
    final key = _normalize(event.title);
    if (key.isEmpty) return const [];
    final scored = <({ReadingGuide guide, int score})>[];
    for (final g in guides) {
      final t = _normalize(g.title);
      final at = t.indexOf(key);
      if (at < 0) continue;
      // 词边界：'civil war' 不该命中 'civil warrior'
      final before = at == 0 ? ' ' : t[at - 1];
      final after = at + key.length >= t.length ? ' ' : t[at + key.length];
      if (!_isBoundary(before) || !_isBoundary(after)) continue;
      final tail = t.substring(at + key.length).trim();
      // 续作/姐妹篇：Secret Wars 不该拿 Civil War II 那种东西
      if (RegExp(r'^(ii|iii|iv|v|vi|vii|2|3|4)\b').hasMatch(tail)) continue;
      var score = 0;
      if (t.contains('complete event')) score += 6;
      if (t.contains('main event')) score += 5;
      if (RegExp(r'\b' + event.year.toString() + r'\b').hasMatch(t)) {
        score += 4;
      }
      if (tail.isEmpty) score += 3; // 纯事件名，最像正传
      if (t.startsWith(key)) score += 2;
      if (tail.startsWith('road to') || tail.startsWith('the road to')) {
        score -= 2; // 前传导览，能不用就不用
      }
      scored.add((guide: g, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(3).map((e) => e.guide).toList();
  }

  /// 指南里的期数发行年份是否和事件年份对得上。
  ///
  /// 大事件正传都是事件当年到次年发的，所以取年份区间放宽 ±2 年做判定。
  static bool _yearFits(List<ComicIssue> issues, int eventYear) {
    final years = issues
        .map((i) => int.tryParse(i.releaseDate.split('-').first))
        .whereType<int>()
        .toList()
      ..sort();
    if (years.isEmpty) return true; // 没有日期就不拦，交给标题匹配
    final lo = years.first;
    final hi = years.last;
    return eventYear >= lo - 2 && eventYear <= hi + 2;
  }

  static bool _isBoundary(String ch) =>
      ch == ' ' || ch == ':' || ch == '-' || ch == ',' || ch == '(';

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'[^a-z0-9:()\-, ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final event = _event;

    if (event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: AsyncView(
          isLoading: _error == null,
          error: _error,
          isEmpty: false,
          onRetry: _load,
          errorMessage: '打不开这个事件',
          builder: (context) => const SizedBox.shrink(),
        ),
      );
    }

    // hero 配图：数据集 URL 优先，其次官方指南里同名事件的封面
    final guides =
        context.watch<CatalogState>().guides ?? const <ReadingGuide>[];
    final coverUrl =
        context.read<EventsRepository>().coverUrlFor(event, guides);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl != null)
                    ComicCover(url: coverUrl, retryOnTap: false)
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            p.brand.withValues(alpha: 0.5),
                            p.background,
                          ],
                        ),
                      ),
                    ),
                  // 底部渐变把标题从图里托出来
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0x59000000),
                          p.background,
                        ],
                        stops: const [0.45, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: event.isCompanyWide
                              ? p.brand
                              : p.brand.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.tierLabel,
                          style: TextStyle(
                            color: event.isCompanyWide
                                ? const Color(0xFFFFFFFF)
                                : p.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${event.year}',
                        style: TextStyle(
                          color: p.textFaint,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    event.title,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  if (event.titleZh.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      event.titleZh,
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (event.oneLiner.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      event.oneLiner,
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 官方阅读指南：找到同名 Complete Event 指南时，直接展示
          // 指南里逐期的官方顺序，每期可点进详情。
          if (_guide != null) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: '官方阅读指南',
                subtitle: '${_guide!.title} · 按官方顺序',
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
              ),
            ),
            if (_guideLoading || _guideIssues == null)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              )
            else if (_guideIssues!.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('官方指南暂无期数数据'),
                ),
              )
            else
              CoverGrid(
                itemCount: _guideIssues!.length,
                textBlockHeight: 32, // 期号 + 系列名
                itemBuilder: (context, i) => _GuideIssueTile(
                  issue: _guideIssues![i],
                  index: i,
                ),
              ),
          ],
          // 没匹配到官方指南的事件，退回静态整理的阅读顺序
          if (_guide == null && !_guideLoading) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: '阅读顺序',
                subtitle: '静态整理（没找到官方指南）',
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              sliver: SliverList.builder(
                itemCount: event.coreOrder.length,
                itemBuilder: (context, i) => _OrderItem(
                  index: i,
                  item: event.coreOrder[i],
                  onTap: () => AppRouter.openSearch(
                      context, query: event.coreOrder[i].series),
                ),
              ),
            ),
            if (event.optionalOrder.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: '可选延伸',
                  subtitle: '感兴趣的支线再补',
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.sm,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverList.builder(
                  itemCount: event.optionalOrder.length,
                  itemBuilder: (context, i) => _OrderItem(
                    index: i,
                    item: event.optionalOrder[i],
                    optional: true,
                    onTap: () => AppRouter.openSearch(
                      context,
                      query: event.optionalOrder[i].series,
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.navBarClearance),
          ),
        ],
      ),
    );
  }
}

/// 官方指南里的一期：封面 + 顺序角标 + 标题，点进 issue 详情。
class _GuideIssueTile extends StatelessWidget {
  const _GuideIssueTile({required this.issue, required this.index});

  final ComicIssue issue;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return InkWell(
      onTap: () => AppRouter.openIssue(context, issue),
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
                  url: issue.coverUrl,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  placeholderIcon: Icons.menu_book,
                ),
                Positioned(
                  left: 4,
                  top: 4,
                  child: CoverBadge(label: '${index + 1}'),
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
              color: p.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            issue.seriesTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.textGhost,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// 阅读顺序里的一项：序号 + 系列 + 期数 + 备注。
class _OrderItem extends StatelessWidget {
  const _OrderItem({
    required this.index,
    required this.item,
    required this.onTap,
    this.optional = false,
  });

  final int index;
  final EventReadingItem item;
  final VoidCallback onTap;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CoverBadge(
                label: optional ? '选' : '${index + 1}',
                color: optional ? p.fillStrong : null,
                foreground: optional ? p.textMuted : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: item.series,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.issues.isNotEmpty)
                          TextSpan(
                            text: '  #${item.issues}',
                            style: TextStyle(
                              color: p.brand,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (item.note != null && item.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.note!,
                      style: TextStyle(color: p.textFaint, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.search, size: 16, color: p.textGhost),
          ],
        ),
      ),
    );
  }
}