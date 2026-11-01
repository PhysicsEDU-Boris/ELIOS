import 'package:flutter/material.dart';

import '../../../../../widgets/learn/learn_ui.dart';

/// Meta, title and subtitle inside the v2 summary card.
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
        Text(tag, style: context.text.labelMedium?.copyWith(color: p.tertiaryText)),
        const SizedBox(height: 4),
        Text(title, style: context.text.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle, style: context.text.bodySmall?.copyWith(color: p.textSecondary)),
      ],
    );
  }
}
