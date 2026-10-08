import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../theme/elio_learning_colors.dart';

class MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const MetaChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: elioMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: elioMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
