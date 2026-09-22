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
///   右侧单词与 logo 等高对齐、同风格的超粗字重，视觉上连成一体。
/// - 没放官方素材时回落到自绘的红底 MARVEL 方块（见 `_WordMark`）。
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 24, this.tail = 'UNLIMITED'});

  /// logo 视觉高度。右侧单词按它换算字号。
  final double height;

  /// logo 右侧的单词。
  final String tail;

  @override
  Widget build(BuildContext context) {
    final path = BrandAssets.logoPath;
    if (path != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (path.endsWith('.svg'))
            SvgPicture.asset(path, height: height, fit: BoxFit.contain)
          else
            Image.asset(
              path,
              height: height,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          // 右侧单词：与 logo 等高对齐（视觉中线），同风格超粗字重
          if (tail.isNotEmpty) ...[
            SizedBox(width: height * 0.28),
            _TailWord(height: height, tail: tail),
          ],
        ],
      );
    }
    return _WordMark(height: height, tail: tail);
  }
}

/// logo 右侧的单词。
///
/// 官方 logo 是红底白字的超粗无衬线体；单词用同级的字重（w900）、
/// 紧字距、按 logo 高度换算字号，颜色跟随主题文本色——深色主题白字、
/// 浅色主题黑字，和 logo 的红底白字自然并排。
class _TailWord extends StatelessWidget {
  const _TailWord({required this.height, required this.tail});

  final double height;
  final String tail;

  @override
  Widget build(BuildContext context) {
    return Baseline(
      baseline: height * 0.72,
      baselineType: TextBaseline.alphabetic,
      child: Text(
        tail,
        style: TextStyle(
          color: context.p.textPrimary,
          fontSize: height * 0.52,
          height: 1.0,
          fontWeight: FontWeight.w900,
          letterSpacing: height * 0.02,
        ),
      ),
    );
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
    final markFont = height * 0.66;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: height * 0.22,
            vertical: height * 0.13,
          ),
          decoration: BoxDecoration(
            color: p.brand,
            borderRadius: BorderRadius.circular(height * 0.1),
          ),
          child: Text(
            'MARVEL',
            style: TextStyle(
              color: const Color(0xFFFFFFFF),
              fontSize: markFont,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              height: 1.0,
            ),
          ),
        ),
        if (tail.isNotEmpty) ...[
          SizedBox(width: height * 0.24),
          _TailWord(height: height, tail: tail),
        ],
      ],
    );
  }
}