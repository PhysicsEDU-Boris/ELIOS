// Segmented control (C1 Segment 349:4444), used on ELIOS setup and Profile.
// The C1 settings sheet is gone in ELIOS 3: connection and video live on
// ELIOS setup, sound and quiz on Profile (decisions 0196, 0198).
import 'package:flutter/material.dart';

import '../../theme/elio_motion.dart';
import '../../widgets/learn/learn_ui.dart';
import 'config_parts.dart';
import '../../services/elio_feedback.dart';

/// Segment 349:4444: green pill on the chosen value.
class ConfigSegmented extends StatelessWidget {
  const ConfigSegmented({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labels,
    this.leading,
    this.neutral = false,
  });

  /// An icon before each label (Quiz source card 629:90989).
  final List<Widget>? leading;

  /// White pill with a soft shadow instead of the green one.
  final bool neutral;

  final String label;
  final List<String> options;

  /// What each option shows, when it differs from the saved value.
  final List<String>? labels;
  final String selected;
  final ValueChanged<String> onSelected;

  /// S1 + H-select on a new value (Figma 13 · 5).
  void _pick(String o) {
    if (o != selected) elioFeedback(ElioSfx.tick, ElioHaptics.select);
    onSelected(o);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final at = options.indexOf(selected);
    final n = options.length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: p.surfaceRaised,
        shape: const StadiumBorder(),
      ),
      child: Stack(
        children: [
          // The green pill slides behind the labels (spring/soft, Figma 13 · 5).
          if (at >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(n == 1 ? 0 : -1 + 2 * at / (n - 1), 0),
                duration: ElioMotion.reduced(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: ElioMotion.soft,
                child: FractionallySizedBox(
                  widthFactor: 1 / n,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: !neutral
                          ? p.primary
                          : p.isDark
                          ? p.textPrimary
                          : p.surface,
                      shape: const StadiumBorder(),
                      shadows: neutral
                          ? const [
                              BoxShadow(
                                color: Color(0x1F0F172A),
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final (i, o) in options.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    inMutuallyExclusiveGroup: true,
                    selected: o == selected,
                    label: '$label ${labels?[i] ?? o}',
                    excludeSemantics: true,
                    onTap: () => _pick(o),
                    child: Material(
                      color: Colors.transparent,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _pick(o),
                        child: SizedBox(
                          height: 44,
                          child: Center(
                            // Colour swaps 150 ms, 40 ms after the pill moves.
                            child: AnimatedDefaultTextStyle(
                              duration: ElioMotion.fast,
                              curve: const Interval(0.25, 1),
                              style: configStrong(
                                p,
                                color: o != selected
                                    ? p.textSecondary
                                    : !neutral
                                    ? p.onPrimary
                                    : p.isDark
                                    ? p.background
                                    : p.textPrimary,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (leading != null) ...[
                                    Opacity(
                                      opacity: o == selected ? 1 : 0.6,
                                      child: leading![i],
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Text(
                                      labels?[i] ?? o,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
        ],
      ),
    );
  }
}
