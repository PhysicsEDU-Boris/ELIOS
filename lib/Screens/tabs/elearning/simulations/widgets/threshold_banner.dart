import 'package:flutter/material.dart';

import '../../../../../widgets/learn/learn_ui.dart';

class ThresholdBanner extends StatelessWidget {
  final bool visible;
  final String text;

  const ThresholdBanner({
    super.key,
    required this.visible,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      liveRegion: true,
      child: AnimatedSize(
        duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: !visible
            ? const SizedBox(width: double.infinity)
            : Container(
                margin: const EdgeInsets.only(top: 10),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: ShapeDecoration(
                  color: p.secondaryText.withValues(alpha: 0.1),
                  shape: learnShape(learnRadiusM, BorderSide(color: p.secondaryText)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: p.secondaryText, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: context.text.labelMedium?.copyWith(color: p.secondaryText),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
