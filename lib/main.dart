import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/brand_assets.dart';
import 'data/repository/preferences_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 手机锁竖屏：本项目是漫画阅读，竖屏单页最合适；平板/桌面
  // （最短边 >= 600 逻辑像素）放开旋转，走横屏双页布局。
  final view = PlatformDispatcher.instance.views.first;
  final shortestLogical =
      view.physicalSize.shortestSide / view.devicePixelRatio;
  if (shortestLogical < 600) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // 品牌资源探测：assets/brand/ 下有 logo 图就用图，没有就用自绘文字标识
  await BrandAssets.probe();

  // 收藏、搜索历史、阅读进度在建界面之前就绪，首页不用先闪一下空态
  final preferences = PreferencesRepository();
  await preferences.load();

  runApp(MarvelApp(preferences: preferences));
}