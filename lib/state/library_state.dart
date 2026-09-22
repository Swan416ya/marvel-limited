import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models/marvel_models.dart';
import '../data/repository/library_repository.dart';
import '../data/repository/preferences_repository.dart';

/// 本地库状态：已导入的漫画文件 + 阅读进度。
///
/// 阅读进度落在 `PreferencesRepository`（按 issue id），所以
/// 「已读/在读」在 Web 端同样有效，本地文件只在支持文件系统的平台上才有。
class LibraryState extends ChangeNotifier {
  LibraryState(this._prefs);

  final PreferencesRepository _prefs;

  LibraryRepository? library;
  bool initing = false;
  String? error;

  bool get isReady => library != null;

  Future<void> init() async {
    if (isReady || initing) return;
    initing = true;
    notifyListeners();
    try {
      if (kIsWeb) {
        library = await LibraryRepository.load('/tmp');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        library = await LibraryRepository.load('${dir.path}/library');
      }
    } catch (e) {
      error = e.toString();
    }
    initing = false;
    notifyListeners();
  }

  bool isImported(String issueId) => library?.isImported(issueId) ?? false;

  ComicIssue? importedIssue(String issueId) => library?.getImported(issueId);

  List<ComicIssue> get importedIssues => library?.allImported ?? const [];

  Future<List<String>> pagesFor(ComicIssue issue) async =>
      await library?.pagesFor(issue) ?? const [];

  /// 导入压缩包。成功后广播，列表页的「已导入」标记会立刻亮起来。
  Future<ComicIssue> importArchive(ComicIssue issue, String archivePath) async {
    final repo = library;
    if (repo == null) {
      throw StateError('本地库尚未初始化');
    }
    final saved = await repo.importArchive(issue, archivePath);
    notifyListeners();
    return saved;
  }

  // ── 阅读进度 ─────────────────────────────────────────────────

  ReadingProgress? progressFor(String issueId) => _prefs.progressFor(issueId);

  /// 首页「继续阅读」用：翻过页且没读完的，最近读的在前。
  List<ReadingProgress> get continueReading => _prefs.continueReading;

  List<ReadingProgress> get recentProgress => _prefs.recentProgress;

  bool isRead(String issueId) => _prefs.progressFor(issueId)?.isFinished ?? false;

  bool isReading(String issueId) =>
      _prefs.progressFor(issueId)?.isReading ?? false;

  Future<void> saveProgress(ReadingProgress progress) async {
    await _prefs.saveProgress(progress);
    notifyListeners();
  }

  Future<void> clearProgress(String issueId) async {
    await _prefs.clearProgress(issueId);
    notifyListeners();
  }

  // ── 书签 ─────────────────────────────────────────────────────

  List<IssueBookmark> bookmarksFor(String issueId) =>
      _prefs.bookmarksFor(issueId);

  bool hasBookmark(String issueId, int page) =>
      _prefs.hasBookmark(issueId, page);

  /// 加/去书签（同一页再点一次就是删）。返回「现在有没有」。
  bool toggleBookmark(String issueId, int page) {
    final now = _prefs.toggleBookmark(issueId, page);
    notifyListeners();
    return now;
  }
}