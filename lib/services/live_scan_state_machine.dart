/// Live-scan state machine for the robot path (M2a): turns stabilizer locks
/// into at most one quiz start per object. Pure logic; time comes from the
/// injected clock. See docs/decisions/0008-live-scan-state-machine.md and
/// 0020 (re-arm rule).
library;

import 'detection_stabilizer.dart';

enum LiveScanState { searching, locking, asking, quiz, cooldown }

/// How a requested quiz start ended.
enum AskOutcome { questionReady, failed, busy, cancelled }

/// No new ask for this long after a quiz closes.
const quizCooldown = Duration(seconds: 15);

/// A quizzed object blocks itself and its label until it has been absent this
/// long (decision 0020; before, the whole scene had to be empty this long).
const quizzedObjectAbsentToRearm = Duration(seconds: 2);

/// Box overlap that keeps following a quizzed object from frame to frame,
/// whatever its label, so a label flicker on it is still the same object.
// ponytail: box overlap only (no track ids yet, ByteTrack is M6); an object
// moved further than its own width between two analysed frames (~5 fps) is
// lost and can be quizzed again once it has been "absent" for 2 s.
const quizzedObjectIou = 0.3;

/// Why nothing is being asked right now (debug overlay and diagnostics).
class BlockReason {
  const BlockReason(this.code, {this.labels = const {}, this.remaining});

  /// One of: quiz_open, cooldown, same_object, same_label (the controller adds
  /// box_too_large and below_min_score).
  final String code;

  /// Labels in view relevant to the reason, with their best score.
  final Map<String, double> labels;

  /// Time left, for cooldown.
  final Duration? remaining;

  String get key => '$code|${(labels.keys.toList()..sort()).join(',')}';

  String get text {
    String objs() => labels.entries.take(2).map((e) => '${e.key} ${e.value.toStringAsFixed(2)}').join(', ');
    return switch (code) {
      'quiz_open' => 'menunggu: kuis masih terbuka',
      'cooldown' => 'menunggu: jeda setelah kuis ${((remaining?.inMilliseconds ?? 0) / 1000).ceil()} s',
      'same_object' => 'menunggu: benda yang sudah dikuis masih terlihat (${objs()})',
      'same_label' => 'menunggu: label sama, tunggu benda sebelumnya pergi 2 s (${objs()})',
      'box_too_large' => 'menunggu: kotak terlalu besar (${objs()})',
      'below_min_score' => 'menunggu: skor di bawah 0.70 (${objs()})',
      'arm_moving' => 'menunggu: lengan bergerak',
      _ => 'menunggu: $code',
    };
  }
}

class _QuizzedObject {
  _QuizzedObject(this.box);
  TrackedDetection box;
  DateTime? missingSince;

  /// Set when a quiz closes: the camera was paused, so the object is found
  /// again by its label (any position) instead of by overlap.
  bool rebind = false;
}

typedef LiveScanEvent = void Function(String event, Map<String, Object?> data);

class LiveScanStateMachine {
  LiveScanStateMachine(this.stabilizer, {DateTime Function()? clock, this.onEvent})
      : _clock = clock ?? monotonicClock();

  final DetectionStabilizer stabilizer;
  final DateTime Function() _clock;

  /// Diagnostics sink (decision 0020); null in tests that don't check events.
  final LiveScanEvent? onEvent;

  LiveScanState _state = LiveScanState.searching;
  int _askCount = 0;
  int _busyCount = 0;
  bool _lastAskFailed = false;
  DateTime? _closedAt;
  final _quizzed = <_QuizzedObject>[];
  _QuizzedObject? _asked;
  _QuizzedObject? _failed;
  BlockReason? _blockReason;
  String? _loggedBlockKey;
  final _logged = <String, String>{};

  LiveScanState get state => _state;

  /// Quiz starts requested so far (the "identify calls" of the plan). An ask
  /// that came back BUSY never reached Gemma and is counted in [busyCount].
  int get askCount => _askCount;

  /// Asks refused because a quiz was already open.
  int get busyCount => _busyCount;

  /// The last ask failed (not a user close) and ended without a quiz. Stays set while that object is still
  /// locked in the stabilizer (it is blocked until absent for re-arm time).
  bool get lastAskFailed => _lastAskFailed;

  /// Why nothing is asked right now, or null when nothing blocks.
  BlockReason? get blockReason => _frozen ? const BlockReason('quiz_open') : _blockReason;

  /// Labels of the quizzed objects still in view (blocking themselves and their label).
  List<String> get quizzedLabels => [for (final q in _quizzed) q.box.label];

  bool get _frozen => _state == LiveScanState.asking || _state == LiveScanState.quiz;

  /// "Scan lagi" may be used: no quiz is open.
  bool get canManualRearm => !_frozen;

