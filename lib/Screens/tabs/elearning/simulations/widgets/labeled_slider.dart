import 'package:flutter/material.dart';

import '../../../../../theme/elio_tokens.dart';
import '../../../../../widgets/learn/learn_ui.dart';

/// Slider 300:3321: label and mono value above a green track.
class LabeledSlider extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const LabeledSlider({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: context.text.bodySmall?.copyWith(color: p.textSecondary)),
            ),
            Text(valueLabel, style: ElioTokens.code.copyWith(color: p.textPrimary)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: p.primary,
            inactiveTrackColor: p.borderSubtle,
            thumbColor: p.primaryActive,
            overlayColor: p.primary.withValues(alpha: 0.15),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            semanticFormatterCallback: (_) => '$label $valueLabel',
          ),
        ),
      ],
    );
  }
}
