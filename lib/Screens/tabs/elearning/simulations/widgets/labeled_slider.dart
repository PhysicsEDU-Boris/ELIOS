import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../theme/elio_learning_colors.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: elioMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              valueLabel,
              style: GoogleFonts.jetBrainsMono(
                color: elioInk,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: elioPrimary,
            inactiveTrackColor: elioBorder,
            thumbColor: elioPrimary,
            overlayColor: elioPrimary.withValues(alpha: 0.15),
            trackHeight: 5,
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
