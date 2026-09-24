import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'flat_glass_bar.dart';
import 'glass_nav_bar.dart';

/// 一个底部导航项。两种实现共用，图标表只写一份。
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  /// 未选中时的线性图标。
  final IconData icon;

  /// 选中时的实心图标。
  final IconData activeIcon;

  /// 无障碍朗读用的名字（也是将来加文字标签时的文案）。
  final String label;
}

/// 底部导航胶囊。按平台分流到两种实现：
///
/// - **非 Web**：`liquid_glass_widgets` 的液态玻璃 tab bar，见 [GlassNavBar]。
/// - **Web**：手绘降级版，见 [FlatGlassBar]。
///
/// 分流的原因是引擎坑而非审美：CanvasKit 上「圆角裁剪 + 背景滤镜」会让整页
/// body 的图片停止绘制（封面全空，本项目实测过，见 README「已知取舍」）。
/// 玻璃材质无论哪档质量都要读背景，所以在 Web 上维持原来的静态实现。
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  /// 分支顺序与路由表一致：首页=0（默认），指南=1，系列=2，事件=3，收藏=4。
  static const destinations = <NavDestination>[
    NavDestination(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: '首页',
    ),
    NavDestination(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: '指南',
    ),
    NavDestination(
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories,
      label: '系列',
    ),
    NavDestination(
      icon: Icons.bolt_outlined,
      activeIcon: Icons.bolt,
      label: '事件',
    ),
    NavDestination(
      icon: Icons.favorite_border,
      activeIcon: Icons.favorite,
      label: '收藏',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return kIsWeb
        ? FlatGlassBar(index: index, onSelect: onSelect, items: destinations)
        : GlassNavBar(index: index, onSelect: onSelect, items: destinations);
  }
}
