import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../media/image_url.dart';
import '../theme/app_tokens.dart';
import '../theme/app_palette.dart';

/// 统一的漫画封面。
///
/// 除了占位/错误兜底统一在这里，还带几件可靠性的事：
/// 1. 加载失败**自动重试**（400ms / 1.2s / 3s 三次），还失败才显示
///    「点一下重试」——封面被 CDN 掐、切页面回来重新加载失败都常见，
///    以前失败一下就永远黑着，得手点；
/// 2. Web 端不走 `CachedNetworkImage`：它底下的 flutter_cache_manager
///    在 Web 上要落 IndexedDB，失败一次就再也不恢复；Web 直接用浏览器
///    自己的 HTTP 缓存更稳（移动端仍用缓存库，磁盘缓存有用）；
/// 3. Web 端对不放 CORS 的图床（fandom wiki）自动改走本地开发代理。
class ComicCover extends StatefulWidget {
  const ComicCover({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderIcon,
    this.placeholderIconSize = 28,
    this.placeholderColor,
    this.errorColor,
    this.heroTag,
    this.fadeIn = AppDuration.normal,
    this.retryOnTap = true,
  });

  /// 封面地址。为空时直接渲染占位，不发请求。
  final String? url;

  final BoxFit fit;

  /// 圆角。为空表示不裁剪，由外层决定（例如整卡已经圆角裁过）。
  final BorderRadius? borderRadius;

  /// 占位和错误态中央的图标。为空则只画底色。
  final IconData? placeholderIcon;
  final double placeholderIconSize;

  /// 占位底色。为空用当前主题的 `p.fill`。
  final Color? placeholderColor;

  /// 错误态底色，默认与占位同色。
  final Color? errorColor;

  /// 传了就包一层 Hero，用于列表 → 详情的封面转场。
  ///
  /// 注意：同一个 tag 在一条路由里只能出现一次。同一个 issue/指南如果在一屏上
  /// 出现在多个分区（首页的轮播、书架、网格），就不能都挂 Hero，否则会抛
  /// "multiple heroes with the same tag"。要开转场请先给每处调用起唯一 tag。
  final Object? heroTag;

  final Duration fadeIn;

  /// 失败态点按重试。用于「错误就换图」的场景（比如卡片背景）可以关掉。
  final bool retryOnTap;

  @override
  State<ComicCover> createState() => _ComicCoverState();
}

class _ComicCoverState extends State<ComicCover> {
  int _attempt = 0;
  Timer? _retryTimer;

  /// 自动重试的间隔（长度即自动重试次数）。
  static const _retryDelays = [
    Duration(milliseconds: 400),
    Duration(milliseconds: 1200),
    Duration(milliseconds: 3000),
  ];

  @override
  void didUpdateWidget(ComicCover old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _retryTimer?.cancel();
      _attempt = 0;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  /// 失败后排一次自动重试。不用 setState 直接改，避免在 build 期间调；
  /// 挪到定时器里（失败态本来就已经画出来了）。
  void _scheduleRetry() {
    if (!widget.retryOnTap) return;
    if (_attempt >= _retryDelays.length) return;
    if (_retryTimer?.isActive ?? false) return;
    _retryTimer = Timer(_retryDelays[_attempt], () {
      if (mounted) setState(() => _attempt++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final placeholderColor = widget.placeholderColor ?? p.fill;

    Widget cover;
    if (widget.url == null || widget.url!.isEmpty) {
      cover = _placeholder(context, placeholderColor);
    } else if (widget.url!.startsWith('assets/')) {
      // 打包进本体的图（事件封面等），不走网络
      cover = Image.asset(
        widget.url!,
        fit: widget.fit,
        errorBuilder: (_, _, _) => _errorPlaceholder(context, placeholderColor),
      );
    } else if (kIsWeb) {
      // Web：走浏览器原生缓存，避开 flutter_cache_manager 那层
      // （它在 Web 上用 IndexedDB，坏一次就再也不出图）
      cover = Image.network(
        resolveImage(widget.url!)!,
        key: ValueKey('${widget.url}#$_attempt'),
        fit: widget.fit,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _placeholder(context, placeholderColor),
        errorBuilder: (_, _, _) => _errorPlaceholder(context, placeholderColor),
      );
    } else {
      cover = CachedNetworkImage(
        // key 带上重试次数，失败后重试会强制重新请求
        key: ValueKey('${widget.url}#$_attempt'),
        imageUrl: resolveImage(widget.url)!,
        fit: widget.fit,
        fadeInDuration: widget.fadeIn,
        placeholder: (_, _) => _placeholder(context, placeholderColor),
        errorWidget: (_, _, _) => _errorPlaceholder(context, placeholderColor),
      );
    }

    if (widget.borderRadius != null) {
      cover = ClipRRect(borderRadius: widget.borderRadius!, child: cover);
    }
    if (widget.heroTag != null) {
      cover = Hero(tag: widget.heroTag!, child: cover);
    }
    return cover;
  }

  Widget _placeholder(BuildContext context, Color color) {
    return ColoredBox(
      color: color,
      child: widget.placeholderIcon == null
          ? const SizedBox.expand()
          : Center(
              child: Icon(
                widget.placeholderIcon,
                size: widget.placeholderIconSize,
                color: context.p.iconOnCover,
              ),
            ),
    );
  }

  Widget _errorPlaceholder(BuildContext context, Color placeholderColor) {
    _scheduleRetry();
    return ColoredBox(
      color: widget.errorColor ?? placeholderColor,
      child: Center(
        child: widget.retryOnTap
            ? InkWell(
                onTap: () => setState(() => _attempt++),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    Icons.refresh,
                    size: widget.placeholderIconSize,
                    color: context.p.iconOnCover,
                  ),
                ),
              )
            : Icon(
                widget.placeholderIcon ?? Icons.image_outlined,
                size: widget.placeholderIconSize,
                color: context.p.iconOnCover,
              ),
      ),
    );
  }
}
