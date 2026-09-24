import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_palette.dart';
import '../../data/translate_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/glass_panel.dart';
import '../../data/models/marvel_models.dart';
import '../../data/ocr_service.dart';
import '../../data/repository/preferences_repository.dart';
import '../../state/library_state.dart';
import 'widgets/reader_toolbar.dart';

/// 阅读器。
///
/// - 竖屏单页 / 横屏自动双页（美漫左→右）
/// - 左 35% 上一页、右 35% 下一页、中间点击显隐工具栏
/// - 双击画面在 1x / 2x 之间缩放，可拖动查看
/// - 键盘 ←/→、空格、PageUp/PageDown、Home/End
/// - 翻页会把进度写进本地，下次从这一页继续
/// - 前后各预解码一页，翻页不再等解码
///
/// `_page` 始终按「单页索引」记，横屏只是一次显示两页，
/// 这样旋转屏幕和保存进度用的是同一个语义。
class ReaderPage extends StatefulWidget {
  final ComicIssue issue;
  final List<String> pages;

  const ReaderPage({super.key, required this.issue, required this.pages});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  /// 左右各 35% 是翻页区，中间 30% 呼出工具栏。
  static const _sideZone = 0.35;

  final _zoomController = TransformationController();
  final _focusNode = FocusNode();

  /// 拿到恢复的进度后才创建：`initialPage` 要落在上次读到的那一页，
  /// 提前建好控制器就只能在第 1 页开局了。
  late final PageController _pageController = PageController(
    initialPage: _initialView,
  );

  late final LibraryState _library = context.read<LibraryState>();

  /// 当前单页索引（0 基）。
  int _page = 0;
  bool _toolbarVisible = true;

  /// 翻译中（工具栏按钮转圈/置灰用）。
  bool _translating = false;

  /// 前一页的 OCR 文本，翻译时当上下文传给模型。
  String? _lastOcr;
  bool? _lastLandscape;
  Offset _lastDoubleTapPoint = Offset.zero;

  /// 双页拼合（竖屏也并排两页，参考 B 站漫画的「双页模式」）。
  /// 横屏天然就是双页，这个开关只影响竖屏。
  bool _spreadMode = false;

  /// 跨页配对偏移：0 = (1,2)(3,4)…，1 = 封面单页 + (2,3)(4,5)…。
  ///
  /// 美漫扫描本的装订起点不固定，有的本子第 1、2 页是一幅跨页大图，
  /// 有的第 2、3 页才是——固定配对总有一半的书对不上。用户在工具栏
  /// 「切换配对」即可平移一格：当前跨页 (4,5) 点一下变成 (5,6)。
  int _pairOffset = 0;

  int get _total => widget.pages.length;

  bool get _isLandscape =>
      MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

  /// 是否处于双页视图（横屏自动，或竖屏手动开启）。
  bool get _isSpreadView => _isLandscape || _spreadMode;

  /// 双页跨页数（offset=1 时第一视图是封面单页）。
  int get _spreadCount =>
      _pairOffset == 0 ? (_total + 1) ~/ 2 : 1 + (_total - 1 + 1) ~/ 2;

  /// 视图 k 的左页（offset=1 的视图 0 是封面单页）。
  int _leftPageOfView(int view) =>
      _pairOffset == 0 ? view * 2 : (view == 0 ? 0 : view * 2 - 1);

  /// 左页 p 对应的视图序号。
  int _viewOfLeftPage(int page) =>
      _pairOffset == 0 ? page ~/ 2 : (page == 0 ? 0 : (page + 1) ~/ 2);

  /// 当前平台下「一屏」的数量。
  int get _viewCount => _isSpreadView ? _spreadCount : _total;

  /// 当前单页索引对应的视图序号。
  int get _viewIndex => _isSpreadView ? _viewOfLeftPage(_page) : _page;

  bool get _zoomed => _zoomController.value.getMaxScaleOnAxis() > 1.01;

