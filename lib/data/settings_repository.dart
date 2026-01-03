import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TimerPreset {
  final String name;
  final int focusMinutes;
  final int restMinutes;

  TimerPreset({
    required this.name,
    required this.focusMinutes,
    required this.restMinutes,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'focusMinutes': focusMinutes,
    'restMinutes': restMinutes,
  };

  factory TimerPreset.fromJson(Map<String, dynamic> json) => TimerPreset(
    name: json['name'],
    focusMinutes: json['focusMinutes'],
    restMinutes: json['restMinutes'],
  );
}

class SettingsRepository {
  static const String _presetsKey = 'timer_presets';
  static const String _autoStartKey = 'auto_start_next';

  Future<bool> getAutoStartNext() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoStartKey) ?? true; // Default to true
  }

  Future<void> setAutoStartNext(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoStartKey, value);
  }

  Future<List<TimerPreset>> getPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final String? presetsJson = prefs.getString(_presetsKey);

    if (presetsJson == null) {
      return _defaultPresets();
    }

    try {
      final List<dynamic> decoded = jsonDecode(presetsJson);
      return decoded.map((e) => TimerPreset.fromJson(e)).toList();
    } catch (e) {
      return _defaultPresets();
    }
  }

  Future<void> savePresets(List<TimerPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(presets.map((e) => e.toJson()).toList());
    await prefs.setString(_presetsKey, encoded);
  }

  List<TimerPreset> _defaultPresets() {
    return [
      TimerPreset(name: 'Classic', focusMinutes: 25, restMinutes: 5),
      TimerPreset(name: 'Long Focus', focusMinutes: 50, restMinutes: 10),
      TimerPreset(name: 'Quick', focusMinutes: 15, restMinutes: 3),
    ];
  }
}
