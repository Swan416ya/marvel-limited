import 'package:flutter/material.dart';

import 'state_views.dart';

/// 四态渲染（普通 box 场景）。
///
/// 判定顺序：error → isEmpty → isLoading → data。
/// 之前各页各写一套 `if (loading) ... else if (error) ... else if (empty) ...`，
/// 有的错误态带重试按钮有的不带，现在统一走这里。
///
/// 用法（`items` 为可空列表时）：
/// ```dart
/// AsyncView(
///   isLoading: items == null,
///   error: _error,
///   isEmpty: items?.isEmpty ?? true,
///   onRetry: _load,
///   builder: (context) => _list(items!),
/// )
/// ```
class AsyncView extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.isLoading,
    required this.error,
    required this.isEmpty,
    required this.builder,
    this.onRetry,
    this.loading,
    this.empty,
    this.errorMessage = '加载失败',
  });

  final bool isLoading;

  /// 为空表示没有错误。可以是 String 或 Exception。
  final Object? error;

  /// 数据已就绪但内容为空。
  final bool isEmpty;

  /// 数据态构造器。
  final WidgetBuilder builder;

  final VoidCallback? onRetry;

  /// 自定义加载态。
  final Widget? loading;

  /// 自定义空态；不传则用列表图标兜底。
  final Widget? empty;

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ErrorView(
        message: errorMessage,
        detail: _detailOf(error),
        onRetry: onRetry,
      );
    }
    if (isEmpty) {
      return empty ?? const EmptyView(icon: Icons.inbox, title: '暂无内容');
    }
    if (isLoading) {
      return loading ?? const LoadingView();
    }
    return builder(context);
  }

  /// 错误对象转一行可读文字，避免把整段异常栈糊在界面上。
  static String? _detailOf(Object? error) {
    if (error == null) return null;
    return error.toString();
  }
}

/// 四态渲染（sliver 场景）。非数据态用 `SliverFillRemaining` 撑满剩余高度。
class SliverAsyncView extends StatelessWidget {
  const SliverAsyncView({
    super.key,
    required this.isLoading,
    required this.error,
    required this.isEmpty,
    required this.builder,
    this.onRetry,
    this.loading,
    this.empty,
    this.errorMessage = '加载失败',
  });

  final bool isLoading;
  final Object? error;
  final bool isEmpty;

  /// 数据态构造器，需返回 sliver。
  final WidgetBuilder builder;

  final VoidCallback? onRetry;
  final Widget? loading;
  final Widget? empty;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorView(
          message: errorMessage,
          detail: error.toString(),
          onRetry: onRetry,
        ),
      );
    }
    if (isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: empty ?? const EmptyView(icon: Icons.inbox, title: '暂无内容'),
      );
    }
    if (isLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: loading ?? const LoadingView(),
      );
    }
    return builder(context);
  }
}