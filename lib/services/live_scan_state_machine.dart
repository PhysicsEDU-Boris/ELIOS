/// Live-scan state machine for the robot path (M2a): turns stabilizer locks
/// into at most one quiz start per object. Pure logic; time comes from the
/// injected clock. See docs/decisions/0008-live-scan-state-machine.md.
library;

import 'detection_stabilizer.dart';

enum LiveScanState { searching, locking, asking, quiz, cooldown }

/// How a requested quiz start ended.
enum AskOutcome { questionReady, failed, busy, cancelled }

/// No new ask for this long after a quiz closes.
const quizCooldown = Duration(seconds: 15);

/// After a quiz closes, the scene must also be empty (nothing present) for
/// this long (still true when [quizCooldown] has passed) before re-arming.
const emptySceneToRearm = Duration(seconds: 2);

/// A label that had a quiz isn't asked again until it has been absent from
/// the scene for this long. Quiz anti-spam only: label = object (decision 0008).
const sameLabelWait = Duration(seconds: 30);

class LiveScanStateMachine {
  LiveScanStateMachine(this.stabilizer, {DateTime Function()? clock}) : _clock = clock ?? monotonicClock();

  final DetectionStabilizer stabilizer;
  final DateTime Function() _clock;

  LiveScanState _state = LiveScanState.searching;
  int _askCount = 0;
  int _busyCount = 0;
  bool _lastAskFailed = false;
  String? _askedLabel;
  DateTime? _closedAt;
  DateTime? _emptySince;
  DateTime? _quizSince;
  final _lastSeen = <String, DateTime>{};
  final _quizzedLabels = <String>{};

  LiveScanState get state => _state;

  /// Quiz starts requested so far (the "identify calls" of the plan). An ask
  /// that came back BUSY never reached Gemma and is counted in [busyCount].
  int get askCount => _askCount;

  /// Asks refused because a quiz was already open.
  int get busyCount => _busyCount;

  /// The last ask failed (not a user close) and ended without a quiz. Stays set while that object is still
  /// locked in the stabilizer (it is blocked until absent for re-arm time).
  bool get lastAskFailed => _lastAskFailed;

  /// Labels that had a quiz and how long until each may be asked again. A
  /// **pure read**: only [onFrame] ever expires a wait, and never while a
  /// quiz is open, so reading this can't itself lose track of a label —
  /// unlike the version this replaces, where the overlay calling this on
  /// every rebuild could silently drop a label mid-quiz (see decision 0008).
  /// While a quiz is open (ASKING or QUIZ) every waiting label shows the
  /// full [sameLabelWait]: nothing can be asked until it closes anyway, and
  /// presence can't be judged mid-quiz before M2b removes the camera pause.
  Map<String, Duration> get labelWaits {
    if (_state == LiveScanState.asking || _state == LiveScanState.quiz) {
      return {for (final label in _quizzedLabels) label: sameLabelWait};
    }
    final now = _clock();
    return {
      for (final label in _quizzedLabels)
        if (_remaining(label, now) case final left when left > Duration.zero) label: left,
    };
  }

