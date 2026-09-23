import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marvel_limited/app.dart';
import 'package:marvel_limited/data/models/marvel_event.dart';
import 'package:marvel_limited/data/repository/events_repository.dart';
import 'package:marvel_limited/data/repository/preferences_repository.dart';
import 'package:marvel_limited/data/sources/bifrost_client.dart';
import 'package:marvel_limited/data/sources/fandom_client.dart';

/// 假的静态事件仓库：直接从内存给两条事件。
///
/// 真实现会去读 200KB+ 的资产 JSON，而 fake-async 里那步读操作不会完成
/// （真实设备/浏览器没问题，纯测试环境限制）。这里要验的是「首页把事件
/// 渲染成卡片」这条逻辑，数据来源不是重点。
class FakeEventsRepository extends EventsRepository {
  @override
  Future<List<MarvelEvent>> all() async => const [
    MarvelEvent(
      id: 'fake-1',
      title: 'Fake Event One',
      titleZh: '假事件一',
      tier: 'company',
      year: 2024,
      oneLiner: '用于测试。',
    ),
    MarvelEvent(
      id: 'fake-2',
      title: 'Fake Event Two',
      titleZh: '假事件二',
      tier: 'cosmic',
      year: 2023,
      oneLiner: '用于测试。',
    ),
  ];
}

void main() {
  // rootBundle 会把 loadString 的 Future 缓存下来，而这个 Future 是在
  // **上一个用例的 fake-async zone** 里创建的——跨用例复用它永远不会
  // 完成（首页 feed 会一直空着）。每个用例开头清一次缓存。
  setUp(() => rootBundle.clear());

  // 注入 MockClient：所有请求立即返回空结果（微任务完成、无 socket、
  // 无真实 HttpClient），fake-async 里才不会留下挂起的 Timer。
  // 同时传零重试退避，双重保险。
  MarvelApp buildApp(
    PreferencesRepository preferences, {
    EventsRepository? events,
  }) {
    final bifrost = BifrostClient(
      retryDelays: const [],
      client: MockClient(
        (req) async => http.Response(
          jsonEncode({
            'data': {'results': <String>[], 'total': 0},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final fandom = FandomClient(
      retryDelays: const [],
      client: MockClient((req) async => http.Response('[]', 200)),
    );
    return MarvelApp(
      preferences: preferences,
      bifrost: bifrost,
      fandom: fandom,
      eventsRepository: events ?? FakeEventsRepository(),
    );
  }

  testWidgets('应用能启动，底部五个 tab 都在', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesRepository();
    await preferences.load();

    await tester.pumpWidget(buildApp(preferences));
    await tester.pump();
    // 推过所有 .timeout(30s/60s) 的窗口：真实 IO（如目录创建）在
    // fake-async 里永不完成，超时定时器会一直挂着，推进时钟让它们触发收尾。
    await tester.pump(const Duration(seconds: 70));

    // 底部导航改成图标胶囊（液态玻璃）后不再有可见文字标签，改查图标：
    // 首页（默认选中，实心）＋ 指南 / 系列 / 事件 / 收藏（线性）。
    expect(find.byIcon(Icons.home_rounded), findsWidgets);
    expect(find.byIcon(Icons.explore_outlined), findsWidgets);
    expect(find.byIcon(Icons.auto_stories_outlined), findsWidgets);
    expect(find.byIcon(Icons.bolt_outlined), findsWidgets);
    expect(find.byIcon(Icons.favorite_border), findsWidgets);
  });

  testWidgets('网络返回空时首页仍渲染本地事件内容', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = PreferencesRepository();
    await preferences.load();

    await tester.pumpWidget(buildApp(preferences));
    await tester.pump();
    await tester.pump(const Duration(seconds: 70));

    // 静态事件库（本地数据）在网络数据为空时也要照常出现在瀑布流里：
    // 卡片带「事件」角标，标题是事件名。
    expect(find.text('事件'), findsWidgets);
    // 事件卡标题用英文原名（和首页其它卡片保持一致）
    expect(find.text('Fake Event One'), findsWidgets);
  });
}
