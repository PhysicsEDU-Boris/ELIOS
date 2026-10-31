import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/appearance_service.dart';
import 'app_preferences_provider.dart' show testerBuild;

enum ElioThemeMode { light, dark }

// shortcut: hidden until S1–S3 migrate every screen to tokens; then remove the gate.
const darkModeOption = bool.fromEnvironment('DARK_MODE_OPTION') || testerBuild;

/// Reads the saved mode before `runApp` so the Flutter splash starts in it (no
/// white flash), and tells Android so the launch screen and icon match from the
/// next start (decision 0160).
Future<List<Override>> startupModeOverrides() async {
  final mode = await ElioThemeModeNotifier.readSaved();
  unawaited(AppearanceService.setDark(mode == ElioThemeMode.dark));
  return [
    elioThemeModeProvider.overrideWith(() => ElioThemeModeNotifier(mode)),
  ];
}

final elioThemeModeProvider =
    NotifierProvider<ElioThemeModeNotifier, ElioThemeMode>(
      ElioThemeModeNotifier.new,
    );

class ElioThemeModeNotifier extends Notifier<ElioThemeMode> {
  /// [initial] is the mode read before `runApp`, so the first frame is right.
  ElioThemeModeNotifier([this._initial = ElioThemeMode.light]);

  static const _key = 'elio_theme_mode_v1';
  final ElioThemeMode _initial;
  bool _touched = false;
  bool _disposed = false;

  /// The saved mode, or light when missing or unreadable.
  static Future<ElioThemeMode> readSaved() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      return saved == 'dark' ? ElioThemeMode.dark : ElioThemeMode.light;
    } catch (e) {
      debugPrint('ElioThemeMode read failed: $e');
      return ElioThemeMode.light;
    }
  }

  @override
  ElioThemeMode build() {
    ref.onDispose(() => _disposed = true);
    _load();
    return _initial;
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (!_disposed && !_touched) {
        state = saved == 'dark' ? ElioThemeMode.dark : ElioThemeMode.light;
      }
    } catch (e) {
      debugPrint('ElioThemeMode load failed: $e');
    }
  }

  void setMode(ElioThemeMode mode) {
    _touched = true;
    state = mode;
    AppearanceService.setDark(mode == ElioThemeMode.dark);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, mode.name))
        .catchError((Object e) {
          debugPrint('ElioThemeMode save failed: $e');
          return false;
        });
  }
}
