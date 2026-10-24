/// Glue for the robot's live scan (M2a): MaixCAM2 detections -> score filter
/// -> stabilizer + state machine -> one quiz start per object. Only used when
/// the app is built with --dart-define=LIVE_SCAN=true. See
/// docs/decisions/0008-live-scan-state-machine.md.
library;

import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import '../models/scanned_waste.dart';
import '../providers/waste_quiz_provider.dart' show WasteQuizPhase;
import 'detection_stabilizer.dart';
import 'live_scan_state_machine.dart';
import 'robot/r1_constants.dart' show armSettle;
import 'scan_diagnostics.dart';
import 'websocket_service.dart' show Detection;

/// Off by default: without the define the robot path keeps the old
/// first-frame trigger in WasteQuizNotifier.onDetections.
const liveScanEnabled = bool.fromEnvironment('LIVE_SCAN');

class LiveScanController extends ChangeNotifier {
  LiveScanController({
    required this.startQuiz,
    int? Function()? firstTokenMs,
    int Function()? ttsCount,
    int? Function()? nextWaitMs,
    DateTime Function()? clock,
    LiveScanEvent? onEvent,
  })  : _firstTokenMs = firstTokenMs,
        _ttsCount = ttsCount,
        _nextWaitMs = nextWaitMs,
        _clock = clock ?? monotonicClock(),
        _sink = onEvent ?? (kDebugMode ? _runLog.event : null) {
    machine = LiveScanStateMachine(
        DetectionStabilizer(ignoredLabels: ignoredLabels, matchTrackIds: false, clock: _clock, onEvent: _emit),
        clock: _clock,
        onEvent: _emit);
  }

  /// One lock-diagnostics JSONL per app run (debug only, decision 0020).
  static final _runLog = ScanDiagnostics(id: 'livescan-${DateTime.now().millisecondsSinceEpoch}');

  /// Any one event is written at most this often; the rest are counted and
  /// the count rides on the next written line as `suppressed`.
  static const eventInterval = Duration(milliseconds: 500);

  /// Minimum detector score for a box to start a lock.
  static const minScore = 0.70;

  /// Once a label reached [minScore], its boxes keep counting for the lock
  /// down to this score (hysteresis), so a hovering score can finish the lock.
  static const keepLockScore = 0.55;

  /// A box at this score or more counts as "something is in the scene" for
  /// the empty-scene and same-label rules (not for locking).
  static const presenceScore = 0.50;

  /// A box covering more than this fraction of the frame is ignored (the
  /// detector's near-full-frame boxes are rarely one real object).
  static const maxBoxAreaFraction = 0.6;

  /// Detector classes never tracked, spelled exactly as the MaixCAM2
  /// firmware sends them (`LABELS` in elio_maixcam2.py).
  static const ignoredLabels = {'Human_Hand'};

  /// Starts identification for the locked box; false if a quiz is open.
  final bool Function(TrackedDetection detection) startQuiz;
  final int? Function()? _firstTokenMs;
  final int Function()? _ttsCount;
  final int? Function()? _nextWaitMs;
  final DateTime Function() _clock;
  final LiveScanEvent? _sink;
  late final LiveScanStateMachine machine;

  final _eventAt = <String, DateTime>{};
  final _suppressed = <String, int>{};
  String? _tooLargeKey;
  DateTime? _belowMinAt;
  BlockReason? _frameBlock;

  /// Why nothing is being asked right now: the J1 guard, else the machine's
  /// reason, else this frame's (boxes too large, scores under [minScore]).
  BlockReason? get blockReason => _scanPaused
      ? const BlockReason('stopped')
      : _armFrozen
          ? const BlockReason('arm_moving')
          : machine.blockReason ?? _frameBlock;

  /// STOPPED (decision 0026): frames still stream and show, but none is
  /// analysed, so nothing locks, identifies or opens a quiz. An open quiz
  /// stays usable. After "Lanjutkan" the 0020 rules apply as usual.
  bool get scanPaused => _scanPaused;
  bool _scanPaused = false;
  bool _skippedWhilePaused = false;

  void setScanPaused(bool paused) {
    if (paused == _scanPaused) return;
    _scanPaused = paused;
    _emit(paused ? 'scan_paused' : 'scan_resumed', {'state': machine.state.name});
    notifyListeners();
  }

  /// J1 guard (decision 0020): the arm moves the camera until this time.
  DateTime? _armGuardUntil;
  bool _armFrozen = false;

  /// The app sent an arm command expected to move for [motion]: the guard
  /// holds for it plus ARM_SETTLE.
  void onArmCommand(Duration motion) => _extendArmGuard(motion + armSettle);

