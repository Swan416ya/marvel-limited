import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/glass_panel.dart';
import '../../data/models/marvel_models.dart';
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

  final _pageController = PageController();
  final _zoomController = TransformationController();
  final _focusNode = FocusNode();

  late final LibraryState _library = context.read<LibraryState>();

  /// 当前单页索引（0 基）。
  int _page = 0;
  bool _toolbarVisible = true;
  bool? _lastLandscape;
  Offset _lastDoubleTapPoint = Offset.zero;

  /// 双页拼合（竖屏也并排两页，参考 B 站漫画的「双页模式」）。
  /// 横屏天然就是双页，这个开关只影响竖屏。
  bool _spreadMode = false;

  int get _total => widget.pages.length;

  bool get _isLandscape =>
      MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

  /// 是否处于双页视图（横屏自动，或竖屏手动开启）。
  bool get _isSpreadView => _isLandscape || _spreadMode;

  /// 双页跨页数。
  int get _spreadCount => (_total + 1) ~/ 2;

  /// 当前平台下「一屏」的数量。
  int get _viewCount => _isSpreadView ? _spreadCount : _total;

  /// 当前单页索引对应的视图序号。
  int get _viewIndex => _isSpreadView ? _page ~/ 2 : _page;

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
      _page = _isLandscape ? view * 2 : view;
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
    // 横屏一次看两页，多备一张
    final extra = _page + 2;
    if (_isLandscape && extra < _total) {
      unawaited(
        precacheImage(FileImage(File(widget.pages[extra])), context,
            onError: (_, _) {}),
      );
    }
  }

  /// 解码宽度：按一屏内每页的显示宽度 × 2 倍放大余量降采样。
  /// 漫画原图往往 2000px 宽，全尺寸解码很吃内存。
  int _cacheWidth() {
    final media = MediaQuery.of(context);
    final perView = _isLandscape
        ? media.size.width / 2
        : media.size.width;
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
        content: Text(now
            ? '已在第 ${_page + 1} 页加书签'
            : '已移除第 ${_page + 1} 页的书签'),
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
                    left: AppSpacing.lg, right: AppSpacing.lg, bottom: AppSpacing.lg),
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
                      leading: Icon(Icons.bookmark,
                          size: 18, color: p.brand),
                      title: Text('第 ${b.page + 1} 页',
                          style: const TextStyle(fontSize: 14)),
                      trailing: GestureDetector(
                        onTap: () {
                          _library.toggleBookmark(widget.issue.id, b.page);
                          Navigator.of(context).pop();
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.close,
                              size: 16, color: p.textGhost),
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
    setState(() => _spreadMode = !_spreadMode);
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
                    itemBuilder: (context, i) => _isSpreadView
                        ? _buildSpread(i)
                        : _buildSinglePage(i),
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
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
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
                  icon: Icon(Icons.bookmarks_outlined,
                      size: 19, color: context.p.textStrong),
                  tooltip: '书签列表',
                  onPressed: _showBookmarks,
                ),
                // 竖屏时的双页拼合切换（横屏天然双页，不显示）
                if (!landscape)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _spreadMode ? Icons.import_contacts : Icons.menu_book_outlined,
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

  String _statusText(bool landscape) {
    final total = _total;
    if (landscape) {
      final left = _page;
      final right = _page + 1;
      if (right >= total) return '第 ${left + 1} 页 / 共 $total 页';
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
    final left = spread * 2;
    final right = left + 1;
    return _ZoomablePage(
      controller: _zoomController,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: _pageImage(left)),
          if (right < _total)
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
          Text(
            '这一页读不出来',
            style: TextStyle(color: p.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}