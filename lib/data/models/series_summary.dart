/// 系列页瀑布流用的系列摘要：不管来自官网还是 wiki，统一一个壳。
class SeriesSummary {
  const SeriesSummary({
    required this.title,
    this.seriesId,
    this.wikiPageName,
    this.coverUrl,
    this.issueCount = 0,
    this.latestIssue,
  });

  /// 展示标题。
  final String title;

  /// 官网系列 id（bifrost）。有它走官网系列页。
  final String? seriesId;

  /// wiki 页面名（形如 "Amazing Spider-Man Vol 5"）。官网没有时走 wiki 系列页。
  final String? wikiPageName;

  final String? coverUrl;

  /// 这个系列在来源数据里的期数（推荐位用）。
  final int issueCount;

  /// 最近一期的期号（有数据时展示）。
  final String? latestIssue;

  bool get fromWiki => seriesId == null && wikiPageName != null;

  Map<String, dynamic> toJson() => {
        'title': title,
        'seriesId': seriesId,
        'wikiPageName': wikiPageName,
        'coverUrl': coverUrl,
        'issueCount': issueCount,
        'latestIssue': latestIssue,
      };

  factory SeriesSummary.fromJson(Map json) => SeriesSummary(
        title: json['title']?.toString() ?? '',
        seriesId: json['seriesId']?.toString(),
        wikiPageName: json['wikiPageName']?.toString(),
        coverUrl: json['coverUrl']?.toString(),
        issueCount: (json['issueCount'] as num?)?.toInt() ?? 0,
        latestIssue: json['latestIssue']?.toString(),
      );
}

/// 官网系列详情（`/catalog/series/{id}`，无 /v1 前缀）。
class SeriesDetail {
  const SeriesDetail({
    required this.id,
    required this.title,
    this.description = '',
    this.coverUrl,
    this.startYear,
    this.endYear,
    this.comicsCount = 0,
  });

  final String id;
  final String title;
  final String description;

  /// 横版系列封面（系列资产支持 landscape 变体）。没有图时为 null。
  final String? coverUrl;

  final int? startYear;
  final int? endYear;
  final int comicsCount;

  factory SeriesDetail.fromBifrost(Map json) {
    final imageBase = json['image_url']?.toString() ?? '';
    final ext = json['image_extension']?.toString() ?? 'jpg';
    // 新系列常是 image_not_available，别拿它当封面
    final hasCover =
        imageBase.isNotEmpty && !imageBase.contains('image_not_available');
    return SeriesDetail(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      coverUrl: hasCover ? '$imageBase/landscape_incredible.$ext' : null,
      startYear: (json['start_year'] as num?)?.toInt(),
      endYear: (json['end_year'] as num?)?.toInt(),
      comicsCount: (json['comics_count'] as num?)?.toInt() ?? 0,
    );
  }
}