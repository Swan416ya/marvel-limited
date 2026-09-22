import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/comic_cover.dart';
import '../../../state/search_state.dart';

/// 一条搜索结果：封面 + 标题 + 副标题 + 类型角标。
/// 不同来源给不同的图标兜底，点击目标由 kind 决定。
class SearchHitTile extends StatelessWidget {
  const SearchHitTile({super.key, required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      leading: SizedBox(
        width: 44,
        height: 62,
        child: hit.coverUrl != null && hit.coverUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: ComicCover(url: hit.coverUrl),
              )
            : Container(
                decoration: BoxDecoration(
                  color: p.fillStrong,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(_icon, color: p.iconOnCover, size: 20),
              ),
      ),
      title: Text(hit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          // 类型角标：漫画 / 系列 / wiki 系列 / 指南 / 事件
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: hit.kind == SearchHitKind.event
                  ? p.brand.withValues(alpha: 0.18)
                  : p.fillStrong,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              hit.kindLabel,
              style: TextStyle(
                color: hit.kind == SearchHitKind.event
                    ? p.brand
                    : p.textFaint,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hit.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.textFaint, fontSize: 12),
            ),
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right, color: p.textGhost),
      onTap: onTap,
    );
  }

  IconData get _icon => switch (hit.kind) {
        SearchHitKind.issue => Icons.menu_book_outlined,
        SearchHitKind.guide => Icons.collections_bookmark_outlined,
        SearchHitKind.series => Icons.library_books_outlined,
        SearchHitKind.wikiSeries => Icons.public,
        SearchHitKind.event => Icons.bolt,
      };
}