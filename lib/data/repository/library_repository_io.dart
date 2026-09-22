import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../models/marvel_models.dart';

/// 本地漫画库（io 平台）：管理已导入的 issue 文件与磁盘索引。
///
/// 阅读进度不放这里——它按 issue id 记在 `PreferencesRepository`，
/// 这样 Web 平台也能记住读到哪。
class LibraryRepository {
  final String root;
  final File _indexFile;
  final Map<String, ComicIssue> _issues = {};

  LibraryRepository(this.root) : _indexFile = File('$root/library.json');

  static Future<LibraryRepository> load(String root) async {
    final repo = LibraryRepository(root);
    await Directory(root).create(recursive: true);
    if (await repo._indexFile.exists()) {
      try {
        final data = json.decode(await repo._indexFile.readAsString())
            as Map<String, dynamic>;
        for (final item in (data['issues'] as List? ?? [])) {
          final issue = ComicIssue.fromJson(item as Map);
          repo._issues[issue.id] = issue;
        }
      } catch (_) {
        // 索引损坏就当作空库，用户重新导入即可
      }
    }
    return repo;
  }

  Future<void> save() async {
    final data = {
      'issues': _issues.values.map((i) => i.toJson()).toList(),
    };
    await _indexFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data));
  }

  bool isImported(String issueId) => _issues[issueId]?.localPath != null;

  ComicIssue? getImported(String issueId) =>
      _issues[issueId]?.localPath == null ? null : _issues[issueId];

  List<ComicIssue> get allImported =>
      _issues.values.where((i) => i.localPath != null).toList();

  /// 某个 issue 的全部页面图片路径（按文件名排序）。
  Future<List<String>> pagesFor(ComicIssue issue) async {
    final imported = _issues[issue.id];
    final path = imported?.localPath ?? issue.localPath;
    if (path == null) return const [];
    final dir = Directory(path);
    if (!await dir.exists()) return const [];
    final files = <File>[];
    await for (final e in dir.list()) {
      if (e is File && _isImage(e.path.split('/').last.split('\\').last)) {
        files.add(e);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files.map((f) => f.path).toList();
  }

  /// 导入压缩包（zip/cbz，嵌套压缩自动解开）。
  ///
  /// 注意：.cbr 如果是真 RAR 压缩（magic `Rar!`）这里解不了——
  /// Dart 生态没有 RAR5 解压器。先用 `tool/convert_cbr.py` 转成 CBZ。
  /// 有些 .cbr 其实是改了后缀的 zip，那种能直接进。
  Future<ComicIssue> importArchive(ComicIssue issue, String archivePath) async {
    if (isImported(issue.id)) return _issues[issue.id]!;

    final bytes = await File(archivePath).readAsBytes();
    if (bytes.length >= 8) {
      final magic = bytes.sublist(0, 8);
      final isRar = magic[0] == 0x52 && magic[1] == 0x61 &&
          magic[2] == 0x72 && magic[3] == 0x21;
      if (isRar) {
        throw UnsupportedError(
            '这个 CBR 是 RAR 压缩，应用内解不了。请先运行 '
            'tool/convert_cbr.py 把它转成 CBZ 再导入。');
      }
    }

    final seriesDir = _safeDirName(issue.seriesTitle);
    final issueDir = _safeDirName('issue-${issue.issueNumber}');
    final target = '$root/$seriesDir/$issueDir';
    await Directory(target).create(recursive: true);

    await _extractNested(ZipDecoder().decodeBytes(bytes), target);

    issue.localPath = target;
    _issues[issue.id] = issue;
    await save();
    return issue;
  }

  Future<void> _extractNested(Archive archive, String target) async {
    for (final file in archive) {
      final name = file.name.split('/').last;
      if (!file.isFile) continue;
      final lower = name.toLowerCase();
      if (lower.endsWith('.zip') || lower.endsWith('.cbz')) {
        final inner = ZipDecoder().decodeBytes(file.content as List<int>);
        await _extractNested(inner, target);
      } else if (_isImage(name)) {
        await File('$target/${_padName(name)}')
            .writeAsBytes(file.content as List<int>);
      }
    }
  }

  bool _isImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.avif');
  }

  /// 页面文件名补零，保证 "2.jpg" 排在 "10.jpg" 前面。
  String _padName(String name) {
    final m = RegExp(r'^(.*?)([0-9]+)(\.[^.]+)$').firstMatch(name);
    if (m == null) return name;
    return (m.group(1) ?? '') +
        (m.group(2) ?? '').padLeft(4, '0') +
        (m.group(3) ?? '');
  }

  String _safeDirName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'untitled' : cleaned;
  }
}