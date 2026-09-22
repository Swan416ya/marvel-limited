import 'package:flutter/services.dart';

/// 品牌资源探测。
///
/// 约定：把品牌 logo 放进 `assets/brand/`，文件名
/// `marvel_unlimited_logo.svg`（优先）或 `marvel_unlimited_logo.png`。
/// 应用启动时探测一次——文件在就用图，不在就用自绘文字标识。
/// 也就是说换 logo 只需丢文件进去，不用改任何代码。
abstract final class BrandAssets {
  /// 品牌 logo（SVG 优先，官方素材常见格式）。
  static const logoSvgPath = 'assets/brand/marvel_unlimited_logo.svg';
  static const logoPngPath = 'assets/brand/marvel_unlimited_logo.png';

  /// 探测到的可用路径；没有素材时为 null（界面用文字标识兜底）。
  static String? logoPath;

  /// 是否探测到 logo 文件。
  static bool get logoAvailable => logoPath != null;

  /// 在 `main()` 里调用一次。
  static Future<void> probe() async {
    for (final path in [logoSvgPath, logoPngPath]) {
      try {
        await rootBundle.load(path);
        logoPath = path;
        return;
      } catch (_) {
        // 这个文件不在，试下一个
      }
    }
    logoPath = null;
  }
}