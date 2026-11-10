// L3 / Discover more (Figma 684:26930, card 20c): Videos, Guides, Simulations
// and Quizzes rails for the module the Explore carousel snapped to. No header
// or module chip: the Explore card on the left is the module indicator.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../theme/elio_motion.dart';
import '../../../services/elio_feedback.dart';
import '../../../widgets/learn/learn_l3.dart';

class DiscoverItem {
  const DiscoverItem({
    required this.tag,
    required this.title,
    required this.meta,
    required this.cover,
    required this.progress,
    required this.onTap,
    this.sticker,
  });
  final String tag, title, meta;
  final Widget cover;
  final double progress;
  final String? sticker;
  final VoidCallback onTap;
}

class DiscoverRail {
  const DiscoverRail({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.items,
    this.onSeeAll,
  });
  final PopKind kind;
  final String title, subtitle;
  final List<DiscoverItem> items;
  final VoidCallback? onSeeAll;
}

class DiscoverMore extends StatefulWidget {
  const DiscoverMore({
    super.key,
    required this.moduleId,
    required this.rails,
    required this.seeAll,
  });

  /// The open module; a change replays the pop-in.
  final String moduleId;
  final List<DiscoverRail> rails;
  final String seeAll;

  @override
  State<DiscoverMore> createState() => _DiscoverMoreState();
}

class _DiscoverMoreState extends State<DiscoverMore> {
  bool _animate = false;

  @override
  void didUpdateWidget(DiscoverMore old) {
    super.didUpdateWidget(old);
    if (old.moduleId != widget.moduleId) _animate = true;
  }

  @override
  Widget build(BuildContext context) {
    final rails = widget.rails.where((r) => r.items.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (r, rail) in rails.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: L3RailHeader(
                    title: rail.title,
                    subtitle: rail.subtitle,
                    seeAll: widget.seeAll,
                    onSeeAll: rail.onSeeAll,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: ElioMotion.fast,
                  reverseDuration: ElioMotion.fast,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, a) {
                    final outgoing =
                        child.key != ValueKey('${widget.moduleId}-$r');
                    if (!outgoing) return child;
                    // Old cards sink 12 px, scale 0.9 and fade (fast, exit).
                    return FadeTransition(
                      opacity: a,
                      child: AnimatedBuilder(
                        animation: a,
                        child: child,
                        builder: (context, child) {
                          final t = ElioMotion.exit.transform(1 - a.value);
                          return Transform.translate(
                            offset: Offset(0, 12 * t),
                            child: Transform.scale(
                              scale: 1 - 0.1 * t,
                              child: child,
                            ),
                          );
                        },
                      ),
                    );
                  },
                  child: _Rail(
                    key: ValueKey('${widget.moduleId}-$r'),
                    rail: rail,
                    railIndex: r,
                    animate: _animate,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    super.key,
    required this.rail,
    required this.railIndex,
    required this.animate,
  });
  final DiscoverRail rail;
  final int railIndex;
  final bool animate;

  static const _gap = 14.0;
  static const _largeW = 212.0, _smallW = 164.0;

  @override
  Widget build(BuildContext context) {
    final items = rail.items;
    return SizedBox(
      height: 265,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (_) {
          elioFeedback(ElioSfx.tick, ElioHaptics.select);
          return false;
        },
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          physics: const _SnapPhysics(
            first: _largeW + _gap,
            rest: _smallW + _gap,
          ),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: _gap),
          itemBuilder: (context, i) {
            final it = items[i];
            // Cards 60 ms apart, rails 40 ms apart, max 6 waits.
            final wait = Duration(
              milliseconds: math.min(railIndex * 40 + i * 60, 6 * 60),
            );
            return Align(
              alignment: Alignment.bottomLeft,
              child: ContentPopCard(
                kind: rail.kind,
                tag: it.tag,
                title: it.title,
                meta: it.meta,
                cover: it.cover,
                progress: it.progress,
                sticker: it.sticker,
                large: i == 0,
                entrance: animate ? wait : null,
                onTap: it.onTap,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Snaps a rail to card edges: the first card is [first] wide (with gap),
/// the others [rest]. Settles with spring/soft.
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.first, required this.rest, super.parent});
  final double first, rest;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPhysics(first: first, rest: rest, parent: buildParent(ancestor));

  double _snap(double offset, double velocity, double max) {
    double edge(int i) => i == 0 ? 0 : first + (i - 1) * rest;
    var i = offset < first ? 0 : 1 + ((offset - first) / rest).floor();
    final lo = edge(i), hi = edge(i + 1);
    final pick = velocity > 300
        ? hi
        : velocity < -300
        ? lo
        : (offset - lo < hi - offset ? lo : hi);
    return pick.clamp(0.0, max);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = _snap(position.pixels, velocity, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) return null;
    return SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 380, damping: 30),
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
