// M2a, real model (no fake identify): scripted MaixCAM2 detections fed in
// real time for 60 s through the live-scan controller, the real quiz
// notifier and the real Gemma. Acceptance row: same object held 60 s ->
// exactly 1 identify (quiz start).
//   caffeinate -dimsu flutter test integration_test/live_scan_real_test.dart -d macos
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/live_scan_controller.dart';
import 'package:elio/services/live_scan_state_machine.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _Prefs extends AppPreferencesNotifier {
  @override
  AppPreferences build() => const AppPreferences(quizDifficulty: 'Easy');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('same object held 60 s (real time, real Gemma): exactly 1 identify', (tester) async {
    await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);
    final service = GemmaQuizService.instance;
    expect(await service.ensureReady(), isTrue, reason: '${service.progress.value.error}');

    var generations = 0;
    final original = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) {
      if (m != null && m.startsWith('[GemmaQuizService] generated ')) generations++;
      original(m, wrapWidth: wrapWidth);
    };

    final container = ProviderContainer(overrides: [appPreferencesProvider.overrideWith(_Prefs.new)]);
    try {
      final quiz = container.read(wasteQuizProvider.notifier)..toggleVoice(); // no TTS in the test
      final clock = Stopwatch()..start();
      final starts = <String>[];
      final events = <String>[];
      final c = LiveScanController(
        startQuiz: (detection) {
          final label = detection.label;
          if (container.read(wasteQuizProvider).phase != WasteQuizPhase.idle) return false;
          starts.add(label);
          events.add('${clock.elapsedMilliseconds} ms: quiz start "$label"');
          quiz.startForLabel(label);
          return true;
        },
        firstTokenMs: () => service.lastFirstTokenMs.value,
      );
      container.listen<WasteQuizUiState>(wasteQuizProvider, (prev, next) {
        if (prev?.phase == next.phase) return;
        events.add('${clock.elapsedMilliseconds} ms: quiz phase ${next.phase.name}');
        c.onQuizPhase(next.phase);
      });

      const plastic = Detection(x: 320, y: 240, w: 120, h: 160, label: 'Plastic', score: 0.9);
      const hand = Detection(x: 300, y: 260, w: 400, h: 400, label: 'Human_Hand', score: 0.97);
      var closed = false;
      while (clock.elapsed < const Duration(seconds: 60)) {
        c.onDetections(const [plastic, hand]);
        if (!closed && clock.elapsed >= const Duration(seconds: 30) && c.machine.state == LiveScanState.quiz) {
          closed = true;
          events.add('${clock.elapsedMilliseconds} ms: user closes the quiz');
          quiz.dismiss();
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      debugPrint('[live-scan-test] ${events.join(' | ')}');
      debugPrint('[live-scan-test] result: identify calls ${c.machine.askCount}, quiz starts ${starts.length}, '
          'Gemma generations $generations, first token ${c.lastFirstTokenMs} ms, final state ${c.machine.state.name}, '
          'quiz closed at 30 s: $closed');

      expect(c.machine.askCount, 1, reason: 'exactly one identify (quiz start) for one object held 60 s');
      expect(starts, ['Plastic']);
      expect(closed, isTrue, reason: 'the question never arrived, so the quiz never opened');
      expect(c.machine.state, LiveScanState.cooldown);
    } finally {
      debugPrint = original;
      container.dispose();
      await service.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
