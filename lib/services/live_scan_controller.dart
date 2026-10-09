/// Glue for the robot's live scan (M2a): MaixCAM2 detections -> score filter
/// -> stabilizer + state machine -> one quiz start per object. Only used when
/// the app is built with --dart-define=LIVE_SCAN=true. See
/// docs/decisions/0008-live-scan-state-machine.md.
library;

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
    DateTime Function()? clock,
  })  : _firstTokenMs = firstTokenMs,
        _clock = clock ?? _monotonicClock() {
    machine = LiveScanStateMachine(DetectionStabilizer(ignoredLabels: ignoredLabels, clock: _clock));
  }

  /// Same minimum score as WasteQuizNotifier.onDetections.
  static const minScore = 0.55;

  /// Detector classes never tracked, spelled exactly as the MaixCAM2
  /// firmware sends them (`LABELS` in elio_maixcam2.py).
  static const ignoredLabels = {'Human_Hand'};

  /// Starts a quiz for [label]; false if one is already open.
  final bool Function(String label) startQuiz;
  final int? Function()? _firstTokenMs;
  final DateTime Function() _clock;
  late final LiveScanStateMachine machine;

  final _unknownLogged = <String>{};
  final _recentFrames = <DateTime>[];

  /// Analysed frames in the last second.
  int get fps => _recentFrames.length;

  /// First-token time of the last quiz start's question, once it arrived.
  int? get lastFirstTokenMs => _lastFirstTokenMs;
  int? _lastFirstTokenMs;

  void onDetections(List<Detection> detections) {
    final now = _clock();
    _recentFrames
      ..add(now)
      ..removeWhere((t) => now.difference(t) >= const Duration(seconds: 1));

    final tracked = [
      for (final d in detections)
        if (d.score >= minScore && d.label.trim().isNotEmpty)
          TrackedDetection(label: d.label.trim(), x: d.x, y: d.y, w: d.w, h: d.h, score: d.score),
    ];
    if (kDebugMode) _logUnknownLabels(tracked);

    final lock = machine.onFrame(tracked);
    if (lock != null && !startQuiz(lock.detection.label)) machine.onAskOutcome(AskOutcome.busy);
    notifyListeners();
  }

  /// Feed every quiz phase change (from WasteQuizNotifier).
  void onQuizPhase(WasteQuizPhase phase) {
    switch (machine.state) {
      case LiveScanState.asking:
        if (phase == WasteQuizPhase.active || phase == WasteQuizPhase.finished) {
          _lastFirstTokenMs = _firstTokenMs?.call();
          machine.onAskOutcome(AskOutcome.questionReady);
        } else if (phase == WasteQuizPhase.idle) {
          machine.onAskOutcome(AskOutcome.cancelled); // dismissed before the question arrived
        }
      case LiveScanState.quiz:
        if (phase == WasteQuizPhase.idle) machine.onQuizClosed();
      default:
        return;
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

  static DateTime Function() _monotonicClock() {
    final base = DateTime.now();
    final sw = Stopwatch()..start();
    return () => base.add(sw.elapsed);
  }
}
