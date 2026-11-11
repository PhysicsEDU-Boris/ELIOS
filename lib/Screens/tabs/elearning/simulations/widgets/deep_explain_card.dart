import 'package:flutter/material.dart';
import '../../../../../widgets/learn/learn_ui.dart';
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
          Text(bodyText, style: context.text.bodySmall),
          const SizedBox(height: 10),
          for (final point in bulletPoints) _bullet(context, point),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    final p = context.elio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2, right: 8),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(color: p.primaryText.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '▸',
              style: TextStyle(
                color: p.primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                height: 1.0,
              ),
            ),
          ),
          Expanded(child: Text(text, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}
