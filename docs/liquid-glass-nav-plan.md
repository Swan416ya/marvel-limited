# 底部导航栏「液态玻璃」技术实现计划

> 目标：把底部导航栏做成 iOS 26 Liquid Glass 那种**真**液态玻璃（折射 + 边缘高光 +
> 自适应色调 + 动态形变），而不是现在的仿制品。
> 本文档 = 调研（苹果设计语言 / 13 个开源仓库 / Flutter 引擎能力 / 6 个 pub 包）
> + 技术选型 + 分阶段实施计划。实施另行开分支。

---

## 1. 现状与约束（项目已知事实）

### 1.1 当前实现

`lib/features/root/root_shell.dart` 的 `_LiquidGlassBar`：

- 悬浮胶囊（圆角 pill，左右留边 8、限宽 640 居中），图标式无文字标签
- 视觉 = 半透明底 + 上半部斜向反光渐变 + 0.8px 亮边 + 外投影
- 高亮胶囊随选中项平移（AnimatedAlign），图标颜色/缩放过渡
- 有意**不用** `BackdropFilter`（见 1.2 的坑），是「假玻璃」：背景内容不透出、
  无折射、高光不随背景变化

### 1.2 已知的引擎坑（本项目踩过的，勿重蹈）

| 坑 | 现象 | 记录位置 |
| --- | --- | --- |
| CanvasKit Web 上 **圆角裁剪 + `BackdropFilter` 会让整页 body 的图片停止绘制** | 加了真模糊后首页/事件页封面全空（图片请求 200 但不绘制），删掉滤镜立刻恢复 | README「已知取舍」、root_shell.dart 注释 |
| Web 中文字体必须打包 | 不打包时缺字形/测量错乱（连带 chip 文字被淡出裁掉） | README、pubspec 注释 |
| release APK 必须主清单声明 INTERNET | Flutter 模板只给 debug/profile 清单加权限，release 真机全网失败 | android/app/src/main/AndroidManifest.xml 注释 |

### 1.3 平台优先级与运行环境

- **主平台：Android 真机**（用户实际使用场景；release APK，split-per-abi）
- **Web：开发预览用**（127.0.0.1:8080 + 本地代理 8322），兼容即可、**允许降级渲染**
- 桌面（Windows）：仅测试用途
- 性能基线：导航栏常驻、滚动实时绘制，目标 60fps 无掉帧
- 包体：当前 arm64 37.5MB（含 OCR 原生管线）；液态玻璃方案不得显著增重
  （shader 数 KB 可接受；不引大体积原生库）
- 可访问性：跟随系统「减少透明度/增强对比度/减弱动态效果」设置（HIG 要求）

### 1.4 集成点

- 唯一使用方：`RootShell` 的 `_LiquidGlassBar`；同类视觉可复用处：阅读器
  工具条 `GlassPanel`、状态胶囊
- 设计约束：导航胶囊限宽 640 居中、高亮平移动画、图标过渡（现有动效保留）

---

## 2. 苹果的设计语言（WWDC25 session 219「Meet Liquid Glass」+ HIG Materials）

**核心定义**：Liquid Glass 是「a new digital meta-material that dynamically bends
and shapes light」——不是复刻现实材质，而是动态弯折、塑形、聚焦光线的数字超材料。

**视觉要素清单**（按识别度排序）：

1. **折射 / 透镜（refraction & lensing）** —— 识别度的主要来源：透明物体对光的
   warp & bend。旧材质散射光，新材料实时弯折并**聚焦**光。用于分隔层级、传达前后关系。
2. **边缘高光 / 镜面反射** —— 独立的 highlights layer：虚拟光源沿材质几何产生高光，
   光沿轮廓游走定义剪影；部分场景响应设备运动（陀螺仪）。
3. **多层结构 + 自适应色调** —— 每层根据身后内容持续微调 tint 与动态范围保证
   控件可读；附近彩色内容的光会「spill onto its surface」并渗入阴影；
   可在 light/dark 间独立切换。
