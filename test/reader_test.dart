import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marvel_limited/data/models/marvel_models.dart';
import 'package:marvel_limited/data/repository/preferences_repository.dart';
import 'package:marvel_limited/features/reader/reader_page.dart';
import 'package:marvel_limited/state/library_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读链路测试：书签存储 + ReaderPage 冒烟（点按翻页/工具栏/书签/双页）。
///
/// 测试跑在 VM 上（dart.library.io 为真），reader_page.dart 的
/// conditional export 解析到完整实现。图片来自不存在的本地路径，
/// 走「这一页读不出来」占位，但翻页/工具栏/书签逻辑照常工作。
void main() {
  late PreferencesRepository prefs;
  late LibraryState library;

  ComicIssue issue() => ComicIssue(
    id: 'reader-test',
    title: 'Reader Test #1',
    seriesTitle: 'Reader Test',
    issueNumber: '1',
    releaseDate: '',
    description: '',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesRepository();
    await prefs.load();
    library = LibraryState(prefs);
  });

  group('书签存储', () {
    test('加书签 → 查询 → 再点同页删除', () {
      expect(library.hasBookmark('reader-test', 3), isFalse);

      final now = library.toggleBookmark('reader-test', 3);
      expect(now, isTrue, reason: '第一次点应该是加书签');
      expect(library.hasBookmark('reader-test', 3), isTrue);
      expect(library.bookmarksFor('reader-test').length, 1);
      expect(library.bookmarksFor('reader-test').first.page, 3);

      final removed = library.toggleBookmark('reader-test', 3);
      expect(removed, isFalse, reason: '同页再点应该是删书签');
      expect(library.hasBookmark('reader-test', 3), isFalse);
      expect(library.bookmarksFor('reader-test'), isEmpty);
    });

    test('多个书签按页码排序', () {
      library.toggleBookmark('reader-test', 10);
      library.toggleBookmark('reader-test', 2);
      library.toggleBookmark('reader-test', 6);

      final pages = library
          .bookmarksFor('reader-test')
          .map((b) => b.page)
          .toList();
      expect(pages, [2, 6, 10]);
    });

    test('不同 issue 的书签互不干扰', () {
      library.toggleBookmark('issue-a', 1);
      library.toggleBookmark('issue-b', 2);

      expect(library.bookmarksFor('issue-a').length, 1);
      expect(library.bookmarksFor('issue-b').length, 1);
      expect(library.bookmarksFor('issue-a').first.page, 1);
    });

    test('书签持久化（重新 load 后还在）', () async {
      library.toggleBookmark('reader-test', 5);

      final prefs2 = PreferencesRepository();
      await prefs2.load();
      final library2 = LibraryState(prefs2);
      expect(library2.hasBookmark('reader-test', 5), isTrue);
    });
  });

  group('ReaderPage 冒烟', () {
    testWidgets('渲染、状态文字、点按翻页、书签、双页拼合', (tester) async {
      final fakePages = [
        '/nonexistent/page-0.jpg',
        '/nonexistent/page-1.jpg',
        '/nonexistent/page-2.jpg',
      ];

      // 测试窗口默认 800x600 是横屏，阅读器会进双页视图——
      // 设成手机竖屏比例，走单页路径
      tester.view.physicalSize = const Size(489, 914);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<LibraryState>.value(
          value: library,
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: ReaderPage(issue: issue(), pages: fakePages),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('第 1 页 / 共 3 页'), findsOneWidget);

      // 工具栏按钮存在
      expect(find.byTooltip('加书签'), findsOneWidget);
      expect(find.byTooltip('书签列表'), findsOneWidget);
      expect(find.byTooltip('双页拼合'), findsOneWidget);

      // 点加书签 → 提示 + 图标切换 + 状态真的写进去
      await tester.tap(find.byTooltip('加书签'));
      await tester.pump();
      expect(find.text('已在第 1 页加书签'), findsOneWidget);
      expect(find.byTooltip('去掉书签'), findsOneWidget);
      expect(library.hasBookmark('reader-test', 0), isTrue);

      // 书签列表弹层：有一条，点了跳页
      await tester.tap(find.byTooltip('书签列表'));
      await tester.pumpAndSettle();
      expect(find.text('书签 · 1'), findsOneWidget);
      expect(find.text('第 1 页'), findsOneWidget);
      await tester.tap(find.text('第 1 页'));
      await tester.pumpAndSettle();

      // 点右侧翻页区 → 第 2 页
      // 先等书签提示的 SnackBar 收掉（1200ms）
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
      // 用工具栏「下一页」按钮翻页（比模拟点按翻页区稳定，
      // 翻页区手势依赖 tap 竞技场仲裁，测试环境行为不一致）
      await tester.tap(find.byTooltip('下一页'));
      await tester.pumpAndSettle();
      expect(find.text('第 2 页 / 共 3 页'), findsOneWidget);

      // 双页拼合切换：3 页 → 2 个跨页，当前锚在第 2-3 页
      await tester.tap(find.byTooltip('双页拼合'));
      await tester.pumpAndSettle();
      expect(find.text('第 1-2 页 / 共 3 页'), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 2)));

    // 回归：竖屏手动开双页后，翻页页码要按「一屏两页」折算
    // （之前 _onPageChanged 只判了横屏，竖屏双页会把页码记错、
    // 「下一页」在奇数跨页上空转）。见 reader_page_io.dart 的注释。
    testWidgets('竖屏双页模式下的页码与翻页', (tester) async {
      final fakePages = [
        for (var i = 0; i < 5; i++) '/nonexistent/page-$i.jpg',
      ];
      tester.view.physicalSize = const Size(489, 914);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<LibraryState>.value(
          value: library,
          child: MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: ReaderPage(issue: issue(), pages: fakePages),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('第 1 页 / 共 5 页'), findsOneWidget);

      // 开双页：5 页 → 3 个跨页，当前锚在第 1-2 页
      await tester.tap(find.byTooltip('双页拼合'));
      await tester.pumpAndSettle();
      expect(find.text('第 1-2 页 / 共 5 页'), findsOneWidget);

      // 下一页 → 第 2 个跨页 = 第 3-4 页（修 bug 前这里会卡住不动）
      await tester.tap(find.byTooltip('下一页'));
      await tester.pumpAndSettle();
      expect(find.text('第 3-4 页 / 共 5 页'), findsOneWidget);

      // 再下一页 → 最后一个跨页 = 第 5 页
      await tester.tap(find.byTooltip('下一页'));
      await tester.pumpAndSettle();
      expect(find.text('第 5 页 / 共 5 页'), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
