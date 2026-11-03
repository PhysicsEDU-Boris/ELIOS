import 'package:flutter/material.dart';

import '../services/live_scan_controller.dart';
import '../services/live_scan_state_machine.dart';
import '../services/websocket_service.dart' show ArmTag;

/// Debug-only readout for the robot live scan (M2a): state, analysed fps,
/// quiz starts ("identify calls"), asks refused as busy, utterances started
/// (decision 0009), the last question's first-token time and
/// ASKING-to-question time, the last "Soal berikutnya" wait (decision 0011),
/// what blocks a new lock right now (decision 0020), and "Reset scan (debug)"
/// (the manual re-arm, disabled while a quiz is open). Shown in the Debug Scan side sheet.
class LiveScanDebugOverlay extends StatelessWidget {
  const LiveScanDebugOverlay({
    super.key,
    required this.controller,
    this.scanLine,
    this.armTags,
    this.eeMm,
  });

  final LiveScanController controller;

  /// The current scan: Gemma's item and the detector class (decision 0025).
  final String? scanLine;

  /// AprilTags on the arm from the camera (decision 0022/0027).
  final List<ArmTag>? armTags;

  /// End-effector coordinates in mm [x, y, z] (decision 0027).
  final List<double>? eeMm;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final m = controller.machine;
        final idle = m.state == LiveScanState.searching || m.state == LiveScanState.locking;
        final state = m.lastAskFailed && idle ? 'ASK FAILED' : m.state.name.toUpperCase();
        final firstToken = controller.lastFirstTokenMs;
        final askToQuestion = controller.lastAskToQuestionMs;
        final nextWait = controller.nextWaitMs;
        final blocked = controller.blockReason?.text;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton(
                  onPressed: controller.canManualRearm ? controller.forgetEverything : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: const Text('Reset scan (debug)'),
                ),
                const SizedBox(height: 4),
                Text(
                  'LIVE SCAN  $state\n'
                  'fps ${controller.fps}   identify ${m.askCount}   busy ${m.busyCount}   tts ${controller.ttsCount}\n'
                  'first token ${firstToken == null ? '-' : '$firstToken ms'}'
                  '   question ${askToQuestion == null ? '-' : '$askToQuestion ms'}'
                  '   next ${nextWait == null ? '-' : '$nextWait ms'}'
                  '${blocked == null ? '' : '\n$blocked'}'
                  '${scanLine == null ? '' : '\n$scanLine'}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 4),
                Text(
                  eeMm != null && eeMm!.length >= 3
                      ? 'EE: x=${eeMm![0].toStringAsFixed(1)} y=${eeMm![1].toStringAsFixed(1)} z=${eeMm![2].toStringAsFixed(1)} mm'
                      : 'EE: -',
                  key: const ValueKey('ee_xyz_readout'),
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35, fontFamily: 'monospace'),
                ),
                if (_visibleTagChips.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _visibleTagChips,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> get _visibleTagChips {
    final tags = armTags;
    if (tags == null || tags.isEmpty) return const [];
    final chips = <Widget>[];
    for (final tag in tags) {
      if (tag.id == 0 || tag.id == 1) {
        chips.add(
          Container(
            key: ValueKey('tag_chip_${tag.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.teal.shade800,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white30),
            ),
            child: Text(
              'Tag ${tag.id}: ${tag.distMm.toStringAsFixed(1)} mm',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    }
    return chips;
  }
}
