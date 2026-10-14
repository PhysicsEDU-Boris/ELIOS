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
  })  : _firstTokenMs = firstTokenMs,
        _ttsCount = ttsCount,
        _nextWaitMs = nextWaitMs,
        _clock = clock ?? monotonicClock() {
    machine = LiveScanStateMachine(DetectionStabilizer(ignoredLabels: ignoredLabels, clock: _clock), clock: _clock);
  }

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

  /// Starts a quiz for [label]; false if one is already open.
  final bool Function(String label) startQuiz;
  final int? Function()? _firstTokenMs;
  final int Function()? _ttsCount;
  final int? Function()? _nextWaitMs;
  final DateTime Function() _clock;
  late final LiveScanStateMachine machine;

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
  void onDetections(List<Detection> detections, {Size? frameSize}) {
    final now = _clock();
    _recentFrames
      ..add(now)
      ..removeWhere((t) => now.difference(t) >= const Duration(seconds: 1));

    final maxArea = frameSize == null ? double.infinity : frameSize.width * frameSize.height * maxBoxAreaFraction;
    final boxes = [
      for (final d in detections)
        if (d.label.trim().isNotEmpty && d.w * d.h <= maxArea)
          TrackedDetection(label: d.label.trim(), x: d.x, y: d.y, w: d.w, h: d.h, score: d.score),
    ];
    final present = {
      for (final d in boxes)
        if (d.score >= presenceScore && !ignoredLabels.contains(d.label)) d.label,
    };

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

    final lock = machine.onFrame(tracked, present: present);
    if (lock != null) {
      if (startQuiz(lock.detection.label)) {
        _askedAt = now;
        // A new ask starts clean: don't show the previous quiz's numbers
        // while this one is still loading, or if it falls back / fails.
        _lastFirstTokenMs = null;
        _lastAskToQuestionMs = null;
      } else {
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
        if (phase == WasteQuizPhase.active || phase == WasteQuizPhase.finished) {
          _lastFirstTokenMs = _firstTokenMs?.call();
          final askedAt = _askedAt;
          _lastAskToQuestionMs = askedAt == null ? null : _clock().difference(askedAt).inMilliseconds;
          machine.onAskOutcome(AskOutcome.questionReady);
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
