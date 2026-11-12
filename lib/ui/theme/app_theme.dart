import 'package:flutter/material.dart';

/// Palette NutriWatt : feuille verte, énergie orange et surfaces lumineuses.
abstract final class AppColors {
  static const green = Color(0xFF246B45);
  static const lime = Color(0xFFB9ED48);
  static const orange = Color(0xFFA95012);
  static const blue = Color(0xFF236D91);
  static const ink = Color(0xFF1D3026);
  static const muted = Color(0xFF5D6D63);
  static const background = Color(0xFFF5F7F2);
  static const border = Color(0xFFE0E7DD);
}

abstract final class AppLayout {
  static const gap = 16.0;
  static const radius = 24.0;
  static const maxWidth = 1120.0;
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE3F3D8),
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.orange,
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outlineVariant: AppColors.border,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -1),
        headlineSmall: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink),
        titleLarge: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
        titleMedium: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
        bodyLarge:
            const TextStyle(fontSize: 16, height: 1.45, color: AppColors.ink),
        bodyMedium:
            const TextStyle(fontSize: 14, height: 1.4, color: AppColors.muted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppLayout.radius),
            side: const BorderSide(color: AppColors.border)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              shape: shape,
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(48, 48), elevation: 0, shape: shape)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: shape,
              side: const BorderSide(color: AppColors.border))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}