4. **厚度 / 深度** —— 形态变大时模拟更厚材质：更深阴影、更强 lensing。
5. **压缩形态（condensed form）与液态透镜（liquid lens）** —— 控件持续 shape shift；
   选中项可「lift up into Liquid Glass」（tab bar 选中项抬升成液态透镜，
   即系统里的 `_UILiquidLensView`）；形变是「gradually modulating the light
   bending」，不是淡入淡出。
6. **滚动联动** —— 深色内容滚过时玻璃切深色样式或 subtle dimming 保对比。

**设计准则（HIG）**：

- 只属于 **controls & navigation 层**：「Don't use Liquid Glass in the content layer」
  「Use Liquid Glass effects sparingly」——滥用 muddy the hierarchy。
  sidebar + tab bar 是跨平台核心导航语言 → **导航栏正是它设计给的场景** ✓
- 两个变体**绝不混用**：
  - **Regular**（模糊 + 亮度自适应）：最常用，任何场景可读 → **本项目用这个**
  - **Clear**（永久透明 + 必须配 ~35% 暗化层）：仅当浮在 media-rich 内容上、
    暗化不伤内容、其上内容 bold and bright 三条件同时满足 → 本场景不满足，不用
- 厚度取舍：厚→不透明→细节对比好；薄→保留背景上下文

**可访问性约束**：Reduced Transparency / Increased Contrast / Reduced Motion
自动生效且「不牺牲视觉吸引力」；薄材质上 vibrancy 对比度最低档禁用。

---

## 3. 开源实现盘点

| 仓库（星数，语言） | 技术路线 | 可借鉴点 | 活跃度 |
| --- | --- | --- | --- |
| **Kyant0/AndroidLiquidGlass** (3.9k, Kotlin) | backdrop 捕获 + AGSL RuntimeShader（圆角折射[+色散]）+ RenderEffect（Android 13+） | **官方教程自带 Glass Bottom Bar / Interactive Glass Bottom Bar**；lens 参数命名 | 活跃 |
| **sdegenaar/liquid_glass_widgets** (665, **Dart**) | Flutter 全平台：Impeller 双 pass 高斯模糊 + GLSL 折射 + 纹理捕获；Web 轻量 2D shader；minimal 档 = BackdropFilter+饱和矩阵+rim | **现成 GlassTabBar/GlassScaffold**；jelly 物理、滚动最小化 tab、**content-aware 亮度翻转**、Reduce Transparency 近似 | 很活跃（2026-09） |
| **whynotmake-it/flutter_liquid_glass** (444, **Dart**) | FragmentShader（SDF squircle→法线→折射采样模糊背景纹理；uniform: refractiveIndex/色差/厚度/光照）+ LiquidGlassLayer 层捕获；LiquidStretch 挤压；FakeGlass 降级 | **shader 源码可直接参考**；Impeller only（Web 不支持）；动画有内存尖峰 bug | 很活跃 |
| **DnV1eX/LiquidGlassKit** (440, Swift) | Metal shader + CABackdropLayer/根视图截图 | **LiquidLensView 复刻 tab bar 液态透镜**：加速度驱动 squash/stretch、resting→lifted 两态 | 中 |
| **BarredEwe/LiquidGlass** (202, Swift) | Metal + 视图层级截图→MTLTexture | 低成本更新策略（continuous/once/manual 重截） | 中 |
| **iyinchao/liquid-glass-studio** (714, Web) | WebGL2/WebGPU，SDF + smooth merge(blob) | **参数最全的「配方」**：折射/色散/Fresnel/glare/多 pass 模糊 | 活跃 |
| **ybouane/liquidglass** (503, TS) | html-to-image 截图→WebGL 片元 | 折射+色差+Fresnel+多光源 specular+rim 全要素 shader | 活跃 |
| **naughtyduk/liquidGL** (894, JS) | 自研截图 + WebGPU→WebGL2→WebGL→CSS backdrop-filter **降级链** | 降级链思路；截图约 55ms/帧（大页面） | 活跃 |
| **rdev/liquid-glass-react** (6.2k, TS) | SVG feDisplacementMap 截图位移（standard/polar/prominent）+ shader 模式 | 弹性形变参数、色差、hover/click 动效；Safari/Firefox 位移不生效 | 2025-06 后停滞 |
| **callstack/liquid-glass** (1.7k, RN) | 封装 iOS 26 原生（Xcode 26+） | regular/clear 双模式、多玻璃合并、文字自适应色（高 ≥65px 失效）；仅 iOS | 活跃 |
| **AndrewPrifer/liquid-dom** (2.5k, TS) | WebGPU，DOM→GPU 纹理 | 全保真方案天花板；需 Chrome 实验 flag | 活跃 |
| shuding/liquid-glass (1.2k, JS) | 单文件 SVG filter 配方 | 最小可行折射配方 | 停滞 |
| QmDeve/AndroidLiquidGlassView (310, Java) | AGSL 真折射+色散，Android 13+，低版本纯透明 | 低端降级策略 | 活跃 |

