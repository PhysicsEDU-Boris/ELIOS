import 'dart:async';
import 'dart:typed_data';

import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/live_scan_controller.dart';
import 'package:elio/services/detection_crop.dart';
import 'package:elio/services/detection_stabilizer.dart' show TrackedDetection;
import 'package:elio/services/frame_source/frame_source.dart';
import 'package:elio/services/robot/r1_constants.dart' show armSettle;
import 'package:elio/services/live_scan_state_machine.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:elio/widgets/control/r2_controls.dart' show TransportKey;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

final _t0 = DateTime(2026, 1, 1);

Detection _det(String label,
        {double x = 320, double score = 0.9, double w = 120, double h = 160, int? trackId, double? distCm, double? lateralCm}) =>
    Detection(
        x: x, y: 240, w: w, h: h, label: label, score: score, trackId: trackId, distCm: distCm, lateralCm: lateralCm);

const _frame = Size(640, 480); // MaixCAM2 frame; 0.6 of it is 184320 px²

final _plastic = _det('Plastic');
final _metal = _det('Metal', x: 600);
// The hand holding the item: bigger and more confident than the item.
const _hand = Detection(x: 300, y: 260, w: 400, h: 400, label: 'Human_Hand', score: 0.97);

/// A controller with a fake clock and a fake quiz the test drives
/// ("fake identify": a quiz start is recorded, its phases are scripted).
class _Rig {
  _Rig({this.busy = false, bool manualPickUpQuiz = false}) {
    c = LiveScanController(
      manualPickUpQuiz: manualPickUpQuiz,
      startQuiz: (detection, _) {
        final label = detection.label;
        if (busy) return false;
        starts.add(label);
        startedTrackIds.add(detection.trackId);
        startedAt = now;
        c.onQuizPhase(WasteQuizPhase.loadingQuestion);
        return true;
      },
      firstTokenMs: () => firstToken,
      clock: () => _t0.add(Duration(milliseconds: now)),
      onEvent: (event, data) => events.add((event, data)),
    );
  }

  final bool busy;
  int now = 0;
  int? startedAt;
  int? firstToken = 321; // mutable: a test can simulate a fallback (null)
  late final LiveScanController c;
  final starts = <String>[];
  final startedTrackIds = <int?>[];
  final events = <(String, Map<String, Object?>)>[];
  List<Map<String, Object?>> logged(String event) => [for (final (e, d) in events) if (e == event) d];

  void at(int ms, List<Detection> frame, {bool? armMoving}) {
    now = ms;
    c.onDetections(frame, frameSize: _frame, armMoving: armMoving);
  }

  /// Frames every [step] ms; the fake quiz shows its question [askMs] after
  /// a start and is closed by the user at [closeAt] (if given).
  void run(int from, int to, List<Detection> frame,
      {int step = 250, int askMs = 4000, int? closeAt, bool? armMoving}) {
    for (var t = from; t <= to; t += step) {
      at(t, frame, armMoving: armMoving);
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
  // WasteQuizNotifier now touches QuizTtsService.instance unconditionally
  // (stop() on every question change, decision 0011's TTS fix) -- its lazy
  // FlutterTts() construction needs the binding ready, even with voice off.
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('G1b: PICK UP crops the frame captured at lock despite later frames without clean_image', (tester) async {
    final imageBytes = Uint8List.fromList(img.encodePng(img.Image(width: 640, height: 480)));
    final lockedFrame = CapturedFrame(
      bytes: imageBytes,
      cleanBytes: imageBytes,
      width: 640,
      height: 480,
      timestamp: _t0,
      frameId: 1,
      detectionFrameId: 1,
    );
    final laterFrame = CapturedFrame(
      bytes: imageBytes,
      width: 640,
      height: 480,
      timestamp: _t0,
      frameId: 2,
      detectionFrameId: 2,
    );
    var now = 0;
    CapturedFrame? latestFrame;
    TrackedDetection? lockedDetection;
    Uint8List? crop;
    CapturedFrame? startedFrame;
    final controller = LiveScanController(
      manualPickUpQuiz: true,
      clock: () => _t0.add(Duration(milliseconds: now)),
      startQuiz: (detection, frame) {
        startedFrame = frame;
        lockedDetection = detection;
        crop = cropDetection((frame!, detection));
        return crop != null;
      },
    );
    addTearDown(controller.dispose);

    for (now = 0; now <= 1500; now += 250) {
      latestFrame = lockedFrame;
      controller.onDetections([_plastic], frameSize: _frame, capturedFrame: lockedFrame);
    }
    expect(controller.machine.state, LiveScanState.asking);
    expect(startedFrame, isNull, reason: 'the live-scan lock alone must not open quiz');
    for (now = 1750; now <= 2250; now += 250) {
      latestFrame = laterFrame;
      controller.onDetections([_plastic], frameSize: _frame, capturedFrame: laterFrame);
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TransportKey(
      icon: Icons.back_hand_outlined,
      label: 'PICK UP',
      onTap: controller.onPickUpPressed,
    ))));
    await tester.tap(find.text('PICK UP'));

    expect(startedFrame, same(lockedFrame));
    expect(crop, isNotNull);
    expect(cropDetection((latestFrame!, lockedDetection!)), isNull,
        reason: 'the old _latestFrame path cannot crop without paired clean_image');
  });

