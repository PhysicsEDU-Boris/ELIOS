import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../theme/elio_learning_colors.dart';

class SimModuleHeader extends StatelessWidget {
  final String tag;
  final String title;
  final String subtitle;

  const SimModuleHeader({
    super.key,
    required this.tag,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: elioPrimaryLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tag,
            style: GoogleFonts.inter(
              color: elioPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: GoogleFonts.inter(
              color: elioInk, fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(color: elioMuted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}
