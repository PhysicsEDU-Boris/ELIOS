import 'package:flutter/material.dart';

import '../../../../../theme/elio_tokens.dart';
import '../../../../../theme/elio_motion.dart';
import '../../../../../widgets/learn/learn_l3.dart';
import '../../../../../widgets/learn/learn_ui.dart';

/// Result box ("HASIL KLASIFIKASI"): green left rule on a tinted fill.
class CalcBox extends StatelessWidget {
  final String headerTitle;
  final String formulaExpression;
  final IconData statusIcon;
  final Color statusColor;
  final String statusText;

  const CalcBox({
    super.key,
    required this.headerTitle,
    required this.formulaExpression,
    required this.statusIcon,
    required this.statusColor,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: ShapeDecoration(
          color: toneBg(p, LearnTone.success),
          shape: RoundedRectangleBorder(
            borderRadius: leafS,
            side: BorderSide(
              color: toneBorder(p, LearnTone.success),
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headerTitle,
              style: context.text.labelSmall?.copyWith(color: p.primaryText),
            ),
            const SizedBox(height: 4),
            Text(
              formulaExpression,
              style: ElioTokens.code.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: 4),
            // A new material band cross-fades the line; the ✓ pops in.
            AnimatedSwitcher(
              duration: ElioMotion.fast,
              child: Row(
                key: ValueKey(statusText),
                children: [
                  ElioPopIn(
                    curve: ElioMotion.pop,
                    scale: 0.4,
                    rise: 0,
                    duration: ElioMotion.base,
                    child: Icon(statusIcon, size: 16, color: statusColor),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      statusText,
                      style: context.text.labelLarge?.copyWith(
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
