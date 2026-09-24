# Marvel Limited

自用的漫威漫画阅读客户端（Flutter）。数据来自 marvel.com 的 bifrost 接口
与 Marvel Database（fandom），大事件库、封面等静态数据打包在应用内，
离线也能看。缺资源的期可一键跳转 getcomics.org 搜索；阅读器内置
OCR + 大模型翻译（ML Kit 仅 Android/iOS，模型接口自备）。

## 构建

**打手机能装的包请用 ABI 拆分**（默认的 `flutter build apk` 会把
arm64 / armeabi-v7a / x86_64 三个架构打进同一个 apk，包体直接翻三倍：
59.9MB → 拆分后单架构 26MB）：

```bash
flutter build apk --release --split-per-abi
# 产物（装 arm64 那个，现代手机都是这个）：
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk    26.0 MB
#   build/app/outputs/flutter-apk/apparmeabi-v7a-release.apk  23.7 MB   （老机器）
#   build/app/outputs/flutter-apk/app-x86_64-release.apk       27.4 MB   （模拟器）
```

只想出一个包、且只给现代手机用：`flutter build apk --release --target-platform android-arm64`。

Web 预览：`flutter run -d web-server --web-port=8080 --web-hostname=127.0.0.1`
（浏览器里拉官网接口要走本地代理，见 `tool/dev_proxy.py`，监听 127.0.0.1:8322）。

## 静态数据

| 文件 | 内容 | 生成方式 |
| --- | --- | --- |
| `assets/data/marvel_events.json` | 53 个大事件（分级 / 阅读顺序 / 简介） | 人工整理，逐条核对官方阅读指南与 Marvel Database |
| `assets/data/event_covers/*.jpg` | 事件封面（本地优先，离线可用） | `python tool/fetch_event_covers.py` |
| `assets/data/hero_avatars/*.jpg` | 英雄头像（官方图床不稳，本地打包；jpg 压体积） | `python tool/fetch_hero_avatars.py` |
| `assets/data/catalog_snapshot.json` | 目录冷启动快照（stale-while-revalidate 的 stale） | `python tool/build_catalog_snapshot.py` |
| `assets/fonts/NotoSansSC-*.ttf` | 中文字体子集（按项目用到的字符裁剪） | `pyftsubset`，见 pubspec 注释 |
| `assets/brand/` | 品牌 logo、应用图标源图 | 见 `assets/brand/README.txt` |

## 工具脚本

| 脚本 | 用途 |
| --- | --- |
| `tool/fetch_event_covers.py` / `tool/fetch_hero_avatars.py` | 抓事件封面 / 英雄头像进包（上表） |
| `tool/build_catalog_snapshot.py` | 生成目录冷启动快照 |
| `tool/build_reading_orders.py` | 从 wiki 拉逐期发行日期，给事件补逐期 `readingOrder` |
| `tool/dev_proxy.py` | Web 联调本地代理（见上文构建一节） |
| `tool/convert_cbr.py` | 个人漫画库 CBR(RAR)→CBZ 批量转换（应用只能解 zip；内含本机路径，用前改） |

## 已知取舍

- **底部导航的液态玻璃分两套实现**：原生平台（Android/iOS/桌面）用
  `liquid_glass_widgets` 的 `GlassTabBar`，材质由 shader 生成（边缘高光、
  Fresnel 受光边、点按回弹、随身后内容亮度切换深浅），画质钉在
  `GlassQuality.standard` 档——它不做背景纹理截图，所以没有 flutter#138627
  那种纹理延迟释放的内存尖峰，滚动中也稳。**Web 不能走这套**：圆角裁剪 +
  背景滤镜在 Flutter Web(CanvasKit) 上会让整页 body 的图片停止绘制（封面
  全空，实测过），所以 Web 保留手绘版（半透明底 + 反光渐变 + 亮边 + 投影）。
  分流在 `lib/features/root/widgets/app_nav_bar.dart`，两套实现各自的注释里
  写了细节。实测两套实现下封面都正常绘制、Web 无 console 报错。
- **中文字体必须打包**：不打包的话 Web 端靠 CanvasKit 联网拉 Noto 回退
  字体，网络一慢就同时出现缺字形（豆腐块）和「测量宽度 ≠ 绘制宽度」
  （中英混排被裁字）。
