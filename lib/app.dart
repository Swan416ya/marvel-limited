import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repository/catalog_repository.dart';
import 'data/repository/disk_cache.dart';
import 'data/repository/events_repository.dart';
import 'data/repository/preferences_repository.dart';
import 'data/repository/wiki_repository.dart';
import 'data/sources/bifrost_client.dart';
import 'data/sources/fandom_client.dart';
import 'state/catalog_state.dart';
import 'state/favorites_state.dart';
import 'state/follows_state.dart';
import 'state/library_state.dart';
import 'state/search_state.dart';
import 'state/theme_state.dart';

/// 应用装配：仓库 → 状态 → 路由 → 主题。
///
/// 依赖只在这里创建一次，页面通过 Provider 拿；页面之间不互相引用，
/// 跳转统一走 `AppRouter`。
class MarvelApp extends StatefulWidget {
  const MarvelApp({
    super.key,
    required this.preferences,
    this.bifrost,
    this.fandom,
    this.eventsRepository,
  });

  /// 已在 `main()` 里加载完的本地偏好（收藏 / 追更 / 书单 / 进度 / 主题）。
  final PreferencesRepository preferences;

  /// 可注入的 HTTP 客户端（widget 测试传零重试退避的实例，
  /// 避免 fake-async 里留下挂起的 Timer）。
  final BifrostClient? bifrost;
  final FandomClient? fandom;

  /// 可注入的静态事件仓库。默认实现要从资产里读两百多 KB 的 JSON，
  /// 而 widget 测试的 fake-async 里那读操作不会完成——测试需要的是
  /// 「首页把事件渲染出来」这条逻辑，所以直接从测试注入数据。
  final EventsRepository? eventsRepository;

  @override
  State<MarvelApp> createState() => _MarvelAppState();
}

class _MarvelAppState extends State<MarvelApp> {
  late final DiskCache _cache = DiskCache();
  late final CatalogRepository _catalogRepo = CatalogRepository(
    client: widget.bifrost,
    cache: _cache,
  );
  late final WikiRepository _wikiRepo = WikiRepository(
    client: widget.fandom,
    cache: _cache,
  );
  late final EventsRepository _eventsRepo =
      widget.eventsRepository ?? EventsRepository();

  late final CatalogState _catalog = CatalogState(_catalogRepo);
  late final FavoritesState _favorites = FavoritesState(widget.preferences);
  late final LibraryState _library = LibraryState(widget.preferences);
  late final FollowsState _follows = FollowsState(widget.preferences);
  late final ThemeState _theme = ThemeState(widget.preferences);

  /// 搜索的「本地索引」：已导入的 + 收藏的 + 本次会话已缓存的目录内容。
  late final SearchState _search = SearchState(
    catalog: _catalogRepo,
    wiki: _wikiRepo,
    events: _eventsRepo,
    prefs: widget.preferences,
    localIssues: () => [
      ..._library.importedIssues,
      ..._favorites.entries
          .where((e) => e.kind == FavoriteKind.issue)
          .map((e) => e.asIssue)
          .whereType(),
      ..._catalogRepo.cachedIssues,
    ],
  );

  late final _router = AppRouter.create();

  @override
  void dispose() {
    _catalog.dispose();
    _favorites.dispose();
    _library.dispose();
    _follows.dispose();
    _theme.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PreferencesRepository>.value(value: widget.preferences),
        Provider<CatalogRepository>.value(value: _catalogRepo),
        Provider<WikiRepository>.value(value: _wikiRepo),
        Provider<EventsRepository>.value(value: _eventsRepo),
        ChangeNotifierProvider<CatalogState>.value(value: _catalog),
        ChangeNotifierProvider<FavoritesState>.value(value: _favorites),
        ChangeNotifierProvider<LibraryState>.value(value: _library),
        ChangeNotifierProvider<FollowsState>.value(value: _follows),
        ChangeNotifierProvider<ThemeState>.value(value: _theme),
        ChangeNotifierProvider<SearchState>.value(value: _search),
      ],
      child: AnimatedBuilder(
        animation: _theme,
        builder: (context, _) => MaterialApp.router(
          title: 'Marvel Limited',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _theme.mode,
          routerConfig: _router,
        ),
      ),
    );
  }
}