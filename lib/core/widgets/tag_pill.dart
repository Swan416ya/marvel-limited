import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

/// 小胶囊标签（筛选 / 创作者 / 搜索历史）。
///
/// **为什么不用 Material 的 Chip**：`chip.dart` 内部把 label 的
/// `overflow` 强制成 `TextOverflow.fade`，label 能用的宽度又是拿「测量出的
/// 自然宽度」反推的。Flutter Web(CanvasKit) 上中英混排的测量会漏掉拉丁部分
/// （实测 "全部 0" 量出 22.4px、真正画出来 36px），多出来的字就被淡出裁掉，
/// 也就是「第二个字右半边渐变消失」。这里改成**按字符自己估宽度**
/// （CJK 算 1 em、拉丁 0.62 em，都是上界），宽度可控、文字永不裁切，
/// 字体测量怎么飘都不影响版式。
class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.fontSize = 13,
    this.height = 32,
    this.horizontalPadding = 14,
    this.bold = false,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double fontSize;
  final double height;
  final double horizontalPadding;

  /// 选中态加粗（筛选 chip 用）。
  final bool bold;

  /// 左侧图标。
  final IconData? leading;

  /// 按字符估宽：CJK 全角 1 em，空格 0.33 em，其余 0.62 em。
  /// 再留一点字距余量。这是上界，宁可宽一两像素也不裁字。
  static double estimateWidth(String text, double fontSize) {
    var em = 0.0;
    for (final r in text.runes) {
      if (r == 0x20) {
        em += 0.33;
      } else if (r >= 0x1100 && r <= 0x115F || // 谚文字母
          r >= 0x2E80 && r <= 0xA4CF || // CJK 部首~注音
          r >= 0xAC00 && r <= 0xD7A3 || // 谚文音节
          r >= 0xF900 && r <= 0xFAFF || // CJK 兼容
          r >= 0xFE30 && r <= 0xFE6F || // CJK 兼容形式
          r >= 0xFF00 && r <= 0xFF60 || // 全角
          r >= 0xFFE0 && r <= 0xFFE6) {
        em += 1.0;
      } else {
        em += 0.62;
      }
    }
    return em * fontSize + text.runes.length * 0.1;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final iconWidth = leading == null ? 0.0 : fontSize + 6;
    final width = estimateWidth(label, fontSize) +
        horizontalPadding * 2 +
        iconWidth +
        2; // 边框
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: selected ? p.brand.withValues(alpha: 0.22) : p.fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: selected ? p.brand : p.border),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  Icon(leading, size: fontSize + 2, color: p.textMuted),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  // 关键：绝不淡出。宽度已经按上界给足，正常也不会溢出。
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: selected ? p.textPrimary : p.textMuted,
                    fontSize: fontSize,
                    fontWeight:
                        selected || bold ? FontWeight.w600 : FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
