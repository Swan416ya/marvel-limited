import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 封面网格（sliver）。
///
/// 为什么不用固定 `childAspectRatio`：卡片高度 = 封面(2:3) + 标题 + 副标题，
/// 封面高度随格子宽度线性变化、文字块却是固定像素，所以**唯一正确的
/// 比例取决于实际宽度**。写死 0.55 时窄屏会差几个像素，就是「标题下面
/// bottom overflowed by 1.3 pixels」的来源。这里按真实约束反推比例，
/// 封面就永远是精确 2:3、文字块也刚好放得下。
class CoverGrid extends StatelessWidget {
  /// 由可用宽度反推格子比例（封面精确 2:3 + 文字块固定高度）。
  /// [CoverGrid] 之外的普通 GridView 也能用这个算。
  static double aspectFor({
    required double usableWidth,
    required int columns,
    required double textBlockHeight,
    double crossSpacing = AppSpacing.sm,
  }) {
    final cellWidth = (usableWidth - crossSpacing * (columns - 1)) / columns;
    return cellWidth / (cellWidth * 1.5 + textBlockHeight);
  }

  /// 按最大格子宽度反推列数。
  static int columnsFor({
    required double usableWidth,
    required double maxCellWidth,
    double crossSpacing = AppSpacing.sm,
  }) =>
      ((usableWidth + crossSpacing) / (maxCellWidth + crossSpacing))
          .floor()
          .clamp(1, 12);

  const CoverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.columns = 3,
    this.maxCellWidth,
    this.textBlockHeight = 45,
    this.crossSpacing = AppSpacing.sm,
    this.mainSpacing = AppSpacing.md,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      0,
      AppSpacing.md,
      0,
    ),
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;

  /// 固定列数（手机端 3 列小卡）。
  final int columns;

  /// 给了这个就按「格子最大宽度」自适应列数（宽屏 Web 用），
  /// 列数随宽度增长，封面不会被撑成巨幅；此时 [columns] 不生效。
  final double? maxCellWidth;

  /// 封面下方文字块的固定高度（含间距），用于反推比例。
  final double textBlockHeight;

  final double crossSpacing;
  final double mainSpacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final usable = constraints.crossAxisExtent - padding.horizontal;
        final cellWidthHint = maxCellWidth;
        final cols = cellWidthHint == null
            ? columns
            : ((usable + crossSpacing) / (cellWidthHint + crossSpacing))
                .floor()
                .clamp(1, 12);
        final cellWidth = (usable - crossSpacing * (cols - 1)) / cols;
        return SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: cellWidth / (cellWidth * 1.5 + textBlockHeight),
              crossAxisSpacing: crossSpacing,
              mainAxisSpacing: mainSpacing,
            ),
            delegate:
                SliverChildBuilderDelegate(itemBuilder, childCount: itemCount),
          ),
        );
      },
    );
  }
}
