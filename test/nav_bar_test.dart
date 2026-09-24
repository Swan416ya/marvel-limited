import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marvel_limited/features/root/widgets/app_nav_bar.dart';
import 'package:marvel_limited/features/root/widgets/flat_glass_bar.dart';
import 'package:marvel_limited/features/root/widgets/glass_nav_bar.dart';

/// 导航栏两条实现都要能渲染、能点。
///
/// Web 降级版（[FlatGlassBar]）只在 Web 生效，而 widget 测试跑在 VM 上
/// （`kIsWeb` 为 false），走的是 [GlassNavBar]。所以这里两个都直接挂载测，
/// 否则降级版没有任何覆盖。
void main() {
  const items = AppNavBar.destinations;

  Widget host(Widget bar) => MaterialApp(
    home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: bar)),
  );

  group('FlatGlassBar（Web 降级版）', () {
    testWidgets('渲染 5 个图标，选中项用实心图标', (tester) async {
      await tester.pumpWidget(
        host(FlatGlassBar(index: 0, onSelect: (_) {}, items: items)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.home_rounded), findsOneWidget); // 选中
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('点第 3 格回调 index 2', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        host(
          FlatGlassBar(index: 0, onSelect: tapped.add, items: items),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.auto_stories_outlined));
      expect(tapped, [2]);
    });
  });

  group('GlassNavBar（原生液态玻璃）', () {
    testWidgets('渲染 5 个图标，选中项用实心图标', (tester) async {
      await tester.pumpWidget(
        host(GlassNavBar(index: 0, onSelect: (_) {}, items: items)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
      expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('点第 3 格回调 index 2', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(
        host(GlassNavBar(index: 0, onSelect: tapped.add, items: items)),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.auto_stories_outlined));
      expect(tapped, [2]);
    });
  });
}
