import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/marvel_event.dart';
import '../../data/models/marvel_models.dart';
import '../../data/repository/preferences_repository.dart';
import '../../features/events/event_detail_page.dart';
import '../../features/events/events_page.dart';
import '../../features/favorites/favorites_page.dart';
import '../../features/favorites/import_flow_page.dart';
import '../../features/favorites/user_list_page.dart';
import '../../features/guide_detail/guide_detail_page.dart';
import '../../features/guides/guides_page.dart';
import '../../features/home/home_page.dart';
import '../../features/issue/issue_route_page.dart';
import '../../features/reader/reader_route_page.dart';
import '../../features/root/root_shell.dart';
import '../../features/search/search_page.dart';
import '../../features/series/series_page.dart';
import '../../features/series_hub/hero_page.dart';
import '../../features/series_hub/series_hub_page.dart';

/// 路由名。跳转时用名字而不是拼路径，改路径不用改调用方。
abstract final class RouteNames {
  static const home = 'home';
  static const guides = 'guides';
  static const seriesHub = 'seriesHub';
  static const events = 'events';
  static const favorites = 'favorites';

  static const search = 'search';
  static const guide = 'guide';
  static const series = 'series';
  static const wikiSeries = 'wikiSeries';
  static const issue = 'issue';
  static const reader = 'reader';
  static const event = 'event';
  static const userList = 'userList';
  static const hero = 'hero';
  static const importFlow = 'import';
}

/// 全应用路由表。
///
/// 底部是五个 tab：指南 / 系列 / 首页（最左侧、默认 tab）/ 事件 / 收藏，
/// 用 `StatefulShellRoute.indexedStack` 保留各自状态。
/// 搜索不再是 tab，从各页右上角推入。
class AppRouter {
  const AppRouter._();

  static GoRouter create() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => RootShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  name: RouteNames.home,
                  builder: (context, state) => const HomePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/guides',
                  name: RouteNames.guides,
                  builder: (context, state) => const GuidesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/series',
                  name: RouteNames.seriesHub,
                  builder: (context, state) => const SeriesHubPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/events',
                  name: RouteNames.events,
                  builder: (context, state) => const EventsPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/favorites',
                  name: RouteNames.favorites,
                  builder: (context, state) => const FavoritesPage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/search',
          name: RouteNames.search,
          pageBuilder: (context, state) => _slideUp(
            state,
            SearchPage(initialQuery: state.uri.queryParameters['q']),
          ),
        ),
        GoRoute(
          path: '/guide/:id',
          name: RouteNames.guide,
          builder: (context, state) => GuideDetailPage(
            guideId: state.pathParameters['id']!,
            initial: state.extra as ReadingGuide?,
          ),
        ),
        GoRoute(
          path: '/series/:id',
          name: RouteNames.series,
          builder: (context, state) => SeriesPage(
            seriesId: state.pathParameters['id']!,
            seriesTitle: state.uri.queryParameters['title'] ?? '',
          ),
        ),
        GoRoute(
          path: '/wiki/:name',
          name: RouteNames.wikiSeries,
          builder: (context, state) => SeriesPage.fandom(
            fandomName: state.pathParameters['name']!,
          ),
        ),
        GoRoute(
          path: '/issue/:id',
          name: RouteNames.issue,
          builder: (context, state) => IssueRoutePage(
            issueId: state.pathParameters['id']!,
            initial: state.extra as ComicIssue?,
          ),
        ),
        GoRoute(
          path: '/reader/:id',
          name: RouteNames.reader,
          builder: (context, state) => ReaderRoutePage(
            issueId: state.pathParameters['id']!,
            initial: state.extra as ComicIssue?,
          ),
        ),
        GoRoute(
          path: '/hero/:id',
          name: RouteNames.hero,
          builder: (context, state) => HeroPage(
            heroId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/import',
          name: RouteNames.importFlow,
          builder: (context, state) => ImportFlowPage(
            initialPaths: (state.extra as List<String>? ?? const []),
          ),
        ),
        GoRoute(
          path: '/event/:id',
          name: RouteNames.event,
          builder: (context, state) => EventDetailPage(
            eventId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/list/:id',
          name: RouteNames.userList,
          builder: (context, state) => UserListPage(
            listId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
  }

  /// 搜索页从底部滑上来，像一层浮层而不是普通推页。
  static CustomTransitionPage<void> _slideUp(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(curved),
          child: child,
        );
      },
    );
  }

  // ── 语义化的跳转入口 ─────────────────────────────────────────

  static void openSearch(BuildContext context, {String? query}) {
    context.pushNamed(
      RouteNames.search,
      queryParameters: query == null ? const <String, String>{} : {'q': query},
    );
  }

  static void openIssue(BuildContext context, ComicIssue issue) {
    context.pushNamed(
      RouteNames.issue,
      pathParameters: {'id': issue.id},
      extra: issue,
    );
  }

  static void openSeries(BuildContext context, String seriesId, String title) {
    context.pushNamed(
      RouteNames.series,
      pathParameters: {'id': seriesId},
      queryParameters: {'title': title},
    );
  }

  static void openWikiSeries(BuildContext context, String pageName) {
    context.pushNamed(RouteNames.wikiSeries, pathParameters: {'name': pageName});
  }

  static void openGuide(BuildContext context, ReadingGuide guide) {
    context.pushNamed(
      RouteNames.guide,
      pathParameters: {'id': guide.id},
      extra: guide,
    );
  }

  static void openReader(BuildContext context, ComicIssue issue) {
    context.pushNamed(
      RouteNames.reader,
      pathParameters: {'id': issue.id},
      extra: issue,
    );
  }

  static void openEvent(BuildContext context, MarvelEvent event) {
    context.pushNamed(RouteNames.event, pathParameters: {'id': event.id});
  }

  static void openUserList(BuildContext context, UserList list) {
    context.pushNamed(RouteNames.userList, pathParameters: {'id': list.id});
  }
}