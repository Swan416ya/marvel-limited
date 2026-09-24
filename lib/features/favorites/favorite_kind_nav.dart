import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../data/repository/preferences_repository.dart';

/// 收藏条目的共享跳转与徽标文案：收藏页与书单详情页各有一份相同的
/// switch，抽到这里避免改一漏一处。

/// 按种类打开收藏详情页。
extension FavoriteEntryNavigation on FavoriteEntry {
  /// issue → 期详情（快照缺失时不跳）、series → 系列页、guide → 指南详情。
  void open(BuildContext context) {
    switch (kind) {
      case FavoriteKind.issue:
        final issue = asIssue;
        if (issue != null) AppRouter.openIssue(context, issue);
      case FavoriteKind.series:
        AppRouter.openSeries(context, id, title);
      case FavoriteKind.guide:
        AppRouter.openGuide(context, asGuide);
    }
  }
}

/// 封面角标/行内徽标用的短文案。
///
/// 注意与 [FavoriteKind.label]（全称「漫画期 / 阅读指南」）不同：
/// 角标空间小，这里保持原有的「期 / 指南」短文案，显示不能变。
extension FavoriteKindBadge on FavoriteKind {
  String get badgeLabel => switch (this) {
    FavoriteKind.issue => '期',
    FavoriteKind.series => '系列',
    FavoriteKind.guide => '指南',
  };
}
