import 'package:shared_preferences/shared_preferences.dart';

import 'prefs/favorites_prefs.dart';
import 'prefs/follows_prefs.dart';
import 'prefs/llm_prefs.dart';
import 'prefs/prefs_storage.dart';
import 'prefs/reading_prefs.dart';
import 'prefs/search_history_prefs.dart';
import 'prefs/theme_prefs.dart';
import 'prefs/user_lists_prefs.dart';

// 数据类历史上住在这个文件，调用方的 import 都指着这里——转发出去，
// 拆文件就不用全项目改 import。
export '../models/llm_config.dart';
export '../models/local_library.dart';

/// 本地偏好仓库：收藏（四类）、追更、自建书单、搜索历史、阅读进度、
/// 书签、主题、翻译模型配置。
///
/// 按域拆成 mixin，每个域一个文件（`prefs/` 下），加域只动自己的那个。
/// 全应用唯一碰 SharedPreferences 的地方：存储句柄收在 [PrefsStorage]，
/// 各域共享同一个实例。内存里留一份同步快照，UI 不用 await 就能读到
/// 当前状态（这是收藏能即时同步的前提）。
class PreferencesRepository
    with
        FavoritesPrefs,
        FollowsPrefs,
        UserListsPrefs,
        SearchHistoryPrefs,
        ReadingPrefs,
        ThemePrefs,
        LlmPrefs {
  @override
  final storage = PrefsStorage();

  bool get isReady => storage.isReady;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    storage.instance = prefs;
    loadFavorites(prefs);
    loadFollows(prefs);
    loadUserLists(prefs);
    loadSearchHistory(prefs);
    loadReadingState(prefs);
    loadTheme(prefs);
    loadLlmConfig(prefs);
  }
}
