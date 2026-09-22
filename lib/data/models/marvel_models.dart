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
    final imageBase = (json['image_url'] ?? '') as String;
    final ext = (json['thumb_ext'] ?? 'jpg') as String;
    final digital = meta['digital_comic'] as Map?;
    return ComicIssue(
      id: json['id'].toString(),
      title: (json['title'] ?? '') as String,
      seriesTitle: (series?['title'] ?? '') as String,
      seriesId: series?['id']?.toString(),
      issueNumber: json['issue_number'].toString(),
      releaseDate: (json['release_date'] ?? '') as String,
      description: (json['summary'] ?? meta['description'] ?? '') as String,
      coverUrl: imageBase.isEmpty
          ? null
          : imageBase.startsWith('http')
              ? '$imageBase/portrait_uncanny.$ext'
              : 'https://cdn.marvel.com/u/prod/marvel$imageBase/portrait_uncanny.$ext',
      creators: ((json['creators'] ?? []) as List).map((e) => e.toString()).toList(),
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

  factory ComicIssue.fromJson(Map json) => ComicIssue(
    id: json['id'],
    title: json['title'],
    seriesTitle: json['seriesTitle'] ?? '',
    seriesId: json['seriesId'],
    issueNumber: json['issueNumber'] ?? '',
    releaseDate: json['releaseDate'] ?? '',
    description: json['description'] ?? '',
    coverUrl: json['coverUrl'],
    creators: (json['creators'] as List? ?? []).map((e) => e.toString()).toList(),
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
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
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
