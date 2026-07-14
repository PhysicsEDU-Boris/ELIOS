import 'package:flutter_riverpod/flutter_riverpod.dart';

/// UI-only application preferences (not device connection related).
///
/// These are held in memory only — they reset on app restart.
/// To persist across restarts, back with `shared_preferences`.
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
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesNotifier, AppPreferences>(
  AppPreferencesNotifier.new,
);

class AppPreferencesNotifier extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => const AppPreferences();

  void update(AppPreferences Function(AppPreferences) patch) =>
      state = patch(state);
}
