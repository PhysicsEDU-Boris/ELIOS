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

/// After a quiz closes, the scene must also show no lockable detection for
/// this long (still true when [quizCooldown] has passed) before re-arming.
const emptySceneToRearm = Duration(seconds: 2);

/// A label isn't asked again within this time of its last ask or quiz close.
const sameLabelWait = Duration(seconds: 30);

class LiveScanStateMachine {
  LiveScanStateMachine(this.stabilizer, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DetectionStabilizer stabilizer;
  final DateTime Function() _clock;

  LiveScanState _state = LiveScanState.searching;
  int _askCount = 0;
  int _busyCount = 0;
  bool _lastAskFailed = false;
  String? _askedLabel;
  DateTime? _closedAt;
  DateTime? _emptySince;
  final _labelAskedAt = <String, DateTime>{};

  LiveScanState get state => _state;

  /// Quiz starts requested so far (the "identify calls" of the plan). An ask
  /// that came back BUSY never reached Gemma and is counted in [busyCount].
  int get askCount => _askCount;

  /// Asks refused because a quiz was already open.
  int get busyCount => _busyCount;

  /// The last ask ended without a quiz. Stays set while that object is still
  /// locked in the stabilizer (it is blocked until absent for re-arm time).
  bool get lastAskFailed => _lastAskFailed;

  /// Feeds one analysed frame. Returns the lock to start a quiz for (the
  /// caller must report the result with [onAskOutcome]), or null.
  ///
  /// Locks during ASKING and QUIZ are dropped, not queued. COOLDOWN asks
  /// nothing: it ends once [quizCooldown] has passed and the scene has had
  /// no lockable detection for [emptySceneToRearm]. A lock for a label asked
  /// within [sameLabelWait] is dropped.
  StabilizerLock? onFrame(List<TrackedDetection> detections) {
    final lock = stabilizer.update(detections);
    final now = _clock();
    if (_state == LiveScanState.asking || _state == LiveScanState.quiz) return null;

    if (_state == LiveScanState.cooldown) {
      final lockable = detections.any((d) => !stabilizer.ignoredLabels.contains(d.label.trim()));
      _emptySince = lockable ? null : (_emptySince ?? now);
      final empty = _emptySince;
      if (now.difference(_closedAt!) < quizCooldown || empty == null || now.difference(empty) < emptySceneToRearm) {
        return null;
      }
      _state = LiveScanState.searching; // re-armed on an empty scene, so nothing is locked here
    }

    if (lock != null) {
      final label = lock.detection.label;
      final askedAt = _labelAskedAt[label];
      if (askedAt == null || now.difference(askedAt) >= sameLabelWait) {
        _state = LiveScanState.asking;
        _askCount++;
        _lastAskFailed = false;
        _askedLabel = label;
        _labelAskedAt[label] = now;
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
      _labelAskedAt.remove(_askedLabel); // no quiz ran for it
    }
    _lastAskFailed = true;
    _state = stabilizer.hasCandidate ? LiveScanState.locking : LiveScanState.searching;
  }

  /// Some quiz is open (also one this machine didn't start, or a minimized
  /// one): show QUIZ and ask nothing until it closes. ASKING keeps waiting for
  /// its own question through [onAskOutcome].
  void onQuizOpen() {
    if (_state == LiveScanState.asking || _state == LiveScanState.quiz) return;
    _state = LiveScanState.quiz;
    _askedLabel = null;
  }

  void onQuizClosed() {
    if (_state != LiveScanState.quiz) return;
    final now = _clock();
    _state = LiveScanState.cooldown;
    _closedAt = now;
    _emptySince = null;
    final label = _askedLabel;
    if (label != null) _labelAskedAt[label] = now;
    _askedLabel = null;
  }
}
