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

  static Color accountSurface(String provider) => switch (provider) {
    'aliyun' || 'tencent' => const Color(0xFFEEF2FD),
    'subscription' => const Color(0xFFF4EFFB),
    'custom' || 'oneapi' => const Color(0xFFFFF4E8),
    _ => const Color(0xFFECF7F3),
  };
}
