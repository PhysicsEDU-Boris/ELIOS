import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../theme/elio_learning_colors.dart';
import 'collapsible_section.dart';

class DeepExplainCard extends StatelessWidget {
  final String title;
  final String bodyText;
  final List<String> bulletPoints;

  const DeepExplainCard({
    super.key,
    required this.title,
    required this.bodyText,
    required this.bulletPoints,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleSection(
      title: title,
      iconEmoji: '📖',
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bodyText,
            textAlign: TextAlign.justify,
            style: GoogleFonts.inter(color: elioInk, fontSize: 12.5, height: 1.6, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          for (final point in bulletPoints)
            _bullet(point),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2, right: 8),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(color: elioPrimary.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('▸', style: TextStyle(color: elioPrimary, fontWeight: FontWeight.bold, fontSize: 10, height: 1.0)),
          ),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.justify,
              style: GoogleFonts.inter(color: elioInk, fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
