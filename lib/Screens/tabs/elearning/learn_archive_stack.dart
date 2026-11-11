// L3 / Archive stack (Figma 695:29623, cards 20a and 20b): the last guides as
// a fanned polaroid stack under Today's Guide. Swipe the top photo to the
// back of the stack; tap it to pull it out and show Continue.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../services/daily_guide_service.dart';
import '../../../services/elio_feedback.dart';
import '../../../services/guide_progress.dart';
import '../../../theme/elio_motion.dart';
import '../../../widgets/learn/learn_l3.dart';
import '../../../widgets/learn/learn_ui.dart';
import 'guides/guide_widgets.dart';

const _deg = math.pi / 180;
const _photoW = 118.0, _photoH = 150.0;

/// Rest slots (left, top, angle) for top, middle and back photo.
const _rest = [(32.0, 28.0, -8.0), (42.0, 31.0, 2.0), (55.0, 39.0, 12.0)];

class ArchiveStack extends ConsumerStatefulWidget {
  const ArchiveStack({
    super.key,
    required this.guides,
    required this.onOpen,
    required this.onSeeAll,
  });

  /// Newest first, at most 3 are shown.
  final List<DailyGuide> guides;
  final void Function(DailyGuide) onOpen;
  final VoidCallback onSeeAll;

  @override
  ConsumerState<ArchiveStack> createState() => _ArchiveStackState();
}

enum _Phase { rest, drag, flick, pulled }

class _ArchiveStackState extends ConsumerState<ArchiveStack> {
  late List<int> _order = _initial();
  double _dx = 0;
  bool _armed = false; // drag is past the flick threshold
  _Phase _phase = _Phase.rest;
  int _top = 0; // index shown in the info and the dots

  List<DailyGuide> get _guides => widget.guides.take(3).toList();

  List<int> _initial() =>
      List.generate(math.min(3, widget.guides.length), (i) => i);

  @override
  void didUpdateWidget(ArchiveStack old) {
    super.didUpdateWidget(old);
    if (_order.length != math.min(3, widget.guides.length)) {
      _order = _initial();
      _top = 0;
    }
  }

  double _threshold(double width) => width * 0.4;

  void _onDragUpdate(DragUpdateDetails d, double width) {
    if (_phase == _Phase.pulled || _order.length < 2) return;
    setState(() {
      _phase = _Phase.drag;
      _dx += d.delta.dx;
      final armed = _dx.abs() > _threshold(width);
      if (armed != _armed) {
        _armed = armed;
        if (armed) ElioHaptics.select();
      }
    });
  }

  void _onDragEnd(DragEndDetails d, double width) {
    if (_phase != _Phase.drag) return;
    final v = d.velocity.pixelsPerSecond.dx;
    if (_dx.abs() > _threshold(width) || v.abs() > 600) {
      _flick(_dx == 0 ? v.sign : _dx.sign);
    } else {
      setState(() {
        _phase = _Phase.rest;
        _dx = 0;
        _armed = false;
      });
    }
  }

  Future<void> _flick(double dir) async {
    setState(() {
      _phase = _Phase.flick;
      _dx = dir * 360;
    });
    await Future<void>.delayed(ElioMotion.base);
    if (!mounted) return;
    setState(() {
      _order = [..._order.skip(1), _order.first];
      _top = _order.first;
      _phase = _Phase.rest;
      _dx = 0;
      _armed = false;
    });
    elioFeedback(ElioSfx.tick, ElioHaptics.select);
  }

  void _togglePull() {
    if (_phase == _Phase.pulled) {
      _push(false);
    } else if (_phase == _Phase.rest) {
      _push(true);
    }
  }

  void _push(bool out) {
    setState(() => _phase = out ? _Phase.pulled : _Phase.rest);
    if (out) elioFeedback(ElioSfx.pop, ElioHaptics.light);
  }

