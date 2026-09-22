import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

/// 骨架屏容器：一个动画驱动整屏占位块，避免每个方块各起一个 controller。
///
/// 用 `ShaderMask` + `srcIn`：占位块当作遮罩，扫光从左上到右下扫过。
/// 颜色走当前主题（`p.skeletonBase` / `p.skeletonHighlight`）。
class SkeletonGroup extends StatefulWidget {
  const SkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonGroup> createState() => _SkeletonGroupState();
}

class _SkeletonGroupState extends State<SkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [p.skeletonBase, p.skeletonHighlight, p.skeletonBase],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlideTransform(_controller.value),
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideTransform extends GradientTransform {
  const _SlideTransform(this.t);

  /// 0→1 时扫光从左侧外扫到右侧外。
  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

/// 骨架块。放在 [SkeletonGroup] 里才有扫光。颜色由外层 ShaderMask 决定。
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = AppRadius.md,
    this.expand = false,
  });

  final double? width;
  final double? height;
  final double radius;

  /// 撑满父级。父级必须给出**有界**的宽高（例如处于 `Expanded` 里），
  /// 在 unbounded 的方向上用它会把约束变成 infinity 并抛布局异常。
  /// 需要「撑满宽度但固定高度」请用 `width: double.infinity` + `height`。
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: context.p.skeletonBase,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
    return expand ? SizedBox.expand(child: box) : box;
  }
}