  group('J1 guard (decision 0020, "J1 guard")', () {
    test('24 Oct j1_sweep: the camera turns away and back, the quizzed bottle is not quizzed again', () {
      final r = _Rig();
      r.run(0, 10000, [_plastic], closeAt: 8000);
      r.run(10250, 25000, [_plastic]); // cooldown over at 23 s; the quizzed bottle stays blocked
      // J1 sweeps +25, -25, 0 for 3 s: the bottle leaves the image, then comes back elsewhere
      // in the image (no overlap with its old box: J1 stopped at a slightly different angle).
      r.run(25250, 28000, [], armMoving: true);
      r.run(28250, 29000, [_det('Plastic', x: 470)], armMoving: true);
      r.run(29250, 60000, [_det('Plastic', x: 470)], armMoving: false);
      expect(r.starts, ['Plastic']);
      expect(r.logged('arm_guard'), isNotEmpty);
    });

    test('while the arm moves nothing locks; once still, a different object locks as usual', () {
      final r = _Rig();
      r.run(0, 3000, [_metal], armMoving: true);
      expect(r.starts, isEmpty);
      expect(r.c.blockReason?.code, 'arm_moving');
      expect(r.c.blockReason?.text, 'menunggu: lengan bergerak');
      r.run(3250, 3250 + armSettle.inMilliseconds - 250, [_metal]); // ARM_SETTLE after the last moving frame
      expect(r.starts, isEmpty);
      r.run(3250 + armSettle.inMilliseconds, 7000, [_metal]);
      expect(r.starts, ['Metal']);
    });

    test("the app's own servo command holds the guard for its motion plus ARM_SETTLE", () {
      final r = _Rig();
      r.at(0, [_metal]);
      r.at(500, [_metal]); // a candidate, 0.5 s held
      r.c.onArmCommand(const Duration(seconds: 1)); // e.g. 60 deg at 60 deg/s
      r.run(750, 2750, [_metal]); // frozen until 0.5 + 1 + 1.5 = 3 s
      expect(r.starts, isEmpty);
      expect(r.c.blockReason?.code, 'arm_moving');
      r.run(3000, 6000, [_metal]); // 3 s: the first analysed frame again
      expect(r.starts, ['Metal'], reason: 'the frozen stabilizer resumes');
      expect(r.startedAt, 3000 + 1000, reason: 'the lock time starts over after the freeze (no pre-freeze credit)');
    });
  });

  group('STOPPED pauses the scan (decision 0026, E1b)', () {
    test('no lock, identify or quiz while STOPPED; frames still counted; resume locks as usual', () {
      final r = _Rig();
      r.c.setScanPaused(true);
      r.run(0, 5000, [_plastic]);
      expect(r.starts, isEmpty);
      expect(r.c.fps, greaterThan(0), reason: 'frames still stream');
      expect(r.c.blockReason?.code, 'stopped');
      expect(r.c.blockReason?.text, 'menunggu: robot dihentikan (STOP)');
      r.c.setScanPaused(false);
      r.run(5250, 8000, [_plastic]);
      expect(r.starts, ['Plastic'], reason: 'after "Lanjutkan" the object locks after the usual 1 s');
      expect(r.startedAt, 5250 + 1000);
      expect(r.logged('scan_paused'), hasLength(1));
      expect(r.logged('scan_resumed'), hasLength(1));
    });

    test('24 Oct: a reconnect while STOPPED does not quiz the same bottle; after Lanjutkan the 0020 rules apply', () {
      final r = _Rig();
      r.run(0, 10000, [_plastic], closeAt: 8000);
      r.c.setScanPaused(true); // the link drops: STOPPED (link_lost)
      r.c.onLinkRestored(); // the reconnect forgets the quizzed bottle (0020 "Link drop")
      r.run(20000, 40000, [_plastic]);
      expect(r.starts, ['Plastic'], reason: 'no new quiz while STOPPED');
      r.c.setScanPaused(false);
      r.run(40250, 45000, [_plastic]);
      expect(r.starts, ['Plastic', 'Plastic'], reason: 'after Lanjutkan the forgotten bottle may lock again (0020)');
    });

    test('an open quiz stays open and closes normally while STOPPED', () {
      final r = _Rig();
      r.run(0, 5000, [_plastic]); // locked at 1 s, question at 5 s
      expect(r.c.machine.state, LiveScanState.quiz);
      r.c.setScanPaused(true);
      r.run(5250, 9000, [_plastic]);
      r.c.onQuizPhase(WasteQuizPhase.idle); // the student closes it
      expect(r.c.machine.state, LiveScanState.cooldown);
      r.c.setScanPaused(false);
      r.run(9250, 30000, [_plastic]);
      expect(r.starts, ['Plastic'], reason: 'the quizzed bottle stays quizzed');
    });
  });

