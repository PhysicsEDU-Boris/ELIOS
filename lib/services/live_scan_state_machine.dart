/// Live-scan state machine for the robot path (M2a): turns stabilizer locks
/// into at most one quiz start per object. Pure logic; time comes from the
/// stabilizer's injected clock. See docs/decisions/0008-live-scan-state-machine.md.
library;

import 'detection_stabilizer.dart';

enum LiveScanState { searching, locking, asking, quiz, cooldown }

/// How a requested quiz start ended.
enum AskOutcome { questionReady, failed, busy, cancelled }

class LiveScanStateMachine {
  LiveScanStateMachine(this.stabilizer);

  final DetectionStabilizer stabilizer;

  LiveScanState _state = LiveScanState.searching;
  int _askCount = 0;
  bool _lastAskFailed = false;

  LiveScanState get state => _state;

  /// Quiz starts requested so far (the "identify calls" of the plan).
  int get askCount => _askCount;

  /// The last ask ended without a quiz. Stays set while that object is still
  /// locked in the stabilizer (it is blocked until absent for re-arm time).
  bool get lastAskFailed => _lastAskFailed;

  /// Feeds one analysed frame. Returns the lock to start a quiz for (the
  /// caller must report the result with [onAskOutcome]), or null.
  ///
  /// Locks during ASKING and QUIZ are dropped, not queued. In COOLDOWN the
  /// machine waits for the stabilizer to re-arm: the quizzed object's lock
  /// ends, or a different object locks (which is then asked).
  StabilizerLock? onFrame(List<TrackedDetection> detections) {
    final lock = stabilizer.update(detections);
    if (_state == LiveScanState.asking || _state == LiveScanState.quiz) return null;
    if (_state == LiveScanState.cooldown && lock == null && stabilizer.isLocked) return null;

    if (lock != null) {
      _state = LiveScanState.asking;
      _askCount++;
      _lastAskFailed = false;
      return lock;
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
    _lastAskFailed = true;
    _state = stabilizer.hasCandidate ? LiveScanState.locking : LiveScanState.searching;
  }

  void onQuizClosed() {
    if (_state == LiveScanState.quiz) _state = LiveScanState.cooldown;
  }
}
