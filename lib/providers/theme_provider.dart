import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkTheme = false;

  bool get isDarkTheme => _isDarkTheme;

  void setDarkTheme(bool value) {
    if (_isDarkTheme == value) return;
    _isDarkTheme = value;
    notifyListeners();
  }

  void toggleTheme() {
    setDarkTheme(!_isDarkTheme);
  }
}
