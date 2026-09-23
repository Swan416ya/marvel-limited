/// 静态大事件数据模型。数据来自 `assets/data/marvel_events.json`，
/// 由编译期外的人工整理（见文件头注释），应用内不联网也能看。
class MarvelEvent {
  const MarvelEvent({
    required this.id,
    required this.title,
    required this.titleZh,
    required this.tier,
    required this.year,
    required this.oneLiner,
    this.coreOrder = const [],
    this.optionalOrder = const [],
    this.readingOrder = const [],
    this.imageUrl,
  });

  final String id;

  /// 英文原名。
  final String title;

  /// 中文译名。
  final String titleZh;

  /// 分级：company（全公司级最大事件）/ cosmic / earth / spider / xmen，
  /// 以及两个平行宇宙线：ultimate1610（地球-1610 终极宇宙）、
  /// ultimate6160（地球-6160 新终极宇宙）。
  final String tier;

  final int year;

  /// 一句话介绍。
  final String oneLiner;

  /// 核心阅读顺序（必读主线）。
  final List<EventReadingItem> coreOrder;

  /// 可选延伸（配角线 / tie-in）。
  final List<EventReadingItem> optionalOrder;

  /// 逐期导读（本地整理、按发行日期排序）。
  ///
  /// 官方阅读指南只覆盖一部分事件，剩下的靠这份数据：一本一本列出来，
  /// 每期都带发行日期与可打开的 id。由 `tool/build_reading_orders.py`
  /// 从 Marvel Database 生成。
  final List<EventIssue> readingOrder;

  /// 主视觉图（漫威 CDN 或 fandom wiki 直链），可能为空。
  final String? imageUrl;

  static const tierLabels = {
    'company': '主线',
    'cosmic': '宇宙线',
    'earth': '地球线',
    'spider': '蜘蛛侠线',
    'xmen': 'X 战警线',
    'ultimate1610': '1610 终极宇宙',
    'ultimate6160': '6160 新终极宇宙',
  };

  /// tier 的展示名，未知值原样返回。
  String get tierLabel => tierLabels[tier] ?? tier;

  /// 是否官方盖章的全公司级（列表里要放在最显要的位置）。
  bool get isCompanyWide => tier == 'company';

  factory MarvelEvent.fromJson(Map json) => MarvelEvent(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    titleZh: json['titleZh']?.toString() ?? '',
    tier: json['tier']?.toString() ?? 'earth',
    year: (json['year'] as num?)?.toInt() ?? 0,
    oneLiner: json['oneLiner']?.toString() ?? '',
    coreOrder: (json['coreOrder'] as List? ?? [])
        .map((e) => EventReadingItem.fromJson(e as Map))
        .toList(),
    optionalOrder: (json['optionalOrder'] as List? ?? [])
        .map((e) => EventReadingItem.fromJson(e as Map))
        .toList(),
    readingOrder: (json['readingOrder'] as List? ?? [])
        .map((e) => EventIssue.fromJson(e as Map))
        .toList(),
    imageUrl: json['imageUrl']?.toString(),
  );
}

/// 阅读顺序里的一项：某系列的哪些期。
class EventReadingItem {
  const EventReadingItem({
    required this.series,
    required this.issues,
    this.note,
  });

  /// 系列英文名，如 "Civil War"。
  final String series;

  /// 期数，如 "1-7" 或 "1, 2, 4"。
  final String issues;

  /// 一句备注（如「主线必读」「钢铁侠视角」）。
  final String? note;

  /// 用于搜索跳转的完整标题："Civil War #1-7"。
  String get searchableTitle => '$series #$issues';

  factory EventReadingItem.fromJson(Map json) => EventReadingItem(
    series: json['series']?.toString() ?? '',
    issues: json['issues']?.toString() ?? '',
    note: json['note']?.toString(),
  );
}

/// 逐期导读里的一期。
class EventIssue {
  const EventIssue({
    required this.id,
    required this.series,
    required this.number,
    this.date = '',
    this.title = '',
    this.cover,
    this.core = true,
    this.note,
  });

  /// 打开详情用的 id（`fandom:<wiki 页面名>`）。
  final String id;

  final String series;

  /// 期号（"3" / "65.DEATHS"）。
  final String number;

  /// 发行日期（YYYY-MM-DD，可能为空）。
  final String date;

  /// 故事标题（wiki 的 StoryTitle，可能为空）。
  final String title;

  /// wiki 上的封面文件名（用 Special:FilePath 取图）。
  final String? cover;

  /// 是否主线（false = 可选延伸）。
  final bool core;

  final String? note;

  /// 展示用标题。
  String get label => title.isNotEmpty ? title : '$series #$number';

  /// 封面直链（wiki 的 Special:FilePath，带宽度参数）。
  String? get coverUrl {
    final c = cover;
    if (c == null || c.isEmpty) return null;
    return 'https://marvel.fandom.com/wiki/Special:FilePath/'
        '${Uri.encodeComponent(c)}?width=400';
  }

  factory EventIssue.fromJson(Map json) => EventIssue(
    id: json['id']?.toString() ?? '',
    series: json['series']?.toString() ?? '',
    number: json['number']?.toString() ?? '',
    date: json['date']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    cover: json['cover']?.toString(),
    core: json['core'] != false,
    note: json['note']?.toString(),
  );
}
