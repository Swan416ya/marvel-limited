import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../brand_assets.dart';
import '../theme/app_palette.dart';

/// 品牌标识。全应用唯一的 logo 入口。
///
/// 布局是「红底 MARVEL 方块 + 右侧单词」：首页 LIMITED，指南 GUIDE，
/// 系列 SERIES，事件 EVENT，收藏 COLLECTION。
///
/// 素材：把官方 logo 放到 `assets/brand/marvel_unlimited_logo.svg|.png`
/// 就会整体替换这个自绘标识（启动时探测，不用改代码）。
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 24, this.tail = 'UNLIMITED'});

  /// 视觉高度。用图时是图片高度，用文字时按它换算字号。
  final double height;

  /// 红块右侧的单词。
  final String tail;

  @override
  Widget build(BuildContext context) {
    final path = BrandAssets.logoPath;
    if (path != null) {
      if (path.endsWith('.svg')) {
        return SvgPicture.asset(
          path,
          height: height,
          fit: BoxFit.contain,
        );
      }
      return Image.asset(
        path,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
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
    final markFont = height * 0.66;
    final tailFont = height * 0.44;
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
        SizedBox(width: height * 0.24),
        Text(
          tail,
          style: TextStyle(
            color: p.textPrimary,
            fontSize: tailFont,
            fontWeight: FontWeight.w700,
            letterSpacing: tailFont * 0.16,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}