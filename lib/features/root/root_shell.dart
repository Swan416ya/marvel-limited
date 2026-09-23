import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';

/// 应用外壳：五个 tab + 悬浮「液态玻璃」胶囊导航。
///
/// 参考 iOS 26 的 Liquid Glass：一枚圆角胶囊浮在内容之上，背景模糊、
/// 边缘有一圈受光的细高光和内侧的玻璃反光，激活项在图标后面垫一层
/// 淡淡的玻璃高光——不用整条实心栏，也不用红色大圆钮。
/// 内容由 `StatefulShellRoute` 提供，切 tab 不重建页面。
///
/// 性能：`BackdropFilter` 只包这一小条（不整屏），模糊半径 18，
/// 移动端一帧的额外开销可以忽略；没有动画背景、没有逐项 blur。
class RootShell extends StatelessWidget {
  const RootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// 分支顺序与路由表一致：首页=0（默认），指南=1，系列=2，事件=3，收藏=4。
  static const _destinations = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: '首页'),
    (icon: Icons.explore_outlined, activeIcon: Icons.explore, label: '指南'),
    (
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories,
      label: '系列'
    ),
    (icon: Icons.bolt_outlined, activeIcon: Icons.bolt, label: '事件'),
    (icon: Icons.favorite_border, activeIcon: Icons.favorite, label: '收藏'),
  ];

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // 再点一下当前 tab 回到该分支的根页面
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Padding(
        // 悬浮胶囊：左右留边、离底部留一点，内容从玻璃下面透出来
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          safeBottom + AppSpacing.sm,
        ),
        child: _LiquidGlassBar(
          index: navigationShell.currentIndex,
          onSelect: _goBranch,
          items: _destinations,
        ),
      ),
    );
  }
}

/// 悬浮的液态玻璃导航胶囊。
class _LiquidGlassBar extends StatelessWidget {
  const _LiquidGlassBar({
    required this.index,
    required this.onSelect,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<({IconData icon, IconData activeIcon, String label})> items;

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

    // 说明：这里刻意**不用 BackdropFilter**。实测在 Flutter Web(CanvasKit)
    // 上，圆角裁剪 + BackdropFilter 会让整页 body 的图片停止绘制（封面全空，
    // 去掉滤镜立刻恢复）。改用「半透明底 + 反光渐变 + 亮边」做的磨砂玻璃，
    // 观感接近而代价是一次普通绘制——顺手把性能开销也省了。
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: isDark ? 0.45 : 0.16),
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
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(child: _slot(context, i, p)),
                  ],
                ),
              ],
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
          child: AnimatedContainer(
            duration: AppDuration.quick,
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              // 激活项：图标后面垫一层玻璃高光（iOS 26 的选中态形制）
              color: active
                  ? fg.withValues(alpha: isDark ? 0.14 : 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(_height / 2),
            ),
            child: Icon(
              active ? item.activeIcon : item.icon,
              size: 23,
              color: active
                  ? (isDark ? fg : p.brand)
                  : fg.withValues(alpha: isDark ? 0.62 : 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
