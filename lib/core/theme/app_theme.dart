import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_tokens.dart';

/// 全应用主题：深浅两套，各自注册一份 [AppPalette]，
/// 页面里用 `context.p.xxx` 取语义颜色。
abstract final class AppTheme {
  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.brand,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      extensions: [palette],
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : palette.textSubtle,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? scheme.primary : palette.textSubtle,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.1,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      dividerColor: palette.border,
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: scheme.primary,
        inactiveTrackColor: palette.trackInactive,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          side: BorderSide(color: palette.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: palette.textGhost),
        filled: true,
        fillColor: palette.fillStrong,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}