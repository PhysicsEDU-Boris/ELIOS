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
              child: Text(
                label,
                style: context.text.bodySmall?.copyWith(color: p.textSecondary),
              ),
            ),
            Text(
              valueLabel,
              style: ElioTokens.code.copyWith(color: p.textPrimary),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: p.primary,
            inactiveTrackColor: p.borderSubtle,
            thumbColor: p.primaryText,
            thumbShape: _RingThumb(p.surface),
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

/// Learn / Slider thumb: 20 px primary/text dot with a 3 px surface ring.
class _RingThumb extends SliderComponentShape {
  const _RingThumb(this.ring);
  final Color ring;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(20, 20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final c = context.canvas;
    c.drawCircle(center, 10, Paint()..color = ring);
    c.drawCircle(center, 7, Paint()..color = sliderTheme.thumbColor!);
  }
}
