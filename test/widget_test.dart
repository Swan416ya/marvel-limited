import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:marvel_limited/app.dart';
import 'package:marvel_limited/data/repository/preferences_repository.dart';
import 'package:marvel_limited/data/sources/bifrost_client.dart';
import 'package:marvel_limited/data/sources/fandom_client.dart';

void main() {
  // rootBundle 会把 loadString 的 Future 缓存下来，而这个 Future 是在
  // **上一个用例的 fake-async zone** 里创建的——跨用例复用它永远不会
  // 完成（首页 feed 会一直空着）。每个用例开头清一次缓存。
  setUp(() => rootBundle.clear());

  // 注入 MockClient：所有请求立即返回空结果（微任务完成、无 socket、
  // 无真实 HttpClient），fake-async 里才不会留下挂起的 Timer。
  // 同时传零重试退避，双重保险。
  MarvelApp buildApp(PreferencesRepository preferences) {
    final bifrost = BifrostClient(
      retryDelays: const [],
      client: MockClient((req) async => http.Response(
            jsonEncode({
              'data': {'results': <String>[], 'total': 0},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    final fandom = FandomClient(
      retryDelays: const [],
      client: MockClient((req) async => http.Response('[]', 200)),
    );
    return MarvelApp(
      preferences: preferences,
      bifrost: bifrost,
      fandom: fandom,
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

    // 静态事件库是本地资产：网络数据为空时首页瀑布流
    // 仍应有大事件卡（带「事件」角标），而不是白屏或报错。
    expect(find.text('事件'), findsWidgets);
  });
}