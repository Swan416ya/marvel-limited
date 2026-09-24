class ComicIssue {
  final String id;
  final String title;
  final String seriesTitle;
  final String? seriesId;
  final String issueNumber;
  final String releaseDate;
  final String description;
  final String? coverUrl;
  final List<String> creators;
  final bool isVariant;
  final bool inMu;

  String? localPath;

  ComicIssue({
    required this.id,
    required this.title,
    required this.seriesTitle,
    this.seriesId,
    required this.issueNumber,
    required this.releaseDate,
    required this.description,
    this.coverUrl,
    this.creators = const [],
    this.isVariant = false,
    this.inMu = false,
    this.localPath,
  });

  factory ComicIssue.fromBifrost(Map json) {
    final meta = (json['metadata'] ?? json) as Map;
    final series = meta['series'] as Map?;
    final imageBase = json['image_url']?.toString() ?? '';
    final ext = json['thumb_ext']?.toString() ?? 'jpg';
    final digital = meta['digital_comic'] as Map?;
    return ComicIssue(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      seriesTitle: series?['title']?.toString() ?? '',
      seriesId: series?['id']?.toString(),
      issueNumber: json['issue_number'].toString(),
      releaseDate: json['release_date']?.toString() ?? '',
      description: (json['summary'] ?? meta['description'])?.toString() ?? '',
      coverUrl: imageBase.isEmpty
          ? null
          : imageBase.startsWith('http')
          ? '$imageBase/portrait_uncanny.$ext'
          : 'https://cdn.marvel.com/u/prod/marvel$imageBase/portrait_uncanny.$ext',
      creators: ((json['creators'] ?? []) as List)
          .map((e) => e.toString())
          .toList(),
      isVariant: json['is_variant'].toString() == '1',
      inMu: digital?['in_mu'] == true || digital?['in_mu'].toString() == 'true',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'seriesTitle': seriesTitle,
    'seriesId': seriesId,
    'issueNumber': issueNumber,
    'releaseDate': releaseDate,
    'description': description,
    'coverUrl': coverUrl,
    'creators': creators,
    'isVariant': isVariant,
    'inMu': inMu,
    'localPath': localPath,
  };

  /// 换个别字段用（字段一多，手抄必漏）。
  ComicIssue copyWith({
    String? title,
    String? seriesTitle,
    String? issueNumber,
    String? releaseDate,
    String? description,
    String? coverUrl,
  }) => ComicIssue(
    id: id,
    title: title ?? this.title,
    seriesTitle: seriesTitle ?? this.seriesTitle,
    seriesId: seriesId,
    issueNumber: issueNumber ?? this.issueNumber,
    releaseDate: releaseDate ?? this.releaseDate,
    description: description ?? this.description,
    coverUrl: coverUrl ?? this.coverUrl,
    creators: creators,
    isVariant: isVariant,
    inMu: inMu,
    localPath: localPath,
  );

  factory ComicIssue.fromJson(Map json) => ComicIssue(
    id: json['id'],
    title: json['title'],
    seriesTitle: json['seriesTitle'] ?? '',
    seriesId: json['seriesId'],
    issueNumber: json['issueNumber'] ?? '',
    releaseDate: json['releaseDate'] ?? '',
    description: json['description'] ?? '',
    coverUrl: json['coverUrl'],
    creators: (json['creators'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    isVariant: json['isVariant'] == true,
    inMu: json['inMu'] == true,
    localPath: json['localPath'],
  );
}

class ComicSeries {
  final String id;
  final String title;
  final String description;
  final String? coverUrl;
  final int totalIssues;

  ComicSeries({
    required this.id,
    required this.title,
    this.description = '',
    this.coverUrl,
    this.totalIssues = 0,
  });
}

/// 官网 lockjaw 联想搜索命中的资源类型（由链接前缀决定）。
enum OfficialSearchKind {
  /// 系列页（`/comics/series/<id>`）。
  series,

  /// 单期页（`/comics/issue/<id>`）。
  issue,
}

class ReadingGuide {
  final String id;
  final String title;
  final String description;
  final String? coverUrl;
  final List issues;

  ReadingGuide({
    required this.id,
    required this.title,
    this.description = '',
    this.coverUrl,
    this.issues = const [],
  });

  factory ReadingGuide.fromBifrostList(Map json) {
    final images = (json['images'] as List?) ?? [];
    final img = images.isNotEmpty ? images.first as Map : null;
    return ReadingGuide(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      coverUrl: img == null ? null : '${img['path']}.${img['extension']}',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'coverUrl': coverUrl,
  };

  factory ReadingGuide.fromJson(Map json) => ReadingGuide(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    coverUrl: json['coverUrl']?.toString(),
  );
}