  void _extendArmGuard(Duration d) {
    final until = _clock().add(d);
    if (_armGuardUntil == null || until.isAfter(_armGuardUntil!)) _armGuardUntil = until;
  }

  /// Logs one event to the live-scan JSONL (the emergency stop, 0026).
  void logEvent(String event, Map<String, Object?> data) => _emit(event, data);

  /// "Scan lagi" is enabled: no quiz is open.
  bool get canManualRearm => machine.canManualRearm;

  /// The robot link reconnected after a drop (decision 0020).
  void onLinkRestored() {
    machine.onLinkRestored();
    notifyListeners();
  }

  /// Debug "Scan lagi": clears the cooldown and the quizzed objects' waits.
  bool manualRearm() {
    final ok = machine.manualRearm();
    notifyListeners();
    return ok;
  }

  void _emit(String event, Map<String, Object?> data) {
    final sink = _sink;
    if (sink == null) return;
    final now = _clock();
    final last = _eventAt[event];
    if (last != null && now.difference(last) < eventInterval) {
      _suppressed[event] = (_suppressed[event] ?? 0) + 1;
      return;
    }
    _eventAt[event] = now;
    final skipped = _suppressed.remove(event);
    sink(event, {...data, 'suppressed': ?skipped});
  }

  final _unknownLogged = <String>{};
  final _keptAt = <String, DateTime>{};
  final _recentFrames = <DateTime>[];

  /// Analysed frames in the last second.
  int get fps => _recentFrames.length;

  /// Utterances started so far (decision 0009), for the debug overlay. 0
  /// when no [ttsCount] source was given.
  int get ttsCount => _ttsCount?.call() ?? 0;

  /// Time the last "Soal berikutnya" tap waited for its question (decision
  /// 0011, M2b part 3), 0 when served straight from the prefetch buffer.
  /// Null when no [nextWaitMs] source was given, or nothing tapped yet.
  int? get nextWaitMs => _nextWaitMs?.call();

  /// First-token time of the last quiz start's question, once it arrived.
  int? get lastFirstTokenMs => _lastFirstTokenMs;
  int? _lastFirstTokenMs;

  /// Time from the lock (ASKING) to the question being shown, for the last
  /// quiz start, once it arrived. Both this and [lastFirstTokenMs] reset to
  /// null the moment a new ask starts, so a fallback question or a failed
  /// generation can't leave the previous quiz's numbers on screen; they stay
  /// null until this ask's question genuinely shows (decision 0009).
  int? get lastAskToQuestionMs => _lastAskToQuestionMs;
  int? _lastAskToQuestionMs;
  DateTime? _askedAt;

  /// [frameSize] is the frame the boxes are in; without it the box-size
  /// filter is skipped.
  ///
  /// [armMoving] is the frame's `arm_moving` (null: the firmware doesn't say).
  /// While the arm moves and for ARM_SETTLE after, the frame is not analysed:
  /// nothing locks or re-arms, and no absence is counted (J1 guard, 0020).
  void onDetections(List<Detection> detections, {Size? frameSize, bool? armMoving}) {
    final now = _clock();
    _recentFrames
      ..add(now)
      ..removeWhere((t) => now.difference(t) >= const Duration(seconds: 1));
    if (_scanPaused) {
      _skippedWhilePaused = true;
      notifyListeners();
      return;
    }
    if (_skippedWhilePaused) {
      _skippedWhilePaused = false;
      machine.onAnalysisResumed('stopped');
    }
    if (armMoving == true) _extendArmGuard(armSettle);
    final guard = _armGuardUntil;
    if (guard != null && now.isBefore(guard)) {
      if (!_armFrozen) _emit('arm_guard', {'untilMs': guard.difference(now).inMilliseconds});
      _armFrozen = true;
      notifyListeners();
      return;
    }
    if (_armFrozen) {
      _armFrozen = false;
      machine.onAnalysisResumed('arm');
    }

    final frameArea = frameSize == null ? double.infinity : frameSize.width * frameSize.height;
    final boxes = <TrackedDetection>[];
    final tooLarge = <String, double>{};
    for (final d in detections) {
      final label = d.label.trim();
      if (label.isEmpty) continue;
      if (d.w * d.h > frameArea * maxBoxAreaFraction) {
        if (!ignoredLabels.contains(label)) tooLarge[label] = (d.w * d.h / frameArea * 100).round() / 100;
        continue;
      }
      boxes.add(TrackedDetection(label: label, x: d.x, y: d.y, w: d.w, h: d.h, score: d.score, trackId: d.trackId));
    }
    final present = [
      for (final d in boxes)
        if (d.score >= presenceScore && !ignoredLabels.contains(d.label)) d,
    ];

    // Hysteresis: a label seen at minScore stays lockable down to keepLockScore,
    // as long as it doesn't drop below that for longer than the stabilizer's dropout.
    final kept = {
      for (final d in boxes)
        if (d.score >= minScore ||
            (d.score >= keepLockScore &&
                _keptAt[d.label] != null &&
                now.difference(_keptAt[d.label]!) <= machine.stabilizer.dropoutTolerance))
          d.label,
    };
    for (final label in kept) {
      _keptAt[label] = now;
    }
    final tracked = [
      for (final d in boxes)
        if (d.score >= minScore || (d.score >= keepLockScore && kept.contains(d.label))) d,
    ];
    if (kDebugMode) _logUnknownLabels(tracked);
    _logFiltered(tooLarge, present, tracked, now);

    final lock = machine.onFrame(tracked, presentBoxes: present);
    if (lock != null) {
      if (startQuiz(lock.detection)) {
        _askedAt = now;
        // A new ask starts clean: don't show the previous quiz's numbers
        // while this one is still loading, or if it falls back / fails.
        _lastFirstTokenMs = null;
        _lastAskToQuestionMs = null;
      } else {
        _emit('ask_busy', {'label': lock.detection.label});
        machine.onAskOutcome(AskOutcome.busy);
      }
    }
    notifyListeners();
  }