  group('acceptance (scripted frames, fake identify)', () {
    test('track_id fills the stabilizer slot, but box overlap still decides (decision 0022)', () {
      final r = _Rig();
      r.at(0, [_det('Plastic', trackId: 7, distCm: 24.5, lateralCm: -3)]);
      r.at(500, [_det('Plastic', trackId: 8)]); // a new id on the same box: still one object
      r.at(1000, [_det('Plastic', trackId: 9)]);
      expect(r.starts, ['Plastic']);
      expect(r.startedTrackIds, [9]);
    });

    test('same object held 60 s: exactly 1 identify', () {
      final r = _Rig();
      r.run(0, 60000, [_plastic, _hand], closeAt: 30000); // 4 fps, quiz closed at 30 s
      expect(r.starts, ['Plastic']);
      expect(r.c.machine.askCount, 1);
      // Decision 0020: re-armed after the cooldown, but the held object stays blocked.
      expect(r.c.machine.state, LiveScanState.searching);
      expect(r.c.blockReason?.code, 'same_object');
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

    test('lastFirstTokenMs/lastAskToQuestionMs reset the instant a new ask starts, '
        'not just once its question shows', () {
      final r = _Rig();
      r.run(0, 10000, [_plastic], closeAt: 8000);
      expect(r.c.lastFirstTokenMs, 321);
      expect(r.c.lastAskToQuestionMs, 4000);

      r.run(10250, 25000, []); // removed: cooldown + empty scene clear by 25000
      // Metal locks at 25250 + 1000 = 26250: the ask fires on that very
      // frame, before any onQuizPhase call for it, so the reset must
      // already have happened here -- not after its question shows.
      r.run(25250, 26250, [_metal]);
      expect(r.starts, ['Plastic', 'Metal']);
      expect(r.c.lastFirstTokenMs, isNull, reason: 'Plastic\'s old value must not linger during Metal\'s ASKING');
      expect(r.c.lastAskToQuestionMs, isNull);
    });

    test('a fallback question (no real token) does not keep the previous quiz\'s first-token time', () {
      final r = _Rig();
      r.run(0, 10000, [_plastic], closeAt: 8000); // real token: 321
      expect(r.c.lastFirstTokenMs, 321);

      r.run(10250, 25000, []); // removed
      r.firstToken = null; // this ask falls back / fails: no real token
      r.run(25250, 35000, [_metal], askMs: 1500, closeAt: 33000);

      expect(r.starts, ['Plastic', 'Metal']);
      expect(r.c.lastFirstTokenMs, isNull, reason: 'a fallback question must show "-", not Plastic\'s 321ms');
      expect(r.c.lastAskToQuestionMs, 1500, reason: 'the ask-to-question time is still real even without a token');
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
      expect(unknown, hasLength(1));
      expect(unknown.single, contains('"human_hand"'));
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
      expect(r.c.machine.quizzedLabels, ['Plastic'], reason: 'present at 0.60: still the quizzed object');
    });

    test('(c) a hand alone is an empty scene', () {
      final r = _Rig();
      r.run(0, 10000, [_plastic], closeAt: 8000);
      r.run(10250, 30000, [_hand]); // cooldown over at 23000, hand only
      expect(r.c.machine.state, LiveScanState.searching);
    });

    test('(c) a low-score object (0.55) no longer holds the cooldown (decision 0020), and never locks', () {
      final r = _Rig();
      r.run(0, 10000, [_plastic], closeAt: 8000);
      r.run(10250, 60000, [_det('Metal', x: 600, score: 0.55)]);
      expect(r.c.machine.state, LiveScanState.searching);
      expect(r.starts, ['Plastic']);
      expect(r.c.blockReason?.code, 'below_min_score');
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

  group('lock diagnostics and manual re-arm (decision 0020)', () {
    test('box_ignored_too_large: once per change of labels, with the area fraction', () {
      final big = _det('E_Waste', w: 500, h: 400); // 200000 / 307200 = 0.65 of the frame
      final r = _Rig()..run(0, 3000, [big]);
      expect(r.logged('box_ignored_too_large'), [
        {'labels': {'E_Waste': 0.65}, 'maxAreaFraction': 0.6},
      ]);
      expect(r.c.blockReason?.text, 'menunggu: kotak terlalu besar (E_Waste 0.65)');
      r.run(3250, 4000, []);
      r.run(4250, 5000, [big]);
      expect(r.logged('box_ignored_too_large'), hasLength(2), reason: 'gone and back is a change');
    });

    test('below_min_score: a summary at most once a second, best score per label', () {
      final r = _Rig()..run(0, 2900, [_det('Plastic', score: 0.62), _det('Metal', x: 600, score: 0.55)], step: 100);
      final lines = r.logged('below_min_score');
      expect(lines, hasLength(3)); // at 0, 1000, 2000
      expect(lines.first, {'labels': {'Plastic': 0.62, 'Metal': 0.55}, 'minScore': 0.70});
      expect(r.c.blockReason?.text, 'menunggu: skor di bawah 0.70 (Plastic 0.62, Metal 0.55)');
    });

    test('ask_busy: a lock refused because a quiz is open', () {
      final r = _Rig(busy: true)..run(0, 2000, [_plastic]);
      expect(r.logged('ask_busy'), [
        {'label': 'Plastic'},
      ]);
    });

    test('every blocking reason is logged once per change with its values', () {
      final r = _Rig();
      r.run(0, 30000, [_plastic], closeAt: 8000); // quiz closed at 8000; Plastic stays
      r.run(30250, 40000, [_plastic, _metal]); // Metal arrives: asked
      final blocked = r.logged('rearm_blocked');
      expect([for (final b in blocked) b['reason']], ['cooldown', 'same_object']);
      expect(blocked.first['labels'], {'Plastic': 0.9});
      expect(blocked.first['remainingMs'], 15000 - 250);
      expect(blocked.last['labels'], {'Plastic': 0.9});
      expect(r.logged('cooldown_enter'), hasLength(1));
      expect(r.logged('rearm').single['reason'], 'cooldown_elapsed');
      expect(r.logged('lock_dropped_same_label'), hasLength(1));
      expect(r.starts, ['Plastic', 'Metal']);
    });

    test('"Scan lagi" during the cooldown: the held object can be asked again at once; logged', () {
      final r = _Rig();
      r.run(0, 10000, [_plastic], closeAt: 8000); // cooldown until 23000
      expect(r.c.blockReason?.code, 'cooldown');
      expect(r.c.canManualRearm, isTrue);
      expect(r.c.manualRearm(), isTrue);
      expect(r.logged('manual_rearm').single, containsPair('state', 'cooldown'));
      expect(r.c.machine.state, LiveScanState.searching);
      r.run(10250, 11500, [_plastic]);
      expect(r.starts, ['Plastic', 'Plastic']);
    });

    test('"Scan lagi" is disabled and does nothing while a quiz is open', () {
      final r = _Rig()..run(0, 6000, [_plastic]); // asked at 1000, question shown at 5000
      expect(r.c.machine.state, LiveScanState.quiz);
      expect(r.c.canManualRearm, isFalse);
      expect(r.c.manualRearm(), isFalse);
      expect(r.c.machine.state, LiveScanState.quiz);
      expect(r.logged('manual_rearm'), isEmpty);
      expect(r.c.blockReason?.text, 'menunggu: kuis masih terbuka');
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
      expect(r.c.machine.lastAskFailed, isFalse, reason: 'a user close is not ASK FAILED');
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
    AiQuizService.instance.mockSendExecute =
        (prompt, {imageBytes, isUser = false}) => question.future;
    addTearDown(() => AiQuizService.instance.mockSendExecute = null);
    // Needs a question that is still loading: only the opt-in Gemma path has one (decision 0017).
    WasteQuizNotifier.sourceOverride = QuestionSource.ai;
    addTearDown(() => WasteQuizNotifier.sourceOverride = null);

    final container = ProviderContainer(overrides: [appPreferencesProvider.overrideWith(_SeededPrefs.new)]);
    addTearDown(container.dispose);
    final quiz = container.read(wasteQuizProvider.notifier)..toggleVoice(); // no TTS in unit tests

    var now = 0;
    final c = LiveScanController(
        startQuiz: (detection, _) {
        final label = detection.label;
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

    question.complete('{"question": "Bahan utama botol ini?", "correct": "PET", "wrong": ["Kaca", "Logam", "Kertas"], '
        ' "explanation": "Botol minum umumnya PET."}');
    await pumpEventQueue();
    expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.active);
    expect(c.machine.state, LiveScanState.quiz);
  });

  test('LiveScanController with no clock: argument still works (uses the monotonic default, decision 0009)', () {
    final c = LiveScanController(startQuiz: (_, _) => true);
    expect(c.machine.state, LiveScanState.searching);
    c.onDetections([_plastic]);
    expect(c.machine.state, LiveScanState.locking);
  });
}
