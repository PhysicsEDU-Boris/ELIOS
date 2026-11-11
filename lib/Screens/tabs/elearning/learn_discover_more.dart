// L3 / Discover more (Figma 684:26930, card 20c): Videos, Guides, Simulations
// and Quizzes rails for the module the Explore carousel snapped to. No header
// or module chip: the Explore card on the left is the module indicator.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/elio_motion.dart';
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
  /// When the current pop-in started, and the extra wait before its first
  /// card; null = show cards at rest. Cards built after their moment (the
  /// list builds Discover lazily as it scrolls into view) also rest, so
  /// scrolling down never shows empty rails waiting to pop in.
  DateTime? _popAt;
  Duration _base = Duration.zero;
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    // During the Learn intro the rails pop in after Explore, at 1100 ms.
    final e = LearnIntroSlice.elapsedMs(context);
    if (e != null && e < 1100) {
      _popAt = DateTime.now();
      _base = Duration(milliseconds: 1100 - e);
    }
  }

  @override
  void didUpdateWidget(DiscoverMore old) {
    super.didUpdateWidget(old);
    if (old.moduleId != widget.moduleId) {
      _popAt = DateTime.now();
      _base = Duration.zero;
    }
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
                    popAt: _popAt,
                    base: _base,
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
    required this.popAt,
    this.base = Duration.zero,
  });
  final DiscoverRail rail;
  final int railIndex;
  final DateTime? popAt;
  final Duration base;

  static const _gap = 14.0;
  static const _largeW = 212.0, _smallW = 164.0;

  @override
  Widget build(BuildContext context) {
    final items = rail.items;
    return SnapRail(
      itemCount: items.length,
      first: _largeW + _gap,
      extent: _smallW + _gap,
      height: 265,
      itemBuilder: (context, i, _) {
        final it = items[i];
        // Cards 60 ms apart, rails 40 ms apart, max 6 waits, counted from
        // the pop-in start; a card built after its slot just shows.
        final slot =
            base +
            Duration(milliseconds: math.min(railIndex * 40 + i * 60, 6 * 60));
        final late = popAt == null
            ? null
            : DateTime.now().difference(popAt!);
        final wait = late == null || late > slot + ElioMotion.base
            ? null
            : (late >= slot ? Duration.zero : slot - late);
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Align(
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
              entrance: wait,
              onTap: it.onTap,
            ),
          ),
        );
      },
    );
  }
}
