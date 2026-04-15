import 'package:flutter/material.dart';

/// ============================================
/// APP THEME - Định nghĩa màu sắc và styles
/// ============================================

class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF3498DB);
  static const Color primaryDark = Color(0xFF2980B9);

  // Status colors
  static const Color success = Color(0xFF2ECC71);
  static const Color danger = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF3498DB);

  // Neutral colors
  static const Color dark = Color(0xFF2C3E50);
  static const Color light = Color(0xFFECF0F1);
  static const Color white = Color(0xFFFFFFFF);

  // Gray scale
  static const Color gray100 = Color(0xFFF8F9FA);
  static const Color gray200 = Color(0xFFE9ECEF);
  static const Color gray300 = Color(0xFFDEE2E6);
  static const Color gray400 = Color(0xFFADB5BD);
  static const Color gray500 = Color(0xFF6C757D);
  static const Color gray600 = Color(0xFF5A6268);
  static const Color gray700 = Color(0xFF495057);
  static const Color gray900 = Color(0xFF212529);

  // Route colors
  static const Color routeLine = Color(0xFF3498DB);
  static const Color startMarker = Color(0xFF2ECC71);
  static const Color endMarker = Color(0xFFE74C3C);
  static const Color normalMarker = Color(0xFF3498DB);
  static const Color highlightMarker = Color(0xFFF39C12);

  // Bluetooth status
  static const Color btConnected = Color(0xFF2ECC71);
  static const Color btDisconnected = Color(0xFF6C757D);
  static const Color btScanning = Color(0xFFF39C12);
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.gray100,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
