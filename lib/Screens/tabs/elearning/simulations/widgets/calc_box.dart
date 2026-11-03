import 'package:flutter/material.dart';

import '../../../../../theme/elio_tokens.dart';
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.primaryText.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(learnRadiusM),
          border: Border(left: BorderSide(color: p.primaryText, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headerTitle, style: context.text.labelSmall?.copyWith(color: p.primaryText)),
            const SizedBox(height: 4),
            Text(formulaExpression, style: ElioTokens.code.copyWith(color: p.textPrimary)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(statusIcon, size: 16, color: statusColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusText,
                    style: context.text.labelMedium?.copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
