import 'package:elio/services/detection_stabilizer.dart';
import 'package:elio/services/live_scan_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 1, 1);

TrackedDetection _box(String label, {double x = 50}) =>
    TrackedDetection(label: label, x: x, y: 50, w: 100, h: 100, score: 0.9);

final _plastic = _box('Plastic');
final _can = _box('Metal', x: 400);

class _RescanRig {
  _RescanRig() {
    DateTime clock() => _t0.add(Duration(milliseconds: _now));
    void log(String event, Map<String, Object?> data) => events.add((event, data));
    m = LiveScanStateMachine(
      DetectionStabilizer(ignoredLabels: {'Human_Hand'}, clock: clock, onEvent: log),
      clock: clock,
      onEvent: log,
    );
  }

  final events = <(String, Map<String, Object?>)>[];
  List<Map<String, Object?>> logged(String event) => [for (final (e, d) in events) if (e == event) d];

  int _now = 0;
  late final LiveScanStateMachine m;

  StabilizerLock? at(int ms, List<TrackedDetection> frame, {List<TrackedDetection>? present}) {
    _now = ms;
    return m.onFrame(frame, presentBoxes: present);
  }

  void hold(int from, int to, List<TrackedDetection> frame, {int step = 100, List<TrackedDetection>? present}) {
    for (var t = from; t <= to; t += step) {
      at(t, frame, present: present);
    }
  }
}

void main() {
  group('LiveScanStateMachine waitingForRescan and rescan flow', () {
    test('transitions to waitingForRescan on onQuizFinished', () {
      final r = _RescanRig();
      // Lock a plastic item
      r.hold(0, 1000, [_plastic]);
      expect(r.m.state, LiveScanState.asking);
      r.m.onAskOutcome(AskOutcome.questionReady);
      expect(r.m.state, LiveScanState.quiz);

      // Quiz finishes
      r.m.onQuizFinished();
      expect(r.m.state, LiveScanState.waitingForRescan);
      expect(r.m.blockReason, isNotNull);
      expect(r.m.blockReason!.code, 'waiting_for_rescan');
    });

    test('no lock before Scan lagi even with the item in view', () {
      final r = _RescanRig();
      r.hold(0, 1000, [_plastic]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      expect(r.m.state, LiveScanState.quiz);

      r.m.onQuizFinished();
      expect(r.m.state, LiveScanState.waitingForRescan);

      // Keep feeding the same plastic item for 5 seconds
      for (var t = 1100; t <= 6100; t += 200) {
        final lock = r.at(t, [_plastic]);
        expect(lock, isNull);
        expect(r.m.state, LiveScanState.waitingForRescan);
        expect(r.m.blockReason!.code, 'waiting_for_rescan');
      }
    });

    test('rescan ends waiting state, but same item still blocked until leaving view', () {
      final r = _RescanRig();
      r.hold(0, 1000, [_plastic]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      expect(r.m.state, LiveScanState.quiz);

      r.m.onQuizFinished();
      expect(r.m.state, LiveScanState.waitingForRescan);

      // User taps "Scan lagi"
      r.m.rescan();
      expect(r.m.state, LiveScanState.searching);

      // Plastic is still in view: blocked because it was just quizzed (decision 0020)
      final lock = r.at(1100, [_plastic]);
      expect(lock, isNull);
      expect(r.m.blockReason, isNotNull);
      expect(r.m.blockReason!.code, anyOf('same_object', 'same_label'));
      expect(r.m.state, LiveScanState.searching);
    });

    test('lock after Scan lagi once the item changed', () {
      final r = _RescanRig();
      r.hold(0, 1000, [_plastic]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      expect(r.m.state, LiveScanState.quiz);

      r.m.onQuizFinished();
      expect(r.m.state, LiveScanState.waitingForRescan);

      // User taps "Scan lagi"
      r.m.rescan();
      expect(r.m.state, LiveScanState.searching);

      // Plastic removed, new item (Metal can) appears in view
      r.at(1100, [_can]);
      expect(r.m.state, LiveScanState.locking);
      r.hold(1200, 2100, [_can]);
      expect(r.m.state, LiveScanState.asking);
    });

    test('forgetEverything clears quizzed history and resets to searching', () {
      final r = _RescanRig();
      r.hold(0, 1000, [_plastic]);
      r.m.onAskOutcome(AskOutcome.questionReady);
      expect(r.m.state, LiveScanState.quiz);

      r.m.onQuizFinished();
      expect(r.m.state, LiveScanState.waitingForRescan);

      // Reset debug action forgets everything
      r.m.forgetEverything();
      expect(r.m.state, LiveScanState.searching);

      // The same plastic can immediately lock again
      r.at(1100, [_plastic]);
      expect(r.m.state, LiveScanState.locking);
    });
  });
}
