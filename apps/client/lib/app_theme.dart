import 'package:flutter/material.dart';

/// First-pass palette; keep visual choices here for the next UI iteration.
abstract final class AstracctTheme {
  static const background = Color(0xFFF6F8FC);
  static const success = Color(0xFF21654D);
  static const warning = Color(0xFF825000);
  static const error = Color(0xFFB3261E);
  static const muted = Color(0xFF566174);

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4967B5),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: background,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: Color(0xFF202C43),
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDCE2ED)),
      ),
    ),
  );

  // Colors and geometry from Netweb/public/assets/astracct/styles.css.
  static const mobileBackground = Color(0xFFF5F7FF);
  static const primary = Color(0xFF6478DF);
  static const ink = Color(0xFF25304A);
  static const border = Color(0xFFDFE6F3);
  static const aiAccent = Color(0xFFA399EA);
  static const cloudAccent = Color(0xFF7DCDB2);
  static const nodesAccent = Color(0xFFEFB37D);

  static ThemeData mobile() {
    final base = light();
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: border),
    );
    return base.copyWith(
      scaffoldBackgroundColor: mobileBackground,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: ink,
        outline: border,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            bodySmall: const TextStyle(fontSize: 12, height: 1.6, color: muted),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.6, color: ink),
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: mobileBackground,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFBFF),
        border: outline,
        enabledBorder: outline,
        disabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF51669E),
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: primary,
        side: const BorderSide(color: border),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
      ),
    );
  }

  static Color accountSurface(String provider) => switch (provider) {
    'aliyun' || 'tencent' => const Color(0xFFEEF2FD),
    'subscription' => const Color(0xFFF4EFFB),
    'custom' || 'oneapi' => const Color(0xFFFFF4E8),
    _ => const Color(0xFFECF7F3),
  };
}
