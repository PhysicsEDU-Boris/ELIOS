import 'package:flutter/material.dart';

import '../../../../../widgets/learn/learn_ui.dart';

/// Collapsible header 300:3329.
class CollapsibleSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final p = context.elio;
    final shape = learnShape(learnRadiusL, BorderSide(color: p.borderSubtle));
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: shape,
        collapsedShape: shape,
        backgroundColor: p.surface,
        collapsedBackgroundColor: p.surface,
        iconColor: p.textSecondary,
        collapsedIconColor: p.textSecondary,
        minTileHeight: 48,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            ExcludeSemantics(child: Text(iconEmoji)),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: context.text.labelSmall?.copyWith(color: p.primaryText))),
          ],
        ),
        children: [child],
      ),
    );
  }
}