**共性结论**：真折射的技术核心都是同一件事——**把背后内容当纹理，按法线位移采样 +
色散 + Fresnel 边缘高光**。区别只在纹理怎么拿到（原生 backdrop 层 / 视图截图 /
toImage）和在哪跑 shader（Metal / AGSL / WebGL / Flutter iMF）。

---

## 4. 技术路线矩阵

| 路线 | 视觉保真 | 性能开销 | 平台限制 | 复杂度 |
| --- | --- | --- | --- | --- |
| a. 纯半透明+渐变+亮边（**当前实现**） | 低-中（静态近似、无折射） | 零 | 无 | 低 |
| b. BackdropFilter 实时模糊 | 中（毛玻璃、无折射） | 每帧 backdrop 采样 + saveLayer | **Web CanvasKit 圆角裁剪+BackdropFilter 整页图片停绘（本项目实测）** | 低 |
| c. b + 边缘高光 + 自适应色调 | 中-高（iOS 静态观感） | b + 渐变绘制 | 同 b 的坑（Web 须改走 shader 路径） | 中 |
| d. 真折射·截图位移（RepaintBoundary→Image→位移采样） | 高 | `toImage` 含 GPU 回读（贵）；滚动每帧重截 ≈55ms 级；Flutter 纹理 dispose bug #138627 内存尖峰 | 可用 CanvasKit shader | 高 |
| e. 真折射·FragmentShader（SDF+法线+折射+色散+Fresnel） | 最高（实时折射） | 层捕获 1 次 + 每帧 shader；Impeller 移动端稳 | Impeller 的 `ImageFilter.shader` 可免截图直取背景（仅 Android/iOS）；Web 用 `toImageSync` 截图喂同一 shader | 高 |
| f. e + 挤压形变（condensed / liquid lens） | 最高（含动效语言） | + 弹簧/几何动画，小面积可控 | 同 e | 最高 |

---

## 5. Flutter 侧技术手段（引擎能力 + 包评估）

### 5.1 引擎能力表（Flutter 3.47）

