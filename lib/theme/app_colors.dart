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
    background: Color(0xFF19183B),
    content1: Color(0xFF31326F),
    content2: Color(0xFFA8FBD3),
  );

  static const AppColorScheme dark = AppColorScheme(
    background: Color(0xFF3E1E68),
    content1: Color(0xFFE45A92),
    content2: Color(0xFFF5D2D2),
  );

  static const List<AppColorScheme> themes = [
    light,
    dark,
  ];
}
