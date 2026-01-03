import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Available colors
const List<Color> appThemeColors = [
  Colors.deepPurple,
  Colors.blue,
  Colors.teal,
  Colors.green,
  Colors.orange,
  Colors.pink,
  Colors.red,
];

class AppThemeSettings {
  final ThemeMode mode;
  final ScrollbarThemeData?
  scrollbarTheme; // Just a placeholder to ensure non-empty for now or we can store color index
  final int colorIndex;

  AppThemeSettings({
    required this.mode,
    required this.colorIndex,
    this.scrollbarTheme,
  });

  Color get seedColor => appThemeColors[colorIndex];

  AppThemeSettings copyWith({ThemeMode? mode, int? colorIndex}) {
    return AppThemeSettings(
      mode: mode ?? this.mode,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }
}

class ThemeNotifier extends Notifier<AppThemeSettings> {
  static const _themeModeKey = 'theme_mode';
  static const _themeColorKey = 'theme_color_index';

  @override
  AppThemeSettings build() {
    _loadSettings();
    return AppThemeSettings(mode: ThemeMode.system, colorIndex: 0);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex =
        prefs.getInt(_themeModeKey) ?? 0; // 0: system, 1: light, 2: dark
    final colorIndex = prefs.getInt(_themeColorKey) ?? 0;

    ThemeMode mode = ThemeMode.system;
    if (modeIndex == 1) mode = ThemeMode.light;
    if (modeIndex == 2) mode = ThemeMode.dark;

    state = AppThemeSettings(mode: mode, colorIndex: colorIndex);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    int modeIndex = 0;
    if (mode == ThemeMode.light) modeIndex = 1;
    if (mode == ThemeMode.dark) modeIndex = 2;
    await prefs.setInt(_themeModeKey, modeIndex);
  }

  Future<void> setColorIndex(int index) async {
    if (index < 0 || index >= appThemeColors.length) return;
    state = state.copyWith(colorIndex: index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeColorKey, index);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeSettings>(
  ThemeNotifier.new,
);