| API | 能力 | 性能代价 | Android | Web(CanvasKit) |
| --- | --- | --- | --- | --- |
| `BackdropFilter` | 实时取样背后内容做滤镜 | 高：saveLayer + 全 backdrop 读取 | 支持 | 支持但不可靠（§5.4） |
| `ImageFiltered` | 只滤自身 child | 便宜（官方明示比 BackdropFilter 轻） | 支持 | 支持 |
| `ImageFilter.blur/compose/matrix` | 模糊、组合滤镜、透视矩阵 | 链式叠加 | 支持 | 支持 |
| **`ImageFilter.shader(FragmentShader)`** | 给 shader 直接喂「已画内容」纹理，配 BackdropFilter 即**真折射**，免手动截图 | 一次 shader pass | **仅 Impeller**（`ImageFilter.isShaderFilterSupported` 运行时检测） | **抛错，不可用** |
| `FragmentProgram.fromAsset` + CustomPaint | 自绘折射/高光/色差/形变 | 首次编译贵（启动预热一次）；shader 实例必须复用 | 支持 | 支持（SkRuntimeEffect） |
| `ShaderMask` / `MaskFilter.blur` | 遮罩发光、柔光 | 各约 1 次 saveLayer | 支持 | 支持 |
| `Transform`（Matrix4 透视） | 挤压/形变 | 几乎免费 | 支持 | 支持 |
| `RepaintBoundary.toImageSync(pixelRatio)` | 截层为纹理喂 sampler | 同步无回读停顿（`toImage` 异步含 GPU 回读，慢）；`OffsetLayer.toImage(rect)` 可只截局部 | 支持 | 支持 |

**关键事实**：除 Impeller 的 `ImageFilter.shader` 外，**没有任何 API 能把背景层当纹理喂给
自定义 shader**；Web 上只能 `toImageSync` 截图传入。

**iMF（.frag）限制**：无 UBO/SSBO、仅 `sampler2D`、仅两参 `texture(s,uv)`、
无 varying/布尔/无符号整型；uniform 按声明顺序逐分量 `setFloat`；输出须**预乘 alpha**；
`#include <flutter/runtime_effect.glsl>` + `FlutterFragCoord()`。

### 5.2 pub 包评估

| 包 | 能力 | 活跃度 | 结论 |
| --- | --- | --- | --- |
| `liquid_glass_renderer` | 真折射（厚度/折射率）+模糊+光源高光 | 886 likes，v0.2.0-dev.4 标 EXPERIMENTAL | **Impeller 专用、Web 不支持**、API 未稳 → 不作主选 |
| `liquid_glass_widgets` | 双 pass（blur + `ImageFilter.shader` 折射/高光/色差/形变），含 GlassTabBar | 305 likes / 77.6k dl，46 小时前刚发版，MIT，6 平台 | **备选首选**（Web 走轻量 shader）；要求 Flutter ≥3.41（本项目 3.47 ✓） |
| `liquid_glass_easy` | 折射透镜+放大+色差+SDF 光学边+触感形变+lite 模式 | 266 likes，10 天前更新，MIT | 功能最全；Skia/Web 明确要求截 backgroundWidget（与 §5.3 同源）；tab pill 每帧截两次 → 建议 lite |
| `oc_liquid_glass` | 玻璃液滴：折射+blur+高光 | 80 likes，MIT | 无 Web → pass |
| `glassmorphism` | 仅 blur+半透明（≈路线 a/b） | 534 likes 但 **5 年未更新** | 无折射、停更 → 不引入 |

### 5.3 自研折射实现路径（双后端共用一个 .frag）

**Android(Impeller) 用 `ImageFilter.shader` 直取背景；Web 用 RepaintBoundary→
`toImageSync` 截条带喂同一个 shader。**

`.frag` 骨架（SDF 法线位移采样 + Fresnel 边缘高光）：

```glsl
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize; uniform vec2 uTexSize; uniform float uStrength;
uniform sampler2D uBackdrop;   // Impeller 自动注入；Web 喂截图
out vec4 fragColor;
void main() {
  vec2 uv = FlutterFragCoord().xy;
  float d = sdCapsule(uv, uSize);                       // 胶囊 SDF（d<0 内部）
  vec2 n  = normalize(vec2(dFdx(d), dFdy(d)));          // 梯度→法线
  float edge = 1.0 - smoothstep(0.0, 16.0, -d);         // 边缘带
  vec2 off = n * edge * edge * uStrength;               // 二次衰减位移（凸透镜）
  vec3 col = texture(uBackdrop, (uv + off) / uTexSize).rgb;
  col = mix(col, vec3(1.0), 0.08);                      // 磨砂白雾
  float rim = pow(edge, 3.0);                           // fresnel 近似边缘高光
  fragColor = vec4(col * 0.92 + rim * 0.35, 0.94);      // 预乘 alpha
}
```

