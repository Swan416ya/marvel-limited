import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

/// 加载中。
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  /// 进度不可知时的文字说明，可省。
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              label!,
              style: TextStyle(color: context.p.textFaint, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// 顶部细进度条，用于「已有内容但正在刷新」。
class LoadingBar extends StatelessWidget {
  const LoadingBar({super.key, this.visible = true});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return visible
        ? const LinearProgressIndicator(minHeight: 2)
        : const SizedBox(height: 2);
  }
}

/// 错误态：一句话 + 可选细节 + 重试。
///
/// 全应用的失败态统一走这里，避免出现「有的页面能重试、有的页面只能干看」。
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.detail,
    this.onRetry,
    this.retryLabel = '重试',
  });

  final String message;

  /// 原始错误信息，折叠在小字里。
  final String? detail;

  /// 为空则不显示重试按钮。
  final VoidCallback? onRetry;

  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: p.textGhost),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail!,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.textGhost, fontSize: 12),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 空态：图标 + 标题 + 说明 + 可选动作。
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitle2,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// 第二行小字提示。
  final String? subtitle2;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: p.textHint),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textFaint),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textGhost, fontSize: 12),
              ),
            ],
            if (subtitle2 != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle2!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textHint, fontSize: 12),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}