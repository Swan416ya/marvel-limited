import 'package:flutter/widgets.dart';

/// 间距刻度。页面里不再写裸数字。
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;

  /// 底部导航栏是悬浮毛玻璃（`extendBody: true`），滚动内容底部要留出这么高。
  static const navBarClearance = 96.0;
}

/// 圆角刻度。
abstract final class AppRadius {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  /// 胶囊形。
  static const pill = 100.0;
}

/// 动效时长。
abstract final class AppDuration {
  /// 点击反馈、颜色变化。
  static const quick = Duration(milliseconds: 150);
  /// 显隐、位移。
  static const normal = Duration(milliseconds: 250);
  /// 翻页、页面转场。
  static const page = Duration(milliseconds: 350);
}

/// 常用内边距。
abstract final class AppInsets {
  /// 普通滚动页：左右 16、顶部 8、底部让开导航栏。
  static const page = EdgeInsets.fromLTRB(16, AppSpacing.sm, 16, AppSpacing.navBarClearance);
  /// 紧凑列表（条目自带内边距）：左右 8。
  static const pageDense = EdgeInsets.fromLTRB(8, AppSpacing.xs, 8, AppSpacing.navBarClearance);
  /// 详情页正文。
  static const detail = EdgeInsets.all(AppSpacing.lg);
  /// 详情页里的说明段落。
  static const detailNote = EdgeInsets.fromLTRB(20, 12, 20, 8);
}

/// 布局断点。按**可用宽度**判断，不按设备类型——横屏手机和竖屏平板
/// 遇到的是同一种版式问题，用宽度一个判据就够。
///
/// 别和 `main.dart` 里「最短边 >= 600 才放开旋转」混起来：那个决定的是
/// **设备类别**（要不要允许横屏），是另一回事。
abstract final class AppBreakpoints {
  /// 够宽到值得并排两张卡的阈值（两张 340 的卡加间距）。
  static const wide = 700.0;

  /// [width] 是**内容区**可用宽度，不是屏幕宽度——已经扣掉页面内边距的那种。
  static bool isWide(double width) => width >= wide;
}