import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// 品牌红渐隐背景。列表页和详情页的 SliverAppBar 都用它。
/// 终点颜色取当前主题的底色，深浅模式各自融合。
class BrandFade extends StatelessWidget {
  const BrandFade({
    super.key,
    this.intensity = 0.35,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.stops,
    this.child,
  });

  /// 红色起始透明度。
  final double intensity;

  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  /// 渐变色停靠点，为空则均分。
  final List<double>? stops;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          stops: stops,
          colors: [
            p.brand.withValues(alpha: intensity),
            p.background,
          ],
        ),
      ),
      child: child,
    );
  }
}