  /// Feeds one analysed frame. [detections] are the lockable boxes;
  /// [presentBoxes] every box that counts as "in the scene" (a looser test,
  /// see LiveScanController), used to follow quizzed objects; it defaults to
  /// [detections]. Returns the lock to start a quiz for (the caller must
  /// report the result with [onAskOutcome]), or null.
  ///
  /// Locks during ASKING and QUIZ are dropped, not queued. COOLDOWN asks
  /// nothing for [quizCooldown]; then the machine re-arms whatever is in view.
  /// After that, a quizzed object still in view, and any object with its
  /// label, are hidden from the stabilizer until that quizzed object has been
  /// absent for [quizzedObjectAbsentToRearm]; other objects lock normally.
  StabilizerLock? onFrame(List<TrackedDetection> detections, {List<TrackedDetection>? presentBoxes}) {
    final now = _clock();
    final scene = [
      for (final d in presentBoxes ?? detections)
        if (!stabilizer.ignoredLabels.contains(d.label.trim())) d,
    ];

    if (_frozen) {
      stabilizer.update(detections);
      _setBlock(const BlockReason('quiz_open'));
      return null;
    }

    _follow(scene, now);
    final blocked = <TrackedDetection, String>{};
    final eligible = <TrackedDetection>[];
    for (final d in detections) {
      final why = _blockedBy(d);
      if (why == null) {
        eligible.add(d);
      } else {
        blocked[d] = why;
      }
    }
    final lock = stabilizer.update(eligible);

    if (_state == LiveScanState.cooldown) {
      final left = quizCooldown - now.difference(_closedAt!);
      if (left > Duration.zero) {
        _setBlock(BlockReason('cooldown', labels: _best(scene), remaining: left));
        return null;
      }
      _rearm('cooldown_elapsed', now);
      return null; // the stabilizer starts fresh on the next frame
    }

    if (lock != null) {
      final q = _QuizzedObject(lock.detection);
      _quizzed.add(q);
      _asked = q;
      _state = LiveScanState.asking;
      _askCount++;
      _lastAskFailed = false;
      _setBlock(null);
      return lock;
    }
    if (!stabilizer.isLocked && !_quizzed.contains(_failed)) _lastAskFailed = false;
    _state = stabilizer.hasCandidate ? LiveScanState.locking : LiveScanState.searching;

    if (blocked.isNotEmpty && !stabilizer.hasCandidate) {
      final sameObject = [for (final e in blocked.entries) if (e.value == 'same_object') e.key];
      final reason = sameObject.isNotEmpty ? 'same_object' : 'same_label';
      final boxes = sameObject.isNotEmpty ? sameObject : blocked.keys.toList();
      _setBlock(BlockReason(reason, labels: _best(boxes)));
      final best = _best(boxes);
      _logOnce('lock_dropped_same_label', '$reason|${(best.keys.toList()..sort()).join(',')}',
          {'reason': reason, 'labels': best, 'quizzed': quizzedLabels});
    } else {
      _logged.remove('lock_dropped_same_label');
      _setBlock(null);
    }
    return null;
  }

  /// The quiz started for the last lock (questionReady), or didn't. Without a
  /// quiz the machine searches again; that object stays blocked (as a quizzed
  /// object, and locked in the stabilizer) until it has been absent, so a
  /// failing ask isn't retried in a loop.
  void onAskOutcome(AskOutcome outcome) {
    if (_state != LiveScanState.asking) return;
    if (outcome == AskOutcome.questionReady) {
      _state = LiveScanState.quiz;
      return;
    }
    if (outcome == AskOutcome.busy) {
      _askCount--;
      _busyCount++;
      _quizzed.remove(_asked); // no quiz ran for it
    }
    _failed = _asked;
    _asked = null;
    _lastAskFailed = outcome != AskOutcome.cancelled; // a user close is not a failure
    _state = stabilizer.hasCandidate ? LiveScanState.locking : LiveScanState.searching;
  }

  /// Some quiz is open (also one this machine didn't start, or a minimized
  /// one): show QUIZ and ask nothing until it closes. ASKING keeps waiting for
  /// its own question through [onAskOutcome].
  void onQuizOpen() {
    if (_frozen) return;
    _state = LiveScanState.quiz;
    _asked = null;
  }

  void onQuizClosed() {
    if (_state != LiveScanState.quiz) return;
    _state = LiveScanState.cooldown;
    _closedAt = _clock();
    _asked = null;
    // The camera pauses while the quiz covers it: an object may have moved, so
    // each quizzed object is found again by its label, and absence restarts.
    for (final q in _quizzed) {
      q
        ..rebind = true
        ..missingSince = null;
    }
    onEvent?.call('cooldown_enter', {'cooldownMs': quizCooldown.inMilliseconds, 'quizzed': quizzedLabels});
  }

