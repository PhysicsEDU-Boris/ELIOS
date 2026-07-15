import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../theme/elio_learning_colors.dart';

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: elioBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: elioPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: GoogleFonts.jetBrainsMono(
                color: elioInk,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              children: [
                formulaText,
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
                color: elioMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
