import 'package:url_launcher/url_launcher.dart';

/// getcomics 下载引导。
/// 实测帖子基本都是 TERABOX/FILEQ 网盘 + Cloudflare 人机验证，
/// 全自动下载不可行，这里只做搜索跳转。
class GetComicsService {
  static const base = 'https://getcomics.org';

  /// 搜索一个 issue。优先精确 "系列 #号"，失败再宽泛搜索系列名。
  static String searchUrl(String seriesTitle, String issueNumber) {
    final query = '$seriesTitle $issueNumber'.trim();
    return '$base/?s=${Uri.encodeQueryComponent(query)}';
  }

  static Future<bool> open(String url) async {
    final uri = Uri.parse(url);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
