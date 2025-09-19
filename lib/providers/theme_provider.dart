import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'isDarkTheme';

  bool _isDarkTheme = false;
  bool _isInitialized = false;

  bool get isDarkTheme => _isDarkTheme;
  bool get isInitialized => _isInitialized;

  Future<void> loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkTheme = prefs.getBool(_prefKey) ?? false;
    _isInitialized = true;
    notifyListeners();
  }

  void setDarkTheme(bool value) {
    if (_isDarkTheme == value) return;
    _isDarkTheme = value;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_prefKey, _isDarkTheme),
    );
    notifyListeners();
  }

  void toggleTheme() {
    setDarkTheme(!_isDarkTheme);
  }
}
