import '../models/marvel_models.dart';

/// Web 平台存根：浏览器无法访问本地文件系统，导入功能仅 Android/桌面可用。
class LibraryRepository {
  final String root;
  LibraryRepository(this.root);

  static Future<LibraryRepository> load(String root) async =>
      LibraryRepository(root);

  Future<void> save() async {}

  bool isImported(String issueId) => false;

  ComicIssue? getImported(String issueId) => null;

  List<ComicIssue> get allImported => const [];

  Future<List<String>> pagesFor(ComicIssue issue) async => const [];

  Future<ComicIssue> importArchive(ComicIssue issue, String archivePath) async {
    throw UnsupportedError('Web 平台不支持本地导入，请使用 Android 版');
  }
}