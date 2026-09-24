import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marvel_limited/app.dart';
import 'package:marvel_limited/data/models/marvel_event.dart';
import 'package:marvel_limited/data/models/marvel_models.dart';
import 'package:marvel_limited/data/repository/events_repository.dart';
import 'package:marvel_limited/data/repository/preferences_repository.dart';
import 'package:marvel_limited/data/sources/bifrost_client.dart';
import 'package:marvel_limited/data/sources/fandom_client.dart';
import 'package:marvel_limited/features/guides/widgets/guide_cards.dart';

/// 平板/宽屏版式的回归测试。
///
/// 起因：指南页 banner 在平板上报「bottom overflowed by 28 pixels」——
/// banner 条按「图高 + 50」估高度、卡片按「图高 + 间距 + 标题」算实际高度，
/// 两边对不上，矮视口 + 单行标题时正好差 28。
/// overflow 在测试里会直接抛异常，所以「跑过不炸」就是有效断言。
///
/// 视口一律用 `tester.view.physicalSize`（逻辑像素 = 物理 / dpr）钉死，
/// 不然测试默认 800×600，平板那档根本走不到。
class FakeEventsRepository extends EventsRepository {
  @override
  Future<List<MarvelEvent>> all() async => const [
    MarvelEvent(
      id: 'e1',
      title: 'Fake Event One',
      titleZh: '假事件一',
      tier: 'company',
      year: 2024,
      oneLiner: '用于测试的一句话。',
    ),
    MarvelEvent(
      id: 'e2',
      title: 'Fake Event Two',
      titleZh: '假事件二',
      tier: 'cosmic',
      year: 2023,
      oneLiner: '用于测试的一句话。',
    ),
  ];
}

void main() {
  // rootBundle 会把 loadString 的 Future 缓存下来，而这个 Future 是在
  // 上一个用例的 fake-async zone 里创建的——跨用例复用它永远不会完成。
  // 与 test/widget_test.dart 同一招。
  setUp(() => rootBundle.clear());

  /// 假的指南列表：banner 只认标题里带 complete event / main event 的，
  /// 这里给够 6 个，走进 banner 的真实分支。
  List<Map<String, dynamic>> fakeGuides(int n) => [
    for (var i = 0; i < n; i++)
      {
        'id': 'g$i',
        'title': 'Fake Event $i: The Complete Event',
        'description': '测试用',
        'images': [
          {'path': 'https://example.invalid/cover$i.jpg', 'extension': 'jpg'},
        ],
      },
  ];

  MarvelApp buildApp(PreferencesRepository preferences) {
    final bifrost = BifrostClient(
      retryDelays: const [],
      client: MockClient((req) async {
        // 只给指南端点喂数据：其它端点照旧返回空，免得错形状的 payload
        // 把 comics 之类的解析器炸掉。
        final guides = req.url.path.contains('reading-lists');
        return http.Response(
          jsonEncode(
            guides
                ? {'data': {'results': fakeGuides(6), 'total': 6}}
                : {'data': {'results': <String>[], 'total': 0}},
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final fandom = FandomClient(
      retryDelays: const [],
      client: MockClient((req) async => http.Response('[]', 200)),
    );
    return MarvelApp(
      preferences: preferences,
      bifrost: bifrost,
      fandom: fandom,
      eventsRepository: FakeEventsRepository(),
    );
  }

  /// 逻辑像素尺寸 → 物理像素（dpr 固定 1，省得换算）。
  Future<void> useViewport(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  /// 从指南 banner 卡在给定宽度下需要的高度这个纯函数开始测：
  /// 这才是当初算错的地方。
  group('GuideWideCard.heightFor', () {
    for (final size in const [
      Size(390, 844), // 手机竖屏
      Size(834, 1112), // 平板竖屏
      Size(1194, 834), // 平板横屏
      Size(932, 430), // 手机横屏（最矮，最容易溢出）
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} 下给的高度够放下卡片',
          (tester) async {
        await useViewport(tester, size);
        late double height;
        late double cardWidth;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  cardWidth = size.width;
                  height = GuideWideCard.heightFor(context, cardWidth);
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: height,
                      child: GuideWideCard(
                        guide: ReadingGuide(
                          id: 'g',
                          title: 'A Very Long Guide Title That Wraps To Two Lines For Sure',
                        ),
                        onTap: () {},
                        width: cardWidth,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        // 高度必须 ≥ 图（封顶后）+ 间距 + 标题两行；少一点就是 overflow
        expect(height, greaterThan(0));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('矮视口下图高被 42% 上限截断，但仍留得下文字块', (tester) async {
      await useViewport(tester, const Size(1400, 400));
      late double height;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                height = GuideWideCard.heightFor(context, 1200);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      // 1200/1.778 ≈ 675，视口高 400 → 图高封顶 400*0.42 - 文字块
      expect(height, lessThan(200));
      expect(height, greaterThan(GuideWideCard.titleBlockHeight - 1));
    });
  });

  group('平板宽度下三个 tab 都不溢出', () {
    for (final size in const [Size(834, 1112), Size(1194, 834)]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}：指南 / 事件两个 tab',
          (tester) async {
        await useViewport(tester, size);
        SharedPreferences.setMockInitialValues({});
        final preferences = PreferencesRepository();
        await preferences.load();

        await tester.pumpWidget(buildApp(preferences));
        await tester.pump();
        await tester.pump(const Duration(seconds: 70));

        // 指南 tab。注意：指南正文依赖 330KB 的目录快照资产，而 fake-async
        // 里那步读操作不会完成（见 widget_test.dart 的同类注释），所以这里
        // 只能保证「切过去不炸」，banner 的高度契约由上面 heightFor 那组
        // 纯函数用例守住——那才是当初算错的地方。
        await tester.tap(find.byIcon(Icons.explore_outlined));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        expect(find.text('GUIDE'), findsWidgets);

        // 事件 tab：宽屏走多列网格（窄屏才是一行一张的 ListView）
        await tester.tap(find.byIcon(Icons.bolt_outlined));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        expect(find.byType(GridView), findsOneWidget);
        expect(find.text('Fake Event One'), findsWidgets);
      });
    }
  });
}