  /// 当前页的书签状态（工具栏按钮用）。
  bool get _bookmarked => _library.hasBookmark(widget.issue.id, _page);

  @override
  void initState() {
    super.initState();
    _restoreProgress();
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNeighbors());
  }

  /// 初始「视图序号」：恢复出来的页码在双页视图下要折半。
  /// _page 已在 initState 的 _restoreProgress() 里设好。
  /// 控制器是 late final，首次访问发生在 build 里，context 可用。
  int get _initialView => _isSpreadView ? _page ~/ 2 : _page;

  void _restoreProgress() {
    if (_total == 0) return;
    final saved = _library.progressFor(widget.issue.id);
    if (saved == null) return;
    _page = saved.page.clamp(0, _total - 1);
  }

  @override
  void dispose() {
    _saveProgress();
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    _pageController.dispose();
    _zoomController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── 进度 ─────────────────────────────────────────────────────

  ReadingProgress _snapshot() => ReadingProgress(
    issue: widget.issue,
    page: _page,
    totalPages: _total,
    updatedAt: DateTime.now(),
  );

  void _saveProgress() {
    // 触发一次即可，state 内部会广播给首页「继续阅读」
    unawaited(_library.saveProgress(_snapshot()));
  }

  // ── 翻页 ─────────────────────────────────────────────────────

  void _goToView(int view) {
    final clamped = view.clamp(0, _viewCount - 1);
    _pageController.animateToPage(
      clamped,
      duration: AppDuration.page,
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int view) {
    setState(() {
      // 一屏两页的场合（横屏或手动双页）按配对偏移反推左页
      _page = _isSpreadView ? _leftPageOfView(view) : view;
      if (_zoomed) _zoomController.value = Matrix4.identity();
    });
    _saveProgress();
    _precacheNeighbors();
  }

  /// 预解码前后页，翻过去时不用等。
  void _precacheNeighbors() {
    if (!mounted) return;
    for (final i in [_page - 1, _page + 1]) {
      if (i < 0 || i >= _total) continue;
      unawaited(
        precacheImage(
          FileImage(File(widget.pages[i])),
          context,
          onError: (_, _) {},
        ),
      );
    }
    // 一屏两页的视图多备一张
    final extra = _page + 2;
    if (_isSpreadView && extra < _total) {
      unawaited(
        precacheImage(
          FileImage(File(widget.pages[extra])),
          context,
          onError: (_, _) {},
        ),
      );
    }
  }

  /// 解码宽度：按一屏内每页的显示宽度 × 2 倍放大余量降采样。
  /// 漫画原图往往 2000px 宽，全尺寸解码很吃内存。
  int _cacheWidth() {
    final media = MediaQuery.of(context);
    final perView = _isSpreadView ? media.size.width / 2 : media.size.width;
    return (perView * media.devicePixelRatio * 2).round();
  }

  void _handleTapUp(TapUpDetails details) {
    final width = context.size?.width ?? MediaQuery.of(context).size.width;
    if (width <= 0) return;
    final ratio = details.localPosition.dx / width;
    if (ratio < _sideZone) {
      _goToView(_viewIndex - 1);
    } else if (ratio > 1 - _sideZone) {
      _goToView(_viewIndex + 1);
    } else {
      setState(() => _toolbarVisible = !_toolbarVisible);
    }
  }

  void _handleDoubleTap() {
    if (_zoomed) {
      _zoomController.value = Matrix4.identity();
      return;
    }
    const scale = 2.0;
    final p = _lastDoubleTapPoint;
    // 以双击点为锚放大到 2x：缩放后该点仍停在原地（s·p + t = p ⇒ t = -p(s-1)）。
    // 直接构造矩阵，不用 translate/scale（后者在 vector_math 里已废弃）。
    _zoomController.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, scale)
      ..setEntry(0, 3, -p.dx * (scale - 1))
      ..setEntry(1, 3, -p.dy * (scale - 1));
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.pageDown) {
      _goToView(_viewIndex + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      _goToView(_viewIndex - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _goToView(0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _goToView(_viewCount - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── 书签 ─────────────────────────────────────────────────────

  void _toggleBookmark() {
    final now = _library.toggleBookmark(widget.issue.id, _page);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(now ? '已在第 ${_page + 1} 页加书签' : '已移除第 ${_page + 1} 页的书签'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
    // 书签状态变了，刷新工具栏图标
    setState(() {});
  }

  /// 书签列表底部弹层：点一条跳过去。
  void _showBookmarks() {
    final p = context.p;
    final bookmarks = _library.bookmarksFor(widget.issue.id);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                '书签 · ${bookmarks.length}',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (bookmarks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                ),
                child: Text(
                  '还没有书签。工具栏的书签图标可以在当前页加一个。',
                  style: TextStyle(color: p.textFaint, fontSize: 13),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: bookmarks.length,
                  itemBuilder: (context, i) {
                    final b = bookmarks[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.bookmark, size: 18, color: p.brand),
                      title: Text(
                        '第 ${b.page + 1} 页',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: GestureDetector(
                        onTap: () {
                          _library.toggleBookmark(widget.issue.id, b.page);
                          Navigator.of(context).pop();
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: p.textGhost,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _goToView(_isSpreadView ? b.page ~/ 2 : b.page);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 竖屏切换单页/双页拼合。切换后锚回当前内容的起始页。
  void _toggleSpreadMode() {
    setState(() {
      _spreadMode = !_spreadMode;
      // 进入双页视图时把 _page 归一化到所在跨页的**左页**（偶数）。
      // 不归一化的话，从奇数页切进来状态文字会显示一个不存在的
      // 跨页（比如在第 4 页切双页显示「第 4-5 页」，但 4-5 根本
      // 不是一对：跨页固定是 (1,2)(3,4)…），进度页码也跟着错。
      if (_isSpreadView) {
        _page = _normalizeToLeftPage(_page);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_viewIndex);
      }
    });
  }

  /// 把任意页码归一化成当前配对下的合法左页。
  int _normalizeToLeftPage(int page) {
    if (page == 0) return 0;
    if (_pairOffset == 0) {
      return page.isEven ? page : page - 1;
    }
    return page.isOdd ? page : page - 1;
  }

  /// 切换跨页配对（平移一格）：当前跨页 (4,5) → (5,6)。
  /// 右页变成新的左页，右边补上它的下一页。
  void _shiftPairing() {
    setState(() {
      _pairOffset = 1 - _pairOffset;
      // 新的左页 = 原来的右页（没有右页就用当前页）
      final right = _page + 1;
      final newLeft = right < _total ? right : _page;
      _page = _normalizeToLeftPage(newLeft);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_viewIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (_, event) => _handleKey(event),
        child: OrientationBuilder(
          builder: (context, orientation) {
            final landscape = orientation == Orientation.landscape;
            // 旋转后页码语义变了，锚回当前内容的第一页
            if (_lastLandscape != null && _lastLandscape != landscape) {
              // 旋转后页码语义变了：先归一化到跨页左页再锚回去
              if (_isSpreadView) {
                _page = _normalizeToLeftPage(_page);
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _pageController.hasClients) {
                  _pageController.jumpToPage(_viewIndex);
                }
              });
            }
            _lastLandscape = landscape;

            return Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _handleTapUp,
                  onDoubleTapDown: (d) => _lastDoubleTapPoint = d.localPosition,
                  onDoubleTap: _handleDoubleTap,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _viewCount,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, i) =>
                        _isSpreadView ? _buildSpread(i) : _buildSinglePage(i),
                  ),
                ),
                _statusPill(landscape),
                _topBar(),
                _bottomToolbar(landscape),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusPill(bool landscape) {
    // 状态文字按「当前视图模式」算（横屏自动双页 + 竖屏手动双页），
    // 不能只看物理方向——手动开双页时也要显示跨页文字
    return AnimatedPositioned(
      duration: AppDuration.normal,
      curve: Curves.easeOutCubic,
      left: AppSpacing.lg,
      bottom: _toolbarVisible ? 84 : AppSpacing.lg,
      child: IgnorePointer(
        child: GlassPanel(
          color: context.p.glass,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            _statusText(_isSpreadView),
            style: TextStyle(color: context.p.textStrong, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return AnimatedPositioned(
      duration: AppDuration.normal,
      curve: Curves.easeOutCubic,
      top: _toolbarVisible ? 0 : -80,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: context.p.textPrimary,
          title: Text(
            widget.issue.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _bottomToolbar(bool landscape) {
    return AnimatedPositioned(
      duration: AppDuration.normal,
      curve: Curves.easeOutCubic,
      bottom: _toolbarVisible ? AppSpacing.lg : -110,
      left: 0,
      right: 0,
      child: Center(
        child: GlassPanel(
          color: context.p.glassStrong,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: context.p.border),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 书签：当前页加/去
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                    color: _bookmarked ? context.p.brand : context.p.textStrong,
                  ),
                  tooltip: _bookmarked ? '去掉书签' : '加书签',
                  onPressed: _toggleBookmark,
                ),
                // 书签列表：点开跳页
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.bookmarks_outlined,
                    size: 19,
                    color: context.p.textStrong,
                  ),
                  tooltip: '书签列表',
                  onPressed: _showBookmarks,
                ),
                // 翻译当前页：点=OCR+翻译；长按=配置大模型接口
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.translate,
                    size: 20,
                    color: _translating
                        ? context.p.brand
                        : context.p.textStrong,
                  ),
                  tooltip: '翻译（长按配置模型）',
                  onPressed: _translating ? null : _translateCurrentPage,
                  onLongPress: _showLlmConfig,
                ),
                // 切换跨页配对：扫描本装订起点不同，固定配对一半的书对不上
                if (_isSpreadView)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.join_left,
                      size: 20,
                      color: context.p.textStrong,
                    ),
                    tooltip: '切换跨页配对',
                    onPressed: _shiftPairing,
                  ),
                // 竖屏时的双页拼合切换（横屏天然双页，不显示）
                if (!landscape)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _spreadMode
                          ? Icons.import_contacts
                          : Icons.menu_book_outlined,
                      size: 20,
                      color: context.p.textStrong,
                    ),
                    tooltip: _spreadMode ? '切回单页' : '双页拼合',
                    onPressed: _toggleSpreadMode,
                  ),
                ReaderToolbar(
                  viewIndex: _viewIndex,
                  viewCount: _viewCount,
                  onChanged: _goToView,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 翻译当前页：设备端 OCR → 大模型翻译 → 底部弹译文。
  Future<void> _translateCurrentPage() async {
    if (_page >= widget.pages.length) return;
    final messenger = ScaffoldMessenger.of(context);
    final prefs = context.read<PreferencesRepository>();
    if (!prefs.llmConfigured) {
      _showLlmConfig();
      messenger.showSnackBar(const SnackBar(content: Text('先长按「翻译」按钮配置大模型接口')));
      return;
    }
    setState(() => _translating = true);
    try {
      // 1) OCR：设备端识别（不联网）。双页视图把当前跨页的
      //    左右两页都识别了拼在一起——之前只翻左页，右半屏的对白全丢。
      final pageIndices = _isSpreadView
          ? [_page, if (_page + 1 < _total) _page + 1]
          : [_page];
      final texts = <String>[];
      for (final i in pageIndices) {
        try {
          texts.add(await OcrService.recognize(File(widget.pages[i])));
        } on MissingPluginException {
          throw UnsupportedError('这个平台没有 OCR（ML Kit 只支持 Android/iOS）');
        }
      }
      final ocr = texts.where((t) => t.trim().isNotEmpty).join('\n\n');
      if (ocr.trim().isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('这一页没有识别到文字')));
        return;
      }
      // 2) 翻译：带上前一页的文本当上下文
      final service = TranslateService(
        baseUrl: prefs.llmBaseUrl,
        apiKey: prefs.llmApiKey,
        model: prefs.llmModel,
      );
      final translated = await service.translate(
        ocr,
        context: _lastOcr,
        seriesTitle: widget.issue.seriesTitle,
      );
      _lastOcr = ocr;
      if (!mounted) return;
      await _showTranslation(ocr, translated);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('翻译失败：$e')));
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  Future<void> _showTranslation(String original, String translated) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: context.p.surface,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        maxChildSize: 0.85,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '译文',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text(translated, style: const TextStyle(fontSize: 15, height: 1.7)),
            const SizedBox(height: 16),
            Text(
              '—— 原文（OCR）——',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              original,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 长按「翻译」进入的模型配置：接口地址 / API Key / 模型名。
  Future<void> _showLlmConfig() {
    final prefs = context.read<PreferencesRepository>();
    final baseUrl = TextEditingController(text: prefs.llmBaseUrl);
    final apiKey = TextEditingController(text: prefs.llmApiKey);
    final model = TextEditingController(text: prefs.llmModel);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.p.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '翻译模型配置',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '接 OpenAI 兼容接口（OpenAI / DeepSeek / Gemini 兼容层等）。'
              '只在翻译时调用，OCR 在本机完成、图片不上传。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(sheetContext).hintColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: baseUrl,
              decoration: const InputDecoration(
                labelText: '接口地址（如 https://api.openai.com/v1）',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: apiKey,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Key',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: model,
              decoration: const InputDecoration(
                labelText: '模型名（如 gpt-4o-mini / deepseek-chat）',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await prefs.saveLlmConfig(
                    baseUrl: baseUrl.text,
                    apiKey: apiKey.text,
                    model: model.text,
                  );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(bool landscape) {
    final total = _total;
    if (landscape) {
      final left = _page;
      final right = left + 1;
      // offset=1 的封面单页，或最后一页落单
      final solo = (_pairOffset == 1 && left == 0) || right >= total;
      if (solo) return '第 ${left + 1} 页 / 共 $total 页';
      return '第 ${left + 1}-${right + 1} 页 / 共 $total 页';
    }
    return '第 ${_page + 1} 页 / 共 $total 页';
  }

  Widget _buildSinglePage(int index) {
    return _ZoomablePage(
      controller: _zoomController,
      child: Center(
        child: Image.file(
          File(widget.pages[index]),
          cacheWidth: _cacheWidth(),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const _BrokenPage(),
        ),
      ),
    );
  }

  /// 横屏双页（美漫左→右）
  Widget _buildSpread(int spread) {
    final left = _leftPageOfView(spread);
    final right = left + 1;
    // offset=1 的视图 0 是封面单页（第 2 页起才两两配对）
    final solo = _pairOffset == 1 && spread == 0;
    return _ZoomablePage(
      controller: _zoomController,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _pageImage(left)),
          if (!solo && right < _total)
            Expanded(child: _pageImage(right))
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _pageImage(int index) {
    return Center(
      child: Image.file(
        File(widget.pages[index]),
        cacheWidth: _cacheWidth(),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _BrokenPage(),
      ),
    );
  }
}

/// 可缩放的图片容器。双击缩放由外层处理，这里只负责把变换接上。
class _ZoomablePage extends StatelessWidget {
  const _ZoomablePage({required this.controller, required this.child});

  final TransformationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: controller,
      maxScale: 5,
      child: child,
    );
  }
}

class _BrokenPage extends StatelessWidget {
  const _BrokenPage();

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: p.textGhost, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('这一页读不出来', style: TextStyle(color: p.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
