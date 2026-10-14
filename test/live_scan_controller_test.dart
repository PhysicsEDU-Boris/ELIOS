import 'dart:async';
import 'dart:ui' show Size;

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

Detection _det(String label, {double x = 320, double score = 0.9, double w = 120, double h = 160}) =>
    Detection(x: x, y: 240, w: w, h: h, label: label, score: score);

const _frame = Size(640, 480); // MaixCAM2 frame; 0.6 of it is 184320 px²

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
    c.onDetections(frame, frameSize: _frame);
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
      expect(r.c.lastAskToQuestionMs, 4000); // ASKING at 0, question shown at the default askMs
    });

    test('object removed, a different one shown: a new lock and one new identify', () {
      final r = _Rig();
      expect(r.c.lastAskToQuestionMs, isNull, reason: 'nothing asked yet');
      r.run(0, 10000, [_plastic], closeAt: 8000);
      expect(r.c.lastAskToQuestionMs, 4000);
      r.run(10250, 25000, []); // removed: empty scene, and the 15 s cooldown ends at 23000
      r.run(25250, 35000, [_metal], askMs: 1500, closeAt: 33000);
      expect(r.starts, ['Plastic', 'Metal']);
      expect(r.c.machine.askCount, 2);
      expect(r.c.lastAskToQuestionMs, 1500); // updated for the second (Metal) ask
    });
  });

  group('filters', () {
    test('a box scoring under 0.70 never locks', () {
      final low = _Rig()..run(0, 5000, [_det('Plastic', score: 0.69)]);
      expect(low.starts, isEmpty);
      expect(low.c.machine.state, LiveScanState.searching);
      final ok = _Rig()..run(0, 5000, [_det('Plastic', score: 0.70)]);
      expect(ok.starts, ['Plastic']);
    });

    test('a box covering more than 0.6 of the frame never locks', () {
      final big = _Rig()..run(0, 5000, [_det('E_Waste', w: 500, h: 400)]); // 200000 px², 0.65 of the frame
      expect(big.starts, isEmpty);
      expect(big.c.machine.state, LiveScanState.searching);
      final ok = _Rig()..run(0, 5000, [_det('E_Waste', w: 480, h: 384)]); // exactly 0.6
      expect(ok.starts, ['E_Waste']);
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

  group('presence and hysteresis', () {
    test('(a) a held object dipping to 0.60 for 2 s after a quiz gets no second quiz', () {
      final r = _Rig();
      r.run(0, 20000, [_plastic], closeAt: 8000); // quiz closes at 8000, object stays
      r.run(20250, 22250, [_det('Plastic', score: 0.60)]); // dip: below lock, still present
      r.run(22500, 60000, [_plastic]);
      expect(r.starts, ['Plastic']);
      expect(r.c.machine.state, LiveScanState.cooldown);
    });

    test('(c) a hand alone is an empty scene', () {
      final r = _Rig();
      r.run(0, 10000, [_plastic], closeAt: 8000);
      r.run(10250, 30000, [_hand]); // cooldown over at 23000, hand only
      expect(r.c.machine.state, LiveScanState.searching);
    });

    test('(c) a low-score object (0.55) is not an empty scene', () {
      final r = _Rig();
      r.run(0, 10000, [_plastic], closeAt: 8000);
      r.run(10250, 60000, [_det('Metal', x: 600, score: 0.55)]);
      expect(r.c.machine.state, LiveScanState.cooldown);
    });

    test('(c) a box under presenceScore (0.49) or over 0.6 of the frame does not count as present', () {
      final r = _Rig();
      r.run(0, 10000, [_plastic], closeAt: 8000);
      r.run(10250, 30000, [_det('Metal', x: 600, score: 0.49), _det('E_Waste', w: 500, h: 400, score: 0.9)]);
      expect(r.c.machine.state, LiveScanState.searching);
    });

    test('(d) a label hovering 0.60-0.80 locks within 1.25 s', () {
      const scores = [0.80, 0.62, 0.66, 0.60, 0.75, 0.64, 0.69, 0.61];
      final r = _Rig();
      for (var i = 0, t = 0; t <= 1250; i++, t += 250) {
        r.at(t, [_det('Plastic', score: scores[i % scores.length])]);
      }
      expect(r.starts, ['Plastic']);
    });

    test('(d) seen once at 0.80, then 0.60-0.69 for over a second: still locks at 1 s', () {
      final r = _Rig()..at(0, [_det('Plastic', score: 0.80)]);
      r.run(250, 1000, [_det('Plastic', score: 0.65)]);
      expect(r.starts, ['Plastic']);
    });

    test('hysteresis never starts a lock: 0.69 forever stays unlocked', () {
      final r = _Rig()..run(0, 10000, [_det('Plastic', score: 0.69)]);
      expect(r.starts, isEmpty);
      expect(r.c.machine.state, LiveScanState.searching);
    });

    test('hysteresis ends when the label drops under 0.55 for longer than the dropout (600 ms)', () {
      final r = _Rig()..at(0, [_det('Plastic', score: 0.80)]);
      r.run(250, 1000, [_det('Plastic', score: 0.40)]);
      r.run(1250, 10000, [_det('Plastic', score: 0.65)]);
      expect(r.starts, isEmpty);
    });
  });

  group('recovery', () {
    test('BUSY (a quiz already open): back to searching, ASK FAILED, no retry loop', () {
      final r = _Rig(busy: true)..run(0, 5000, [_plastic]);
      expect(r.c.machine.askCount, 0, reason: 'a busy ask is not an identify');
      expect(r.c.machine.busyCount, 1);
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

    test('a quiz already open (not started by the live scan, maybe minimized) shows QUIZ; nothing is asked or counted', () {
      final r = _Rig();
      r.c.onQuizPhase(WasteQuizPhase.active); // the control screen feeds the current phase at start
      r.run(0, 10000, [_plastic]);
      expect(r.c.machine.state, LiveScanState.quiz);
      expect(r.starts, isEmpty);
      expect(r.c.machine.askCount, 0);
      expect(r.c.machine.busyCount, 0);
      r.c.onQuizPhase(WasteQuizPhase.idle);
      expect(r.c.machine.state, LiveScanState.cooldown);
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