Dart 骨架：

```dart
final prog = await FragmentProgram.fromAsset('shaders/nav_glass.frag'); // 启动预热
final img = (barKey.currentContext!.findRenderObject()! as RenderRepaintBoundary)
    .toImageSync(pixelRatio: 0.75);      // 只截导航条下方条带
final sh = prog.fragmentShader();        // 缓存复用，勿每帧新建
sh.setFloat(0, w); sh.setFloat(1, h); sh.setFloat(2, texW); sh.setFloat(3, texH);
sh.setImageSampler(0, img);
canvas.drawRRect(pill, Paint()..shader = sh);  // CustomPaint 画胶囊
```

**截图姿势**：RepaintBoundary 只包「导航条正下方约 640×160 的内容带」；
`toImageSync` 同步无停顿；**滚动时节流到 15–20Hz 或滚动停止/切 tab 才重截**，
静止时缓存复用，重截后 `oldImage.dispose()`。交互形变再叠 2 个 uniform
（触点位置+强度）进位移项。

### 5.4 性能预算与平台差异

- **Web 的坑怎么绕**：搜遍 flutter/flutter 未见与本项目现象完全对应的 issue
  （最近似 #154303「CanvasKit 带 blur 图片间歇不绘」已关闭、#154338「ImageFiltered
  web 渲染差异」仍 open）。结论：CanvasKit 的 backdrop/saveLayer+滤镜链路不可靠。
  **绕法：Web 彻底不用 BackdropFilter**——「截图 + Paint.shader」路径在 Web 只是
  一次 drawImageRect + runtime effect，没有 backdrop saveLayer，**反而避开该坑**。
- **Android**：Impeller 下 `ImageFilter.shader` 一条 BackdropFilter 即真折射
  （1 次 saveLayer）；注意 flutter#138627（纹理延迟释放→动画内存尖峰）、
  #187009（低端 Adreno 回归）。GLES 驱动有运行时编译卡顿风险 → 需启动预热 + 降级档。
- **60fps 预算（16.6ms）**：saveLayer ≤2；shader 每像素 ≤3 次 texture 采样、无循环；
  截图 ≤640×160@0.75 条带、≤20Hz（或事件驱动）；FragmentProgram 预热 1 次、
  FragmentShader 复用；边缘高光优先 shader 内 rim 项（免费）。

---

## 6. 推荐方案与实施计划

### 6.1 选型结论

**主路线：自研路线 e（真折射 FragmentShader），渐进到 f（形变）；Web 走同 shader
的截图后端（保真度接近）；同时保留路线 a 作为「lite 降级档」。**

理由：
- 导航胶囊是**小面积**控件（640×62 上限），shader + 局部截图的开销完全可控，
  而视觉收益（折射是 Liquid Glass 的识别度来源）正中要害；
- 自研只加一个数 KB 的 .frag，**包体零增重**（引包还带额外代码，且导航栏现有
  高亮平移动画/限宽胶囊是自研布局，包的 TabBar 要大改）；
- Web 走同一 shader（toImageSync 后端）**天然绕开 CanvasKit BackdropFilter 坑**，
  两端视觉一致；
- 参考实现充分：Kyant0/AndroidLiquidGlass 的 Glass Bottom Bar（lens 参数命名）、
  whynotmake-it/flutter_liquid_glass 的 GLSL（SDF squircle→法线→折射）、
  iyinchao/liquid-glass-studio 的配方（色散/Fresnel/glare）。

