import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/comic_cover.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/state_views.dart';
import '../../data/repository/preferences_repository.dart';
import '../../state/favorites_state.dart';

/// 自建书单详情：改名、删除、逐项移除。
class UserListPage extends StatelessWidget {
  const UserListPage({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesState>();
    // 书单列表本身可能被别的入口改过，按 id 找当前的
    final list = favorites.lists
        .cast<UserList?>()
        .firstWhere((l) => l!.id == listId, orElse: () => null);

    if (list == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(
          icon: Icons.playlist_remove_outlined,
          title: '这个书单已经不存在了',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: '重命名',
            onPressed: () => _rename(context, favorites, list),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '删除书单',
            onPressed: () => _delete(context, favorites, list),
          ),
        ],
      ),
      body: list.items.isEmpty
          ? const EmptyView(
              icon: Icons.playlist_add_outlined,
              title: '书单还是空的',
              subtitle: '在漫画/系列/指南的详情页里点「加入书单」',
            )
          : ListView.builder(
              padding: AppInsets.page,
              itemCount: list.items.length,
              itemBuilder: (context, i) {
                final entry = list.items[i];
                return Dismissible(
                  key: ValueKey('list-${list.id}-${entry.kind.name}-${entry.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.xl),
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: context.p.like.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.remove_circle_outline, color: context.p.like),
                  ),
                  onDismissed: (_) =>
                      favorites.toggleListItem(list.id, entry),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xs,
                    ),
                    leading: SizedBox(
                      width: 52,
                      height: 72,
                      child: ComicCover(
                        url: entry.coverUrl,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        placeholderColor: context.p.fillStrong,
                      ),
                    ),
                    title: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: entry.subtitle == null
                        ? null
                        : Text(
                            entry.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.p.textFaint,
                              fontSize: 12,
                            ),
                          ),
                    trailing: CoverBadge(
                      label: switch (entry.kind) {
                        FavoriteKind.issue => '期',
                        FavoriteKind.series => '系列',
                        FavoriteKind.guide => '指南',
                      },
                      color: context.p.fillStrong,
                      foreground: context.p.textMuted,
                    ),
                    onTap: () => _open(context, entry),
                  ),
                );
              },
            ),
    );
  }

  void _open(BuildContext context, FavoriteEntry entry) {
    switch (entry.kind) {
      case FavoriteKind.issue:
        final issue = entry.asIssue;
        if (issue != null) AppRouter.openIssue(context, issue);
      case FavoriteKind.series:
        AppRouter.openSeries(context, entry.id, entry.title);
      case FavoriteKind.guide:
        AppRouter.openGuide(context, entry.asGuide);
    }
  }

  Future<void> _rename(
    BuildContext context,
    FavoritesState favorites,
    UserList list,
  ) async {
    final controller = TextEditingController(text: list.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名书单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    favorites.renameList(list.id, name.trim());
  }

  Future<void> _delete(
    BuildContext context,
    FavoritesState favorites,
    UserList list,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「${list.name}」？'),
        content: const Text('书单里的收藏不会被取消收藏。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    favorites.deleteList(list.id);
    if (context.mounted) Navigator.of(context).maybePop();
  }
}