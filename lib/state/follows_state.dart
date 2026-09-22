import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repository/preferences_repository.dart';

/// 追更（关注的系列）。首页「我的追更」和系列页的追更按钮共用。
class FollowsState extends ChangeNotifier {
  FollowsState(this._prefs);

  final PreferencesRepository _prefs;

  List<FollowedSeries> get series => _prefs.follows;

  bool isFollowing(String seriesId) => _prefs.isFollowing(seriesId);

  /// 返回「现在是否在追」。
  bool toggle(FollowedSeries series) {
    final now = _prefs.toggleFollow(series);
    unawaited(_prefs.persistFollows());
    notifyListeners();
    return now;
  }
}