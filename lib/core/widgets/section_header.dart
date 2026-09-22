import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import 'glass_panel.dart';

/// 分区标题：「继续阅读」+ 右侧「全部 >」。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.seeAllLabel = '全部',
    this.accent = true,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.xxl,
      AppSpacing.lg,
      AppSpacing.md,
    ),
  });

  final String title;

  /// 标题下方的小字说明。
  final String? subtitle;

  /// 为空则不显示右侧入口。
  final VoidCallback? onSeeAll;
  final String seeAllLabel;

  /// 是否显示左侧红色强调条。
  final bool accent;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (accent) ...[
            const BrandAccentBar(height: 18),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(color: p.textFaint, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: p.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(seeAllLabel, style: const TextStyle(fontSize: 13)),
                  const Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}