import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI-only application preferences (not device connection related),
/// persisted so quiz settings (difficulty, skip) survive restarts.
class AppPreferences {
  final bool soundEffects;
  final double masterVolume;
  final String quizDifficulty;
  final String quizTimer;
  final bool skipAllowed;

  const AppPreferences({
    this.soundEffects = true,
    this.masterVolume = 0.75,
    this.quizDifficulty = 'Medium',
    this.quizTimer = '60s',
    this.skipAllowed = false,
  });

  AppPreferences copyWith({
    bool? soundEffects,
    double? masterVolume,
    String? quizDifficulty,
    String? quizTimer,
    bool? skipAllowed,
  }) {
    return AppPreferences(
      soundEffects: soundEffects ?? this.soundEffects,
      masterVolume: masterVolume ?? this.masterVolume,
      quizDifficulty: quizDifficulty ?? this.quizDifficulty,
      quizTimer: quizTimer ?? this.quizTimer,
      skipAllowed: skipAllowed ?? this.skipAllowed,
    );
  }

  Map<String, dynamic> toMap() => {
        'soundEffects': soundEffects,
        'masterVolume': masterVolume,
        'quizDifficulty': quizDifficulty,
        'quizTimer': quizTimer,
        'skipAllowed': skipAllowed,
      };

  factory AppPreferences.fromMap(Map<String, dynamic> map) {
    const d = AppPreferences();
    return AppPreferences(
      soundEffects: map['soundEffects'] is bool ? map['soundEffects'] as bool : d.soundEffects,
      masterVolume: map['masterVolume'] is num ? (map['masterVolume'] as num).toDouble() : d.masterVolume,
      quizDifficulty: map['quizDifficulty'] is String ? map['quizDifficulty'] as String : d.quizDifficulty,
      quizTimer: map['quizTimer'] is String ? map['quizTimer'] as String : d.quizTimer,
      skipAllowed: map['skipAllowed'] is bool ? map['skipAllowed'] as bool : d.skipAllowed,
    );
  }
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesNotifier, AppPreferences>(
  AppPreferencesNotifier.new,
);

class AppPreferencesNotifier extends Notifier<AppPreferences> {
  static const _key = 'app_preferences_v1';
  bool _touched = false;

  @override
  AppPreferences build() {
    _load();
    return const AppPreferences();
  }

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      // Don't overwrite a change the user made while this was loading.
      if (raw != null && !_touched) {
        state = AppPreferences.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('AppPreferences load failed: $e');
    }
  }

  void update(AppPreferences Function(AppPreferences) patch) {
    _touched = true;
    state = patch(state);
    final snapshot = state;
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, jsonEncode(snapshot.toMap())))
        .catchError((Object e) {
      debugPrint('AppPreferences save failed: $e');
      return false;
    });
  }
}
