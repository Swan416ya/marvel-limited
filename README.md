# Marvel Limited

自用的漫威漫画阅读客户端（Flutter）。数据来自 marvel.com 的 bifrost 接口
与 Marvel Database（fandom），大事件库、封面等静态数据打包在应用内，
离线也能看。

## 构建

**打手机能装的包请用 ABI 拆分**（默认的 `flutter build apk` 会把
arm64 / armeabi-v7a / x86_64 三个架构打进同一个 apk，包体直接翻三倍：
59.9MB → 拆分后单架构 26MB）：

```bash
flutter build apk --release --split-per-abi
# 产物（装 arm64 那个，现代手机都是这个）：
#   build/app/outputs/flutter-apk/app-arm64-v8a-release.apk    26.0 MB
#   build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk  23.7 MB   （老机器）
#   build/app/outputs/flutter-apk/app-x86_64-release.apk       27.4 MB   （模拟器）
```

只想出一个包、且只给现代手机用：`flutter build apk --release --target-platform android-arm64`。

Web 预览：`flutter run -d web-server --web-port=8080 --web-hostname=127.0.0.1`
（浏览器里拉官网接口要走本地代理，见 `tool/dev_proxy.py`，监听 127.0.0.1:8322）。

## 静态数据

| 文件 | 内容 | 生成方式 |
| --- | --- | --- |
| `assets/data/marvel_events.json` | 55 个大事件（分级 / 阅读顺序 / 简介） | 人工整理，逐条核对官方阅读指南与 Marvel Database |
| `assets/data/event_covers/*.jpg` | 事件封面（本地优先，离线可用） | `python tool/fetch_event_covers.py` |
| `assets/data/hero_avatars/*.png` | 英雄头像（官方图床不稳，本地打包） | `python tool/fetch_hero_avatars.py` |
| `assets/fonts/NotoSansSC-*.ttf` | 中文字体子集（按项目用到的字符裁剪） | `pyftsubset`，见 pubspec 注释 |

## 已知取舍

- **底部导航不用 `BackdropFilter`**：圆角裁剪 + BackdropFilter 在
  Flutter Web(CanvasKit) 上会让整页 body 的图片停止绘制（封面全空）。
  现在的「液态玻璃」是半透明底 + 反光渐变 + 亮边 + 投影做的，观感接近
  且省掉一次 saveLayer。
- **中文字体必须打包**：不打包的话 Web 端靠 CanvasKit 联网拉 Noto 回退
  字体，网络一慢就同时出现缺字形（豆腐块）和「测量宽度 ≠ 绘制宽度」
  （中英混排被裁字）。
