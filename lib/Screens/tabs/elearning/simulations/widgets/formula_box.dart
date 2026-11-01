import 'package:flutter/material.dart';

import '../../../../../theme/elio_tokens.dart';
import '../../../../../widgets/learn/learn_ui.dart';

/// Rumus tab body (Figma 310:5964): overline, mono formula, note.
class FormulaBox extends StatelessWidget {
  final String title;
  final TextSpan formulaText;
  final String subtitle;

  const FormulaBox({
    super.key,
    required this.title,
    required this.formulaText,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.labelSmall?.copyWith(color: p.primaryText)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: ElioTokens.subhead.copyWith(color: p.textPrimary),
            children: [formulaText],
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: context.text.bodySmall?.copyWith(color: p.textSecondary)),
      ],
    );
  }
}