  /// Transform, opacity and timing of the photo in [slot].
  ({Matrix4 m, double opacity, Duration d, Curve c}) _place(int slot) {
    final reduced = ElioMotion.reduced(context);
    var (x, y, a) = _rest[math.min(slot, 2)];
    var scale = slot == 0 ? 1.0 : 0.96;
    var opacity = 1.0;
    var d = ElioMotion.slow;
    Curve c = ElioMotion.soft;
    final t = (_dx.abs() / 120).clamp(0.0, 1.0);
    switch (_phase) {
      case _Phase.drag || _Phase.flick:
        if (slot == 0) {
          x += _dx;
          y -= 6;
          // Tilts up to +17° (x ÷ 120 × 17°) toward the swipe.
          a = _dx >= 0 ? -8 + 25 * t : -8 - 9 * t;
          if (_phase == _Phase.flick) {
            d = ElioMotion.base;
            c = ElioMotion.exit;
            opacity = 0.92;
          } else {
            d = Duration.zero;
          }
        } else if (slot == 1) {
          // The next photo comes forward 0.96 → 1 and turns to −6°.
          scale = 0.96 + 0.04 * t;
          a = 2 + (-6 - 2) * t;
          x = 42 + (31 - 42) * t;
          y = 31 + (27 - 31) * t;
          if (_phase == _Phase.drag) d = Duration.zero;
        } else {
          a = 12 + (6 - 12) * t;
          x = 55 + (31 - 55) * t;
          y = 39 + (38 - 39) * t;
          if (_phase == _Phase.drag) d = Duration.zero;
        }
      case _Phase.pulled:
        c = ElioMotion.pop;
        if (slot == 0) {
          // Slides up 24 px out of the stack, scales 1.22, straightens to −2°.
          // Figma: 144 × 183 at (27, 2); scaling is about the centre.
          x = 27 + 72 - _photoW / 2;
          y = 2 + 91.5 - _photoH / 2;
          a = -2;
          scale = 1.22;
        } else {
          d = ElioMotion.base;
          c = ElioMotion.standard;
          opacity = slot == 1 ? 0.6 : 0.5;
          a = slot == 1 ? -10 : 11;
          x = slot == 1 ? 17 : 2;
          y = slot == 1 ? 46 : 66;
        }
      case _Phase.rest:
        break;
    }
    if (reduced) d = d == Duration.zero ? d : ElioMotion.fast;
    final m = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..rotateZ(a * _deg)
      ..scaleByDouble(scale, scale, 1, 1);
    return (m: m, opacity: opacity, d: d, c: c);
  }

