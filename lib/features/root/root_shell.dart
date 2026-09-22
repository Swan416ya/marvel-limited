import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_palette.dart';
import '../../core/widgets/glass_panel.dart';

/// 应用外壳：五个 tab + 悬浮毛玻璃底部导航。
///
/// 中间的「首页」是骑在导航栏顶上的大圆钮（参考 B 站加号按钮的形制），
/// 其余四个（指南 / 系列 / 事件 / 收藏）是常规图标位。
/// 内容由 `StatefulShellRoute` 提供，切 tab 不重建页面。
class RootShell extends StatelessWidget {
  const RootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// 分支顺序与路由表一致：指南=0，系列=1，首页=2（中间），事件=3，收藏=4。
  static const _homeIndex = 2;

  static const _destinations = [
    (icon: Icons.explore_outlined, activeIcon: Icons.explore, label: '指南'),
    (icon: Icons.auto_stories_outlined, activeIcon: Icons.auto_stories, label: '系列'),
    (icon: null, activeIcon: null, label: '首页'), // 中间大按钮占位
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
    final p = context.p;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const barHeight = 64.0;
    // 大按钮要「骑」在玻璃栏顶上：把 bottomNavigationBar 整体加高 28，
    // 玻璃栏贴底放，按钮钉在顶部。不靠负偏移（会受外层裁剪影响，实测被压平）。
    const raise = 28.0;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SizedBox(
        height: barHeight + safeBottom + raise,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlassPanel(
                border: Border(top: BorderSide(color: p.border)),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: barHeight,
                    child: Row(
                      children: [
                        for (var i = 0; i < _destinations.length; i++)
                          Expanded(child: _slot(context, i)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 中央大按钮：钉在整个导航区域顶部，带一圈底色描边从内容里浮出来。
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _CenterButton(
                  active: navigationShell.currentIndex == _homeIndex,
                  onTap: () => _goBranch(_homeIndex),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slot(BuildContext context, int index) {
    final p = context.p;
    final d = _destinations[index];
    final active = navigationShell.currentIndex == index;

    // 中间位留给大按钮，这里只画与其它位对齐的标签
    if (d.icon == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goBranch(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(
                d.label,
                style: TextStyle(
                  color: active ? p.brand : p.textSubtle,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _goBranch(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active ? d.activeIcon : d.icon,
            size: 24,
            color: active ? p.brand : p.textSubtle,
          ),
          const SizedBox(height: 3),
          Text(
            d.label,
            style: TextStyle(
              color: active ? p.brand : p.textSubtle,
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 中间的红色大圆钮。
class _CenterButton extends StatelessWidget {
  const _CenterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: p.background,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: p.brand.withValues(alpha: active ? 0.55 : 0.3),
              blurRadius: active ? 18 : 10,
              spreadRadius: active ? 2 : 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              color: p.brand,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.home_rounded,
              color: const Color(0xFFFFFFFF),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}