**备选（不想自研时）**：引入 `liquid_glass_widgets`（MIT、6 平台、自带 GlassTabBar +
内容亮度自适应 + Reduce Transparency 近似、46 小时前刚发版）。代价：外部依赖 +
其 premium 管线要求 Impeller；导航栏现有动效（高亮平移）需在其 TabBar 上重接。

### 6.2 分阶段实施

**Phase 1 — 玻璃质感（路线 c，1-2 天）**
- 现有 `_LiquidGlassBar` 换成自研 CustomPaint：SDF 胶囊 + 上高光渐变 + 内侧反光 +
  受光边（静态 rim）
- 自适应色调：采样背景亮度（toImageSync 截 64×32 缩略图算均值），深色内容上切
  深色玻璃样式（对照 HIG「深色内容滚过时切深色样式」）
- Reduce Transparency / Increase Contrast 开关：改纯色/高对比边框
- 验收：与 iOS 截图并排对比；滚动列表 60fps；Android + Web 同观感

**Phase 2 — 真模糊（2 天，Android 全量 / Web 跳过）**
- Android：`BackdropFilter(ImageFilter.blur(18))`（Impeller 安全；本项目此前的坑
  只在 Web 触发）——或直接进 Phase 3 的 shader 模糊（更接近 iOS 的多 pass）
- Web：不加模糊（Phase 1 的静态质感已可接受），**严禁**圆角裁剪+BackdropFilter 组合
- 验收：截图对比 + 帧率监测（DevTools timeline）+ **图片绘制不回归**
  （重点回归首页/事件页封面，这是当年踩坑的地方）

**Phase 3 — 真折射（核心，3-5 天）**
- 实现 §5.3 的 `nav_glass.frag`（SDF 胶囊→法线→位移采样 + 色散 2 次采样 + rim）
- Android(Impeller)：`ImageFilter.shader` 后端（免截图）；检测不到则自动降级 Phase 2/1
- Web + Android(GLES)：`RepaintBoundary.toImageSync` 条带后端（≤20Hz 节流、
  静止缓存、dispose 旧图）
- 参数面板（调试用，不入产品 UI）：折射强度 uStrength、色散量、rim 亮度、雾度
- 验收：截图对比（与 Kyant0 的 Glass Bottom Bar 效果并排）；滚动 60fps；
  内存无尖峰（#138627 注意 dispose）；`lite` 开关一键退回 Phase 1

**Phase 4 — 液态透镜动效（路线 f，3 天，可选）**
- 选中项「抬升」为液态透镜（resting→lifted 两态），点按弹性 squash/stretch
- 仿 LiquidGlassKit 的 LiquidLensView：加速度计驱动轻微挤压
  （HIG 提到的「响应设备运动」；需 `sensors_plus`）
- 与高亮平移动画并存的取舍：平移胶囊改为「液滴」随选中项移动并轻微形变
- 验收：动效手感（盲测对比）；Reduce Motion 下退化为平移

**Phase 5 — 质量收尾（1 天）**
- 三档画质开关（full / lite / off），低端机与 WebGL 自动降级
- widget 测试：lite 模式渲染冒烟；黄金图（golden）对比容差
- README「已知取舍」更新：液态玻璃的平台差异表

### 6.3 风险清单

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| CanvasKit BackdropFilter+裁剪停绘 | Web 图片全挂（当年踩过） | **Web 不用 BackdropFilter**（走 shader/静态）；Phase 2/3 验收必含「封面绘制回归」 |
| flutter#138627 纹理延迟释放 | 动画期内存尖峰 | 重截后立即 `oldImage.dispose()`；动画期截图频率减半 |
| GLES 运行时编译 shader 卡顿 | 首次显示顿一下 | 启动时预热（空画一次）；`ImageFilter.isShaderFilterSupported` 检测 + 自动降级 |
| 滚动时背景持续变化 | 折射纹理过期/性能 | 15-20Hz 节流；滚动减速/停止即重截；静止复用 |
| 低端 Adreno 回归（#187009） | 帧率掉 | lite 档（无色散、blur 半径减半）；真机实测阈值 |
| 包体/性能超标 | 违反 §1.3 约束 | 只加 .frag（数 KB）；saveLayer ≤2 预算内 |
| 依赖包 API 不稳（liquid_glass_renderer 等） | 后续维护成本 | 主选自研；包只当参考实现读源码 |

