import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/comic_cover.dart';
import '../../core/widgets/tag_pill.dart';
import '../../data/getcomics_service.dart';
import '../../data/models/marvel_models.dart';
import '../../data/repository/catalog_repository.dart';
import '../../data/repository/preferences_repository.dart';
import '../../state/favorites_state.dart';
import '../../state/library_state.dart';

/// issue 详情：封面、简介、可点的创作者与系列、收藏/书单、导入与阅读。
class IssueDetailPage extends StatefulWidget {
  const IssueDetailPage({super.key, required this.issue});

  final ComicIssue issue;

  @override
  State<IssueDetailPage> createState() => _IssueDetailPageState();
}

class _IssueDetailPageState extends State<IssueDetailPage> {
  bool _importing = false;
  bool _resolvingSeries = false;

  String? _error;

  ComicIssue get _issue => widget.issue;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    // 收藏状态直接订阅，点❤️后收藏页同步更新
    final favorites = context.watch<FavoritesState>();
    final isFav = favorites.isFavorite(FavoriteKind.issue, _issue.id);
    final library = context.watch<LibraryState>();
    final imported = library.isImported(_issue.id);
    final progress = library.progressFor(_issue.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(_issue.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? p.like : null,
            ),
            tooltip: isFav ? '取消收藏' : '收藏',
            onPressed: () {
              final now = favorites.toggle(FavoriteEntry.fromIssue(_issue));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(now ? '已加入收藏' : '已取消收藏'),
                  duration: const Duration(milliseconds: 1200),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(Icons.playlist_add, size: 22),
            onSelected: (listId) {
              if (listId.isEmpty) {
                _createListAndAdd(favorites);
              } else {
                final inList = favorites.toggleListItem(
                  listId,
                  FavoriteEntry.fromIssue(_issue),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(inList ? '已加入书单' : '已从书单移除'),
                    duration: const Duration(milliseconds: 1200),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              for (final list in favorites.lists)
                PopupMenuItem(
                  value: list.id,
                  child: Row(
                    children: [
                      Icon(
                        favorites.containsInList(
                              list.id,
                              FavoriteKind.issue,
                              _issue.id,
                            )
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 18,
                        color: p.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          list.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: '', child: Text('＋ 新建书单')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: AppInsets.detail,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 180,
                height: 276,
                child: ComicCover(
                  url: _issue.coverUrl,
                  placeholderColor: p.coverFallback,
                  errorColor: p.coverPlaceholder,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _issue.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_issue.releaseDate.isNotEmpty)
                      Text(
                        _issue.releaseDate,
                        style: TextStyle(color: p.textFaint, fontSize: 12),
                      ),
                    // 系列名做成醒目的可点入口。指南来源的 issue 没有
                    // seriesId，点的时候用 lockjaw 按系列名现查再跳。
                    if (_issue.seriesTitle.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      InkWell(
                        onTap: _resolvingSeries ? null : _openSeries,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: p.brand.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: p.brand.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_resolvingSeries)
                                const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.library_books,
                                  size: 15,
                                  color: p.brand,
                                ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _issue.seriesTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.brand,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 15,
                                color: p.brand,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_issue.creators.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              '创作者',
              style: TextStyle(
                color: p.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // 每位创作者可点：跳搜索定位这个人的作品
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final creator in _issue.creators.take(8))
                  TagPill(
                    label: creator,
                    fontSize: 12.5,
                    height: 30,
                    onTap: () => AppRouter.openSearch(context, query: creator),
                  ),
              ],
            ),
          ],
          if (_issue.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _issue.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(_error!, style: TextStyle(color: p.danger)),
            ),
          if (_importing)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (imported) ...[
            FilledButton.icon(
              icon: const Icon(Icons.menu_book),
              label: Text(
                progress == null || progress.page == 0
                    ? '开始阅读'
                    : '继续阅读 · 第 ${progress.page + 1} 页',
              ),
              onPressed: () => AppRouter.openReader(context, _issue),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重新导入'),
              onPressed: _pickAndImport,
            ),
          ] else ...[
            if (!kIsWeb) ...[
              FilledButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('导入本地文件 (CBZ/ZIP)'),
                onPressed: _pickAndImport,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('去 GetComics 搜索下载'),
              onPressed: () => GetComicsService.open(
                GetComicsService.searchUrl(
                  _issue.seriesTitle,
                  _issue.issueNumber,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 跳到所属系列。有 seriesId 直接跳；没有（指南来源的 issue 只有标题）
  /// 用 lockjaw 现查官网系列 id。
  ///
  /// 匹配规则和官网 issue 页跳系列一致：标题里的括号年份用来锁定卷
  /// （"Secret Wars (2015)" 不能落到 1984 那卷），归一化后要求候选以
  /// 系列名开头——不能像之前那样取第一个结果，联想搜索前排全是变体封面。
  Future<void> _openSeries() async {
    final seriesId = _issue.seriesId;
    if (seriesId != null) {
      AppRouter.openSeries(context, seriesId, _issue.seriesTitle);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _resolvingSeries = true);
    try {
      final raw = _issue.seriesTitle; // 形如 "Secret Wars (2015)"
      final year = RegExp(r'[(（](\d{4})').firstMatch(raw)?.group(1);
      final base = raw.replaceAll(RegExp(r'\s*[(（]\d{4}.*?[)）]'), '').trim();
      final query = base.isEmpty ? raw : base;
      final norm = _normalizeTitle(query);
      final results = await context
          .read<CatalogRepository>()
          .searchOfficialSeries(query)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;

      // 变体封面/复刻版在官网是独立「系列」，先滤掉
      final noise = RegExp(
        r'variant|homage|facsimile|print|cover\s*[a-z]|tbd|blank',
        caseSensitive: false,
      );
      String? exact;
      String? prefix;
      for (final r in results) {
        final rn = _normalizeTitle(r.title);
        if (!rn.startsWith(norm) && !rn.contains(norm)) continue;
        if (noise.hasMatch(r.title)) continue;
        final rYear = RegExp(r'[(（](\d{4})').firstMatch(r.title)?.group(1);
        if (year != null && rYear == year) {
          exact = r.id;
          break;
        }
        prefix ??= r.id;
      }
      final hit = exact ?? prefix;
      if (hit != null) {
        AppRouter.openSeries(context, hit, base.isEmpty ? raw : base);
      } else {
        AppRouter.openSearch(context, query: _issue.seriesTitle);
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('没查到这个系列，试试搜索')));
    } finally {
      if (mounted) setState(() => _resolvingSeries = false);
    }
  }

  /// 标题归一化：小写、去年份括号、去符号——比对用。
  static String _normalizeTitle(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[(（][^)）]*[)）]'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _createListAndAdd(FavoritesState favorites) async {
    final name = await _promptListName();
    if (name == null || name.trim().isEmpty) return;
    final list = favorites.createList(name);
    favorites.toggleListItem(list.id, FavoriteEntry.fromIssue(_issue));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已创建「${list.name}」并加入这一期'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  Future<String?> _promptListName() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建书单'),
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

  Future<void> _pickAndImport() async {
    final library = context.read<LibraryState>();
    if (!library.isReady) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cbz', 'zip'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      await library.importArchive(_issue, path);
      if (mounted) setState(() => _importing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _error = '导入失败: $e';
        });
      }
    }
  }
}
