import 'package:flutter/material.dart';

/// 卡片点击区：**只包住内容**，不吞掉槽位里多出来的空白。
///
/// 场景：卡片放进固定高度的槽位（横向书架、顶部轮播），槽位高度是按
/// 「图 + 两行标题」估的；标题只有一行时底下会空一截（空着好看），
/// 但 InkWell 如果直接包住整个槽位，鼠标悬停/手指按在那截空白上也会
/// 高亮，看着像点错了东西。
///
/// 包一层 [Align] 让 InkWell 收缩到内容大小——槽位本身仍然占满，
/// 内容照旧顶到上沿，只有高亮和水波纹收紧了。子组件必须是内容自适应
/// 高度的（`Column(mainAxisSize: MainAxisSize.min)`）。
class CardTapArea extends StatelessWidget {
  const CardTapArea({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}