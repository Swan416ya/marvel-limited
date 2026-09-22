import 'package:flutter/foundation.dart';

import '../data/models/marvel_models.dart';
import '../data/repository/catalog_repository.dart';

/// 官网目录状态：阅读指南列表 + 各详情页取数入口。
///
/// 列表页的加载/错误/空三态挂在这里，详情页的取数直接透给仓库
/// （详情页是一次性的 pushed route，自己管自己的 loading 更简单）。
class CatalogState extends ChangeNotifier {
  CatalogState(this._repo);

  final CatalogRepository _repo;

  /// null 表示还没加载过。
  List<ReadingGuide>? guides;
  String? guidesError;
  bool loadingGuides = false;

  bool get isReady => guides != null;

  Future<void> loadGuides({bool force = false}) async {
    if (loadingGuides) return;
    if (!force && guides != null) return;

    loadingGuides = true;
    guidesError = null;
    notifyListeners();

    try {
      guides = await _repo.readingGuides(force: force);
    } catch (e) {
      guidesError = e.toString();
    }
    loadingGuides = false;
    notifyListeners();
  }

  /// 下拉刷新：清掉指南列表缓存重新拉。
  Future<void> refresh() async {
    _repo.evictGuides();
    guides = null;
    await loadGuides(force: true);
  }

  Future<List<ComicIssue>> guideIssues(String guideId, {bool force = false}) =>
      _repo.readingGuideIssues(guideId, force: force);

  Future<List<ComicIssue>> seriesIssues(String seriesId, {bool force = false}) =>
      _repo.seriesIssues(seriesId, force: force);

  ComicIssue? findCachedIssue(String issueId) => _repo.findCachedIssue(issueId);

  /// 首页 hero 用：取第一个有封面的指南。
  ReadingGuide? get featuredGuide {
    final list = guides;
    if (list == null || list.isEmpty) return null;
    return list.firstWhere((g) => g.coverUrl != null, orElse: () => list.first);
  }
}