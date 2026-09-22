import 'models/marvel_models.dart';

/// 从本地漫画文件名解析出「系列名 + 期号」，并匹配到 issue。
///
/// 目标文件名形态（实测自用户的漫画库）：
/// - `Amazing Spider-Man - Renew Your Vows 002 (2015) GetComics.INFO.cbr`
/// - `Civil War 001 (2006) (Digital) (Zone-Empire).cbr`
/// - `Amazing Spider-Man #300.cbz`
/// - `Batman 012 (2000).cbz`（非漫威也能解析，只是匹配不上）
class ParsedFilename {
  const ParsedFilename({
    required this.seriesGuess,
    this.issueNumber,
    this.year,
    this.cleanTitle,
  });

  /// 系列名猜测（已清洗）。
  final String seriesGuess;

  /// 期号（纯数字或带小数），解析不出为 null。
  final String? issueNumber;

  /// 文件名里出现的年份。
  final int? year;

  /// 清洗后的完整标题（系列 + 期号），用于展示。
  final String? cleanTitle;

  bool get hasIssue => issueNumber != null && issueNumber!.isNotEmpty;
}

/// 清洗文件名：去扩展名、去发布组/格式标签、去年份、规整分隔符。
ParsedFilename parseComicFilename(String filename) {
  var name = filename.replaceAll(RegExp(r'\.(cbz|cbr|zip|rar)$', caseSensitive: false), '');

  // 去掉常见发布组/格式标签（括号内容和 GetComics.INFO 这类裸标签）
  name = name.replaceAll(RegExp(r'\(([^)]*)\)'), ' ');
  name = name.replaceAll(RegExp(r'GetComics\.\w+', caseSensitive: false), ' ');
  name = name.replaceAll('_', ' ');
  name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

  // 年份 = 清洗后残留的四位数字（1980-2030）
  int? year;
  final yearMatch =
      RegExp(r'\b(19[89]\d|20[0-3]\d)\b').firstMatch(name);
  if (yearMatch != null) {
    year = int.parse(yearMatch.group(1)!);
    name = name.replaceFirst(yearMatch.group(0)!, ' ');
  }

  // 期号：优先 "#300"，否则取结尾的独立数字（含小数 12.5）
  String? issueNumber;
  var hash = RegExp(r'#\s*(\d+(?:\.\d+)?)').firstMatch(name);
  if (hash != null) {
    issueNumber = _trimLeadingZeros(hash.group(1)!);
    name = name.replaceFirst(hash.group(0)!, ' ');
  } else {
    final trailing =
        RegExp(r'(?:^|\s)(\d{1,4}(?:\.\d+)?)(?:\s*$)')
            .allMatches(name)
            .toList();
    if (trailing.isNotEmpty) {
      final last = trailing.last;
      issueNumber = _trimLeadingZeros(last.group(1)!);
      // 只把最后一个数字当期号，且系列名不能因此变空
      final before = name.substring(
          0, name.lastIndexOf(last.group(1)!) >= 0
              ? name.lastIndexOf(last.group(1)!)
              : name.length);
      if (before.trim().replaceAll(RegExp(r'[-–—\s]$'), '').isNotEmpty) {
        name = before;
      } else {
        issueNumber = null;
      }
    }
  }

  var series = name
      .replaceAll(RegExp(r'\s*[-–—]\s*$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return ParsedFilename(
    seriesGuess: series,
    issueNumber: issueNumber,
    year: year,
    cleanTitle: issueNumber == null ? series : '$series #$issueNumber',
  );
}

String _trimLeadingZeros(String number) {
  if (number.contains('.')) {
    final parts = number.split('.');
    return '${int.tryParse(parts[0]) ?? 0}.${parts[1]}';
  }
  return (int.tryParse(number) ?? 0).toString();
}

/// 匹配结果：一个文件对应的最优 issue（或 null）+ 候选列表。
class FilenameMatch {
  const FilenameMatch({
    required this.parsed,
    this.best,
    this.candidates = const [],
  });

  final ParsedFilename parsed;
  final ComicIssue? best;
  final List<ComicIssue> candidates;
}

/// 在本地已缓存的 issue 里找匹配（不发请求，命中即最佳）。
///
/// 规则：系列名双向包含（大小写不敏感）+ 期号精确相等。
ComicIssue? matchLocalIssue(
  ParsedFilename parsed,
  List<ComicIssue> localIssues,
) {
  if (!parsed.hasIssue) return null;
  final guess = parsed.seriesGuess.toLowerCase();
  if (guess.isEmpty) return null;

  ComicIssue? contains;
  for (final issue in localIssues) {
    if (issue.issueNumber != parsed.issueNumber) continue;
    final series = issue.seriesTitle.toLowerCase();
    if (series == guess) return issue;
    if (series.contains(guess) || guess.contains(series)) {
      contains ??= issue;
    }
  }
  return contains;
}

/// 用官网系列（lockjaw 结果）构造一个可导入的 issue。
ComicIssue issueFromOfficialSeries({
  required String seriesId,
  required String seriesTitle,
  required String issueNumber,
}) {
  return ComicIssue(
    id: 'series:$seriesId#$issueNumber',
    title: '$seriesTitle #$issueNumber',
    seriesTitle: seriesTitle,
    seriesId: seriesId,
    issueNumber: issueNumber,
    releaseDate: '',
    description: '',
  );
}

/// 用 wiki 系列页名构造一个可导入的 issue。
ComicIssue issueFromWikiSeries({
  required String wikiPageName,
  required String issueNumber,
}) {
  final seriesTitle =
      wikiPageName.replaceAll(RegExp(r'\s+Vol\.\s*\d+$'), '').trim();
  return ComicIssue(
    id: 'fandom:$wikiPageName #$issueNumber',
    title: '$wikiPageName #$issueNumber',
    seriesTitle: seriesTitle,
    issueNumber: issueNumber,
    releaseDate: '',
    description: '',
  );
}