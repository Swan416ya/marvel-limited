/// 系列名 / 期号的解析与拼装规则。
///
/// 原先这些正则和启发式散在 `BifrostService` 与 `SeriesPage` 里，
/// 抽成纯函数后可以单测，也能被仓库层和 UI 共用。
abstract final class SeriesNaming {
  /// 从 "Amazing Spider-Man #300" 这类标题里取出系列名 → "Amazing Spider-Man"。
  static String seriesFromTitle(String title) {
    final hashIdx = title.lastIndexOf(' #');
    if (hashIdx > 0) return title.substring(0, hashIdx);
    return title;
  }

  /// 取出期号 → "300"。取不到返回空串。
  static String issueFromTitle(String title) {
    final hashIdx = title.lastIndexOf(' #');
    if (hashIdx > 0) return title.substring(hashIdx + 2);
    return '';
  }

  /// 期号排序键：纯数字按期号大小；"Annual"/"300.1" 之类排在同年数字之后。
  static double issueSortKey(String number) {
    final n = double.tryParse(number);
    if (n != null) return n;
    final base =
        double.tryParse(RegExp(r'^[0-9]+').firstMatch(number)?.group(0) ?? '');
    return (base ?? 99999) + 0.75;
  }

  /// 官网系列标题 → Marvel Database(fandom) 页面名。
  ///
  /// 官网写 "Amazing Spider-Man (2018)"，wiki 写 "Amazing Spider-Man Vol 5"。
  /// 年份到 Vol 号的换算只能靠启发式（wiki 的 Vol 划分并不完全等于年份区间），
  /// 所以这里只覆盖主流区间，落不到就原样返回由调用方兜底。
  static String wikiPageName(String title) {
    final m = RegExp(r'^(.*?)\s*\((\d{4})\)\s*$').firstMatch(title);
    if (m == null) return title;
    final name = m.group(1)!.trim();
    final year = int.parse(m.group(2)!);
    if (year <= 1963) return '$name Vol 1';
    if (year <= 1998) return '$name Vol 2';
    if (year <= 2013) return '$name Vol 3';
    if (year <= 2018) return '$name Vol 4';
    return '$name Vol 5';
  }
}