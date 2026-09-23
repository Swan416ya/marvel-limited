import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../brand_assets.dart';
import '../theme/app_palette.dart';

/// 品牌标识。全应用唯一的 logo 入口。
///
/// 结构是「漫威 logo + 右侧单词」组合标题：
/// - 首页 MARVEL LIMITED、指南 MARVEL GUIDE、系列 MARVEL SERIES、
///   事件 MARVEL EVENT、收藏 MARVEL COLLECTION。
/// - logo 用 `assets/brand/marvel_unlimited_logo.svg|.png`（存在即用）；
///   右侧单词和 logo **竖直居中对齐**（字高按 MARVEL 字形实测比例算，
///   字号固定不变），字体用打包的 Anton（OFL 授权）。
/// - 没放官方素材时回落到自绘的红底 MARVEL 方块（见 `_WordMark`）。
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 24, this.tail = 'UNLIMITED'});

  /// logo 视觉高度（红底方块的高度）。
  final double height;

  /// logo 右侧的单词。
  final String tail;

  /// 官方 SVG（viewBox 500×200）里 MARVEL 白色字形的实测包围盒，
  /// 换算成占 logo 高度的比例：字顶 0.0798、基线 0.9202 → 字高 0.8403。
  /// 右侧单词就按这个字高和基线摆，才能和标志连成一个 lockup。
  static const glyphBaseline = 0.9202;
  static const glyphCapHeight = 0.8403;

  /// Anton 的 capHeight / unitsPerEm = 1760 / 2048。
  static const antonCapRatio = 0.859375;

  /// 文字的**视觉**下沉量（占 logo 高的比例）。
  ///
  /// 基线对齐在几何上是对的（MARVEL 字形中心恰好在红方块中心），
  /// 但 Anton 的字形墨迹底部比基线高约 1px（H=22 时实测：文字中心
  /// 比方块中心高 1.0px），所以只挪绘制、不动布局，把墨迹压回中心。
  /// 截图像素量过：加了这个量后 |文字中心 - 方块中心| < 0.5px。
  static const tailNudge = 0.048;

  /// 右侧单词的字号：目标字高反推。
  static double tailFontSize(double height) =>
      height * glyphCapHeight / antonCapRatio;

  @override
  Widget build(BuildContext context) {
    final path = BrandAssets.logoPath;
    if (path != null) {
      final logo = path.endsWith('.svg')
          ? SvgPicture.asset(path, height: height, fit: BoxFit.contain)
          : Image.asset(
              path,
              height: height,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            );
      return Row(
        mainAxisSize: MainAxisSize.min,
        // 对齐方式：**字形块的竖直中心**对齐红方块的竖直中心。
        // 不能用 Row 的 center——那对齐的是文字「行框」（含下降部的
        // 空白），字形会整体偏上。SVG 里 MARVEL 字形占 y 0.0798H~
        // 0.9202H（几何中心恰好在方块中心），所以把 logo 的基线申报为
        // 0.9202H、文字基线也落在那里，两边字形中心就重合了。
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Baseline(
            baseline: height * glyphBaseline,
            baselineType: TextBaseline.alphabetic,
            child: logo,
          ),
          if (tail.isNotEmpty) ...[
            SizedBox(width: height * 0.22),
            Transform.translate(
              offset: Offset(0, height * tailNudge),
              child: Text(
                tail,
                style: TextStyle(
                  color: context.p.textPrimary,
                  fontFamily: 'Anton',
                  fontSize: tailFontSize(height),
                  // 必须显式给字重：AppBar 的 titleTextStyle 是 w700，而 Anton
                  // 只注册了 w400，继承下去会让 Flutter 做**合成加粗**——字被
                  // 撑大一圈，看着比 logo 的字形大、也比 logo 更粗。
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                  letterSpacing: tailFontSize(height) * 0.01,
                ),
              ),
            ),
          ],
        ],
      );
    }
    return _WordMark(height: height, tail: tail);
  }
}

/// 自绘文字标识：MARVEL 红底白字 + 右侧紧字距单词。
/// 这是本项目自己的排版兜底；放了官方素材就不会走到这里。
class _WordMark extends StatelessWidget {
  const _WordMark({required this.height, required this.tail});

  final double height;
  final String tail;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final markFont = height * 0.62;
    final cap = markFont * BrandLogo.antonCapRatio;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Baseline(
          // 方块里文字垂直居中，基线 = 中线 + 半个字高
          baseline: height * 0.5 + cap * 0.5,
          baselineType: TextBaseline.alphabetic,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: height * 0.22),
            decoration: BoxDecoration(
              color: p.brand,
              borderRadius: BorderRadius.circular(height * 0.1),
            ),
            alignment: Alignment.center,
            child: Text(
              'MARVEL',
              style: TextStyle(
                color: const Color(0xFFFFFFFF),
                fontFamily: 'Anton',
                fontSize: markFont,
                fontWeight: FontWeight.w400,
                height: 1.0,
                letterSpacing: markFont * 0.01,
              ),
            ),
          ),
        ),
        if (tail.isNotEmpty) ...[
          SizedBox(width: height * 0.22),
          Text(
            tail,
            style: TextStyle(
              color: p.textPrimary,
              fontFamily: 'Anton',
              fontSize: BrandLogo.tailFontSize(height),
              fontWeight: FontWeight.w400,
              height: 1.0,
              letterSpacing: BrandLogo.tailFontSize(height) * 0.01,
            ),
          ),
        ],
      ],
    );
  }
}
