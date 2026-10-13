import 'package:flutter/material.dart';

import '../services/live_scan_controller.dart';
import '../services/live_scan_state_machine.dart';

/// Debug-only readout for the robot live scan (M2a): state, analysed fps,
/// quiz starts ("identify calls"), asks refused as busy, the last
/// question's first-token time and the labels still waiting (sameLabelWait).
class LiveScanDebugOverlay extends StatelessWidget {
  const LiveScanDebugOverlay({super.key, required this.controller});

  final LiveScanController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final m = controller.machine;
          final idle = m.state == LiveScanState.searching || m.state == LiveScanState.locking;
          final state = m.lastAskFailed && idle ? 'ASK FAILED' : m.state.name.toUpperCase();
          final firstToken = controller.lastFirstTokenMs;
          final waits = [
            for (final MapEntry(:key, :value) in m.labelWaits.entries) '$key ${(value.inMilliseconds / 1000).ceil()}s',
          ];
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                'LIVE SCAN  $state\n'
                'fps ${controller.fps}   identify ${m.askCount}   busy ${m.busyCount}\n'
                'first token ${firstToken == null ? '-' : '$firstToken ms'}'
                '${waits.isEmpty ? '' : '\nwait ${waits.join(', ')}'}',
                style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35, fontFamily: 'monospace'),
              ),
            ),
          );
        },
      ),
    );
  }
}
