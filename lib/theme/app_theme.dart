import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {

  static ThemeData get lightTheme {
    final colors = AppColors.light;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.content1,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.content1,
        brightness: Brightness.light,
        surface: colors.background,
        primary: colors.content1,
        secondary: colors.content2,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.content1,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.background,
        selectedItemColor: colors.content2,
        unselectedItemColor: colors.content1,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: colors.content1),
        headlineMedium: TextStyle(color: colors.content1),
        headlineSmall: TextStyle(color: colors.content1),
        bodyLarge: TextStyle(color: colors.content1),
        bodyMedium: TextStyle(color: colors.content1),
        bodySmall: TextStyle(color: colors.content2),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colors = AppColors.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.content1,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.content1,
        brightness: Brightness.dark,
        surface: colors.background,
        primary: colors.content1,
        secondary: colors.content2,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.content1,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.background,
        selectedItemColor: colors.content2,
        unselectedItemColor: colors.content1,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: colors.content1),
        headlineMedium: TextStyle(color: colors.content1),
        headlineSmall: TextStyle(color: colors.content1),
        bodyLarge: TextStyle(color: colors.content1),
        bodyMedium: TextStyle(color: colors.content1),
        bodySmall: TextStyle(color: colors.content2),
      ),
    );
  }
}