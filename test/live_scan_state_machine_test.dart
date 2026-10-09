import 'package:elio/services/detection_stabilizer.dart';
import 'package:elio/services/live_scan_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 1, 1);

TrackedDetection _box(String label, {double x = 50}) =>
    TrackedDetection(label: label, x: x, y: 50, w: 100, h: 100, score: 0.9);

final _a = _box('Plastic');
final _b = _box('Metal', x: 400);

/// A state machine over a stabilizer with a fake clock (ms from [_t0]).
class _Rig {
  _Rig() {
    m = LiveScanStateMachine(DetectionStabilizer(clock: () => _t0.add(Duration(milliseconds: _now))));
  }

  int _now = 0;
  late final LiveScanStateMachine m;
  final asked = <String>[];

  StabilizerLock? at(int ms, List<TrackedDetection> frame) {
    _now = ms;
    final lock = m.onFrame(frame);
    if (lock != null) asked.add(lock.detection.label);
    return lock;
  }

  void hold(int from, int to, List<TrackedDetection> frame, {int step = 100}) {
    for (var t = from; t <= to; t += step) {
      at(t, frame);
    }
  }
}

void main() {
  group('transitions', () {
    test('starts in SEARCHING; empty frames stay there', () {
      final r = _Rig();
      expect(r.m.state, LiveScanState.searching);
      r.hold(0, 3000, []);
      expect(r.m.state, LiveScanState.searching);
      expect(r.asked, isEmpty);
    });

    test('SEARCHING -> LOCKING on a candidate, back to SEARCHING when it drops out', () {
      final r = _Rig();
      r.at(0, [_a]);
      expect(r.m.state, LiveScanState.locking);
      r.hold(100, 700, []); // missing from 100: exactly 600 ms keeps the candidate
      expect(r.m.state, LiveScanState.locking);
      r.at(701, []); // 601 ms: dropped
      expect(r.m.state, LiveScanState.searching);
    });

    test('LOCKING -> ASKING at the lock: exactly one ask, with the locked label', () {
      final r = _Rig();
      r.hold(0, 900, [_a]);
      expect(r.m.state, LiveScanState.locking);
      final lock = r.at(1000, [_a]);
      expect(lock?.detection.label, 'Plastic');
      expect(r.m.state, LiveScanState.asking);
      expect(r.m.askCount, 1);
    });

    test('ASKING -> QUIZ -> COOLDOWN -> SEARCHING once the stabilizer re-arms', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]); // asks at 1000
      r.m.onAskOutcome(AskOutcome.questionReady);
      expect(r.m.state, LiveScanState.quiz);
      r.m.onQuizClosed();
      expect(r.m.state, LiveScanState.cooldown);
      r.hold(1100, 5000, [_a]); // same object still there: stays in cooldown
      expect(r.m.state, LiveScanState.cooldown);
      r.hold(5100, 6500, []); // missing from 5100
      expect(r.m.state, LiveScanState.cooldown);
      r.at(6600, []); // missing 1500 ms: re-armed
      expect(r.m.state, LiveScanState.searching);
      expect(r.asked, ['Plastic']);
    });

    test('outcomes outside ASKING and a close outside QUIZ are ignored', () {
      final r = _Rig();
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.m.onQuizClosed();
      expect(r.m.state, LiveScanState.searching);
      r.hold(0, 1000, [_a]);
      r.m.onQuizClosed(); // still ASKING
      expect(r.m.state, LiveScanState.asking);
    });
  });

  group('no double ask', () {
    test('locks while ASKING or in QUIZ are dropped, not queued', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]); // asks for Plastic
      r.hold(1100, 2100, [_b]); // Metal locks while ASKING: dropped
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.hold(2200, 3200, [_a]); // in QUIZ: nothing is asked
      r.m.onQuizClosed();
      r.hold(3300, 4300, [_a]); // nothing queued comes out after the close
      expect(r.asked, ['Plastic']);
      expect(r.m.askCount, 1);
    });

    test('in COOLDOWN a different object that locks ends it and is asked once', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.m.onQuizClosed();
      r.hold(1100, 2100, [_b]); // Plastic gone, Metal held 1 s
      expect(r.asked, ['Plastic', 'Metal']);
      expect(r.m.state, LiveScanState.asking);
    });
  });

  group('ask failure recovery (failed, busy, cancelled)', () {
    for (final outcome in [AskOutcome.failed, AskOutcome.busy, AskOutcome.cancelled]) {
      test('$outcome: back to searching, the object stays blocked until absent 1.5 s, never stuck', () {
        final r = _Rig();
        r.hold(0, 1000, [_a]); // asks
        r.m.onAskOutcome(outcome);
        expect(r.m.state, LiveScanState.searching);
        expect(r.m.lastAskFailed, isTrue);
        r.hold(1100, 5000, [_a]); // same object still there: blocked, not retried in a loop
        expect(r.m.askCount, 1);
        expect(r.m.lastAskFailed, isTrue);
        r.hold(5100, 6500, []);
        r.at(6600, []); // re-armed
        expect(r.m.lastAskFailed, isFalse);
        r.hold(6700, 7700, [_a]); // back and held 1 s: asked again
        expect(r.m.askCount, 2);
        expect(r.m.state, LiveScanState.asking);
      });
    }

    test('after a failure another object can be asked right away', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.busy);
      r.hold(1100, 2100, [_b]);
      expect(r.asked, ['Plastic', 'Metal']);
    });
  });
}
