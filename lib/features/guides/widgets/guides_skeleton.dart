import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/skeleton.dart';

/// 指南页骨架屏：形状对齐真实布局（横版 hero + 书架 + 网格），
/// 数据到位时不会跳动。
class GuidesSkeleton extends StatelessWidget {
  const GuidesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            // 撑满宽度 + 固定高度，别用 expand（unbounded 会抛布局异常）
            child: const SkeletonBox(
              width: double.infinity,
              height: 200,
              radius: 12,
            ),
          ),
          _header(),
          SizedBox(
            height: 208,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, _) => const SizedBox(
                width: 232,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 130, width: 232, radius: 12),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonBox(height: 12, width: 200),
                    SizedBox(height: 6),
                    SkeletonBox(height: 10, width: 120),
                  ],
                ),
              ),
            ),
          ),
          _header(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                const Expanded(
                  child: SkeletonBox(height: 140, radius: 12, expand: true),
                ),
                SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: SkeletonBox(height: 140, radius: 12, expand: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _header() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          SkeletonBox(width: 3, height: 18, radius: 2),
          SizedBox(width: AppSpacing.sm),
          SkeletonBox(width: 120, height: 18),
        ],
      ),
    );
  }
}