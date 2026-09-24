import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/card_tap_area.dart';
import '../../../core/widgets/comic_cover.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../data/models/marvel_models.dart';

/// 书架用的横版指南卡：官方指南缩略图本来就是横向的，按 16:9 走。
///
/// `width` 传 `double.infinity` 时按可用宽度撑满（banner 轮播用），
/// 内部用 LayoutBuilder 拿真实宽度再算图高——直接用 infinity 算
/// 高度会得到无穷大，布局直接崩。
class GuideWideCard extends StatelessWidget {
  const GuideWideCard({
    super.key,
    required this.guide,
    required this.onTap,
    this.width = 232,
    this.imageAspect = 16 / 9,
  });

  final ReadingGuide guide;
  final VoidCallback onTap;
  final double width;

  /// 图区宽高比（宽 / 高）。
  final double imageAspect;

  /// 横屏/矮视口时的卡片高度上限（视口高度的 42%）。
  /// banner 与卡片两处共用，改一处漏一处会错位。
  static double maxCardHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height * 0.42;

  /// 标题行高：`fontSize 13 × height 1.25`。预留和实际绘制必须用同一个数，
  /// 差一点点就是「bottom overflowed by N pixels」。
  static const double _titleLineHeight = 13 * 1.25;

  /// 图区下方的文字块高度（间距 + 标题两行）。
  /// **总是按两行预留**：按实际行数预留的话，标题短的那张卡高度会忽高忽低，
  /// 同一排卡片对不齐。
  static const double titleBlockHeight = AppSpacing.sm + _titleLineHeight * 2;

  /// 图区高度上限。矮视口下 [maxCardHeight] 可能比文字块还小，兜个 0。
  static double _maxImageHeight(BuildContext context) =>
      math.max(0, maxCardHeight(context) - titleBlockHeight);

  /// 一张卡在 [cardWidth] 宽度下**需要**的高度。
  ///
  /// banner 条和网格都从这里取，别再各自加减常数——之前 banner 条按
  /// 「图高 + 50」估、卡片按「图高 + 间距 + 标题」算，两边对不上，
  /// 矮视口 + 单行标题时会溢出 28 像素。
  static double heightFor(
    BuildContext context,
    double cardWidth, {
    double imageAspect = 16 / 9,
  }) =>
      (cardWidth / imageAspect).clamp(0.0, _maxImageHeight(context)) +
      titleBlockHeight;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = width.isInfinite ? constraints.maxWidth : width;
        // 横屏限高：外层把卡片高度封顶后，图高不能再按宽度算
        // （16:9 的大图在横屏会把文字顶出屏幕）
        final maxImage = _maxImageHeight(context);
        // 槽位高度是按「图 + 两行标题」估的，标题只有一行时底下会空一截；
        // 用 CardTapArea 让高亮/水波纹只跟着内容，别把那截空白也点亮
        return CardTapArea(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            width: w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: (w / imageAspect).clamp(0.0, maxImage),
                  child: ComicCover(
                    url: guide.coverUrl,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    placeholderIcon: Icons.menu_book,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  guide.title,
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
      },
    );
  }
}

/// 网格用的横版指南瓦片：图铺 16:10，标题压在底部渐变上。
class GuideWideTile extends StatelessWidget {
  const GuideWideTile({super.key, required this.guide, required this.onTap});

  final ReadingGuide guide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: guide.coverUrl ?? '',
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => ColoredBox(
                  color: p.fillStrong,
                  child: Icon(Icons.menu_book, size: 36, color: p.iconOnCover),
                ),
              ),
              // 底部渐变保证文字可读
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [const Color(0x00000000), p.scrim],
                      stops: const [0.55, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: 10,
                child: Text(
                  guide.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 指南网格里的一期：封面 + 阅读顺序角标 + 标题，点进 issue 详情。
///
/// 大事件详情页与指南详情页共用。两处原有观感差异做成参数保留：
/// [radius] 圆角、[titleFontSize] 期号字号、[alwaysShowSeries] 系列名
/// 是否无条件显示——不要为了统一而抹掉。
class GuideIssueCard extends StatelessWidget {
  const GuideIssueCard({
    super.key,
    required this.issue,
    required this.index,
    this.radius = AppRadius.sm,
    this.titleFontSize = 12,
    this.alwaysShowSeries = false,
  });

  final ComicIssue issue;

  /// 阅读顺序角标（显示时 +1）。
  final int index;

  /// 封面/水波纹圆角（大事件页用 md，指南页用 sm）。
  final double radius;

  /// 期号那行的字号。
  final double titleFontSize;

  /// 指南页只在「有期号且有系列名」时才显示系列名行，大事件页则无条件
  /// 显示（哪怕内容为空也保留那一行）。
  final bool alwaysShowSeries;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final showSeries =
        alwaysShowSeries ||
        (issue.issueNumber.isNotEmpty && issue.seriesTitle.isNotEmpty);
    return InkWell(
      onTap: () => AppRouter.openIssue(context, issue),
      borderRadius: BorderRadius.circular(radius),
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
                  borderRadius: BorderRadius.circular(radius),
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
              color: p.textPrimary,
              fontSize: titleFontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showSeries)
            Text(
              issue.seriesTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.textGhost, fontSize: 10, height: 1.3),
            ),
        ],
      ),
    );
  }
}
