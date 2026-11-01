import 'package:flutter/material.dart';

import '../../../../../widgets/learn/learn_ui.dart';

class MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const MetaChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(color: p.surfaceRaised, shape: learnShape(8)),
      child: LearnMeta(icon: icon, label: label),
    );
  }
}
