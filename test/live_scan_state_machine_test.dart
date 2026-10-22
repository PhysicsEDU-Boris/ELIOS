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
    void log(String event, Map<String, Object?> data) => events.add((event, data));
    m = LiveScanStateMachine(DetectionStabilizer(ignoredLabels: {'Human_Hand'}, clock: clock, onEvent: log),
        clock: clock, onEvent: log);
  }

  final events = <(String, Map<String, Object?>)>[];
  List<Map<String, Object?>> logged(String event) => [for (final (e, d) in events) if (e == event) d];

  int _now = 0;
  late final LiveScanStateMachine m;
  final asked = <String>[];

  StabilizerLock? at(int ms, List<TrackedDetection> frame, {List<TrackedDetection>? present}) {
    _now = ms;
    final lock = m.onFrame(frame, presentBoxes: present);
    if (lock != null) asked.add(lock.detection.label);
    return lock;
  }

  void hold(int from, int to, List<TrackedDetection> frame, {int step = 100, List<TrackedDetection>? present}) {
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

    test('ASKING -> QUIZ -> COOLDOWN -> SEARCHING after 15 s, objects in view or not (decision 0020)', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]); // asks at 1000
      r.m.onAskOutcome(AskOutcome.questionReady);
      expect(r.m.state, LiveScanState.quiz);
      r.at(2000, [_a]);
      r.m.onQuizClosed(); // closed at 2000
      expect(r.m.state, LiveScanState.cooldown);
      r.hold(2100, 16900, [_a]); // still in view, 15 s not over yet
      expect(r.m.state, LiveScanState.cooldown);
      r.at(17000, [_a]); // 15 s since the close: re-armed without an empty scene
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
      test('$outcome: back to searching, the object stays blocked until absent 2 s (decision 0020), never stuck', () {
        final asks = outcome == AskOutcome.busy ? 0 : 1; // a busy ask is counted as busy, not identify
        final r = _Rig();
        r.hold(0, 1000, [_a]); // asks
        r.m.onAskOutcome(outcome);
        expect(r.m.state, LiveScanState.searching);
        final failed = outcome != AskOutcome.cancelled; // a user close is not ASK FAILED
        expect(r.m.lastAskFailed, failed);
        r.hold(1100, 5000, [_a]); // same object still there: blocked, not retried in a loop
        expect(r.m.askCount, asks);
        expect(r.m.busyCount, 1 - asks);
        expect(r.m.lastAskFailed, failed);
        r.hold(5100, 7000, []);
        r.at(7100, []); // absent 2 s: forgotten
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

  group('cooldown and re-arm (decision 0020: a different object may lock)', () {
    /// Plastic asked at 1000, question shown, quiz closed at 2000.
    _Rig closedAt2000() {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.at(2000, [_a]);
      r.m.onQuizClosed();
      return r;
    }

    final bottle2 = _box('Plastic', x: 400); // a second object with the quizzed label

    test('the same object back after the close is not asked within 15 s', () {
      final r = closedAt2000();
      r.hold(2100, 5000, []); // gone for 2.9 s
      r.hold(5100, 16900, [_a]); // back and held
      expect(r.asked, ['Plastic']);
      expect(r.m.state, LiveScanState.cooldown);
    });

    test('a different label locks after the cooldown while the quizzed object stays in view', () {
      final r = closedAt2000();
      r.hold(2100, 17000, [_a]); // quizzed object held through the cooldown
      r.hold(17100, 18100, [_a, _b]);
      expect(r.asked, ['Plastic', 'Metal']);
      expect(r.m.state, LiveScanState.asking);
    });

    test('a different label already in view during the cooldown is asked right after it', () {
      final r = closedAt2000();
      r.hold(2100, 18100, [_a, _b]); // Metal locks in the stabilizer during the cooldown: discarded, not blocking
      expect(r.asked, ['Plastic', 'Metal']);
    });

    test('a same-label object in view does not lock until the quizzed object has been absent 2 s', () {
      final r = closedAt2000();
      r.hold(2100, 17000, [_a]);
      r.hold(17100, 25000, [_a, bottle2]);
      expect(r.asked, ['Plastic']);
      expect(r.m.blockReason?.code, 'same_object');
      r.hold(25100, 27000, [bottle2]); // the quizzed bottle left at 25100: 1.9 s
      expect(r.asked, ['Plastic']);
      expect(r.m.blockReason?.code, 'same_label');
      expect(r.m.blockReason?.labels, {'Plastic': 0.9});
      r.hold(27100, 28100, [bottle2]); // absent 2 s: the second bottle locks
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('the same object held in view is never asked twice; absent 1.8 s is not enough, 2 s is', () {
      final r = closedAt2000();
      r.hold(2100, 40000, [_a]); // held 38 s
      expect(r.asked, ['Plastic']);
      expect(r.m.state, LiveScanState.searching, reason: 're-armed after 15 s without an empty scene');
      expect(r.m.blockReason?.text, 'menunggu: benda yang sudah dikuis masih terlihat (Plastic 0.90)');
      r.hold(40100, 41900, []);
      r.hold(42000, 44000, [_a]); // back after 1.8 s away
      expect(r.asked, ['Plastic']);
      r.hold(44100, 46100, []); // absent 2 s (from 44100)
      expect(r.m.quizzedLabels, isEmpty);
      r.hold(46200, 47200, [_a]);
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('a label flicker on the quizzed object is still the same object', () {
      final r = closedAt2000();
      final flicker = _box('Metal'); // the quizzed box, read as another label
      for (var t = 2100; t <= 40000; t += 100) {
        r.at(t, [t % 300 == 0 ? flicker : _a]);
      }
      r.hold(40100, 60000, [flicker]);
      expect(r.asked, ['Plastic']);
      expect(r.m.blockReason?.code, 'same_object');
    });

    test('the quizzed object moving slowly is followed, whatever its label', () {
      final r = closedAt2000();
      for (var t = 2100, x = 50.0; t <= 60000; t += 100, x += 5) {
        r.at(t, [_box(t > 30000 ? 'Metal' : 'Plastic', x: x)]); // 5 px per frame, label changes halfway
      }
      expect(r.asked, ['Plastic']);
    });

    test('a hand alone still counts as empty, even over the quizzed object\'s place', () {
      final r = closedAt2000();
      final hand = _box('Human_Hand'); // same box as the quizzed Plastic
      r.hold(2100, 17000, [hand]);
      expect(r.m.state, LiveScanState.searching);
      expect(r.m.quizzedLabels, isEmpty, reason: 'only the hand was in view: the object is gone');
      r.hold(17100, 18100, [_a, hand]);
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('a quizzed object only seen as present (not lockable) keeps itself blocked', () {
      final r = closedAt2000();
      r.hold(2100, 60000, [], present: [_a]); // e.g. a 0.60 bottle: present, never lockable
      expect(r.m.state, LiveScanState.searching);
      expect(r.m.quizzedLabels, ['Plastic']);
      r.hold(60100, 61100, [_a]); // lockable again: still the quizzed object
      expect(r.asked, ['Plastic']);
    });

    test('two quizzed objects in view both stay blocked', () {
      final r = closedAt2000();
      r.hold(2100, 18100, [_a, _b]); // Metal asked after the cooldown
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.at(19000, [_a, _b]);
      r.m.onQuizClosed();
      r.hold(19100, 60000, [_a, _b]);
      expect(r.asked, ['Plastic', 'Metal']);
      expect(r.m.quizzedLabels, unorderedEquals(['Plastic', 'Metal']));
      expect(r.m.blockReason?.labels.keys, unorderedEquals(['Plastic', 'Metal']));
    });

    test('bottle A swapped for bottle B during the quiz: B counts as the quizzed bottle until gone 2 s', () {
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
      r.hold(40100, 42100, []); // B gone 2 s
      r.hold(42200, 43200, [_a]); // the next Plastic
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('no frames while the quiz covers the camera: the object is found again by its label', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]); // asked at 1000
      r.m.onAskOutcome(AskOutcome.questionReady);
      r._now = 21000; // 20 s quiz, stream paused: no frames
      r.m.onQuizClosed();
      r.hold(21100, 40000, [_box('Plastic', x: 300)]); // moved while the camera was covered
      expect(r.asked, ['Plastic']);
      r.hold(40100, 42100, []);
      r.hold(42200, 43200, [_a]);
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

  group('long quiz (the robot recording bug: a quiz over 30 s lost its wait)', () {
    test('(a) a quiz open 45 s with no frames: no quiz with the box in view, none after 1.8 s away, one after 2 s', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]); // asks at 1000
      r.m.onAskOutcome(AskOutcome.questionReady);
      r._now = 46000;
      r.m.onQuizClosed(); // closed at 46000, with the box still in view
      r.hold(46100, 70000, [_a]);
      expect(r.asked, ['Plastic']);
      r.hold(70100, 71900, []);
      r.hold(72000, 90000, [_a]);
      expect(r.asked, ['Plastic']);
      r.hold(90100, 92100, []);
      r.hold(92200, 93200, [_a]);
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('(b) same as (a), but frames with Plastic keep arriving during the quiz (M2b): same result', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      for (var t = 1100; t <= 46000; t += 1000) {
        r.at(t, [_a]);
        expect(r.m.quizzedLabels, ['Plastic'], reason: 'kept at t=$t');
      }
      r.m.onQuizClosed();
      r.hold(46100, 70000, [_a]);
      expect(r.asked, ['Plastic']);
      r.hold(70100, 71900, []);
      r.hold(72000, 90000, [_a]);
      expect(r.asked, ['Plastic']);
      r.hold(90100, 92100, []);
      r.hold(92200, 93200, [_a]);
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('(c) reading blockReason 100 times during an open quiz changes nothing', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      r._now = 40000;
      for (var i = 0; i < 100; i++) {
        r.m.blockReason;
        r.m.quizzedLabels;
      }
      expect(r.m.state, LiveScanState.quiz);
      r.m.onQuizClosed();
      r.at(40100, [_a]);
      expect(r.m.state, LiveScanState.cooldown);
      expect(r.asked, ['Plastic']);
    });

    test('absent exactly 2 s: forgotten (logged once), then asked again', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.at(2000, [_a]);
      r.m.onQuizClosed();
      r.hold(2100, 20000, [_a]);
      r.hold(20100, 22000, []); // 1.9 s
      expect(r.m.quizzedLabels, ['Plastic']);
      r.at(22100, []); // 2.0 s
      expect(r.m.quizzedLabels, isEmpty);
      expect(r.logged('quizzed_object_gone'), [
        {'label': 'Plastic'},
      ]);
      r.hold(22200, 23200, [_a]);
      expect(r.asked, ['Plastic', 'Plastic']);
    });
  });

  group('diagnostics and manual re-arm (decision 0020)', () {
    test('each blocking reason is logged once per change, with its labels and time left', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      r.at(2000, [_a]);
      r.m.onQuizClosed();
      expect(r.logged('cooldown_enter'), [
        {'cooldownMs': 15000, 'quizzed': ['Plastic']},
      ]);
      r.hold(2100, 4900, [_a]);
      r.hold(5000, 5900, [_a, _b]); // Metal comes in: a change
      r.hold(6000, 16900, [_a]);
      r.hold(17000, 20000, [_a]); // re-armed at 17000; Plastic still in view
      final blocked = r.logged('rearm_blocked');
      expect(blocked, [
        {'reason': 'cooldown', 'labels': {'Plastic': 0.9}, 'remainingMs': 14900},
        {'reason': 'cooldown', 'labels': {'Plastic': 0.9, 'Metal': 0.9}, 'remainingMs': 12000},
        {'reason': 'cooldown', 'labels': {'Plastic': 0.9}, 'remainingMs': 11000},
        {'reason': 'same_object', 'labels': {'Plastic': 0.9}},
      ]);
      expect(r.logged('rearm'), [
        {'reason': 'cooldown_elapsed', 'sinceCloseMs': 15000, 'quizzed': ['Plastic']},
      ]);
      expect(r.logged('lock_dropped_same_label'), [
        {'reason': 'same_object', 'labels': {'Plastic': 0.9}, 'quizzed': ['Plastic']},
      ]);
    });

    test('candidate_start and candidate_drop with their reason', () {
      final r = _Rig();
      r.at(0, [_a]);
      r.hold(100, 701, [], step: 601);
      r.at(800, [_a]);
      r.at(900, [_box('Metal')]); // same box, new label
      expect([for (final (e, d) in r.events) if (e.startsWith('candidate_')) [e, d]], [
        ['candidate_start', {'label': 'Plastic', 'score': 0.9}],
        ['candidate_drop', {'label': 'Plastic', 'reason': 'dropout'}],
        ['candidate_start', {'label': 'Plastic', 'score': 0.9}],
        ['candidate_drop', {'label': 'Plastic', 'reason': 'label_change'}],
        ['candidate_start', {'label': 'Metal', 'score': 0.9}],
      ]);
    });

    test('manual re-arm ends the cooldown and forgets the quizzed object; refused while a quiz is open', () {
      final r = _Rig();
      r.hold(0, 1000, [_a]);
      expect(r.m.canManualRearm, isFalse, reason: 'ASKING');
      expect(r.m.manualRearm(), isFalse);
      r.m.onAskOutcome(AskOutcome.questionReady);
      expect(r.m.manualRearm(), isFalse, reason: 'QUIZ');
      expect(r.logged('manual_rearm'), isEmpty);
      r.at(2000, [_a]);
      r.m.onQuizClosed();
      r.hold(2100, 5000, [_a]);
      expect(r.m.canManualRearm, isTrue);
      expect(r.m.manualRearm(), isTrue);
      expect(r.logged('manual_rearm'), [
        {'state': 'cooldown', 'quizzed': ['Plastic'], 'sinceCloseMs': 3000},
      ]);
      expect(r.logged('rearm').single['reason'], 'manual');
      expect(r.m.state, LiveScanState.searching);
      r.hold(5100, 6100, [_a]); // the held object, asked again on request
      expect(r.asked, ['Plastic', 'Plastic']);
    });

    test('block texts for the overlay', () {
      expect(const BlockReason('same_object', labels: {'Plastic': 0.93}).text,
          'menunggu: benda yang sudah dikuis masih terlihat (Plastic 0.93)');
      expect(const BlockReason('cooldown', remaining: Duration(milliseconds: 4100)).text,
          'menunggu: jeda setelah kuis 5 s');
    });
  });

  test('LiveScanStateMachine with no clock: argument still works (uses the monotonic default, decision 0009)', () {
    final m = LiveScanStateMachine(DetectionStabilizer());
    expect(m.state, LiveScanState.searching);
    expect(m.onFrame([_a]), isNull); // first sighting: candidate only, no clock crash
    expect(m.state, LiveScanState.locking);
  });
}
