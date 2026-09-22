import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/models/marvel_models.dart';
import '../../data/repository/wiki_repository.dart';
import '../../state/catalog_state.dart';
import '../../state/favorites_state.dart';
import '../../state/library_state.dart';

/// 按 issue id 找回那个 issue 对象。
///
/// 详情页/阅读器只吃 ID 是为了支持深链（`/issue/<id>` 直接打开）。
/// 手上已经有对象时走 `initial` 快路径；否则按以下顺序兜底：
/// 1. 目录内存缓存（本次会话里加载过的指南/系列）
/// 2. 本地库已导入的
/// 3. 收藏里的快照
/// 4. 阅读进度里的快照
/// 5. `fandom:` 前缀的走 wiki 拉一次
Future<ComicIssue?> resolveIssue(
  BuildContext context,
  String issueId,
  ComicIssue? initial,
) async {
  if (initial != null && initial.id == issueId) return initial;

  final catalog = context.read<CatalogState>();
  final cached = catalog.findCachedIssue(issueId);
  if (cached != null) return cached;

  final library = context.read<LibraryState>();
  final imported = library.importedIssue(issueId);
  if (imported != null) return imported;

  final progress = library.progressFor(issueId);
  if (progress != null) return progress.issue;

  for (final fav in context.read<FavoritesState>().entries) {
    final issue = fav.asIssue;
    if (issue != null && issue.id == issueId) return issue;
  }

  if (issueId.startsWith('fandom:')) {
    return context.read<WikiRepository>().issueByPageName(
          issueId.substring('fandom:'.length),
        );
  }

  return null;
}