### 6.4 验收标准

1. **视觉**：与 iOS 26 真机截图并排对比（折射扭曲度、边缘高光、自适应色调三项
   各拍一张），盲测 ≥3/5 人认为接近；
2. **性能**：导航常驻、快速滚动首页/系列页 60fps（DevTools timeline 无超 16.6ms 帧）；
   滚动期间图片继续正常绘制（当年的回归点）；
3. **平台**：Android 真机 + Web 预览均可接受观感（Web 允许保真度略降）；
   Reduce Transparency / Increase Contrast / Reduce Motion 三种设置下表现正确；
4. **包体**：arm64 增量 <1MB（shader + 少量代码）；
5. **降级**：`lite` 开关一键退回 Phase 1 静态玻璃，无残留 shader 依赖。

---

## 7. 开放问题（待你拍板）

1. 视觉目标：要「真折射」（背景透出并扭曲）还是「高光质感」（静态近似即可）？
   → 计划按真折射（Phase 3）规划；若只要高光质感，Phase 1+2 即够（省 3-5 天）。
2. 交互形变（点按抬升液态透镜 + 挤压）这一档要不要做？
   → 即 Phase 4，可后置。
3. Web 端允许降级到什么程度？
   → 计划默认「Web 走同 shader 的截图后端」（观感接近）；若嫌截图开销，
   可退回静态质感（Phase 1）。
4. 自研（计划默认）还是引 `liquid_glass_widgets` 包？
   → 自研零依赖、包体零增重、贴合现有导航布局；引包省 2-3 天但受其 API 约束。

---

## 8. 实施记录（2026-09-24 完成）

### 8.1 拍板结果

| 问题 | 决定 |
| --- | --- |
| 1 视觉目标 | **高光质感**（不做真折射）→ 跳过 Phase 3 |
| 2 交互形变 | **要** → 即 Phase 4，本次一并做 |
| 3 Web 降级 | **降到现在的样子**（手绘版原样保留） |
| 4 自研还是引包 | **引包**（推翻本文档 §6.1 的自研默认） |

### 8.2 实际做法

包选 **`liquid_glass_widgets` 1.7.2**（MIT，6 平台，Flutter ≥3.41；本项目
3.47.5 ✓）。选它而不是 `liquid_glass_easy` 的理由：下载量/点赞高一个量级
（77.6k / 305 vs 15.8k / 266）、发布方是认证 publisher、且自带
`GlassQuality` 三档 + `GlassAdaptiveScope` 自动降级 + 无障碍开关，正好覆盖
本文档 §1.3 的性能与可访问性约束。

| 文件 | 作用 |
| --- | --- |
| `lib/features/root/widgets/app_nav_bar.dart` | 导航项数据 + 平台分流（`kIsWeb` 选实现） |
| `lib/features/root/widgets/glass_nav_bar.dart` | 原生：`GlassTabBar.bottom`，质量钉 `standard` |
| `lib/features/root/widgets/flat_glass_bar.dart` | Web：原 `_LiquidGlassBar` 原样搬过来 |
| `lib/main.dart` | 非 Web 时 `LiquidGlassWidgets.initialize()` 预热 shader |
| `lib/app.dart` | 非 Web 时 `wrap(adaptiveQuality: true, brightnessResolver: ...)` |

