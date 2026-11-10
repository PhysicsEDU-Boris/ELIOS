import 'package:flutter/material.dart';

import '../../../../../widgets/learn/learn_l3.dart';
import '../../../../../widgets/learn/learn_ui.dart';

/// Overline, Headline title with squiggle, and subtitle (Learn L3).
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
    final p = context.elio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        L3TitleBlock(
          overline: tag,
          title: title,
          overlineColor: p.tertiaryText,
          squiggle: 190,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: context.text.bodyMedium?.copyWith(color: p.textSecondary),
        ),
      ],
    );
  }
}
