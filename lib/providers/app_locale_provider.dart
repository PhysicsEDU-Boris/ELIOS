import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/guide_progress.dart';
import '../services/quiz_tts_service.dart';

/// The UI language picked in the sidebar; null = follow the device language.
final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale?>(
  AppLocaleNotifier.new,
);

class AppLocaleNotifier extends Notifier<Locale?> {
  static const _key = 'elio_locale_v1';
  bool _touched = false;
  bool _disposed = false;

  @override
  Locale? build() {
    ref.onDispose(() => _disposed = true);
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (!_disposed && !_touched && saved != null) state = Locale(saved);
    } catch (e) {
      debugPrint('AppLocale load failed: $e');
    }
  }

  void setLocale(Locale locale) {
    _touched = true;
    // Speech in the old language stops at once (decision 0185).
    if (state?.languageCode != locale.languageCode) {
      unawaited(QuizTtsService.instance.stop());
      // Guides follow the app language again: an older in-guide language pick
      // would keep Today's Guide in the other language (decision 0218).
      try {
        unawaited(
          ref
              .read(guideProgressProvider.notifier)
              .setGuideLang(null)
              .catchError((Object e) => debugPrint('Guide lang reset: $e')),
        );
      } catch (e) {
        debugPrint('Guide lang reset: $e');
      }
    }
    state = locale;
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, locale.languageCode))
        .catchError((Object e) {
          debugPrint('AppLocale save failed: $e');
          return false;
        });
  }
}
