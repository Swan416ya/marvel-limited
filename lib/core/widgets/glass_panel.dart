import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// 毛玻璃面板。底部导航栏、阅读器悬浮工具条、浮层共用一套参数。
///
/// 传了 `borderRadius` 就按圆角裁剪，否则用 `ClipRect` 裁掉模糊溢出
/// （底部导航栏整条贴边时必须走这个分支）。
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.blur = 24,
    this.color,
    this.borderRadius,
    this.border,
    this.padding,
    this.alignment,
  });

  final Widget child;

  /// 模糊半径。
  final double blur;

  /// 面板底色（半透明）。为空用当前主题的 `p.glass`。
  final Color? color;

  final BorderRadius? borderRadius;

  /// 描边，可只给单边（如导航栏只给上边）。
  final BoxBorder? border;

  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final panel = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        decoration: BoxDecoration(
          color: color ?? context.p.glass,
          borderRadius: borderRadius,
          border: border,
        ),
        padding: padding,
        alignment: alignment,
        child: child,
      ),
    );
    return borderRadius == null
        ? ClipRect(child: panel)
        : ClipRRect(borderRadius: borderRadius!, child: panel);
  }
}

/// 图片上的小角标（阅读顺序、类型标识等）。
class CoverBadge extends StatelessWidget {
  const CoverBadge({
    super.key,
    required this.label,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.color,
    this.foreground,
  });

  final String label;
  final EdgeInsetsGeometry padding;

  /// 底色，默认压图黑。
  final Color? color;

  /// 文字色，默认白（角标底是黑的）。
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.p.badge,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground ?? const Color(0xFFFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 自绘的漫画式红色强调条，用于分区标题等处的品牌点缀。
class BrandAccentBar extends StatelessWidget {
  const BrandAccentBar({super.key, this.width = 3, this.height = 16});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.p.brand,
        borderRadius: BorderRadius.circular(width / 2),
      ),
    );
  }
}