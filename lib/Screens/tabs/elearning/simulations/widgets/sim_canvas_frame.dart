import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../theme/elio_learning_colors.dart';

class SimCanvasFrame extends StatelessWidget {
  final Widget canvas;
  final String noteText;
  final bool showRiskBadge;
  final String riskBadgeText;

  const SimCanvasFrame({
    super.key,
    required this.canvas,
    required this.noteText,
    this.showRiskBadge = false,
    this.riskBadgeText = '⚠ RISIKO TERGULING',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: elioBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          canvas,
          Positioned(
            top: 10,
            left: 10,
            right: 110,
            child: _SimNote(text: noteText),
          ),
          if (showRiskBadge)
            Positioned(
              top: 10, 
              right: 10, 
              child: _RiskBadge(text: riskBadgeText),
            ),
        ],
      ),
    );
  }
}

class _SimNote extends StatelessWidget {
  final String text;
  const _SimNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: elioMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String text;
  const _RiskBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: elioDanger,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
