import 'package:flutter/material.dart';

class AppColorScheme {
  final Color background;
  final Color content1;
  final Color content2;

  const AppColorScheme({
    required this.background,
    required this.content1,
    required this.content2,
  });
}

class AppColors {
  static const AppColorScheme light = AppColorScheme(
    background: Color(0xFFFFF5F8),
    content1: Color(0xFF2D1A3C),
    content2: Color(0xFFE25598),
  );

  static const AppColorScheme dark = AppColorScheme(
    background: Color(0xFF241028),
    content1: Color(0xFFFBE5F1),
    content2: Color(0xFFF778B8),
  );

  static const List<AppColorScheme> themes = [light, dark];
}
