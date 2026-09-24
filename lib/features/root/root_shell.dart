import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import 'widgets/app_nav_bar.dart';

/// 应用外壳：五个 tab + 悬浮「液态玻璃」胶囊导航。
///
/// 参考 iOS 26 的 Liquid Glass：一枚圆角胶囊浮在内容之上，玻璃材质本身
/// 由 `liquid_glass_widgets` 渲染（边缘高光、Fresnel 受光边、点按回弹）。
/// 内容由 `StatefulShellRoute` 提供，切 tab 不重建页面。
///
/// 平台分流和各自的实现取舍写在 [AppNavBar] 及其两个实现的注释里。
class RootShell extends StatelessWidget {
  const RootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

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
      // heightFactor 必须给：bottomNavigationBar 槽位的高度约束是松的
      // （0<=h<=整屏高），而 Center 默认会把自己撑满可用高度。那样 Scaffold
      // 会认为这条栏有整屏那么高，于是把「整屏高的 Center」贴在 y=0，胶囊
      // 就被居中到屏幕正中间去了（渲染树里 Center 的 size 是 430×932、
      // 子节点 offset 是 (0, 431)，实测过）。heightFactor: 1 让它收缩成
      // 胶囊自身的高度，Scaffold 才能把它钉到底部。
      bottomNavigationBar: Center(
        heightFactor: 1,
        // 平板/横屏时限宽：一条胶囊拉满 1200px 宽会非常诡异，
        // 五个图标各占 240px 也点不准。手机上 640 上限等于没限。
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            // 悬浮胶囊：左右留边、离底部留一点，内容从玻璃下面透出来
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              safeBottom + AppSpacing.sm,
            ),
            child: AppNavBar(
              index: navigationShell.currentIndex,
              onSelect: _goBranch,
            ),
          ),
        ),
      ),
    );
  }
}
