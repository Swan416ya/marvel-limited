/// 漫威系接口共用的请求件：浏览器 UA + 带退避的重试循环。
///
/// UA 必须像真实移动端浏览器——CDN 对脚本 UA 会直接掐连接。
/// bifrost / fandom 两个客户端用的是同一套。
library;

const chromeMobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

/// 带退避重试地跑 [run]。
///
/// [retryDelays] 长度即重试次数（列表为空=只试一次、不等待；测试传空
/// 列表，重试即时完成、不产生 Timer，widget 测试才不会被挂起的定时器
/// 绊倒）。每次失败退避后重来，全部失败抛最后一次的错。
Future<T> withRetry<T>({
  required List<Duration> retryDelays,
  required String failureMessage,
  required Future<T> Function() run,
}) async {
  Object lastError = Exception('$failureMessage failed after retries');
  for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
    try {
      return await run();
    } catch (e) {
      lastError = e;
      if (attempt < retryDelays.length) {
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
  }
  throw lastError;
}
