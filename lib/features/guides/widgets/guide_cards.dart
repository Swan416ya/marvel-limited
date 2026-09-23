import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/card_tap_area.dart';
import '../../../core/widgets/comic_cover.dart';
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

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return LayoutBuilder(builder: (context, constraints) {
      final w = width.isInfinite ? constraints.maxWidth : width;
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
                height: w / imageAspect,
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
    });
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
                  child: Icon(Icons.menu_book,
                      size: 36, color: p.iconOnCover),
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