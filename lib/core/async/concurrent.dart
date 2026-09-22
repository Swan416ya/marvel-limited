/// 限并发地执行一批任务，结果按输入顺序返回（丢弃 null 结果）。
///
/// wiki 补全要发几十上百个请求，串行太慢、全放出去又容易被限流，
/// 所以统一走这里：并发数可控，还能报进度。
Future<List<R>> mapConcurrent<T, R>(
  List<T> items,
  Future<R?> Function(T item) task, {
  int concurrency = 6,
  void Function(int done, int total)? onProgress,
}) async {
  if (items.isEmpty) return <R>[];

  final results = List<R?>.filled(items.length, null);
  final workers = concurrency < 1
      ? 1
      : (concurrency > items.length ? items.length : concurrency);

  var next = 0;
  var done = 0;

  Future<void> worker() async {
    while (true) {
      final i = next;
      next++;
      if (i >= items.length) return;
      results[i] = await task(items[i]);
      done++;
      onProgress?.call(done, items.length);
    }
  }

  await Future.wait(List.generate(workers, (_) => worker()));
  return results.whereType<R>().toList();
}