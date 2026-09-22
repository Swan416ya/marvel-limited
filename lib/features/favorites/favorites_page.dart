import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/comic_cover.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/tab_app_bar.dart';
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

    final showLists = _filter == _Filter.all || _filter == _Filter.list;
    final filtered = switch (_filter) {
      _Filter.all => entries,
      _Filter.list => const <FavoriteEntry>[],
      _ => entries.where((e) => e.kind.name == _filter.name).toList(),
    };

    final empty = filtered.isEmpty && (!showLists || lists.isEmpty);

    return Scaffold(
      appBar: const TabAppBar(word: 'COLLECTION'),
      body: Column(
        children: [
          _filters(counts),
          Expanded(
            // 注意：空态也要显示「+」导入卡——收藏为空时它往往是
            // 用户最先要用的功能，藏在 ListView 里会跟着空态一起消失。
            child: ListView(
              padding: AppInsets.page,
              children: [
                if (empty)
                  // ListView 里没有高度约束，给空态一个固定高度居中
                  SizedBox(
                    height: 460,
                    child: _emptyFor(_filter),
                  )
                else ...[
                  if (showLists) ..._listSection(lists),
                  if (_filter == _Filter.all && lists.isNotEmpty && filtered.isNotEmpty)
                    const _SectionLabel('收藏的内容'),
                  ...filtered.map((e) => _swipeable(e)),
                ],
                if (_filter == _Filter.all || _filter == _Filter.issue)
                  const _ImportCard(),
              ],
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
          final selected = f == _filter;
          return Center(
            child: ChoiceChip(
              label: Text('${f.label} ${counts[f] ?? 0}'),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f),
              showCheckmark: false,
              labelStyle: TextStyle(
                color: selected
                    ? context.p.textPrimary
                    : context.p.textMuted,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              backgroundColor: context.p.fill,
              selectedColor: context.p.brand.withValues(alpha: 0.22),
              side: BorderSide(
                color: selected ? context.p.brand : context.p.border,
              ),
            ),
          );
        },
      ),
    );
  }

  EmptyView _emptyFor(_Filter filter) {
    if (filter == _Filter.list) {
      return EmptyView(
        icon: Icons.playlist_add_outlined,
        title: '还没有自建书单',
        subtitle: '在详情页的「加入书单」里新建一个',
        action: FilledButton.tonalIcon(
          onPressed: () => _createList(),
          icon: const Icon(Icons.add),
          label: const Text('新建书单'),
        ),
      );
    }
    return EmptyView(
      icon: Icons.favorite_outline,
      title: '这里还没有收藏',
      subtitle: filter == _Filter.all
          ? '漫画、系列、指南都能收藏，详情页右上角的心形按钮'
          : '去${filter.label}相关的详情页点收藏',
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
      child: _FavoriteTile(entry: entry),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: context.p.textFaint,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 末尾的「+」导入卡。点 = 选文件进导入流程（可逐个核对匹配）；
/// 长按 = 多选批量，直接进流程一键全导。
class _ImportCard extends StatelessWidget {
  const _ImportCard();

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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: InkWell(
        onTap: () => _pick(context, batch: false),
        onLongPress: () => _pick(context, batch: true),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: p.fill,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: p.brand.withValues(alpha: 0.35),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 22, color: p.brand),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '导入本地漫画（CBZ/ZIP）',
                  style: TextStyle(
                    color: p.brand,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '长按批量',
                  style: TextStyle(color: p.textGhost, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 一条收藏：封面（带种类角标）+ 标题 + 副标题/进度。
class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.entry});

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

  @override
  Widget build(BuildContext context) {
    final progress = entry.kind == FavoriteKind.issue
        ? context.watch<LibraryState>().progressFor(entry.id)
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      leading: SizedBox(
        width: 52,
        height: 72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ComicCover(
              url: entry.coverUrl,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              placeholderColor: context.p.fillStrong,
            ),
            // 种类角标：全部视图里一眼区分这是什么
            Positioned(
              left: 0,
              top: 0,
              child: CoverBadge(
                label: switch (entry.kind) {
                  FavoriteKind.issue => '期',
                  FavoriteKind.series => '系列',
                  FavoriteKind.guide => '指南',
                },
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              ),
            ),
          ],
        ),
      ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: _subtitle(context, progress),
      trailing: Icon(Icons.chevron_right, color: context.p.textGhost),
      onTap: () => _open(context),
    );
  }

  Widget? _subtitle(BuildContext context, ReadingProgress? progress) {
    final p = context.p;
    if (progress != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.xs),
          Text(
            progress.isFinished
                ? '已读完 · 共 ${progress.totalPages} 页'
                : '第 ${progress.page + 1} / ${progress.totalPages} 页',
            style: TextStyle(
              color: progress.isFinished ? p.success : p.brand,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.ratio,
              minHeight: 3,
              backgroundColor: p.fillStrong,
              valueColor: AlwaysStoppedAnimation(
                progress.isFinished ? p.success : p.brand,
              ),
            ),
          ),
        ],
      );
    }
    if (entry.subtitle == null || entry.subtitle!.isEmpty) return null;
    return Text(
      entry.subtitle!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: p.textFaint, fontSize: 12),
    );
  }
}