import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/theme/app_palette.dart';
import 'app_nav_bar.dart';

/// 液态玻璃导航胶囊——**原生平台（Android / iOS / 桌面）实现**。
///
/// 材质交给 `liquid_glass_widgets` 的 [GlassTabBar.bottom]：边缘高光、
/// Fresnel 受光边、随身后内容亮度切换深浅、点按回弹与指示器挤压都由 shader
/// 生成，也自动尊重系统的「减弱动态效果 / 降低透明度 / 增强对比度」设置。
/// Web 不走这里，见 [FlatGlassBar] 顶部注释。
///
/// 质量档固定 [GlassQuality.standard]：它走轻量着色器，**不做背景纹理截图**，
/// 因此没有 flutter#138627（纹理延迟释放 → 动画期内存尖峰）那条风险，滚动中
/// 也稳。`premium` 档多出来的主要是背景折射——本项目要的是高光质感，不值这个
/// 代价。低端机由 `LiquidGlassWidgets.wrap(adaptiveQuality: true)` 自动把上限
/// 压到 [GlassQuality.minimal]。
///
/// 布局沿用原设计：图标式无文字标签（`label` 留空，`semanticLabel` 保证无障碍
/// 朗读）、胶囊限宽 640 居中、离底部留边——外层尺寸仍由 `RootShell` 给。
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0B0B10);

    return SizedBox(
      // 和 FlatGlassBar 一样钉死高度：这个槽位里没有约束的话胶囊会被撑开
      height: _height,
      child: GlassTabBar.bottom(
        tabs: [
          for (final d in items)
            GlassTab(
              icon: Icon(d.icon),
              activeIcon: Icon(d.activeIcon),
              // 图标式无文字标签：文案只给读屏用
              semanticLabel: d.label,
            ),
        ],
        selectedIndex: index,
        onTabSelected: onSelect,
        barHeight: _height,
        // 外层留边（限宽 640 + 安全区）由 RootShell 给，这里不再重复
        verticalPadding: 0,
        // 高光质感：轻量着色器 + iOS 26 校准的镜面高光
        quality: GlassQuality.standard,
        iconSize: 23,
        selectedIconColor: isDark ? fg : p.brand,
        unselectedIconColor: fg.withValues(alpha: isDark ? 0.62 : 0.45),
        // 交互形变：点按整条胶囊回弹（pressScale）+ 指示器挤压（pinch）+
        // 触点处的方向性高光，是 iOS 26 那条「玻璃会动」的观感来源
        interactionBehavior: GlassInteractionBehavior.full,
        pressScale: 1.04,
        indicatorPinchStrength: 0.4,
        // 深色封面滚过时自动切深色玻璃样式，保证图标对比度（HIG 要求）
        adaptiveBrightness: true,
      ),
    );
  }
}
