import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';

/// 阅读器底部悬浮工具条：上一页 / 进度滑块 / 下一页 / 页码。
///
/// 滑块走的是「视图序号」——竖屏一页一个，横屏一个跨页一个，
/// 跟用户实际看到的内容对齐。滑块宽度会自动收缩适配剩余空间
/// （书签/双页按钮加入后工具栏变长）。
class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    super.key,
    required this.viewIndex,
    required this.viewCount,
    required this.onChanged,
    this.sliderWidth,
  });

  final int viewIndex;
  final int viewCount;
  final ValueChanged<int> onChanged;

  /// 滑块宽度。为空时自适应（140~220，按可用空间收缩）。
  final double? sliderWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // 按钮区（前后翻页 + 页码）约占 170，给滑块留剩余空间
      final available = (constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 400.0) - 170;
      final width = sliderWidth ?? available.clamp(100.0, 220.0);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.chevron_left, color: context.p.textStrong, size: 20),
            tooltip: '上一页',
            onPressed: viewIndex > 0 ? () => onChanged(viewIndex - 1) : null,
          ),
          SizedBox(
            width: width,
            child: Slider(
              value: viewIndex.toDouble(),
              // 只有一屏内容时把上限设成 1，避免 max == min 让滑块算出 NaN
              max: viewCount <= 1 ? 1.0 : (viewCount - 1).toDouble(),
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.chevron_right, color: context.p.textStrong, size: 20),
            tooltip: '下一页',
            onPressed:
                viewIndex < viewCount - 1 ? () => onChanged(viewIndex + 1) : null,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${viewIndex + 1} / $viewCount',
            style: TextStyle(color: context.p.textSubtle, fontSize: 12),
          ),
        ],
      );
    });
  }
}