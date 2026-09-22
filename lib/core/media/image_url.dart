import 'package:flutter/foundation.dart' show kIsWeb;

/// 图片地址统一出口。
///
/// Web 端有些图床不放 CORS（CanvasKit 画图必须 CORS 干净），
/// 比如 fandom wiki 的 static.wikia.nocookie.net；漫威自家 CDN 是放的。
/// 这里维护一个「可以直连」的白名单，其它一律走本地开发代理
/// （`tool/dev_proxy.py`，见 `data/sources` 里两个 client 的同款约定）。
///
/// 注意：发布版 web 如果没有这个代理，非白名单图会加载失败——
/// 这是开发期权衡，Android 端不受影响（不走这里，直接原图）。
const _directHosts = [
  'cdn.marvel.com',
  'i.annihil.us',
];

/// 返回真正用于请求的图片地址；null/空串原样返回。
String? resolveImage(String? url) {
  if (url == null || url.isEmpty) return url;
  if (!kIsWeb) return url;
  final host = Uri.tryParse(url)?.host.toLowerCase();
  if (host == null) return url;
  for (final allowed in _directHosts) {
    if (host == allowed || host.endsWith('.$allowed')) return url;
  }
  return 'http://127.0.0.1:8322/proxy/${Uri.encodeFull(url)}';
}