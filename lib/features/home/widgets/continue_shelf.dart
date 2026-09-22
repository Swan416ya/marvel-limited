import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/comic_cover.dart';
import '../../../data/repository/preferences_repository.dart';

/// 「继续阅读」书架：带进度条，点一下直接跳回上次那一页。
class ContinueShelfCard extends StatelessWidget {
  const ContinueShelfCard({
    super.key,
    required this.progress,
    required this.onTap,
    this.width = 132,
  });

  final ReadingProgress progress;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final issue = progress.issue;
    final posterHeight = width / (2 / 3);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: posterHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ComicCover(
                    url: issue.coverUrl,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    placeholderIcon: Icons.menu_book,
                  ),
                  // 进度条压在封面底部
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AppRadius.lg),
                      ),
                      child: LinearProgressIndicator(
                        value: progress.ratio,
                        minHeight: 3,
                        backgroundColor: p.badge,
                        valueColor: AlwaysStoppedAnimation(p.brand),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              issue.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '第 ${progress.page + 1} / ${progress.totalPages} 页',
              style: TextStyle(color: p.textFaint, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}