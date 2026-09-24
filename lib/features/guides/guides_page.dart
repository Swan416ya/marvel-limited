import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/shelf_list.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/tab_app_bar.dart';
import '../../data/models/marvel_models.dart';
import '../../state/catalog_state.dart';
import 'widgets/guide_cards.dart';
import 'widgets/guides_skeleton.dart';

/// 指南 tab：只放官方阅读指南。
///
/// 原来的「首页」混了继续阅读、追更等内容，现在那些都搬去综合首页，
/// 这里就是纯粹的指南浏览：hero 轮播 + 精选书架 + 全部指南网格。
/// 卡片是横版的——官方指南缩略图本来就是横向的。
class GuidesPage extends StatefulWidget {
  const GuidesPage({super.key});

  @override
  State<GuidesPage> createState() => _GuidesPageState();
}

class _GuidesPageState extends State<GuidesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogState>().loadGuides();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogState>();
    final guides = catalog.guides;

    return Scaffold(
      appBar: const TabAppBar(word: 'GUIDE'),
      body: RefreshIndicator(
        onRefresh: () => context.read<CatalogState>().refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (guides == null && catalog.guidesError != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(
                  message: '指南加载失败',
                  detail: catalog.guidesError,
                  onRetry: () => catalog.loadGuides(force: true),
                ),
              )
            else if (guides == null)
              const SliverToBoxAdapter(child: GuidesSkeleton())
            else if (guides.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  icon: Icons.menu_book,
                  title: '还没有可用的阅读指南',
                  subtitle: '下拉刷新试试',
                ),
              )
            else
              ..._content(context, guides),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.navBarClearance),
            ),
          ],
        ),
      ),
    );
  }

  /// 时间最近的 Complete Event 型导览（列表本身新的在前）。
  /// 官方最近的大事件导览一般都叫 "XXX: The Complete Event"，
  /// banner 只放这类，比泛泛的「官方精选」有意义。
  static List<ReadingGuide> _completeEventGuides(List<ReadingGuide> guides) {
    final matched = <ReadingGuide>[];
    for (final g in guides) {
      final t = g.title.toLowerCase();
      if (t.contains('complete event') || t.contains('main event')) {
        matched.add(g);
      }
      if (matched.length >= 6) break;
    }
    // 不够 6 个就用最近的指南补齐，避免 banner 空着
    if (matched.length < 6) {
      for (final g in guides) {
        if (matched.contains(g)) continue;
        matched.add(g);
        if (matched.length >= 6) break;
      }
    }
    return matched;
  }

  List<Widget> _content(BuildContext context, List<ReadingGuide> guides) {
    return [
      // 顶部 banner：时间最近的 Complete Event 型官方导览
      // （指南列表本身就是新的在前）。原来重复的「官方精选」书架删掉了。
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: _HeroStrip(
            guides: _completeEventGuides(guides),
            onOpen: (g) => AppRouter.openGuide(context, g),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SectionHeader(title: '全部指南', subtitle: '共 ${guides.length} 个专题'),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          0,
        ),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 340,
            childAspectRatio: 16 / 10,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => GuideWideTile(
              guide: guides[i],
              onTap: () => AppRouter.openGuide(context, guides[i]),
            ),
            childCount: guides.length,
          ),
        ),
      ),
    ];
  }
}

/// 顶部横版 banner。两种版式：
///
/// - **窄屏**：一次一张 16:9 大卡，左右翻页，底部圆点；
/// - **宽屏（[AppBreakpoints.isWide]）**：横着排开，一屏能放几张放几张，
///   超出的横向滑——不再翻页，也就不需要圆点。
///
/// 卡片高度一律走 [GuideWideCard.heightFor]，别在这里另算一套：之前这里按
/// 「图高 + 50」估、卡片按「图高 + 间距 + 标题」算，矮视口下两边对不上，
/// 标题只有一行时会溢出 28 像素。
class _HeroStrip extends StatefulWidget {
  const _HeroStrip({required this.guides, required this.onOpen});

  final List<ReadingGuide> guides;
  final ValueChanged<ReadingGuide> onOpen;

  @override
  State<_HeroStrip> createState() => _HeroStripState();
}

class _HeroStripState extends State<_HeroStrip> {
  /// 窄屏翻页时每页占视口的比例（露出下一张的边，提示可以滑）。
  static const _viewportFraction = 0.88;

  /// 宽屏横排时单张卡的最小宽度，用来决定一屏放几张。
  static const _minCardWidth = 300.0;

  /// 宽屏横排最多放几张（再宽也别把卡摊成巨幅）。
  static const _maxColumns = 4;

  late final PageController _controller = PageController(
    viewportFraction: _viewportFraction,
  );
  int _index = 0;

  List<ReadingGuide> get _items => widget.guides.take(6).toList();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 卡片左右各留 AppSpacing.xs 的缝，两种版式共用同一份
        const gap = AppSpacing.xs * 2;
        return AppBreakpoints.isWide(constraints.maxWidth)
            ? _wide(context, items, constraints.maxWidth, gap)
            : _paged(
                context,
                items,
                constraints.maxWidth * _viewportFraction - gap,
              );
      },
    );
  }

  /// 宽屏：一屏 [columns] 张并排、等分填满一行；多余的横向滑。
  Widget _wide(
    BuildContext context,
    List<ReadingGuide> items,
    double width,
    double gap,
  ) {
    // 左右留边对齐下方的指南网格（那里的 padding 是 AppSpacing.lg）
    const inset = AppSpacing.lg;
    final usable = width - inset * 2;
    final columns = ((usable + gap) / (_minCardWidth + gap))
        .floor()
        .clamp(2, _maxColumns);
    final cardWidth = (usable - gap * (columns - 1)) / columns;

    return ShelfList(
      height: GuideWideCard.heightFor(context, cardWidth),
      itemCount: items.length,
      itemWidth: cardWidth,
      spacing: gap,
      padding: const EdgeInsets.symmetric(horizontal: inset),
      itemBuilder: (context, i) => GuideWideCard(
        guide: items[i],
        width: cardWidth,
        onTap: () => widget.onOpen(items[i]),
      ),
    );
  }

  /// 窄屏：翻页轮播 + 圆点。
  Widget _paged(
    BuildContext context,
    List<ReadingGuide> items,
    double cardWidth,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: GuideWideCard.heightFor(context, cardWidth),
          child: PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: GuideWideCard(
                guide: items[i],
                width: double.infinity,
                onTap: () => widget.onOpen(items[i]),
              ),
            ),
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: AppDuration.normal,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? context.p.brand : context.p.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
