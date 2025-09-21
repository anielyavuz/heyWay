import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final colors = AppColors.light;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: colors.content2,
      brightness: Brightness.light,
    );
    final colorScheme = baseScheme.copyWith(
      surface: colors.background,
      primary: colors.content2,
      onPrimary: Colors.white,
      secondary: colors.content1,
      onSecondary: Colors.white,
      onSurface: colors.content1,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.content2,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.content1,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.background,
        selectedItemColor: colors.content2,
        unselectedItemColor: colors.content1.withValues(alpha: 0.7),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: colors.content1),
        headlineMedium: TextStyle(color: colors.content1),
        headlineSmall: TextStyle(color: colors.content1),
        bodyLarge: TextStyle(color: colors.content1),
        bodyMedium: TextStyle(color: colors.content1),
        bodySmall: TextStyle(color: colors.content1.withValues(alpha: 0.7)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colors = AppColors.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: colors.content2,
      brightness: Brightness.dark,
    );
    final colorScheme = baseScheme.copyWith(
      surface: colors.background,
      primary: colors.content2,
      onPrimary: Colors.black,
      secondary: colors.content1,
      onSecondary: Colors.black,
      onSurface: colors.content1,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.content2,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.content1,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.background,
        selectedItemColor: colors.content2,
        unselectedItemColor: colors.content1.withValues(alpha: 0.7),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: colors.content1),
        headlineMedium: TextStyle(color: colors.content1),
        headlineSmall: TextStyle(color: colors.content1),
        bodyLarge: TextStyle(color: colors.content1),
        bodyMedium: TextStyle(color: colors.content1),
        bodySmall: TextStyle(color: colors.content1.withValues(alpha: 0.7)),
      ),
    );
  }
}
