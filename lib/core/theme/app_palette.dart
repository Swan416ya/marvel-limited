import 'package:flutter/material.dart';

/// 语义调色板。
///
/// 之前的 `AppColors` 是静态常量，只能有一套（暗色）。要做深浅双主题，
/// 颜色必须跟着主题走，所以改成 `ThemeExtension`：两套实例分别注册进
/// `AppTheme.dark()` / `AppTheme.light()`，取用方式 `context.p.textMuted`。
///
/// 命名沿用「语义」而不是数值：`textMuted` 比 `white60` 在换肤时更好判断。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brand,
    required this.background,
    required this.surface,
    required this.like,
    required this.success,
    required this.danger,
    required this.coverPlaceholder,
    required this.coverFallback,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textStrong,
    required this.textMuted,
    required this.textSubtle,
    required this.textFaint,
    required this.textGhost,
    required this.textHint,
    required this.iconOnCover,
    required this.fill,
    required this.fillStrong,
    required this.border,
    required this.borderFaint,
    required this.trackInactive,
    required this.glass,
    required this.glassStrong,
    required this.badge,
    required this.scrim,
  });

  /// 漫威红，两种主题下不变。
  final Color brand;
  final Color background;
  final Color surface;
  final Color like;
  final Color success;
  final Color danger;

  final Color coverPlaceholder;
  final Color coverFallback;
  final Color skeletonBase;
  final Color skeletonHighlight;

  // ── 文本与图标层级 ─────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textStrong;
  final Color textMuted;
  final Color textSubtle;
  final Color textFaint;
  final Color textGhost;
  final Color textHint;
  final Color iconOnCover;

  // ── 填充与描边 ─────────────────────────────────────────────
  final Color fill;
  final Color fillStrong;
  final Color border;
  final Color borderFaint;
  final Color trackInactive;

  // ── 遮罩（压在图片上，深浅主题都用黑） ─────────────────────
  final Color glass;
  final Color glassStrong;
  final Color badge;
  final Color scrim;

  /// 暗色（默认）。
  static const dark = AppPalette(
    brand: Color(0xFFED1D24),
    background: Color(0xFF0A0A0C),
    surface: Color(0xFF16161A),
    like: Color(0xFFFF375F),
    success: Color(0xFF30D158),
    danger: Color(0xFFFF453A),
    coverPlaceholder: Color(0xFF212121),
    coverFallback: Color(0xFF424242),
    skeletonBase: Color(0xFF1A1A1E),
    skeletonHighlight: Color(0xFF2A2A31),
    textPrimary: Colors.white,
    textSecondary: Color(0xD9FFFFFF),
    textStrong: Color(0xB3FFFFFF),
    textMuted: Color(0x99FFFFFF),
    textSubtle: Color(0x8AFFFFFF),
    textFaint: Color(0x66FFFFFF),
    textGhost: Color(0x40FFFFFF),
    textHint: Color(0x33FFFFFF),
    iconOnCover: Color(0x3DFFFFFF),
    fill: Color(0x0DFFFFFF),
    fillStrong: Color(0x0FFFFFFF),
    border: Color(0x14FFFFFF),
    borderFaint: Color(0x0DFFFFFF),
    trackInactive: Color(0x26FFFFFF),
    glass: Color(0x8C000000),
    glassStrong: Color(0xB8000000),
    badge: Color(0xB3000000),
    scrim: Color(0xD9000000),
  );

  /// 浅色。文本阶梯整体换成黑，遮罩保持黑（都压在图片上）。
  static const light = AppPalette(
    brand: Color(0xFFED1D24),
    background: Color(0xFFF6F6F8),
    surface: Colors.white,
    like: Color(0xFFFF375F),
    success: Color(0xFF1FA24A),
    danger: Color(0xFFE0352B),
    coverPlaceholder: Color(0xFFE8E8EC),
    coverFallback: Color(0xFFD6D6DC),
    skeletonBase: Color(0xFFE7E7EC),
    skeletonHighlight: Color(0xFFF4F4F7),
    textPrimary: Color(0xFF0B0B10),
    textSecondary: Color(0xD90B0B10),
    textStrong: Color(0xB30B0B10),
    textMuted: Color(0x990B0B10),
    textSubtle: Color(0x8A0B0B10),
    textFaint: Color(0x660B0B10),
    textGhost: Color(0x400B0B10),
    textHint: Color(0x330B0B10),
    iconOnCover: Color(0x3D0B0B10),
    fill: Color(0x0D0B0B10),
    fillStrong: Color(0x0F0B0B10),
    border: Color(0x140B0B10),
    borderFaint: Color(0x0D0B0B10),
    trackInactive: Color(0x260B0B10),
    glass: Color(0xBFFFFFFF),
    glassStrong: Color(0xE6FFFFFF),
    badge: Color(0xB3000000),
    scrim: Color(0xD9000000),
  );

  @override
  AppPalette copyWith({
    Color? brand,
    Color? background,
    Color? surface,
    Color? like,
    Color? success,
    Color? danger,
    Color? coverPlaceholder,
    Color? coverFallback,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? textPrimary,
    Color? textSecondary,
    Color? textStrong,
    Color? textMuted,
    Color? textSubtle,
    Color? textFaint,
    Color? textGhost,
    Color? textHint,
    Color? iconOnCover,
    Color? fill,
    Color? fillStrong,
    Color? border,
    Color? borderFaint,
    Color? trackInactive,
    Color? glass,
    Color? glassStrong,
    Color? badge,
    Color? scrim,
  }) {
    return AppPalette(
      brand: brand ?? this.brand,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      like: like ?? this.like,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      coverPlaceholder: coverPlaceholder ?? this.coverPlaceholder,
      coverFallback: coverFallback ?? this.coverFallback,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textStrong: textStrong ?? this.textStrong,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      textFaint: textFaint ?? this.textFaint,
      textGhost: textGhost ?? this.textGhost,
      textHint: textHint ?? this.textHint,
      iconOnCover: iconOnCover ?? this.iconOnCover,
      fill: fill ?? this.fill,
      fillStrong: fillStrong ?? this.fillStrong,
      border: border ?? this.border,
      borderFaint: borderFaint ?? this.borderFaint,
      trackInactive: trackInactive ?? this.trackInactive,
      glass: glass ?? this.glass,
      glassStrong: glassStrong ?? this.glassStrong,
      badge: badge ?? this.badge,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brand: Color.lerp(brand, other.brand, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      like: Color.lerp(like, other.like, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      coverPlaceholder: Color.lerp(coverPlaceholder, other.coverPlaceholder, t)!,
      coverFallback: Color.lerp(coverFallback, other.coverFallback, t)!,
      skeletonBase: Color.lerp(skeletonBase, other.skeletonBase, t)!,
      skeletonHighlight: Color.lerp(skeletonHighlight, other.skeletonHighlight, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      textGhost: Color.lerp(textGhost, other.textGhost, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      iconOnCover: Color.lerp(iconOnCover, other.iconOnCover, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      fillStrong: Color.lerp(fillStrong, other.fillStrong, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderFaint: Color.lerp(borderFaint, other.borderFaint, t)!,
      trackInactive: Color.lerp(trackInactive, other.trackInactive, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassStrong: Color.lerp(glassStrong, other.glassStrong, t)!,
      badge: Color.lerp(badge, other.badge, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// 取当前主题的调色板：`context.p.textMuted`。
extension AppPaletteX on BuildContext {
  AppPalette get p => Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}