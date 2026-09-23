import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// 毛玻璃面板（阅读器悬浮工具条、详情页浮层等）。
///
/// **注意**：底部导航栏**不用**这个组件——圆角裁剪 + BackdropFilter 在
/// Flutter Web(CanvasKit) 上会让整页 body 的图片停止绘制（详见
/// root_shell.dart 的注释和 README「已知取舍」）。本组件目前只用于
/// 工具条/浮层这类小面积、且实测没触发问题的场合；在封面网格上方
/// 新增使用前，务必先在浏览器里确认封面还画得出来。
///
/// 传了 `borderRadius` 就按圆角裁剪，否则用 `ClipRect` 裁掉模糊溢出。
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