// Segmented control (C1 Segment 349:4444), used on ELIOS setup and Profile.
// The C1 settings sheet is gone in ELIOS 3: connection and video live on
// ELIOS setup, sound and quiz on Profile (decisions 0196, 0198).
import 'package:flutter/material.dart';

import '../../widgets/learn/learn_ui.dart';
import 'config_parts.dart';

/// Segment 349:4444: green pill on the chosen value.
class ConfigSegmented extends StatelessWidget {
  const ConfigSegmented({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labels,
  });

  final String label;
  final List<String> options;

  /// What each option shows, when it differs from the saved value.
  final List<String>? labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: p.surfaceRaised,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          for (final (i, o) in options.indexed)
            Expanded(
              child: Semantics(
                button: true,
                inMutuallyExclusiveGroup: true,
                selected: o == selected,
                label: '$label ${labels?[i] ?? o}',
                excludeSemantics: true,
                onTap: () => onSelected(o),
                child: Material(
                  color: o == selected ? p.primary : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelected(o),
                    child: SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          labels?[i] ?? o,
                          style: configStrong(
                            p,
                            color: o == selected
                                ? p.onPrimary
                                : p.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
