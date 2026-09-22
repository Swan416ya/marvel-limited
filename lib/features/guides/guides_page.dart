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

  List<Widget> _content(BuildContext context, List<ReadingGuide> guides) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: _HeroStrip(
            guides: guides,
            onOpen: (g) => AppRouter.openGuide(context, g),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SectionHeader(
          title: '官方精选',
          subtitle: '按官方推荐顺序整理',
        ),
      ),
      SliverToBoxAdapter(
        child: ShelfList(
          height: 208,
          itemCount: guides.length,
          itemWidth: 232,
          itemBuilder: (context, i) => GuideWideCard(
            guide: guides[i],
            onTap: () => AppRouter.openGuide(context, guides[i]),
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

  List<ReadingGuide> get _items => widget.guides.take(5).toList();

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
        SizedBox(
          height: 200,
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