import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/comic_cover.dart';
import '../../core/widgets/cover_grid.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/tab_app_bar.dart';
import '../../core/widgets/tag_pill.dart';
import '../../data/repository/preferences_repository.dart';
import '../../state/favorites_state.dart';
import '../../state/library_state.dart';

/// 收藏 tab。
///
/// 四类收藏（漫画期 / 系列 / 指南）+ 自建书单：
/// - 顶部按种类筛选，每种有自己的视图；
/// - 全部视图里封面带种类角标；
/// - 左滑移除带撤销；issue 行内显示阅读进度。
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

enum _Filter {
  all('全部'),
  issue('漫画'),
  series('系列'),
  guide('指南'),
  list('书单');

  const _Filter(this.label);
  final String label;
}

class _FavoritesPageState extends State<FavoritesPage> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesState>();
    final entries = favorites.entries;
    final lists = favorites.lists;

    final counts = {
      _Filter.all: entries.length + lists.length,
      _Filter.issue: entries.where((e) => e.kind == FavoriteKind.issue).length,
      _Filter.series: entries.where((e) => e.kind == FavoriteKind.series).length,
      _Filter.guide: entries.where((e) => e.kind == FavoriteKind.guide).length,
      _Filter.list: lists.length,
    };

    final filtered = switch (_filter) {
      _Filter.all => entries,
      _Filter.list => const <FavoriteEntry>[],
      _ => entries.where((e) => e.kind.name == _filter.name).toList(),
    };

    final showShelf = _filter == _Filter.all || _filter == _Filter.issue;

    return Scaffold(
      appBar: const TabAppBar(word: 'COLLECTION'),
      body: Column(
        children: [
          _filters(counts),
          Expanded(
            // 书架式：漫画封面一行一行排列，「+」是最后一本的下一本——
            // 灰色、和封面同尺寸的方块，点击导入本地漫画。
            child: _filter == _Filter.list || !showShelf
                ? ListView(
                    padding: AppInsets.page,
                    children: [
                      if (_filter == _Filter.list) ..._listSection(lists),
                      if (_filter == _Filter.series || _filter == _Filter.guide)
                        ...filtered.map((e) => _swipeable(e)),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, c) {
                      // 比例按真实宽度算：固定 0.55 在窄屏会差几像素，
                      // 卡片标题就被 overflow 顶掉
                      final usable = c.maxWidth - AppInsets.page.horizontal;
                      final cols = CoverGrid.columnsFor(
                        usableWidth: usable,
                        maxCellWidth: 150,
                        crossSpacing: AppSpacing.md,
                      );
                      return GridView.builder(
                        padding: AppInsets.page,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          childAspectRatio: CoverGrid.aspectFor(
                            usableWidth: usable,
                            columns: cols,
                            textBlockHeight: 32, // 标题两行
                            crossSpacing: AppSpacing.md,
                          ),
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                        ),
                        itemCount: filtered.length + 1,
                        itemBuilder: (context, i) {
                          // 最后一格永远是「+」导入卡
                          if (i == filtered.length) {
                            return const _ImportBookCard();
                          }
                          return _ShelfBookTile(entry: filtered[i]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filters(Map<_Filter, int> counts) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: _Filter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final f = _Filter.values[i];
          return Center(
            child: TagPill(
              label: '${f.label} ${counts[f] ?? 0}',
              selected: f == _filter,
              onTap: () => setState(() => _filter = f),
            ),
          );
        },
      ),
    );
  }

  // ── 自建书单 ─────────────────────────────────────────────────

  List<Widget> _listSection(List<UserList> lists) {
    return [
      if (_filter == _Filter.list)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _createList,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新建书单'),
            ),
          ),
        ),
      for (final list in lists)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.p.fillStrong,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(Icons.playlist_play, color: context.p.textMuted),
          ),
          title: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${list.items.length} 项'),
          trailing: const Icon(Icons.chevron_right, color: null),
          onTap: () => AppRouter.openUserList(context, list),
        ),
      if (lists.isNotEmpty) const SizedBox(height: AppSpacing.sm),
    ];
  }

  Future<void> _createList() async {
    final favorites = context.read<FavoritesState>();
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptName(context, title: '新建书单');
    if (name == null || name.trim().isEmpty) return;
    final list = favorites.createList(name);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('已创建「${list.name}」'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  Future<String?> _promptName(BuildContext context,
      {required String title, String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: '书单名称'),
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
  }

  // ── 收藏条目 ─────────────────────────────────────────────────

  Widget _swipeable(FavoriteEntry entry) {
    return Dismissible(
      key: ValueKey('fav-${entry.kind.name}-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        decoration: BoxDecoration(
          color: context.p.like.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(Icons.heart_broken_outlined, color: context.p.like),
      ),
      onDismissed: (_) {
        final favorites = context.read<FavoritesState>();
        final messenger = ScaffoldMessenger.of(context);
        final index = favorites.remove(entry);
        messenger.showSnackBar(
          SnackBar(
            content: Text('已移除《${entry.title}》'),
            action: SnackBarAction(
              label: '撤销',
              onPressed: () => favorites.restore(entry, index),
            ),
          ),
        );
      },
      child: _ShelfBookTile(entry: entry),
    );
  }
}

/// 书架末尾的「+」导入卡：作为最后一本书的下一本——灰色、
/// 和漫画封面同尺寸的方块，中间一个加号。
/// 点 = 选文件进导入流程（可逐个核对匹配）；长按 = 多选批量。
class _ImportBookCard extends StatelessWidget {
  const _ImportBookCard();

  Future<void> _pick(BuildContext context, {required bool batch}) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web 预览不支持本地导入，请使用 Android 版')),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cbz', 'zip', 'cbr'],
      allowMultiple: batch,
    );
    final paths = result?.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList() ??
        const <String>[];
    if (paths.isEmpty) return;
    if (!context.mounted) return;
    context.pushNamed(RouteNames.importFlow, extra: paths);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _pick(context, batch: false),
            onLongPress: () => _pick(context, batch: true),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              decoration: BoxDecoration(
                color: p.fillStrong,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: p.textFaint,
                  width: 1.4,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.add,
                  size: 40,
                  color: p.textMuted,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '导入本地漫画',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: p.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 书架上的一本：封面（2:3，带种类角标、进度条）+ 标题。
/// 长按移除（带撤销）。
class _ShelfBookTile extends StatelessWidget {
  const _ShelfBookTile({required this.entry});

  final FavoriteEntry entry;

  void _open(BuildContext context) {
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

  void _remove(BuildContext context) {
    final favorites = context.read<FavoritesState>();
    final messenger = ScaffoldMessenger.of(context);
    final index = favorites.remove(entry);
    messenger.showSnackBar(
      SnackBar(
        content: Text('已移除《${entry.title}》'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => favorites.restore(entry, index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final progress = entry.kind == FavoriteKind.issue
        ? context.watch<LibraryState>().progressFor(entry.id)
        : null;

    return InkWell(
      onTap: () => _open(context),
      onLongPress: () => _remove(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ComicCover(
                  url: entry.coverUrl,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  placeholderIcon: Icons.menu_book,
                ),
                // 种类角标
                Positioned(
                  left: 4,
                  top: 4,
                  child: CoverBadge(
                    label: switch (entry.kind) {
                      FavoriteKind.issue => '期',
                      FavoriteKind.series => '系列',
                      FavoriteKind.guide => '指南',
                    },
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                  ),
                ),
                // 在读进度条压在封面底部
                if (progress != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AppRadius.md),
                      ),
                      child: LinearProgressIndicator(
                        value: progress.ratio,
                        minHeight: 3,
                        backgroundColor: p.badge,
                        valueColor: AlwaysStoppedAnimation(
                          progress.isFinished ? p.success : p.brand,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 11.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