  /// Feed every quiz phase change (from WasteQuizNotifier), and the current
  /// phase once at start: a quiz may already be open (for example minimized).
  void onQuizPhase(WasteQuizPhase phase) {
    switch (machine.state) {
      case LiveScanState.asking:
        if (phase == WasteQuizPhase.active) {
          _lastFirstTokenMs = _firstTokenMs?.call();
          final askedAt = _askedAt;
          _lastAskToQuestionMs = askedAt == null ? null : _clock().difference(askedAt).inMilliseconds;
          machine.onAskOutcome(AskOutcome.questionReady);
        } else if (phase == WasteQuizPhase.finished) {
          machine.onAskOutcome(AskOutcome.failed);
        } else if (phase == WasteQuizPhase.idle) {
          machine.onAskOutcome(AskOutcome.cancelled); // dismissed before the question arrived
        }
      case LiveScanState.quiz:
        if (phase == WasteQuizPhase.idle) machine.onQuizClosed();
      default:
        if (phase == WasteQuizPhase.idle) return;
        machine.onQuizOpen(); // a quiz the live scan didn't start
    }
    notifyListeners();
  }

  /// Boxes dropped before the stabilizer: too large (logged once per change
  /// of labels) and in the scene but under [minScore] (a summary at most once
  /// a second). Sets the frame's block reason when nothing is lockable.
  void _logFiltered(Map<String, double> tooLarge, List<TrackedDetection> present, List<TrackedDetection> tracked,
      DateTime now) {
    final key = (tooLarge.keys.toList()..sort()).join(',');
    if (key != _tooLargeKey) {
      _tooLargeKey = key;
      if (tooLarge.isNotEmpty) _emit('box_ignored_too_large', {'labels': tooLarge, 'maxAreaFraction': maxBoxAreaFraction});
    }
    final low = <String, double>{};
    for (final d in present) {
      if (tracked.contains(d)) continue;
      final s = (d.score * 100).round() / 100;
      if ((low[d.label] ?? -1) < s) low[d.label] = s;
    }
    if (low.isNotEmpty && (_belowMinAt == null || now.difference(_belowMinAt!) >= const Duration(seconds: 1))) {
      _belowMinAt = now;
      _emit('below_min_score', {'labels': low, 'minScore': minScore});
    }
    _frameBlock = tracked.isNotEmpty
        ? null
        : tooLarge.isNotEmpty
            ? BlockReason('box_too_large', labels: tooLarge)
            : low.isNotEmpty
                ? BlockReason('below_min_score', labels: low)
                : null;
  }

  /// Debug only: a label the app can't sort and doesn't ignore (for example
  /// a casing mismatch like "human_hand") is logged once.
  void _logUnknownLabels(List<TrackedDetection> tracked) {
    for (final d in tracked) {
      if (ignoredLabels.contains(d.label) || _unknownLogged.contains(d.label)) continue;
      if (ScannedWaste.fromLabel(d.label).category != null) continue;
      _unknownLogged.add(d.label);
      debugPrint('[LiveScan] unknown detector label "${d.label}" (no waste category, not ignored)');
    }
  }

}
