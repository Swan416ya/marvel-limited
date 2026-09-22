import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../state/theme_state.dart';
import 'brand_logo.dart';

/// 主 tab 页共用的 AppBar：品牌标识（红底 MARVEL + 单词）+ 主题切换 + 搜索。
///
/// 每个页面的单词不同：指南 GUIDE、系列 SERIES、事件 EVENT、收藏
/// COLLECTION——和官网命名的「MARVEL XXX」一个路数。搜索不再是
/// 底部 tab，每个主页面右上角都能唤起。
class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabAppBar({super.key, this.word});

  /// 品牌标识右侧的单词（GUIDE / SERIES / EVENT / COLLECTION）。
  final String? word;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    return AppBar(
      title: BrandLogo(height: 22, tail: word ?? ''),
      actions: [
        IconButton(
          icon: Icon(switch (theme.mode) {
            ThemeMode.light => Icons.light_mode_outlined,
            ThemeMode.dark => Icons.dark_mode_outlined,
            ThemeMode.system => Icons.brightness_6_outlined,
          }),
          tooltip: switch (theme.mode) {
            ThemeMode.light => '浅色，点切深色',
            ThemeMode.dark => '深色，点跟随系统',
            ThemeMode.system => '跟随系统，点切浅色',
          },
          color: context.p.textMuted,
          onPressed: () => theme.cycle(),
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: '搜索',
          onPressed: () => AppRouter.openSearch(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}