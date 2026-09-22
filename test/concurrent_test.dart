import 'package:flutter_test/flutter_test.dart';
import 'package:marvel_limited/core/async/concurrent.dart';

void main() {
  group('mapConcurrent', () {
    test('结果按输入顺序返回，即使完成顺序不同', () async {
      final out = await mapConcurrent<int, String>(
        [1, 2, 3, 4],
        (n) async {
          // 越小的越慢，逼出乱序完成
          await Future<void>.delayed(Duration(milliseconds: (5 - n) * 5));
          return 'v$n';
        },
        concurrency: 4,
      );
      expect(out, ['v1', 'v2', 'v3', 'v4']);
    });

    test('丢弃 null 结果', () async {
      final out = await mapConcurrent<int, String>(
        [1, 2, 3],
        (n) async => n.isEven ? 'v$n' : null,
      );
      expect(out, ['v2']);
    });

    test('并发数不超过设定值', () async {
      var running = 0;
      var peak = 0;
      await mapConcurrent<int, int>(
        List.generate(20, (i) => i),
        (n) async {
          running++;
          peak = running > peak ? running : peak;
          await Future<void>.delayed(const Duration(milliseconds: 2));
          running--;
          return n;
        },
        concurrency: 3,
      );
      expect(peak, lessThanOrEqualTo(3));
    });

    test('进度回调覆盖到最后一项', () async {
      final seen = <int>[];
      await mapConcurrent<int, int>(
        [1, 2, 3, 4, 5],
        (n) async => n,
        concurrency: 2,
        onProgress: (done, total) {
          expect(total, 5);
          seen.add(done);
        },
      );
      expect(seen.length, 5);
      expect(seen.last, 5);
    });

    test('空输入直接返回空', () async {
      final out = await mapConcurrent<int, int>([], (n) async => n);
      expect(out, isEmpty);
    });
  });
}