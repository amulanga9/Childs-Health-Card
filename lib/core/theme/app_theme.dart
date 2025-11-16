import 'package:flutter/material.dart';

/// Темы приложения (светлая и тёмная)
class AppTheme {
  // Цветовая схема приложения
  static const Color primaryColor = Color(0xFF2196F3); // Синий
  static const Color secondaryColor = Color(0xFF4CAF50); // Зелёный
  static const Color accentColor = Color(0xFFFF9800); // Оранжевый
  static const Color errorColor = Color(0xFFF44336); // Красный

  /// Светлая тема
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      secondary: secondaryColor,
      error: errorColor,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 2,
      scrolledUnderElevation: 4,
    ),

    // Card
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // FloatingActionButton
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 4,
    ),

    // InputDecoration
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    ),

    // Chip
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    // Fonts
    fontFamily: 'Roboto',
  );

  /// Тёмная тема
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      secondary: secondaryColor,
      error: errorColor,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 2,
      scrolledUnderElevation: 4,
    ),

    // Card
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),

    // FloatingActionButton
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 4,
    ),

    // InputDecoration
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    ),

    // Chip
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    // Fonts
    fontFamily: 'Roboto',
  );
}
