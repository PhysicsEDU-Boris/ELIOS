import 'package:flutter/material.dart';

import '../history_ui.dart' show HistoryTone, historyTint;
import '../learn/learn_ui.dart' show LearnTheme;

/// What the arm's sort is doing, for the bubble over the robot camera (0243).
enum SortBubbleKind { busy, help, success, failed }

/// A round bubble over the camera picture (L2 v3 bubble): sorting in progress, "check the hand",
/// or "Sorting successful". Solid surface so it reads over any video.
class SortBubble extends StatelessWidget {
  const SortBubble({super.key, required this.text, required this.kind});

  final String text;
  final SortBubbleKind kind;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final tone = switch (kind) {
      SortBubbleKind.busy => HistoryTone.info,
      SortBubbleKind.help => HistoryTone.warning,
      SortBubbleKind.success => HistoryTone.success,
      SortBubbleKind.failed => HistoryTone.error,
    };
    final fg = historyTint(p, tone).fg;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('sort_bubble'),
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: fg, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (kind == SortBubbleKind.busy)
            SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          else
            Icon(
              switch (kind) {
                SortBubbleKind.help => Icons.front_hand_outlined,
                SortBubbleKind.success => Icons.check_circle_rounded,
                _ => Icons.error_outline_rounded,
              },
              size: 18,
              color: fg,
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text, maxLines: 3, style: TextStyle(color: p.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}
