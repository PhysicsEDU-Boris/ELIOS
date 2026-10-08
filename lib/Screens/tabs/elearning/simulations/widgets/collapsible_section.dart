import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../theme/elio_learning_colors.dart';

class CollapsibleSection extends StatefulWidget {
  final String title;
  final String iconEmoji;
  final Widget child;
  final bool initiallyExpanded;

  const CollapsibleSection({
    super.key,
    required this.title,
    required this.iconEmoji,
    required this.child,
    this.initiallyExpanded = true,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: elioBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: widget.initiallyExpanded,
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: elioPrimaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(widget.iconEmoji, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF004D37),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          children: [widget.child],
        ),
      ),
    );
  }
}
