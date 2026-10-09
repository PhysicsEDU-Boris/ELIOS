import 'dart:async';

import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/live_scan_controller.dart';
import 'package:elio/services/live_scan_state_machine.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 1, 1);

Detection _det(String label, {double x = 320, double score = 0.9}) =>
    Detection(x: x, y: 240, w: 120, h: 160, label: label, score: score);

final _plastic = _det('Plastic');
final _metal = _det('Metal', x: 600);
// The hand holding the item: bigger and more confident than the item.
const _hand = Detection(x: 300, y: 260, w: 400, h: 400, label: 'Human_Hand', score: 0.97);

/// A controller with a fake clock and a fake quiz the test drives
/// ("fake identify": a quiz start is recorded, its phases are scripted).
class _Rig {
  _Rig({this.busy = false}) {
    c = LiveScanController(
      startQuiz: (label) {
        if (busy) return false;
        starts.add(label);
        startedAt = now;
        c.onQuizPhase(WasteQuizPhase.loadingQuestion);
        return true;
      },
      firstTokenMs: () => 321,
      clock: () => _t0.add(Duration(milliseconds: now)),
    );
  }

  final bool busy;
  int now = 0;
  int? startedAt;
  late final LiveScanController c;
  final starts = <String>[];

  void at(int ms, List<Detection> frame) {
    now = ms;
    c.onDetections(frame);
  }

  /// Frames every [step] ms; the fake quiz shows its question [askMs] after
  /// a start and is closed by the user at [closeAt] (if given).
  void run(int from, int to, List<Detection> frame, {int step = 250, int askMs = 4000, int? closeAt}) {
    for (var t = from; t <= to; t += step) {
      at(t, frame);
      if (c.machine.state == LiveScanState.asking && startedAt != null && t >= startedAt! + askMs) {
        c.onQuizPhase(WasteQuizPhase.active);
      }
      if (closeAt != null && t == closeAt && c.machine.state == LiveScanState.quiz) {
        c.onQuizPhase(WasteQuizPhase.idle);
      }
    }
  }
}

class _SeededPrefs extends AppPreferencesNotifier {
  @override
  AppPreferences build() => const AppPreferences(quizDifficulty: 'Easy');
}

void main() {
  group('acceptance (scripted frames, fake identify)', () {
    test('same object held 60 s: exactly 1 identify', () {
      final r = _Rig();
      r.run(0, 60000, [_plastic, _hand], closeAt: 30000); // 4 fps, quiz closed at 30 s
      expect(r.starts, ['Plastic']);
      expect(r.c.machine.askCount, 1);
      expect(r.c.machine.state, LiveScanState.cooldown);
      expect(r.c.lastFirstTokenMs, 321);
    });

    test('object removed, a different one shown: a new lock and one new identify', () {
      final r = _Rig();
      r.run(0, 10000, [_plastic], closeAt: 8000);
      r.run(10250, 12000, []); // removed
      r.run(12250, 22000, [_metal], closeAt: 20000);
      expect(r.starts, ['Plastic', 'Metal']);
      expect(r.c.machine.askCount, 2);
    });
  });

  group('filters', () {
    test('keeps the existing 0.55 score filter', () {
      final low = _Rig()..run(0, 5000, [_det('Plastic', score: 0.54)]);
      expect(low.starts, isEmpty);
      final ok = _Rig()..run(0, 5000, [_det('Plastic', score: 0.55)]);
      expect(ok.starts, ['Plastic']);
    });

    test('Human_Hand (exact firmware spelling) is never tracked, even as the biggest, most confident box', () {
      final r = _Rig()..run(0, 5000, [_hand]);
      expect(r.starts, isEmpty);
      expect(r.c.machine.state, LiveScanState.searching);
      final withItem = _Rig()..run(0, 5000, [_hand, _plastic]);
      expect(withItem.starts, ['Plastic']);
    });

    test('debug: each unknown label is logged once; a mis-spelled hand is not ignored', () {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
      addTearDown(() => debugPrint = original);

      final r = _Rig()..run(0, 3000, [_det('human_hand'), _det('Tetra_Pak', x: 600), _plastic]);
      final unknown = logs.where((l) => l.startsWith('[LiveScan] unknown detector label')).toList();
      expect(unknown, hasLength(2));
      expect(unknown.join(), allOf(contains('"human_hand"'), contains('"Tetra_Pak"')));
      expect(r.starts, isNotEmpty, reason: 'only the exact spelling is ignored');
    });
  });

  group('recovery', () {
    test('BUSY (a quiz already open): back to searching, ASK FAILED, no retry loop', () {
      final r = _Rig(busy: true)..run(0, 5000, [_plastic]);
      expect(r.c.machine.askCount, 1);
      expect(r.c.machine.state, LiveScanState.searching);
      expect(r.c.machine.lastAskFailed, isTrue);
    });

    test('cancelled (quiz dismissed before its question arrived): back to searching', () {
      final r = _Rig()..run(0, 1000, [_plastic]);
      expect(r.c.machine.state, LiveScanState.asking);
      r.c.onQuizPhase(WasteQuizPhase.idle);
      expect(r.c.machine.state, LiveScanState.searching);
      expect(r.c.machine.lastAskFailed, isTrue);
    });

    test('fps counts analysed frames in the last second', () {
      final r = _Rig()..run(0, 3000, []);
      expect(r.c.fps, 4);
    });
  });

  test('a chat message during ASKING gets the "Scan sampah dulu" reply and does not stall the machine', () async {
    final question = Completer<String?>();
    GemmaQuizService.instance.mockSendExecute =
        (prompt, {imageBytes, fresh = false, isUser = false, onToken}) => question.future;
    addTearDown(() => GemmaQuizService.instance.mockSendExecute = null);

    final container = ProviderContainer(overrides: [appPreferencesProvider.overrideWith(_SeededPrefs.new)]);
    addTearDown(container.dispose);
    final quiz = container.read(wasteQuizProvider.notifier)..toggleVoice(); // no TTS in unit tests

    var now = 0;
    final c = LiveScanController(
      startQuiz: (label) {
        if (container.read(wasteQuizProvider).phase != WasteQuizPhase.idle) return false;
        quiz.startForLabel(label);
        return true;
      },
      clock: () => _t0.add(Duration(milliseconds: now)),
    );
    container.listen<WasteQuizUiState>(wasteQuizProvider, (prev, next) {
      if (prev?.phase != next.phase) c.onQuizPhase(next.phase);
    });

    for (now = 0; now <= 1000; now += 100) {
      c.onDetections([_plastic]);
    }
    expect(c.machine.state, LiveScanState.asking);
    expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.loadingQuestion);

    await quiz.sendChatMessage('ini sampah apa?');
    expect(container.read(wasteQuizProvider).messages.last.text, startsWith('Scan sampah dulu'));
    expect(c.machine.state, LiveScanState.asking);

    question.complete('{"question": "Bahan utama botol ini?", "options": ["PET", "Kaca", "Logam", "Kertas"], '
        '"correctIndex": 0, "explanation": "Botol minum umumnya PET."}');
    await pumpEventQueue();
    expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.active);
    expect(c.machine.state, LiveScanState.quiz);
  });
}