  /// Feeds one analysed frame. [present] are the labels in the scene (a
  /// looser test than lockable, see LiveScanController); it defaults to the
  /// labels of [detections] that the stabilizer doesn't ignore. Returns the
  /// lock to start a quiz for (the caller must report the result with
  /// [onAskOutcome]), or null.
  ///
  /// Locks during ASKING and QUIZ are dropped, not queued. COOLDOWN asks
  /// nothing: it ends once [quizCooldown] has passed and nothing has been
  /// present for [emptySceneToRearm]. A lock for a label still inside its
  /// [sameLabelWait] is dropped.
  StabilizerLock? onFrame(List<TrackedDetection> detections, {Iterable<String>? present}) {
    final now = _clock();
    final seen = present?.toSet() ??
        {for (final d in detections) if (!stabilizer.ignoredLabels.contains(d.label.trim())) d.label.trim()};

    final frozen = _state == LiveScanState.asking || _state == LiveScanState.quiz;
    if (!frozen) {
      // Checked against last frame's _lastSeen, before it's refreshed below:
      // a label back after its wait matured during the absence unblocks on
      // this very frame. The only place a wait expires, and never while a
      // quiz is open, so an open quiz can't lose track of a label it already
      // quizzed, however long it runs (even once M2b lets frames keep
      // arriving during it).
      for (final label in _quizzedLabels.toList()) {
        _expireIfDue(label, now);
      }
    }
    for (final label in seen) {
      _lastSeen[label] = now; // tracked even while a quiz is open (owner's Q3)
    }

    final lock = stabilizer.update(detections);
    if (frozen) return null;

    if (_state == LiveScanState.cooldown) {
      _emptySince = seen.isEmpty ? (_emptySince ?? now) : null;
      final empty = _emptySince;
      if (now.difference(_closedAt!) < quizCooldown || empty == null || now.difference(empty) < emptySceneToRearm) {
        return null;
      }
      _state = LiveScanState.searching; // re-armed on an empty scene, so nothing is locked here
    }

    if (lock != null) {
      final label = lock.detection.label;
      if (!_quizzedLabels.contains(label)) {
        _state = LiveScanState.asking;
        _askCount++;
        _lastAskFailed = false;
        _askedLabel = label;
        _quizzedLabels.add(label);
        _lastSeen[label] = now;
        _quizSince = now;
        return lock;
      }
      // Same label too soon: dropped. The stabilizer keeps it locked until it leaves.
    }
    if (!stabilizer.isLocked) _lastAskFailed = false;
    _state = stabilizer.hasCandidate ? LiveScanState.locking : LiveScanState.searching;
    return null;
  }

  /// The quiz started for the last lock (questionReady), or didn't. Without a
  /// quiz the machine searches again; the stabilizer keeps that object
  /// blocked until it has been absent for its re-arm time, so a failing ask
  /// isn't retried in a loop.
  void onAskOutcome(AskOutcome outcome) {
    if (_state != LiveScanState.asking) return;
    if (outcome == AskOutcome.questionReady) {
      _state = LiveScanState.quiz;
      return;
    }
    if (outcome == AskOutcome.busy) {
      _askCount--;
      _busyCount++;
      _quizzedLabels.remove(_askedLabel); // no quiz ran for it
    }
    _lastAskFailed = outcome != AskOutcome.cancelled; // a user close is not a failure
    _state = stabilizer.hasCandidate ? LiveScanState.locking : LiveScanState.searching;
  }

  /// Some quiz is open (also one this machine didn't start, or a minimized
  /// one): show QUIZ and ask nothing until it closes. ASKING keeps waiting for
  /// its own question through [onAskOutcome].
  void onQuizOpen() {
    if (_state == LiveScanState.asking || _state == LiveScanState.quiz) return;
    _state = LiveScanState.quiz;
    _askedLabel = null;
    _quizSince = _clock();
  }

  void onQuizClosed() {
    if (_state != LiveScanState.quiz) return;
    final now = _clock();
    _state = LiveScanState.cooldown;
    _closedAt = now;
    _emptySince = null;
    // The camera pauses while the quiz covers it, so absence during the quiz
    // can't be measured: a label seen since the quiz started counts as seen now.
    final since = _quizSince;
    if (since != null) {
      for (final MapEntry(:key, :value) in _lastSeen.entries.toList()) {
        if (!value.isBefore(since)) _lastSeen[key] = now;
      }
    }
    _askedLabel = null;
  }

  /// Time left before [label] may be asked again (may be zero or negative),
  /// assuming it's still quizzed. Pure: never mutates.
  Duration _remaining(String label, DateTime now) {
    final seenAt = _lastSeen[label];
    return seenAt == null ? Duration.zero : sameLabelWait - now.difference(seenAt);
  }

  /// Removes [label] from the waiting set once its wait is over. The only
  /// place a wait actually expires.
  void _expireIfDue(String label, DateTime now) {
    if (_remaining(label, now) <= Duration.zero) _quizzedLabels.remove(label);
  }
}
