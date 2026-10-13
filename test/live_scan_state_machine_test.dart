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
    DateTime clock() => _t0.add(Duration(milliseconds: _now));
    m = LiveScanStateMachine(DetectionStabilizer(ignoredLabels: {'Human_Hand'}, clock: clock), clock: clock);
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

    test('ASKING -> QUIZ -> COOLDOWN -> SEARCHING after 15 s and a 2 s empty scene', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]); // asks at 1000
      r.m.onAskOutcome(AskOutcome.questionReady);
      expect(r.m.state, LiveScanState.quiz);
      r.at(2000, [_a]);
      r.m.onQuizClosed(); // closed at 2000
      expect(r.m.state, LiveScanState.cooldown);
      r.hold(2100, 16900, []); // empty, but 15 s not over yet
      expect(r.m.state, LiveScanState.cooldown);
      r.at(17000, []); // 15 s since the close, empty since 2100
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

    test('in COOLDOWN even a different object is not asked', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.m.onQuizClosed();
      r.hold(1100, 10000, [_b]); // Plastic gone, Metal held 9 s
      expect(r.asked, ['Plastic']);
      expect(r.m.state, LiveScanState.cooldown);
    });
  });

  group('ask failure recovery (failed, busy, cancelled)', () {
    for (final outcome in [AskOutcome.failed, AskOutcome.busy, AskOutcome.cancelled]) {
      test('$outcome: back to searching, the object stays blocked until absent 1.5 s, never stuck', () {
        final asks = outcome == AskOutcome.busy ? 0 : 1; // a busy ask is counted as busy, not identify
        final r = _Rig();
        r.hold(0, 1000, [_a]); // asks
        r.m.onAskOutcome(outcome);
        expect(r.m.state, LiveScanState.searching);
        expect(r.m.lastAskFailed, isTrue);
        r.hold(1100, 5000, [_a]); // same object still there: blocked, not retried in a loop
        expect(r.m.askCount, asks);
        expect(r.m.busyCount, 1 - asks);
        expect(r.m.lastAskFailed, isTrue);
        r.hold(5100, 6500, []);
        r.at(6600, []); // re-armed
        expect(r.m.lastAskFailed, isFalse);
        r.hold(31100, 32100, [_a]); // back after the 30 s label wait, held 1 s: asked again
        expect(r.m.askCount, asks + 1);
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

  group('cooldown (no quiz spam)', () {
    /// Plastic asked at 1000, question shown, quiz closed at 2000.
    _Rig closedAt2000() {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.at(2000, [_a]);
      r.m.onQuizClosed();
      return r;
    }

    test('the same object back after the close is not asked within 15 s', () {
      final r = closedAt2000();
      r.hold(2100, 5000, []); // gone for 2.9 s
      r.hold(5100, 16900, [_a]); // back and held
      expect(r.asked, ['Plastic']);
      expect(r.m.state, LiveScanState.cooldown);
    });

    test('nothing is asked until an empty scene was seen for 2 s, however long it takes', () {
      final r = closedAt2000();
      r.hold(2100, 40000, [_a]); // held for 38 s: past the cooldown and the label wait
      expect(r.asked, ['Plastic']);
      expect(r.m.state, LiveScanState.cooldown);
      r.hold(40100, 42000, []); // empty 1.9 s
      expect(r.m.state, LiveScanState.cooldown);
      r.at(42100, []); // empty 2 s: re-armed
      expect(r.m.state, LiveScanState.searching);
      r.hold(42200, 43200, [_a]);
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('a detection the stabilizer ignores (Human_Hand) still counts as an empty scene', () {
      final r = closedAt2000();
      r.hold(2100, 17000, [_box('Human_Hand')]);
      expect(r.m.state, LiveScanState.searching);
    });

    test('a different label can ask once the cooldown is over', () {
      final r = closedAt2000();
      r.hold(2100, 17000, []);
      r.hold(17100, 18100, [_b]);
      expect(r.asked, ['Plastic', 'Metal']);
      expect(r.m.state, LiveScanState.asking);
    });

    test('the same label within 30 s of its quiz closing is blocked, and asked after', () {
      final r = closedAt2000();
      r.hold(2100, 17000, []); // cooldown over
      r.hold(17100, 20000, [_a]); // locks at 18100: within 30 s of the close at 2000
      expect(r.asked, ['Plastic']);
      expect(r.m.state, isNot(LiveScanState.asking));
      r.hold(20100, 21700, []); // leaves: the stabilizer re-arms it
      r.hold(32100, 33100, [_a]); // locks at 33100, 31.1 s after the close
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('an open quiz the machine did not start shows QUIZ and asks nothing', () {
      final r = _Rig();
      r.m.onQuizOpen();
      expect(r.m.state, LiveScanState.quiz);
      r.hold(0, 5000, [_a]);
      expect(r.asked, isEmpty);
      expect(r.m.askCount, 0);
      expect(r.m.busyCount, 0);
      r.m.onQuizClosed();
      expect(r.m.state, LiveScanState.cooldown);
    });
  });
}