**为什么质量钉 `standard`**：`premium` 档要多做一次背景纹理截图
（`RepaintBoundary.toImage`），正是本文档 §6.3 风险表里的 flutter#138627
（纹理延迟释放 → 动画期内存尖峰）；而它多出来的收益主要是**背景折射**——
本次拍板不要折射，所以不划算。`standard` 走轻量着色器、不做截图，滚动中也稳。
低端机由 `GlassAdaptiveScope` 自动把上限压到 `minimal`（免 shader 档）。

**交互形变**由 `interactionBehavior: full` + `pressScale: 1.04` +
`indicatorPinchStrength: 0.4` 提供：点按整条胶囊回弹、指示器挤压、触点处的
方向性高光。**自适应色调**由 `adaptiveBrightness: true` 提供（深色内容滚过时
切深色玻璃样式保对比度，即 HIG 那条）。**无障碍**由包自动处理
（Reduce Transparency / Increase Contrast / Reduce Motion），无需额外代码。

### 8.3 顺手修掉的既有 bug：导航胶囊浮在屏幕正中间

实施中发现**导航条一直渲染在屏幕纵向正中**，不是贴底。渲染树是地面真相：

```
RenderPositionedBox#cacee (Center)   ← Scaffold 的 bottomNavigationBar 槽位
  size: Size(430.0, 932.0)           ← 被撑满了整屏高
  └ RenderConstrainedBox#c6dc3
      parentData: offset=Offset(0.0, 431.0)   ← 于是胶囊被居中到 431
```

成因：`bottomNavigationBar` 槽位给的是**松高度约束**（`0<=h<=整屏高`），而
`Center`（`Align`）默认会把自己撑满可用高度；Scaffold 于是认为这条栏有整屏
那么高，把它贴在 y=0，胶囊就被它居中到屏幕中间了。`git diff HEAD` 确认
`Center > ConstrainedBox > Padding` 这层嵌套是**原有代码**，非本次引入
（旧构建截图同样量到选中图标在 y≈455）。修法一行：`Center(heightFactor: 1)`。
修完导航项落在 y=862（= 932 − 8 − 62），符合预期。

### 8.4 验收结果

| 项 | 结果 |
| --- | --- |
| `flutter analyze` | 0 issue |
| `flutter test` | 71 项全过；新增 `test/nav_bar_test.dart` 4 项覆盖两条实现 |
| Web 构建 | release 构建通过；包的 5 个 `.frag` 正确进包 |
| APK 构建 | arm64 release 构建通过；5 个 `.frag` 在 APK 内 |
| 包体增量 | arm64 split **37.49 MB → 38.10 MB（+0.61 MB）**，满足 §6.4 的「<1MB」 |
| 封面绘制回归（Web） | 通过：19.5 万色（玻璃版）/19.9 万色（降级版），无停绘 |
| Web console | 0 error / 0 warn |
| 点击切页 | 通过：点「事件」→ URL 变 `#/events`；组件树确认选中态跟随 |
| 无障碍语义 | 5 个 tab 都有正确 `aria-label`（首页/指南/系列/事件/收藏），高度 62 |
| 深浅两主题 | 通过：浅色下选中图标品牌红、深色下白色，均符合代码意图 |

**未完成**：真机（Android）观感与 60fps 帧率**未实测**——本机当时没有连
设备（`adb devices` 为空）。请在真机上装 release APK 确认观感与滚动帧率，
重点看：折射虽不做、但边缘高光与点按回弹的手感是否够「液态」；低端机是否
被 `GlassAdaptiveScope` 降到 `minimal`。

**踩坑记录（给下次验证用）**：IAB 浏览器里 `flt-semantics-host` 带
`scale(0.6667)`（= 1/dpr），`getBoundingClientRect` 量出来的坐标看着像
「导航栏跑到屏幕中间」——**这次它恰好是真 bug**，所以别像上次那样直接归因于
工具假象；判断方法是 dump 渲染树看 `RenderPositionedBox` 的 `size` 与子节点
`parentData: offset`。另外开启语义树后语义 DOM 层会**拦住画布点击**，测点击
行为要开新标签页且不要先开语义。