  @override
  Widget build(BuildContext context) {
    final guides = _guides;
    if (guides.isEmpty) return const SizedBox.shrink();
    final pulled = _phase == _Phase.pulled;
    final top = guides[_top];
    return PopScope(
      canPop: !pulled,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && pulled) _push(false);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            L3RailHeader(
              title: l10n.lnArchiveTitle,
              subtitle: pulled
                  ? l10n.lnArchivePulled
                  : l10n.lnArchiveSub(guides.length),
              seeAll: l10n.lnSeeAll,
              onSeeAll: widget.onSeeAll,
            ),
            TapRegion(
              onTapOutside: pulled ? (_) => _push(false) : null,
              child: LayoutBuilder(
                builder: (context, box) => SizedBox(
                  height: 214,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // While the feed has fewer than 3 older guides, empty
                      // frames keep the Figma fan; they hold no content.
                      for (var slot = 2; slot >= _order.length; slot--)
                        _blank(slot),
                      // Back photo first; keys keep each photo's animation state.
                      for (var slot = _order.length - 1; slot >= 0; slot--)
                        _photo(guides[_order[slot]], slot, box.maxWidth),
                      Positioned(
                        left: 200,
                        right: 0,
                        top: pulled ? 28 : 34,
                        child: _Info(
                          guide: top,
                          pulled: pulled,
                          onContinue: () {
                            ElioHaptics.medium();
                            widget.onOpen(top);
                          },
                        ),
                      ),
                      Positioned(
                        left: 16,
                        top: 206,
                        child: _Dots(count: guides.length, active: _top),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blank(int slot) {
    final p = _place(slot);
    final pal = context.elio;
    return Positioned(
      key: ValueKey('blank-$slot'),
      left: 0,
      top: 0,
      child: IgnorePointer(
        child: ElioPopIn(
          index: 2 - slot,
          child: AnimatedOpacity(
            opacity: _phase == _Phase.pulled ? 0.5 : 1,
            duration: ElioMotion.base,
            child: AnimatedContainer(
              duration: p.d,
              curve: p.c,
              transform: p.m,
              transformAlignment: Alignment.center,
              width: _photoW,
              height: _photoH,
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 32),
              decoration: BoxDecoration(
                color: pal.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pal.borderSubtle),
                boxShadow: l3Shadow,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: pal.surfaceRaised,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photo(DailyGuide g, int slot, double width) {
    final p = _place(slot);
    // Entrance: rule 7, back photo first, 40 ms apart.
    final photo = ElioPopIn(
      index: 2 - slot,
      child: AnimatedOpacity(
        opacity: p.opacity,
        duration: p.d,
        child: AnimatedContainer(
          duration: p.d,
          curve: p.c,
          transform: p.m,
          transformAlignment: Alignment.center,
          width: _photoW,
          height: _photoH,
          child: _Polaroid(guide: g),
        ),
      ),
    );
    return Positioned(
      key: ValueKey(g.date),
      left: 0,
      top: 0,
      child: slot != 0
          ? IgnorePointer(child: photo)
          : Semantics(
              container: true,
              button: true,
              excludeSemantics: true,
              label: l10n.lnArchivePhotoLabel(
                g.title[g.lang(guideLangOf(ref))] ?? '',
              ),
              onTap: _togglePull,
              child: GestureDetector(
                onTap: _togglePull,
                onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
                onHorizontalDragEnd: (d) => _onDragEnd(d, width),
                child: photo,
              ),
            ),
    );
  }
}

/// L3 / Archive polaroid (695:29529): photo, caption, 1 px subtle edge.
class _Polaroid extends ConsumerWidget {
  const _Polaroid({required this.guide});
  final DailyGuide guide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final lang = guide.lang(guideLangOf(ref));
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.borderSubtle),
        boxShadow: l3Shadow,
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 106,
              height: 112,
              child: GuidePhotoImage(guide: guide, width: 106, height: 112),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            guide.topic[lang] ?? topicName(guide.theme),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Info extends ConsumerWidget {
  const _Info({
    required this.guide,
    required this.pulled,
    required this.onContinue,
  });
  final DailyGuide guide;
  final bool pulled;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final lang = guide.lang(guideLangOf(ref));
    final progress = ref.watch(
      guideProgressProvider.select((s) => s.of(guide.date)),
    );
    final tone = topicTone(guide.theme);
    final done = progress.stopsDone;
    final xp = done == 3
        ? l10n.lnArchiveXpDone(guide.xp.total)
        : l10n.lnArchiveXp(progress.xp, guide.xp.total);
    return AnimatedSwitcher(
      duration: ElioMotion.fast,
      child: Column(
        key: ValueKey(guide.date),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: ShapeDecoration(
              color: toneBg(
                p,
                tone == LearnTone.neutral ? LearnTone.info : tone,
              ),
              shape: const StadiumBorder(),
            ),
            child: Text(
              '${guideDate(guide, pattern: 'd MMM')} · ${topicName(guide.theme)}',
              style: context.text.labelLarge?.copyWith(
                color: toneFg(
                  p,
                  tone == LearnTone.neutral ? LearnTone.info : tone,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            guide.title[lang]!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleLarge,
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: pulled ? ElioMotion.base : ElioMotion.fast,
            switchInCurve: ElioMotion.standard,
            switchOutCurve: ElioMotion.exit,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: AnimatedBuilder(
                animation: a,
                child: child,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, 8 * (1 - a.value)),
                  child: child,
                ),
              ),
            ),
            child: pulled
                ? Column(
                    key: const ValueKey('continue'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: L3Button(
                          label: l10n.lnContinue,
                          height: 48,
                          onPressed: onContinue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.lnArchiveStops(done)} · $xp',
                        style: captionStyle(context),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('stops'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < done ? p.primary : p.borderMedium,
                              ),
                            ),
                          const SizedBox(width: 2),
                          Text(
                            l10n.lnArchiveStops(done),
                            style: captionStyle(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(xp, style: captionStyle(context)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Page dots; the active one morphs 6 → 16 px.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active, this.wide = 16});
  final int count, active;
  final double wide;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: ElioMotion.base,
            curve: ElioMotion.standard,
            margin: const EdgeInsets.only(right: 5),
            width: i == active ? wide : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? p.primary : p.borderMedium,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Page dots for carousels (Explore uses 18 px).
class LearnPageDots extends StatelessWidget {
  const LearnPageDots({super.key, required this.count, required this.active});
  final int count, active;
  @override
  Widget build(BuildContext context) =>
      _Dots(count: count, active: active, wide: 18);
}
