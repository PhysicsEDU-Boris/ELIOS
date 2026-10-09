import 'package:elio/services/detection_stabilizer.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime(2026, 1, 1);

TrackedDetection _box(String label, {double x = 50, double y = 50, double w = 100, double h = 100, double score = 0.9, int? id}) =>
    TrackedDetection(label: label, x: x, y: y, w: w, h: h, score: score, trackId: id);

final _plastic = _box('Plastic');

/// Drives a stabilizer with a fake clock, in milliseconds from [_t0].
class _Rig {
  _Rig({Set<String> ignoredLabels = const {}}) {
    s = DetectionStabilizer(ignoredLabels: ignoredLabels, clock: () => _t0.add(Duration(milliseconds: _now)));
  }

  int _now = 0;
  late final DetectionStabilizer s;
  final locks = <int>[];
  final lockedLabels = <String>[];
  final lockedTrackIds = <int?>[];

  StabilizerLock? at(int ms, List<TrackedDetection> frame) {
    _now = ms;
    final lock = s.update(frame);
    if (lock != null) {
      locks.add(lock.at.difference(_t0).inMilliseconds);
      lockedLabels.add(lock.detection.label);
      lockedTrackIds.add(lock.detection.trackId);
    }
    return lock;
  }

  /// The same frame every [step] ms from [from] to [to], inclusive.
  void hold(int from, int to, List<TrackedDetection> frame, {int step = 100}) {
    for (var t = from; t <= to; t += step) {
      at(t, frame);
    }
  }
}

