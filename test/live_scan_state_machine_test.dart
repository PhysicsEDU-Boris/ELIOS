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

  StabilizerLock? at(int ms, List<TrackedDetection> frame, {Set<String>? present}) {
    _now = ms;
    final lock = m.onFrame(frame, present: present);
    if (lock != null) asked.add(lock.detection.label);
    return lock;
  }

  void hold(int from, int to, List<TrackedDetection> frame, {int step = 100, Set<String>? present}) {
    for (var t = from; t <= to; t += step) {
      at(t, frame, present: present);
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
        r.hold(35100, 36100, [_a]); // back after 30 s of absence (last seen at 5000), held 1 s: asked again
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
      r.hold(42200, 43200, [_a]); // back after only 2.1 s away: Plastic still waits
      expect(r.asked, ['Plastic']);
      r.hold(43300, 73200, []); // away 30 s (last seen at 43200)
      r.hold(73300, 74300, [_a]);
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

    test('the same label is blocked until it has been absent 30 s, counted from when it left', () {
      final r = closedAt2000();
      r.hold(2100, 17000, []); // cooldown over; Plastic last seen at 2000
      r.hold(17100, 20000, [_a]); // back after 15 s away: locks at 18100, blocked
      expect(r.asked, ['Plastic']);
      expect(r.m.state, isNot(LiveScanState.asking));
      r.hold(20100, 49900, []); // left at 20000: 29.9 s away
      r.hold(50000, 51000, [_a]); // 30 s after it left: asked
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('a held object only seen as present (not lockable) keeps the cooldown and its label wait', () {
      final r = closedAt2000();
      r.hold(2100, 60000, [], present: {'Plastic'}); // e.g. a 0.60 bottle: present, never empty
      expect(r.m.state, LiveScanState.cooldown);
      r.hold(60100, 62100, []); // empty 2 s: re-armed
      expect(r.m.state, LiveScanState.searching);
      r.hold(62200, 63200, [_a]); // but Plastic left only 2 s ago
      expect(r.asked, ['Plastic']);
      expect(r.m.labelWaits.keys, ['Plastic']);
    });

    test('removed 6 s and back within 30 s of leaving: no quiz; back after 30 s away: quiz', () {
      final r = closedAt2000();
      r.hold(2100, 20000, [_a]); // stays after the close
      r.hold(20100, 26000, []); // removed 6 s (re-arms at 22100: cooldown over, empty 2 s)
      expect(r.m.state, LiveScanState.searching);
      r.hold(26100, 30000, [_a]); // back after 6 s: locks at 27100, blocked
      expect(r.asked, ['Plastic']);
      r.hold(30100, 60000, []); // removed again; last seen at 30000
      r.hold(60100, 61100, [_a]); // back after 30.1 s away: locks at 61100, asked
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('Plastic quiz open, bottle A swapped for bottle B with a 1 s gap: no quiz after close until B is gone 30 s', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]); // bottle A asked
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.hold(1100, 5000, [_a]); // quiz open (minimized: frames still arrive)
      r.hold(5100, 6000, []); // swap gap
      final bottleB = _box('Plastic', x: 300);
      r.hold(6100, 10000, [bottleB]);
      r.m.onQuizClosed(); // closes with B in view
      r.hold(10100, 40000, [bottleB]);
      expect(r.asked, ['Plastic']);
      expect(r.m.state, LiveScanState.cooldown);
      r.hold(40100, 70000, []); // B removed 30 s (last seen at 40000)
      expect(r.m.state, LiveScanState.searching);
      r.hold(70100, 71100, [_a]); // the next Plastic
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('no frames while the quiz covers the camera: that time is not counted as absence', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]); // asked at 1000
      r.m.onAskOutcome(AskOutcome.questionReady);
      r._now = 21000; // 20 s quiz, stream paused: no frames
      r.m.onQuizClosed();
      r.hold(21100, 40000, []); // object gone after the close
      r.hold(40100, 41100, [_a]); // 19 s after the close, 39 s after the last frame
      expect(r.asked, ['Plastic']);
      r.hold(41200, 71100, []);
      r.hold(71200, 72200, [_a]); // 30 s after it left
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('a quizzed label seen during a later quiz (minimized) has its wait reset by that sighting', () {
      final r = _Rig();
      r.hold(0, 1000, [_b]); // Metal asked
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.at(2000, [_b]);
      r.m.onQuizClosed();
      r.hold(2100, 17000, []); // Metal last seen at 2000
      r.hold(17100, 18100, [_a]); // Plastic asked
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.hold(18200, 40000, [_a, _b]); // Plastic quiz open (minimized): Metal in view too
      r.m.onQuizClosed();
      r.hold(40100, 60000, []); // both gone; Metal left at 40000, not 2000
      r.hold(60100, 61100, [_b]);
      expect(r.asked, ['Metal', 'Plastic']);
    });

        test('labelWaits: full wait while present, counts down once the label leaves', () {
      final r = closedAt2000();
      r.hold(2100, 5000, [_a]);
      expect(r.m.labelWaits['Plastic'], sameLabelWait);
      r.hold(5100, 17000, []); // left at 5000, now 17000
      expect(r.m.labelWaits['Plastic'], const Duration(seconds: 18));
      r.hold(17100, 35000, []);
      expect(r.m.labelWaits, isEmpty);
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

  group('wait freeze during a quiz (the robot recording bug: a quiz over 30 s lost its wait)', () {
    test('(a) a quiz open 45 s with no frames: labelWaits stays at 30 s the whole time, then '
        'no quiz with the box in view, none within 2 s of leaving, one once absent 30 s', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]); // asks at 1000
      r.m.onAskOutcome(AskOutcome.questionReady);

      // 45 s quiz, stream paused: no onFrame calls, only labelWaits reads
      // (what the debug overlay does on every rebuild).
      for (var t = 1100; t <= 46000; t += 1000) {
        r._now = t;
        expect(r.m.labelWaits['Plastic'], sameLabelWait, reason: 'frozen at t=$t');
      }

      r._now = 46000;
      r.m.onQuizClosed(); // closed at 46000, with the box still in view
      r.hold(46100, 70000, [_a]); // stays well past the 15 s cooldown
      expect(r.m.state, LiveScanState.cooldown);
      expect(r.asked, ['Plastic']);

      r.hold(70100, 72000, []); // removed 1.9 s
      r.hold(72100, 90000, [_a]); // back within 2 s: no quiz, cooldown holds
      expect(r.m.state, LiveScanState.cooldown);
      expect(r.asked, ['Plastic']);

      r.hold(90100, 120000, []); // absent 30 s (last seen at 90000)
      r.hold(120100, 121100, [_a]); // back after 30 s away: asked again
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('(b) same as (a), but frames with Plastic keep arriving during the quiz (M2b): same result', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.questionReady);

      for (var t = 1100; t <= 46000; t += 1000) {
        r.at(t, [_a]); // onFrame called with the object still present
        expect(r.m.labelWaits['Plastic'], sameLabelWait, reason: 'frozen at t=$t');
      }

      r._now = 46000;
      r.m.onQuizClosed();
      r.hold(46100, 70000, [_a]);
      expect(r.m.state, LiveScanState.cooldown);
      expect(r.asked, ['Plastic']);

      r.hold(70100, 72000, []);
      r.hold(72100, 90000, [_a]);
      expect(r.m.state, LiveScanState.cooldown);
      expect(r.asked, ['Plastic']);

      r.hold(90100, 120000, []);
      r.hold(120100, 121100, [_a]);
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('(c) reading labelWaits 100 times during an open quiz changes nothing', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.questionReady);

      r._now = 40000; // 39 s into the quiz, no frames
      for (var i = 0; i < 100; i++) {
        r.m.labelWaits;
      }
      expect(r.m.state, LiveScanState.quiz);
      expect(r.m.labelWaits['Plastic'], sameLabelWait);

      r.m.onQuizClosed(); // closed at 40000, box still in view
      r.at(40100, [_a]);
      expect(r.m.state, LiveScanState.cooldown);
      expect(r.asked, ['Plastic']); // not re-asked: the 100 reads didn't expire it
    });

    test('a label back exactly when its wait ends can be asked (checked against the previous frame)', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.at(2000, [_a]);
      r.m.onQuizClosed(); // closed at 2000; Plastic last seen at 2000
      r.hold(2100, 17000, []); // cooldown clears (empty since ~2100)
      expect(r.m.state, LiveScanState.searching);
      // Back exactly 30 s after it was last seen (2000 + 30000 = 32000); a
      // further 1 s hold to lock.
      r.hold(32000, 33000, [_a]);
      expect(r.asked, ['Plastic', 'Plastic']);
    });
  });
}
