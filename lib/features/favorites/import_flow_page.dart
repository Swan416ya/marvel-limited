import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/tab_app_bar.dart';
import '../../data/filename_matcher.dart';
import '../../data/models/marvel_models.dart';
import '../../data/repository/catalog_repository.dart';
import '../../state/library_state.dart';

/// 一个待导入的文件及其匹配状态。
class _PendingFile {
  _PendingFile({required this.path, required this.parsed});

  final String path;
  final ParsedFilename parsed;

  /// 用户确认的匹配（null = 未匹配）。
  ComicIssue? match;

  /// 候选项（点条目时现查）。
  List<ComicIssue> candidates = const [];

  bool importing = false;
  String? error;
  bool done = false;

  String get fileName => path.split('/').last.split('\\').last;
}

/// 本地漫画导入流程：
/// 1. 选文件（收藏页「+」进来，或多选批量）；
/// 2. 文件名自动解析「系列 + 期号」，先撞本地缓存，再查官网（lockjaw）；
/// 3. 每个文件可以点开改匹配（候选列表）；
/// 4. 「全部导入」把匹配好的落库。
class ImportFlowPage extends StatefulWidget {
  const ImportFlowPage({super.key, required this.initialPaths});

  /// 调用方已经选好的文件（批量模式直接进来）。
  final List<String> initialPaths;

  @override
  State<ImportFlowPage> createState() => _ImportFlowPageState();
}

class _ImportFlowPageState extends State<ImportFlowPage> {
  final List<_PendingFile> _files = [];
  bool _matching = false;

  @override
  void initState() {
    super.initState();
    for (final p in widget.initialPaths) {
      _files.add(_PendingFile(path: p, parsed: parseComicFilename(p)));
    }
    _autoMatchAll();
  }

  /// 自动匹配：本地缓存 → lockjaw 官网系列。
  Future<void> _autoMatchAll() async {
    setState(() => _matching = true);
    final local = context.read<CatalogRepository>().cachedIssues;

    var matched = 0;
    for (final f in _files) {
      if (f.done) continue;
      // 1) 本地缓存命中
      f.match = matchLocalIssue(f.parsed, local);
      if (f.match != null) {
        matched++;
        continue;
      }
      // 2) lockjaw 官网系列
      if (f.parsed.hasIssue && f.parsed.seriesGuess.isNotEmpty) {
        try {
          final results = await context
              .read<CatalogRepository>()
              .searchOfficialSeries(f.parsed.seriesGuess)
              .timeout(const Duration(seconds: 10));
          if (results.isNotEmpty) {
            final best = results.first;
            f.match = issueFromOfficialSeries(
              seriesId: best.id,
              seriesTitle: best.title,
              issueNumber: f.parsed.issueNumber!,
            );
            matched++;
          }
        } catch (_) {
          // 官网查不到就留空，用户手动改
        }
      }
    }
    if (!mounted) return;
    setState(() => _matching = false);
    debugPrint('[Import] 自动匹配 $matched/${_files.length}');
  }

