import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/comic_cover.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/tab_app_bar.dart';
import '../../data/models/marvel_event.dart';
import '../../data/models/marvel_models.dart';
import '../../data/repository/events_repository.dart';
import '../../state/catalog_state.dart';

/// 事件 tab：静态存储的漫威大事件库，打开即看（不联网）。
///
/// 顶部两个下拉（级别 / 年份）+ 右侧排序按钮，不用翻完
/// 全公司级才能看到其它分类。列表按排序展示。
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<MarvelEvent>? _events;
  String? _error;

  /// 筛选与排序状态。null 表示「全部」。
  String? _tierFilter;
  int? _yearFilter;
  bool _descending = true;

  @override
  void initState() {
    super.initState();
    _load();
    // 事件封面要从官方指南列表里匹配——这里主动触发加载，
    // 之前只在首页/指南页触发，直接进事件 tab 时封面全是渐变兜底。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogState>().loadGuides();
    });
  }

  Future<void> _load() async {
    try {
      final events = await context.read<EventsRepository>().all();
      if (!mounted) return;
      setState(() => _events = events);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// 应用筛选 + 排序。
  List<MarvelEvent> _visible(List<MarvelEvent> events) {
    var list = [...events];
    if (_tierFilter != null) {
      list = list.where((e) => e.tier == _tierFilter).toList();
    }
    if (_yearFilter != null) {
      list = list.where((e) => e.year == _yearFilter).toList();
    }
    list.sort((a, b) =>
        _descending ? b.year.compareTo(a.year) : a.year.compareTo(b.year));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final events = _events;
    // 事件配图优先用官方指南列表里的同名封面
    final guides =
        context.watch<CatalogState>().guides ?? const <ReadingGuide>[];
    final repo = context.read<EventsRepository>();
    final visible = events == null ? const <MarvelEvent>[] : _visible(events);

    return Scaffold(
      appBar: const TabAppBar(word: 'EVENT'),
      body: events == null
          ? AsyncView(
              isLoading: _error == null,
              error: _error,
              isEmpty: false,
              onRetry: _load,
              errorMessage: '事件库读不出来',
              builder: (context) => const SizedBox.shrink(),
            )
          : Column(
              children: [
                _filterBar(p, events),
                Expanded(
                  child: visible.isEmpty
                      ? const EmptyView(
                          icon: Icons.filter_alt_off_outlined,
                          title: '这个筛选组合下没有事件',
                          subtitle: '换一级别或年份',
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            // 宽屏（平板/横屏）：一张大卡独占一行会拉成一条
                            // 细长横条，并排两列才像话。
                            final wide = AppBreakpoints.isWide(
                              constraints.maxWidth,
                            );

                            Widget itemAt(BuildContext context, int i) {
                              final e = visible[i];
                              return _CompanyEventCard(
                                event: e,
                                coverUrl: repo.coverUrlFor(e, guides),
                                onTap: () => AppRouter.openEvent(context, e),
                                // 网格：高度交给格子、间距交给 delegate
                                fillHeight: wide,
                                margin: wide
                                    ? EdgeInsets.zero
                                    : _CompanyEventCard.listMargin,
                              );
                            }

                            if (!wide) {
                              return ListView.builder(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.navBarClearance),
                                itemCount: visible.length,
                                itemBuilder: itemAt,
                              );
                            }
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.navBarClearance,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 440,
                                childAspectRatio: 16 / 9,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: AppSpacing.md,
                              ),
                              itemCount: visible.length,
                              itemBuilder: itemAt,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  /// 筛选栏：级别下拉 + 年份下拉 + 排序按钮。
  Widget _filterBar(AppPalette p, List<MarvelEvent> events) {
    final tiers = events.map((e) => e.tier).toSet().toList()..sort();
    final tierLabels = {
      for (final t in tiers) t: MarvelEvent.tierLabels[t] ?? t,
    };
    final years = events.map((e) => e.year).toSet().toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _EventDropdown(
              value: _tierFilter,
              hint: '级别',
              items: [
                for (final t in tiers)
                  DropdownMenuItem(value: t, child: Text(tierLabels[t]!)),
              ],
              onChanged: (v) =>
                  setState(() => _tierFilter = (v == '') ? null : v),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _EventDropdown(
              value: _yearFilter?.toString(),
              hint: '年份',
              items: [
                for (final y in years)
                  DropdownMenuItem(value: y.toString(), child: Text('$y')),
              ],
              onChanged: (v) =>
                  setState(() => _yearFilter = int.tryParse(v ?? '')),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 排序切换（与下拉框同高，视觉对齐）
          InkWell(
            onTap: () => setState(() => _descending = !_descending),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: p.fill,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: p.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _descending ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 15,
                    color: p.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _descending ? '新→旧' : '旧→新',
                    style: TextStyle(
                      color: p.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 轻量下拉框（值类型用 String? 统一，年份也转字符串存）。
class _EventDropdown extends StatelessWidget {
  const _EventDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: p.fill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.border),
      ),
      child: Center(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(
              hint,
              style: TextStyle(
                color: p.textMuted,
                fontSize: 12.5,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: '', child: Text('全部')),
              ...items,
            ],
            onChanged: onChanged,
            icon: Icon(Icons.expand_more, size: 18, color: p.textMuted),
            // 必须带 family：DropdownButton 把这个 style 当 DefaultTextStyle 用，
            // 家族为 null 就落到系统字体，Web 上中文直接变豆腐块
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 13,
              fontFamily: AppTheme.fontFamily,
            ),
            dropdownColor: p.surface,
          ),
        ),
      ),
    );
  }
}

/// 事件大卡：横版主视觉 + 标题 + 年份 + 一句话。
/// 所有级别统一这个样式，级别用角标区分（全公司级红底，其它中性底）。
///
/// 两种形态共用：手机端单列大卡（固定高 [listHeight]、自带 [listMargin]），
/// 平板端多列网格（高度由格子给、间距交给 GridView 的 delegate）。
class _CompanyEventCard extends StatelessWidget {
  /// 单列列表里卡片自己的外边距。
  static const listMargin = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.xs,
    AppSpacing.lg,
    AppSpacing.md,
  );

  /// 单列列表里卡片的高度。
  static const listHeight = 176.0;

  const _CompanyEventCard({
    required this.event,
    required this.coverUrl,
    required this.onTap,
    this.margin = listMargin,
    this.fillHeight = false,
  });

  final MarvelEvent event;

  /// 已解析的配图（数据集 URL 或指南匹配），可能为空。
  final String? coverUrl;

  final VoidCallback onTap;

  final EdgeInsetsGeometry margin;

  /// true = 撑满父级给的高度（网格格子）；false = 用 [listHeight] 钉死。
  final bool fillHeight;

  /// 列表模式套一层固定高度；网格模式原样返回，别白搭一层布局。
  Widget _box({required Widget child}) =>
      fillHeight ? child : SizedBox(height: listHeight, child: child);

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: margin,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: _box(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl != null)
                ComicCover(
                  url: coverUrl,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  retryOnTap: false,
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        p.brand.withValues(alpha: 0.45),
                        p.surface,
                      ],
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0x66000000),
                      const Color(0xE6000000),
                    ],
                    stops: const [0.3, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
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
                                : p.badge,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            event.tierLabel,
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${event.year}',
                          style: const TextStyle(
                            color: Color(0xB3FFFFFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (event.titleZh.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.titleZh,
                        style: const TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (event.oneLiner.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        event.oneLiner,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 12,
                          height: 1.4,
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
    );
  }
}