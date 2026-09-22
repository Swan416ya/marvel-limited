import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

/// 阅读器底部悬浮工具条：上一页 / 进度滑块 / 下一页 / 页码。
///
/// 滑块走的是「视图序号」——竖屏一页一个，横屏一个跨页一个，
/// 跟用户实际看到的内容对齐。
class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    super.key,
    required this.viewIndex,
    required this.viewCount,
    required this.onChanged,
    this.sliderWidth = 220,
  });

  final int viewIndex;
  final int viewCount;
  final ValueChanged<int> onChanged;
  final double sliderWidth;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: p.textStrong, size: 20),
          tooltip: '上一页',
          onPressed: viewIndex > 0 ? () => onChanged(viewIndex - 1) : null,
        ),
        SizedBox(
          width: sliderWidth,
          child: Slider(
            value: viewIndex.toDouble(),
            // 只有一屏内容时把上限设成 1，避免 max == min 让滑块算出 NaN
            max: viewCount <= 1 ? 1.0 : (viewCount - 1).toDouble(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: p.textStrong, size: 20),
          tooltip: '下一页',
          onPressed:
              viewIndex < viewCount - 1 ? () => onChanged(viewIndex + 1) : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${viewIndex + 1} / $viewCount',
          style: TextStyle(color: p.textSubtle, fontSize: 12),
        ),
      ],
    );
  }
}