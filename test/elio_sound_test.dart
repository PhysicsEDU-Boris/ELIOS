// One audio service (decision 0201): Profile → Sound effects and Master volume
// reach every sound at once, persist, and silent mode / throttle apply.
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sound = ElioSound.instance;
  late List<(ElioSfx, double)> played;
  late DateTime now;
  var silent = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    played = [];
    now = DateTime.now().add(const Duration(days: 1));
    silent = false;
    sound
      ..sink = ((s, v) => played.add((s, v)))
      ..isSilent = (() async => silent)
      ..clock = (() => now);
  });
  tearDown(() {
    sound
      ..sink = null
      ..clock = DateTime.now;
    applySoundPrefs(const AppPreferences());
  });

  Future<bool> play(ElioSfx s) {
    now = now.add(const Duration(seconds: 1));
    return sound.play(s);
  }

  test(
    'a Profile change reaches the service and the quiz voice at once',
    () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final prefs = c.read(appPreferencesProvider.notifier);
      c.read(appPreferencesProvider);

      prefs.update((p) => p.copyWith(masterVolume: 0.4));
      expect(sound.volume, 0.4);
      expect(QuizTtsService.instance.volume, 0.4);
      expect(await play(ElioSfx.pop), isTrue);
      expect(played.single, (ElioSfx.pop, 0.4));

      prefs.update((p) => p.copyWith(soundEffects: false));
      expect(sound.enabled, isFalse);
      expect(await play(ElioSfx.chime), isFalse);
      expect(
        played,
        hasLength(1),
        reason: 'Sound effects off mutes everything',
      );

      prefs.update((p) => p.copyWith(soundEffects: true, masterVolume: 0));
      expect(await play(ElioSfx.tick), isFalse, reason: 'volume 0');
    },
  );

  test('saved settings are applied after a restart', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.app_preferences_v1':
          '{"soundEffects": false, "masterVolume": 0.3}',
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(appPreferencesProvider);
    for (var i = 0; i < 10 && sound.enabled; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(sound.enabled, isFalse);
    expect(sound.volume, 0.3);
    expect(QuizTtsService.instance.volume, 0.3);
  });

  test(
    'silent mode mutes; at most one sound per 120 ms; S10 off by default',
    () async {
      silent = true;
      expect(await play(ElioSfx.pop), isFalse);
      silent = false;
      expect(await play(ElioSfx.pop), isTrue);
      now = now.add(const Duration(milliseconds: 50));
      expect(await sound.play(ElioSfx.tick), isFalse, reason: 'throttled');
      expect(await play(ElioSfx.air), isFalse);
      expect(played.map((p) => p.$1), [ElioSfx.pop]);
    },
  );

  test('every palette asset exists and is declared', () async {
    for (final s in ElioSfx.values) {
      final data = await rootBundle.load('assets/${s.asset}');
      expect(data.lengthInBytes, greaterThan(44), reason: s.file);
    }
  });
}
