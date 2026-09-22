import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/section_header.dart';
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
        child: SectionHeader(
          title: '全部指南',
          subtitle: '共 ${guides.length} 个专题',
        ),
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

/// 顶部横版轮播：一次一张 16:9 大卡，底部圆点。
class _HeroStrip extends StatefulWidget {
  const _HeroStrip({required this.guides, required this.onOpen});

  final List<ReadingGuide> guides;
  final ValueChanged<ReadingGuide> onOpen;

  @override
  State<_HeroStrip> createState() => _HeroStripState();
}

class _HeroStripState extends State<_HeroStrip> {
  late final PageController _controller =
      PageController(viewportFraction: 0.88);
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 高度由实际宽度计算（图 16:9 + 标题两行），窗口宽度变化时
        // 自动重排，写死高度会在窄屏溢出、宽屏留白。
        LayoutBuilder(builder: (context, constraints) {
          final pageWidth = constraints.maxWidth * 0.88;
          final cardHeight = pageWidth / (16 / 9) + 50;
          return SizedBox(
            height: cardHeight,
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
          );
        }),
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
                  color: active
                      ? context.p.brand
                      : context.p.border,
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