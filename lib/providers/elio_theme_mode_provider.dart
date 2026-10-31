import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences_provider.dart' show testerBuild;

enum ElioThemeMode { light, dark }

// shortcut: hidden until S1–S3 migrate every screen to tokens; then remove the gate.
const darkModeOption = bool.fromEnvironment('DARK_MODE_OPTION') || testerBuild;

final elioThemeModeProvider =
    NotifierProvider<ElioThemeModeNotifier, ElioThemeMode>(
      ElioThemeModeNotifier.new,
    );

class ElioThemeModeNotifier extends Notifier<ElioThemeMode> {
  static const _key = 'elio_theme_mode_v1';
  bool _touched = false;
  bool _disposed = false;

  @override
  ElioThemeMode build() {
    ref.onDispose(() => _disposed = true);
    _load();
    return ElioThemeMode.light;
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
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, mode.name))
        .catchError((Object e) {
          debugPrint('ElioThemeMode save failed: $e');
          return false;
        });
  }
}