  /// "Scan lagi" (debug): ends the cooldown and forgets every quizzed object.
  /// Does nothing while a quiz is open. Returns whether it re-armed.
  bool manualRearm() {
    if (_frozen) return false;
    final now = _clock();
    onEvent?.call('manual_rearm', {
      'state': _state.name,
      'quizzed': quizzedLabels,
      if (_closedAt != null) 'sinceCloseMs': now.difference(_closedAt!).inMilliseconds,
    });
    _quizzed.clear();
    _rearm('manual', now);
    return true;
  }

  /// The J1 guard ended (decision 0020, "J1 guard"): no frames were analysed
  /// while the arm moved the camera, so each quizzed object is found again by
  /// its label (any position) and its absence restarts, like after a quiz.
  /// Nothing is forgotten.
  void onArmSettled() {
    for (final q in _quizzed) {
      q
        ..rebind = true
        ..missingSince = null;
    }
    onEvent?.call('arm_settled', {'quizzed': quizzedLabels});
  }

  /// The link to the robot came back after a drop (decision 0020, "Link
  /// drop"): no frames arrived, so no absence could be timed, and the robot
  /// may have been driven. Forgets the quizzed objects of closed quizzes and
  /// the stabilizer's lock; an open quiz and a running cooldown are kept.
  void onLinkRestored() {
    final forgotten = [for (final q in _quizzed) if (q != _asked) q.box.label];
    _quizzed.removeWhere((q) => q != _asked);
    if (!_frozen) stabilizer.reset();
    onEvent?.call('link_restored', {'state': _state.name, 'forgotten': forgotten});
  }

  void _rearm(String reason, DateTime now) {
    _state = LiveScanState.searching;
    final closed = _closedAt;
    _closedAt = null;
    stabilizer.reset(); // a lock discarded during the quiz or cooldown must not block anything
    _setBlock(null);
    onEvent?.call('rearm', {
      'reason': reason,
      if (closed != null) 'sinceCloseMs': now.difference(closed).inMilliseconds,
      'quizzed': quizzedLabels,
    });
  }

  /// Follows each quizzed object in [scene]: by overlap (any label), or right
  /// after a quiz by its label. Forgets it once absent for the re-arm time.
  void _follow(List<TrackedDetection> scene, DateTime now) {
    for (final q in _quizzed.toList()) {
      TrackedDetection? match;
      if (q.rebind) {
        final same = scene.where((d) => d.label == q.box.label).toList()
          ..sort((a, b) {
            final byOverlap = intersectionOverUnion(b, q.box).compareTo(intersectionOverUnion(a, q.box));
            return byOverlap != 0 ? byOverlap : b.score.compareTo(a.score);
          });
        match = same.firstOrNull;
      } else {
        var best = 0.0;
        for (final d in scene) {
          final iou = intersectionOverUnion(d, q.box);
          if (iou >= quizzedObjectIou && iou > best) {
            best = iou;
            match = d;
          }
        }
      }
      final missing = q.missingSince;
      if (match != null && missing != null && now.difference(missing) >= quizzedObjectAbsentToRearm) {
        match = null; // gone long enough, with no frames in between: back as a new object
        q.missingSince = now.subtract(quizzedObjectAbsentToRearm);
      }
      if (match != null) {
        q
          ..box = match
          ..rebind = false
          ..missingSince = null;
      } else if (now.difference(q.missingSince ??= now) >= quizzedObjectAbsentToRearm) {
        _quizzed.remove(q);
        onEvent?.call('quizzed_object_gone', {'label': q.box.label});
      }
    }
  }

  /// Why [d] may not lock: it is a quizzed object still in view, or has the
  /// label of one. Null when it may lock.
  String? _blockedBy(TrackedDetection d) {
    for (final q in _quizzed) {
      if (!q.rebind && intersectionOverUnion(d, q.box) >= quizzedObjectIou) return 'same_object';
    }
    for (final q in _quizzed) {
      if (d.label == q.box.label) return 'same_label';
    }
    return null;
  }

  void _setBlock(BlockReason? reason) {
    _blockReason = reason;
    if (reason == null || reason.code == 'quiz_open') {
      _loggedBlockKey = null;
      return;
    }
    if (reason.key == _loggedBlockKey) return;
    _loggedBlockKey = reason.key;
    onEvent?.call('rearm_blocked', {
      'reason': reason.code,
      'labels': reason.labels,
      if (reason.remaining != null) 'remainingMs': reason.remaining!.inMilliseconds,
    });
  }

  /// Logs [event] when its [key] changed since the last time (rate limit).
  void _logOnce(String event, String key, Map<String, Object?> data) {
    if (_logged[event] == key) return;
    _logged[event] = key;
    onEvent?.call(event, data);
  }

  static Map<String, double> _best(Iterable<TrackedDetection> boxes) {
    final best = <String, double>{};
    for (final d in boxes) {
      if ((best[d.label] ?? -1) < d.score) best[d.label] = _round(d.score);
    }
    return Map.fromEntries(best.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  static double _round(double v) => (v * 100).round() / 100;
}
