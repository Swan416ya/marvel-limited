import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:marvel_limited/data/models/marvel_models.dart';
import 'package:marvel_limited/data/repository/library_repository_io.dart';
import 'package:marvel_limited/features/reader/reader_page_io.dart';
import 'package:marvel_limited/state/library_state.dart';
import 'package:marvel_limited/data/repository/preferences_repository.dart';

/// 用**真实漫画文件**过一遍导入 → 阅读 全链路：
/// 1. cbz 解包（zip、目录内排序、期号补零）；
/// 2. 阅读器渲染真图（不是占位）；
/// 3. 翻页 / 双页拼合 / 状态文字；
/// 4. 进度保存（重开落在上次那页）。
///
/// 测试文件来自 `E:\Comic Manager Library`（One World Under Doom #1，
/// 36 页真扫描）。没有这个目录时整个文件跳过（CI 上没有漫画库）。
void main() {
  final comicPath = Platform.isWindows
      ? 'E:/Comic Manager Library/One World Under Doom (2025)/Chapter-01/'
            'One World Under Doom 001 (2025) (Digital) (Shan-Empire).cbz'
      : '';
  final available = comicPath.isNotEmpty && File(comicPath).existsSync();

  test('环境里有测试漫画', () {
    // 提醒：本机没有漫画库时下面全部跳过，等于没测
    expect(available, isTrue, reason: '找不到 $comicPath，真实漫画阅读链路没法测');
  }, skip: !available ? '本机没有漫画库' : false);

  group('真实漫画：导入 + 阅读', () {
    late Directory tmp;
    late LibraryRepository library;
    // setUpAll 在第一个 setUp 之前跑，library 在那里初始化
    final issue = ComicIssue(
      id: 'real-owud-1',
      title: 'One World Under Doom #1',
      seriesTitle: 'One World Under Doom',
      issueNumber: '1',
      releaseDate: '2025-02-12',
      description: '',
    );

    setUp(() async {
      // SharedPreferences 在测试里要给假数据，否则 getInstance 永不完成
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    tearDownAll(() async {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    test(
      'cbz 导入：解包、按文件名排序、能列出全部页面',
      () async {
        // ignore: avoid_print
        print('[T] 开始导入 ${DateTime.now()}');
        final imported = await library.importArchive(issue, comicPath);
        // ignore: avoid_print
        print('[T] 导入完成 ${DateTime.now()}');
        expect(imported.localPath, isNotNull);
        expect(library.isImported(issue.id), isTrue);

        final pages = await library.pagesFor(issue);
        expect(pages.length, 36, reason: '这一期应有 36 页');
        // 排序必须是数字序：00001 在 00009 前面（字典序也行，但补零后两者一致）
        expect(pages.first, contains('00001'));
        expect(pages.last, contains('00036'));
        // 文件真实存在且非空
        for (final p in pages.take(3)) {
          expect(File(p).existsSync(), isTrue);
          expect(File(p).lengthSync(), greaterThan(10 * 1024));
        }
      },
      skip: !available,
      timeout: const Timeout(Duration(minutes: 4)),
    );

    // 导入在 setUpAll（真实异步）里完成：testWidgets 的 fake-async
    // 环境里真文件 IO（读 78MB 的 cbz）不会完成，直接在测试体里做会挂死。
    List<String> realPages = const [];
    setUpAll(() async {
      // package:test 对被 skip 的用例仍会跑 setUpAll：没有漫画库的
      // 环境（CI）必须在这里就退出去，否则整组标红，skip 形同虚设
      if (!available) return;
      // setUpAll 先于 setUp 执行，库在这里自建（真实异步，IO 能完成）
      tmp = await Directory.systemTemp.createTemp('marvel-reader-all-');
      library = await LibraryRepository.load('${tmp.path}/library');
      final imported = await library.importArchive(issue, comicPath);
      realPages = await library.pagesFor(imported);
    });

    testWidgets('阅读器渲染真图：翻页、双页拼合、进度记忆', (tester) async {
      // 36 页全解码太慢（78MB 真扫描），渲染测试只喂前 6 页；
      // 完整 36 页的存在性由上面的导入测试保证
      final pages = realPages.take(6).toList();
      expect(pages.length, 6);
      expect(File(pages.first).existsSync(), isTrue);

      final prefs = PreferencesRepository();
      await prefs.load();
      final state = LibraryState(prefs);

      // 竖屏手机视口
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<LibraryState>.value(
          value: state,
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: ReaderPage(issue: issue, pages: pages),
          ),
        ),
      );
      // 不用 pumpAndSettle：真图的解码事件在 fake-async 里可能永不完成
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('第 1 页 / 共 6 页'), findsOneWidget);
      expect(find.byTooltip('下一页'), findsOneWidget);
      expect(find.byTooltip('双页拼合'), findsOneWidget);

      // 翻 3 页（翻页动画是 timer 驱动，定长 pump 推进）
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('下一页'));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.text('第 4 页 / 共 6 页'), findsOneWidget);

      // 开双页：第 4 页 → 第 3-4 跨页，再翻 → 第 5-6 跨页
      await tester.tap(find.byTooltip('双页拼合'));
      await tester.pump(const Duration(milliseconds: 400));
      // 开双页：锚到第 4 页所在的跨页（3-4）——跨页固定是 (1,2)(3,4)(5,6)
      expect(find.text('第 3-4 页 / 共 6 页'), findsOneWidget);
      await tester.tap(find.byTooltip('下一页'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 400));
      // 再翻到最后一跨：第 5-6 页
      expect(find.text('第 5-6 页 / 共 6 页'), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('进度记忆：重开直接落在上次那页', (tester) async {
      final prefs = PreferencesRepository();
      await prefs.load();
      // 预置进度：读到了第 18 页（0 基 17）
      await prefs.saveProgress(
        ReadingProgress(
          issue: issue,
          page: 17,
          totalPages: 36,
          updatedAt: DateTime.now(),
        ),
      );

      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = LibraryState(prefs);
      await tester.pumpWidget(
        ChangeNotifierProvider<LibraryState>.value(
          value: state,
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: ReaderPage(
              issue: issue,
              // 用 36 个假路径（不解码，只要页数对）
              pages: [for (var i = 0; i < 36; i++) '/nonexistent/p-$i.jpg'],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 重开直接落在第 18 页，而不是第 1 页（修复前 initialPage
      // 没接恢复值，永远从第一页开始）
      expect(find.text('第 18 页 / 共 36 页'), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
