import 'package:flutter/material.dart';

import 'app.dart';
import 'core/brand_assets.dart';
import 'data/repository/preferences_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 品牌资源探测：assets/brand/ 下有 logo 图就用图，没有就用自绘文字标识
  await BrandAssets.probe();

  // 收藏、搜索历史、阅读进度在建界面之前就绪，首页不用先闪一下空态
  final preferences = PreferencesRepository();
  await preferences.load();

  runApp(MarvelApp(preferences: preferences));
}