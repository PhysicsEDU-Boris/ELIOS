import 'package:flutter/material.dart';

import '../services/live_scan_controller.dart';
import '../services/live_scan_state_machine.dart';

/// Debug-only readout for the robot live scan (M2a): state, analysed fps,
/// quiz starts ("identify calls"), asks refused as busy, utterances started
/// (decision 0009), the last question's first-token time and
/// ASKING-to-question time, the last "Soal berikutnya" wait (decision 0011),
/// what blocks a new lock right now (decision 0020), and "Reset scan (debug)"
/// (the manual re-arm, disabled while a quiz is open). Shown in the Debug Scan side sheet.
class LiveScanDebugOverlay extends StatelessWidget {
  const LiveScanDebugOverlay({super.key, required this.controller, this.scanLine});

  final LiveScanController controller;

  /// The current scan: Gemma's item and the detector class (decision 0025).
  final String? scanLine;

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
              ],
            ),
          ),
        );
      },
    );
  }
}