  /// 导入所有已匹配且未导入的文件。
  Future<void> _importAll() async {
    final library = context.read<LibraryState>();
    var ok = 0;
    var fail = 0;
    for (final f in _files) {
      if (f.done || f.match == null) continue;
      setState(() => f.importing = true);
      try {
        await library.importArchive(f.match!, f.path);
        f.done = true;
        ok++;
      } catch (e) {
        f.error = e.toString();
        fail++;
      }
      if (mounted) setState(() => f.importing = false);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('导入完成：$ok 成功${fail > 0 ? '，$fail 失败' : ''}')),
    );
  }

  /// 点一个文件：展示候选 / 改匹配。
  Future<void> _editMatch(_PendingFile f) async {
    final p = context.p;
    // 现查候选（lockjaw 前五个）
    if (f.parsed.seriesGuess.isNotEmpty) {
      try {
        final results = await context
            .read<CatalogRepository>()
            .searchOfficialSeries(f.parsed.seriesGuess)
            .timeout(const Duration(seconds: 10));
        f.candidates = [
          for (final r in results.take(6))
            if (f.parsed.hasIssue)
              issueFromOfficialSeries(
                seriesId: r.id,
                seriesTitle: r.title,
                issueNumber: f.parsed.issueNumber!,
              ),
        ];
      } catch (_) {
        f.candidates = const [];
      }
    }

    if (!mounted) return;
    final selected = await showModalBottomSheet<ComicIssue>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _MatchSheet(file: f),
    );
    if (selected != null) {
      setState(() => f.match = selected);
    }
  }

  /// 追加更多文件（页面里的「继续添加」）。
  Future<void> _pickMore() async {
    if (kIsWeb) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cbz', 'zip', 'cbr'],
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final file in result.files) {
        if (file.path == null) continue;
        _files.add(_PendingFile(path: file.path!, parsed: parseComicFilename(file.path!)));
      }
    });
    _autoMatchAll();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final matchedCount = _files.where((f) => f.match != null).length;

    return Scaffold(
      appBar: TabAppBar(word: 'COLLECTION'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Text(
                  '${_files.length} 个文件 · $matchedCount 已匹配',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickMore,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('继续添加'),
                ),
              ],
            ),
          ),
          if (_matching)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '正在自动匹配（官网搜索）…',
                style: TextStyle(color: p.textFaint, fontSize: 12),
              ),
            ),
          Expanded(
            child: _files.isEmpty
                ? Center(
                    child: Text('没有选择文件',
                        style: TextStyle(color: p.textFaint)))
                : ListView.builder(
                    padding: const EdgeInsets.only(
                        bottom: AppSpacing.navBarClearance),
                    itemCount: _files.length,
                    itemBuilder: (context, i) => _fileTile(p, _files[i]),
                  ),
          ),
          // 底部导入按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: matchedCount == 0 ? null : _importAll,
                  icon: const Icon(Icons.download),
                  label: Text('导入 $matchedCount 个匹配的文件'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileTile(AppPalette p, _PendingFile f) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: 2),
      leading: _statusIcon(p, f),
      title: Text(
        f.parsed.cleanTitle ?? f.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: f.match != null ? p.textPrimary : p.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        f.done
            ? '已导入 ✓'
            : f.importing
                ? '导入中…'
                : f.error != null
                    ? f.error!
                    : f.match != null
                        ? '匹配：${f.match!.seriesTitle} #${f.match!.issueNumber}'
                        : f.parsed.hasIssue
                            ? '未匹配（点我手动选择）'
                            : '没解析出期号（点我手动选择）',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: f.done
              ? p.success
              : f.match != null
                  ? p.textFaint
                  : p.textGhost,
          fontSize: 12,
        ),
      ),
      trailing: f.done
          ? Icon(Icons.check_circle, color: p.success, size: 20)
          : Icon(Icons.edit_outlined, size: 18, color: p.textGhost),
      onTap: f.done ? null : () => _editMatch(f),
    );
  }

  Widget _statusIcon(AppPalette p, _PendingFile f) {
    if (f.done) {
      return Icon(Icons.check_circle, color: p.success, size: 24);
    }
    if (f.match != null) {
      return Icon(Icons.link, color: p.brand, size: 24);
    }
    if (f.fileName.toLowerCase().endsWith('.cbr')) {
      return Icon(Icons.warning_amber_rounded, color: p.danger, size: 24);
    }
    return Icon(Icons.help_outline, color: p.textGhost, size: 24);
  }
}

/// 改匹配的底部弹层：候选列表 + 手动输入期号。
class _MatchSheet extends StatelessWidget {
  const _MatchSheet({required this.file});

  final _PendingFile file;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              '选择正确的匹配',
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              '文件：${file.fileName}',
              style: TextStyle(color: p.textFaint, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in file.candidates)
                  ListTile(
                    dense: true,
                    title: Text('${c.seriesTitle} #${c.issueNumber}',
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text('官网系列',
                        style: TextStyle(color: p.textFaint, fontSize: 11)),
                    onTap: () => Navigator.of(context).pop(c),
                  ),
                if (file.candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      '官网没搜到候选。可以试试直接导入为「未关联」条目，之后从详情页再关联。',
                      style: TextStyle(color: p.textFaint, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          // 兜底：按解析结果直接导入（无关联）
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.content_paste_off, size: 16),
                label: Text(
                  '按文件名导入（${file.parsed.cleanTitle ?? '未命名'}）',
                ),
                onPressed: file.parsed.hasIssue
                    ? () => Navigator.of(context).pop(ComicIssue(
                          id: 'file:${file.fileName}',
                          title:
                              '${file.parsed.seriesGuess} #${file.parsed.issueNumber}',
                          seriesTitle: file.parsed.seriesGuess,
                          issueNumber: file.parsed.issueNumber!,
                          releaseDate: '',
                          description: '',
                        ))
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}