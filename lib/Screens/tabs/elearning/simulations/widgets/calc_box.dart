import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../theme/elio_learning_colors.dart';

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: elioPrimaryLight,
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: elioPrimary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headerTitle,
            style: GoogleFonts.inter(
              color: const Color(0xFF004D37),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            formulaExpression,
            style: GoogleFonts.jetBrainsMono(
                color: elioInk, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(statusIcon, size: 15, color: statusColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    color: elioMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
