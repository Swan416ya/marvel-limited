import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import 'app_nav_bar.dart';

/// 手绘的液态玻璃导航胶囊——**Web 降级实现**。
///
/// 视觉 = 半透明底 + 上半部斜向反光渐变 + 0.8px 亮边 + 外投影；高亮胶囊随
/// 选中项平移，图标颜色/缩放过渡。刻意**不用** `BackdropFilter`：实测在
/// Flutter Web(CanvasKit) 上，圆角裁剪 + BackdropFilter 会让整页 body 的
/// 图片停止绘制（封面全空，去掉滤镜立刻恢复）。代价是背景内容不透出、
/// 没有折射、高光不随背景变化——但一帧只是几次普通绘制。
///
/// 原生平台不走这里，见 [GlassNavBar]。
class FlatGlassBar extends StatelessWidget {
  const FlatGlassBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<NavDestination> items;

  static const _height = 62.0;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final radius = BorderRadius.circular(_height / 2);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 液态玻璃的「边缘受光」：外圈一道很淡的白边，内侧一层斜向反光
    final edge = isDark ? const Color(0x2EFFFFFF) : const Color(0x1F0B0B10);
    final sheen = isDark ? const Color(0x1FFFFFFF) : const Color(0x59FFFFFF);
    // 玻璃底：半透明，能透出一点下面的内容
    final fill = isDark ? const Color(0xB3151518) : const Color(0xE8FFFFFF);

    return SizedBox(
      // 少了这层高度约束，胶囊会在 bottomNavigationBar 槽位里被撑满整页
      // （半透明底就成了覆盖全屏的灰色遮罩，还会吃掉所有点击）
      height: _height,
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF000000,
                ).withValues(alpha: isDark ? 0.45 : 0.16),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: radius,
                border: Border.all(color: edge, width: 0.8),
              ),
              child: Stack(
                children: [
                  // 反光：上半部一层从白到透明的斜向渐变
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [sheen, const Color(0x00FFFFFF)],
                            stops: const [0, 0.62],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 高亮胶囊：跟随着选中项**平移**过去（不是就地闪现）。
                  // 两端各内缩 8：药丸两端是圆角，胶囊不内缩的话
                  // 直边贴着曲率，看着像顶到边上了。
                  Positioned(
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: AnimatedAlign(
                        duration: AppDuration.page,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment(
                          -1 + 2 * index / (items.length - 1),
                          0,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: 1 / items.length,
                          child: Center(
                            child: AnimatedContainer(
                              duration: AppDuration.page,
                              curve: Curves.easeOutCubic,
                              height: 38,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0x24FFFFFF)
                                    : const Color(0x140B0B10),
                                borderRadius: BorderRadius.circular(
                                  _height / 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(child: _slot(context, i, p)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _slot(BuildContext context, int i, AppPalette p) {
    final item = items[i];
    final active = i == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0B0B10);

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: InkWell(
        onTap: () => onSelect(i),
        borderRadius: BorderRadius.circular(_height / 2),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Center(
          child: _AnimatedNavIcon(
            active: active,
            activeIcon: item.activeIcon,
            icon: item.icon,
            activeColor: isDark ? fg : p.brand,
            idleColor: fg.withValues(alpha: isDark ? 0.62 : 0.45),
          ),
        ),
      ),
    );
  }
}

/// 导航图标：选中时颜色渐变过去，实心/线性图标切换带一点缩放淡入。
class _AnimatedNavIcon extends StatelessWidget {
  const _AnimatedNavIcon({
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.activeColor,
    required this.idleColor,
  });

  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final Color activeColor;
  final Color idleColor;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: AppDuration.normal,
      curve: Curves.easeOut,
      tween: Tween(begin: 0, end: active ? 1 : 0),
      builder: (context, t, child) {
        // t: 0(未选中) → 1(选中)，颜色插值 + 图标缩放一点
        final color = Color.lerp(idleColor, activeColor, t)!;
        return Transform.scale(
          scale: 1 + t * 0.08,
          child: Icon(active ? activeIcon : icon, size: 23, color: color),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
