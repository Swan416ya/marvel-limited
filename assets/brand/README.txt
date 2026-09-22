品牌资源目录
============

marvel_unlimited_logo.svg    ← 界面上的品牌标识（优先用这个，SVG）
marvel_unlimited_logo.png    ← 同上，PNG 版（有 SVG 时忽略）

    把品牌 logo 存成上面任一文件名放进本目录，重启应用即可生效——代码不用改。
    SVG 官方素材直接丢进来就能用（flutter_svg 渲染，任意缩放不糊）；
    PNG 建议透明底、高度 120px 以上（首页品牌栏按 22 逻辑像素显示，
    给 3 倍屏留够分辨率）。

    两个文件都不在时，界面会用 `lib/core/widgets/brand_logo.dart` 里自绘的
    文字标识（漫威红底白字 MARVEL + 字距拉开的 UNLIMITED）兜底。

app_icon_source.png         应用图标源图（1024×1024，全幅）
app_icon_foreground.png     自适应图标前景（1024×1024，透明底，内容在中央 62% 安全区）

    当前这两张是项目自绘的占位图标（深黑底 + 红色圆角块 + 白色翻开的书），
    不是漫威官方图形。换成自己的图之后重新生成各平台图标：

        dart run flutter_launcher_icons

    会一次性更新 Android 的 mipmap-*/ic_launcher.png、Web 的 favicon.png
    和 PWA 的 Icon-192/512 与 maskable 版本。

注意：Marvel / Marvel Unlimited 是漫威的注册商标。自用没问题，
对外分发或上架应用商店会有商标风险。