import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ElioThemeMode { light, dark }

const appIconChannel = MethodChannel('elio/app_icon');

/// The Android launcher icon follows the theme (decision 0146). Other
/// platforms keep their icon; a failure never blocks the theme change.
Future<void> applyAppIcon(ElioThemeMode mode) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await appIconChannel.invokeMethod<void>('setDark', mode == ElioThemeMode.dark);
  } catch (e) {
    debugPrint('App icon switch failed: $e');
  }
}

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
        unawaited(applyAppIcon(state)); // repairs an icon left out of step
      }
    } catch (e) {
      debugPrint('ElioThemeMode load failed: $e');
    }
  }

  void setMode(ElioThemeMode mode) {
    _touched = true;
    state = mode;
    unawaited(applyAppIcon(mode));
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, mode.name))
        .catchError((Object e) {
          debugPrint('ElioThemeMode save failed: $e');
          return false;
        });
  }
}