void main() {
  group('lock time', () {
    test('locks at exactly the lock time and not before', () {
      final r = _Rig();
      expect(r.at(0, [_plastic]), isNull);
      expect(r.at(500, [_plastic]), isNull);
      expect(r.at(999, [_plastic]), isNull);
      final lock = r.at(1000, [_plastic]);
      expect(lock, isNotNull);
      expect(lock!.detection.label, 'Plastic');
      expect(r.locks, [1000]);
    });
  });

  group('dropout', () {
    // Absence is timed from the first frame that arrives without the object.
    test('a 599 ms dropout keeps the timer', () {
      final r = _Rig();
      r.hold(0, 400, [_plastic]);
      r.hold(500, 1000, []); // missing from 500
      expect(r.at(1099, [_plastic]), isNotNull); // back after 599 ms: the timer kept running
      expect(r.locks, [1099]);
    });

    test('a 601 ms dropout resets the timer', () {
      final r = _Rig();
      r.hold(0, 400, [_plastic]);
      r.hold(500, 1000, []);
      r.at(1101, [_plastic]); // back after 601 ms: new candidate from here
      r.at(2100, [_plastic]);
      expect(r.locks, isEmpty);
      expect(r.at(2101, [_plastic]), isNotNull);
      expect(r.locks, [2101]);
    });

    // A frame is "missed" when it arrives without the object.
    test('2 fps: one missed frame keeps the timer', () {
      final r = _Rig();
      r.at(0, [_plastic]);
      r.at(500, []);
      expect(r.at(1000, [_plastic]), isNotNull);
    });

    test('2 fps: two missed frames reset the timer', () {
      final r = _Rig();
      r.at(0, [_plastic]);
      r.at(500, []);
      r.at(1000, []);
      r.hold(1500, 2500, [_plastic], step: 500); // new candidate from 1500
      expect(r.locks, [2500]);
    });

    test('4 fps: one missed frame keeps the timer', () {
      final r = _Rig();
      r.hold(0, 250, [_plastic], step: 250);
      r.at(500, []);
      r.hold(750, 1000, [_plastic], step: 250);
      expect(r.locks, [1000]);
    });

    test('4 fps: two missed frames (500 ms) still keep the timer; three (750 ms) reset it', () {
      // With a time tolerance this can't be otherwise: two misses at 4 fps last
      // as long as one miss at 2 fps (500 ms). See decision 0007.
      final two = _Rig();
      two.hold(0, 250, [_plastic], step: 250);
      two.hold(500, 750, [], step: 250);
      two.at(1000, [_plastic]);
      expect(two.locks, [1000]);

      final three = _Rig();
      three.hold(0, 250, [_plastic], step: 250);
      three.hold(500, 1000, [], step: 250);
      three.hold(1250, 2250, [_plastic], step: 250); // new candidate from 1250
      expect(three.locks, [2250]);
    });

    test('a 2 fps stream (frames 500 ms apart, none missing) still locks', () {
      final r = _Rig();
      r.at(0, [_plastic]);
      r.at(500, [_plastic]);
      expect(r.at(1000, [_plastic]), isNotNull);
    });

    test('time with no frames at all is not absence: a locked object stays locked', () {
      final r = _Rig();
      r.hold(0, 1000, [_plastic]); // locks at 1000
      r.hold(6000, 9000, [_plastic]); // e.g. analysis paused while the quiz was open
      expect(r.locks, [1000]);
    });
  });

  group('read-only state (hasCandidate, isLocked)', () {
    test('follow a candidate, its lock, and the re-arm', () {
      final r = _Rig();
      expect((r.s.hasCandidate, r.s.isLocked), (false, false));
      r.at(0, [_plastic]);
      expect((r.s.hasCandidate, r.s.isLocked), (true, false));
      r.hold(100, 1000, [_plastic]); // locks at 1000
      expect((r.s.hasCandidate, r.s.isLocked), (false, true));
      r.hold(1100, 2400, []); // missing from 1100
      expect(r.s.isLocked, isTrue);
      r.at(2600, []); // missing 1500 ms: re-armed
      expect((r.s.hasCandidate, r.s.isLocked), (false, false));
    });

    test('a candidate that drops out clears hasCandidate', () {
      final r = _Rig();
      r.at(0, [_plastic]);
      r.hold(100, 700, []); // missing from 100: dropped once over 600 ms
      expect(r.s.hasCandidate, isTrue);
      r.at(701, []);
      expect(r.s.hasCandidate, isFalse);
    });
  });

  group('pauses (maxFrameGap)', () {
    test('a 20 s pause after 0.5 s of candidate time does not lock on the next frame', () {
      final r = _Rig();
      r.hold(0, 500, [_plastic]);
      expect(r.at(20500, [_plastic]), isNull); // timer dropped: new candidate from here
      r.hold(20600, 21400, [_plastic]);
      expect(r.locks, isEmpty);
      r.at(21500, [_plastic]);
      expect(r.locks, [21500]);
    });

    test('a frame gap of exactly 1.5 s keeps the candidate; 1501 ms drops it', () {
      final keep = _Rig();
      keep.hold(0, 500, [_plastic]);
      expect(keep.at(2000, [_plastic]), isNotNull);

      final drop = _Rig();
      drop.hold(0, 500, [_plastic]);
      expect(drop.at(2001, [_plastic]), isNull);
    });

    test('a locked object stays locked across a 20 s pause', () {
      final r = _Rig();
      r.hold(0, 1000, [_plastic]); // locks at 1000
      r.hold(21000, 30000, [_plastic]);
      expect(r.locks, [1000]);
    });

    test('a locked object missing just before a pause is not re-armed by the pause', () {
      final r = _Rig();
      r.hold(0, 1000, [_plastic]); // locks at 1000
      r.at(1100, []); // missing from 1100
      r.hold(21100, 30000, [_plastic]); // 20 s with no frames is not absence
      expect(r.locks, [1000]);
    });
  });

  group('overlap and label', () {
    // Two 100x100 boxes shifted by dx along x have IoU (100 - dx) / (100 + dx).
    final justAbove = _box('Plastic', x: 71); // dx 21: IoU 0.6529
    final justBelow = _box('Plastic', x: 72); // dx 22: IoU 0.6393

    test('IoU just above the threshold continues the same object', () {
      expect(intersectionOverUnion(_plastic, justAbove), inInclusiveRange(0.65, 0.66));
      final r = _Rig();
      r.at(0, [_plastic]);
      r.at(500, [justAbove]);
      expect(r.at(1000, [justAbove]), isNotNull);
      expect(r.locks, [1000]);
    });

    test('IoU just below the threshold is another object: the old timer does not carry over', () {
      expect(intersectionOverUnion(_plastic, justBelow), lessThan(0.65));
      final r = _Rig();
      r.at(0, [_plastic]);
      r.hold(500, 1000, [justBelow]);
      expect(r.locks, isEmpty); // the same object would have locked at 1000
      r.hold(1100, 4000, [justBelow]); // after the old candidate's grace, it locks
      expect(r.locks, hasLength(1));
      expect(r.locks.single, greaterThan(1500));
    });

    test('a label change on the same box starts a new candidate', () {
      final r = _Rig();
      r.at(0, [_plastic]);
      r.at(500, [_box('Metal')]);
      expect(r.at(1000, [_box('Metal')]), isNull);
      expect(r.at(1500, [_box('Metal')]), isNotNull);
      expect(r.lockedLabels, ['Metal']);
    });
  });

  group('one lock per object', () {
    test('an object held for 60 s locks once', () {
      final r = _Rig();
      r.hold(0, 60000, [_plastic]);
      expect(r.locks, [1000]);
    });

    test('missing for 1499 ms: still the same object, no new lock', () {
      final r = _Rig();
      r.hold(0, 1000, [_plastic]); // locks at 1000
      r.hold(1100, 2500, []); // missing from 1100
      r.hold(2599, 6599, [_plastic]); // back after 1499 ms
      expect(r.locks, [1000]);
    });

    test('missing for 1500 ms: re-armed, locks again after the lock time', () {
      final r = _Rig();
      r.hold(0, 1000, [_plastic]);
      r.hold(1100, 2500, []);
      r.hold(2600, 3500, [_plastic]); // back after 1500 ms: new candidate from 2600
      expect(r.locks, [1000]);
      r.at(3600, [_plastic]);
      expect(r.locks, [1000, 3600]);
    });

    test('a one-frame label flicker (Plastic, Paper, Plastic) locks once', () {
      final r = _Rig();
      r.hold(0, 1000, [_plastic]); // locks at 1000
      r.at(1100, [_box('Paper')]);
      r.hold(1200, 2200, [_plastic]);
      r.at(2300, [_box('Paper')]); // a second flicker must not finish an old Paper timer
      r.hold(2400, 6000, [_plastic]);
      expect(r.locks, [1000]);
      expect(r.lockedLabels, ['Plastic']);
    });

    test('a label that really changes and holds for the lock time locks once more', () {
      final r = _Rig();
      r.hold(0, 1000, [_plastic]);
      r.hold(1100, 5000, [_box('Metal')]);
      expect(r.locks, [1000, 2100]);
      expect(r.lockedLabels, ['Plastic', 'Metal']);
    });
  });

  group('identity', () {
    test('track_id: the same id is one object even when the box jumps', () {
      final r = _Rig();
      r.at(0, [_box('Plastic', id: 7)]);
      r.at(500, [_box('Plastic', x: 400, id: 7)]);
      expect(r.at(1000, [_box('Plastic', x: 400, id: 7)]), isNotNull);
      expect(r.locks, [1000]);
    });

    test('track_id: a new id over the same box is a new object', () {
      final r = _Rig();
      r.at(0, [_box('Plastic', id: 7)]);
      r.hold(500, 1000, [_box('Plastic', id: 8)]);
      expect(r.locks, isEmpty); // id 7 would have locked at 1000
      r.hold(1100, 4000, [_box('Plastic', id: 8)]);
      expect(r.lockedTrackIds, [8]);
    });

    test('no track_id (old firmware): overlap decides, also when only one side has an id', () {
      final r = _Rig();
      r.at(0, [_box('Plastic')]);
      r.at(500, [_box('Plastic', id: 7)]);
      expect(r.at(1000, [_box('Plastic')]), isNotNull);
      expect(r.locks, [1000]);
    });
  });

  group('timestamps', () {
    test('a frame timed earlier than the previous one is ignored', () {
      final r = _Rig();
      r.at(0, [_plastic]);
      r.at(500, [_plastic]);
      expect(r.at(300, [_box('Metal', x: 400)]), isNull); // would start a new candidate if used
      expect(r.at(1000, [_plastic]), isNotNull);
      expect(r.lockedLabels, ['Plastic']);
    });

    test('equal timestamps neither advance the timer nor lock twice', () {
      final r = _Rig();
      for (var i = 0; i < 5; i++) {
        r.at(0, [_plastic]);
      }
      expect(r.at(999, [_plastic]), isNull);
      r.at(1000, [_plastic]);
      r.at(1000, [_plastic]);
      expect(r.locks, [1000]);
    });
  });

  group('empty frames', () {
    test('only empty frames never lock', () {
      final r = _Rig();
      r.hold(0, 5000, []);
      expect(r.locks, isEmpty);
    });

    test('boxes with an empty label are ignored', () {
      final r = _Rig();
      r.hold(0, 5000, [_box('  ')]);
      expect(r.locks, isEmpty);
    });
  });

  group('several boxes per frame', () {
    final a = _box('Plastic', score: 0.9);
    final b = _box('Metal', x: 400, score: 0.6);

    test('tracks the most confident box', () {
      final r = _Rig();
      r.hold(0, 1000, [a, b]);
      expect(r.lockedLabels, ['Plastic']);
    });

    test('keeps following the candidate when the scores flip', () {
      final r = _Rig();
      r.at(0, [a, b]);
      r.at(500, [_box('Plastic', score: 0.5), _box('Metal', x: 400, score: 0.95)]);
      r.at(1000, [_box('Plastic', score: 0.5), _box('Metal', x: 400, score: 0.95)]);
      expect(r.lockedLabels, ['Plastic']);
    });

    test('equal scores: the larger box wins', () {
      final r = _Rig();
      r.hold(0, 1000, [_box('Plastic', score: 0.8), _box('Metal', x: 400, w: 200, h: 200, score: 0.8)]);
      expect(r.lockedLabels, ['Metal']);
    });

    test('the candidate missing for one frame while another object is visible keeps its grace', () {
      final r = _Rig();
      r.hold(0, 400, [a]);
      r.at(500, [_box('Metal', x: 400, score: 0.99)]); // a missed, b visible and more confident
      r.hold(600, 1000, [a]);
      expect(r.locks, [1000]);
      expect(r.lockedLabels, ['Plastic']);
    });

    test('a second object waits while the locked one is in view, then locks', () {
      final r = _Rig();
      r.hold(0, 5000, [a, b]);
      expect(r.locks, [1000]);
      r.hold(5100, 6100, [b]);
      expect(r.locks, [1000, 6100]);
      expect(r.lockedLabels, ['Plastic', 'Metal']);
    });
  });

  group('ignoredLabels', () {
    final hand = _box('Human_Hand', x: 200, y: 200, w: 300, h: 300, score: 0.95);
    final plastic = _box('Plastic', x: 600, w: 80, h: 80, score: 0.7);

    test('a large ignored box never wins: the smaller Plastic box locks', () {
      final r = _Rig(ignoredLabels: {'Human_Hand'});
      r.hold(0, 1000, [hand, plastic]);
      expect(r.lockedLabels, ['Plastic']);

      final unfiltered = _Rig();
      unfiltered.hold(0, 1000, [hand, plastic]);
      expect(unfiltered.lockedLabels, ['Human_Hand'], reason: 'without the filter the hand would win');
    });

    test('a frame with only the ignored label counts as empty for the dropout', () {
      final r = _Rig(ignoredLabels: {'Human_Hand'});
      r.hold(0, 400, [plastic]);
      r.hold(500, 1000, [hand]); // Plastic missing from 500
      r.at(1101, [plastic]); // 601 ms: timer resets
      r.at(2100, [plastic]);
      expect(r.locks, isEmpty);
      r.at(2101, [plastic]);
      expect(r.locks, [2101]);
    });

    test('a frame with only the ignored label counts as empty for the re-arm', () {
      final r = _Rig(ignoredLabels: {'Human_Hand'});
      r.hold(0, 1000, [plastic]); // locks at 1000
      r.hold(1100, 2500, [hand]); // Plastic missing from 1100
      r.hold(2600, 3600, [plastic]); // back after 1500 ms: re-armed
      expect(r.locks, [1000, 3600]);
    });
  });
}
