import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 横向书架：固定高度、懒加载、可左右甩动。
///
/// 首页的「继续阅读」「官方精选」都用它，避免每个分区各写一遍
/// `SizedBox(height:) + ListView(scrollDirection: horizontal)`。
class ShelfList extends StatelessWidget {
  const ShelfList({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.itemWidth,
    this.spacing = AppSpacing.md,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
  });

  /// 书架高度（含条目文字）。
  final double height;

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// 每项宽度。为空则条目自行决定宽度（builder 需返回有确定宽度的组件）。
  final double? itemWidth;

  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: itemCount,
        physics: const BouncingScrollPhysics(),
        separatorBuilder: (_, _) => SizedBox(width: spacing),
        itemBuilder: (context, i) {
          final child = itemBuilder(context, i);
          return itemWidth == null
              ? child
              : SizedBox(width: itemWidth, child: child);
        },
      ),
    );
  }
}