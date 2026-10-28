import 'package:flutter/material.dart';

/// Shared Material palette and surfaces across desktop, mobile and Web.
abstract final class AstracctTheme {
  static const background = Color(0xFFF0EEF2);
  static const mobileBackground = background;
  static const primary = Color(0xFF087EFF);
  static const ink = Color(0xFF22232A);
  static const border = Color(0xFFE3E0E7);
  static const muted = Color(0xFF686773);
  static const success = Color(0xFF24733D);
  static const warning = Color(0xFF865000);
  static const error = Color(0xFFB3261E);
  static const aiAccent = Color(0xFF087EFF);
  static const cloudAccent = Color(0xFF36A57B);
  static const nodesAccent = Color(0xFFDC923E);

  static ThemeData _build(Brightness brightness, {bool highContrast = false}) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: dark ? const Color(0xFFFFA14A) : primary,
          brightness: brightness,
          contrastLevel: highContrast ? 1 : 0,
        ).copyWith(
          primary: dark ? const Color(0xFFFFA14A) : primary,
          onPrimary: dark ? const Color(0xFF35200C) : Colors.white,
          surface: dark ? const Color(0xFF171615) : background,
          surfaceContainerLow: dark
              ? const Color(0xFF282623)
              : const Color(0xFFFAF8FB),
          surfaceContainer: dark
              ? const Color(0xFF302D29)
              : const Color(0xFFE7E4EA),
        );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: rounded,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .5),
        thickness: .7,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        iconColor: scheme.onSurfaceVariant,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        height: 72,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: rounded,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
    );
  }

  static ThemeData light() => _build(Brightness.light);
  static ThemeData mobile() => light();
  static ThemeData dark({bool highContrast = false}) =>
      _build(Brightness.dark, highContrast: highContrast);
  static ThemeData accessibleLight() =>
      _build(Brightness.light, highContrast: true);
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color mutedFor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  static Color errorFor(BuildContext context) =>
      Theme.of(context).colorScheme.error;
  static Color successFor(BuildContext context) =>
      isDark(context) ? const Color(0xFF9AEBA5) : success;
  static Color warningFor(BuildContext context) =>
      isDark(context) ? const Color(0xFFFFC487) : warning;
  static Color surfaceFor(BuildContext context, String provider) =>
      Theme.of(context).colorScheme.surfaceContainerLow;
  static Color accountSurface(String provider) => const Color(0xFFFAF8FB);
}
