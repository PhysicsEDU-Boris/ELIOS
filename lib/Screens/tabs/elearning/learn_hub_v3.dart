// Learn hub L2 v3 "organic" (Figma 570:5147, decision 0195): curved green
// header, Today's Guide ticket, shortcut bubbles, Explore with leaf cards.
import '../../../widgets/tour/app_tour.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/l10n.dart';
import '../../../models/elearning_module.dart';
import '../../../providers/learn_shortcut_provider.dart';
import '../../../providers/physics_progress_provider.dart';
import '../../../services/daily_guide_service.dart';
import '../../../services/guide_progress.dart';
import '../../../services/elio_feedback.dart';
import '../../../theme/elio_motion.dart';
import '../../../widgets/learn/learn_l3.dart';
import '../../../widgets/learn/learn_ui.dart';
import 'learn_archive_stack.dart';
import 'guides/guide_widgets.dart';
import 'learn_content.dart';

const _homeArt = 'assets/illustrations/home';

String moduleBuddy(String moduleId) => switch (moduleId) {
  'inorganic' => '$_homeArt/bin_anorganik.svg',
  'hazardous' => '$_homeArt/bin_b3.svg',
  _ => '$_homeArt/bin_organik.svg',
};

/// Bin tone as in History (H3): organik amber, anorganik green, B3 red.
LearnTone moduleTone(String moduleId) => switch (moduleId) {
  'inorganic' => LearnTone.success,
  'hazardous' => LearnTone.error,
  _ => LearnTone.warning,
};

// ---------------------------------------------------------------- header

/// Curved green header with the module ring; Today's Guide ticket overlaps it.
class LearnCurvedHeader extends StatelessWidget {
  const LearnCurvedHeader({
    super.key,
    required this.modules,
    required this.moduleValues,
    required this.overall,
    required this.title,
    required this.subtitle,
    required this.onOpenProgress,
    this.ticket,
    this.top,
    this.rewards,
  });

  final List<ElearningModule> modules;
  final List<double> moduleValues;
  final double overall;
  final String title, subtitle;
  final VoidCallback onOpenProgress;
  final Widget? ticket;

  /// Title row above the ring (Learn tab title and reward pills).
  final Widget? top;

  /// "260 XP · 1 clover · from Daily Guides" under the legend.
  final String? rewards;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final on = p.onPrimary;
    final green = ClipPath(
      clipper: _CurveClipper(),
      child: ColoredBox(
        color: p.primary,
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -80,
              child: LearnIntroRise(
                from: 0,
                to: 500,
                rise: 0,
                scale: 0.4,
                curve: ElioMotion.pop,
                child: _Blob(size: 190, color: p.primaryHover),
              ),
            ),
            Positioned(
              left: -24,
              bottom: 30,
              child: LearnIntroRise(
                from: 80,
                to: 580,
                rise: 0,
                scale: 0.4,
                curve: ElioMotion.pop,
                child: _Blob(size: 64, color: p.primaryHover),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ELIOS 3: the page title sits on the green, under the status bar.
                if (top != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.paddingOf(context).top + 8,
                      0,
                      8,
                    ),
                    child: top,
                  ),
                Semantics(
                  button: true,
                  label: '$title. $subtitle',
                  excludeSemantics: true,
                  onTap: onOpenProgress,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onOpenProgress,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        4,
                        16,
                        ticket == null ? 36 : 84,
                      ),
                      child: Row(
                        children: [
                          LearnIntroRise(
                            from: 0,
                            to: 420,
                            rise: 0,
                            scale: 0.8,
                            curve: ElioMotion.pop,
                            child: KeyedSubtree(
                              key: TourKeys.learnRing,
                              child: _ModuleRing(
                                values: moduleValues,
                                tones: [
                                  for (final m in modules) moduleTone(m.id),
                                ],
                                overall: overall,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.toUpperCase(),
                                  style: context.text.labelSmall?.copyWith(
                                    color: on.withValues(alpha: 0.75),
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: context.text.titleLarge?.copyWith(
                                    color: on,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 4,
                                  children: [
                                    for (var i = 0; i < modules.length; i++)
                                      LearnIntroRise(
                                        from: 420 + i * 70,
                                        to: 720 + i * 70,
                                        rise: 6,
                                        scale: 0.6,
                                        curve: ElioMotion.pop,
                                        child: _LegendDot(
                                          color: toneFg(
                                            p,
                                            moduleTone(modules[i].id),
                                          ),
                                          label:
                                              '${binLabel(modules[i].id)} ${(moduleValues[i] * 100).round()}',
                                        ),
                                      ),
                                  ],
                                ),
                                if (rewards != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    rewards!,
                                    style: context.text.labelMedium?.copyWith(
                                      color: on,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ticket == null) return green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        green,
        _Lift(
          dy: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ticket,
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: p.surface, width: 1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.text.labelMedium?.copyWith(color: p.onPrimary),
        ),
      ],
    );
  }
}

/// Loading state of the hub: the empty curved header with the title, so the
/// Learn intro grows out of it instead of a different layout.
class LearnHeaderShell extends StatelessWidget {
  const LearnHeaderShell({super.key, required this.top});
  final Widget top;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ClipPath(
      clipper: _CurveClipper(),
      child: ColoredBox(
        color: p.primary,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 8,
            0,
            180,
          ),
          child: top,
        ),
      ),
    );
  }
}

class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(0, s.height - 40)
    ..quadraticBezierTo(s.width / 2, s.height + 28, s.width, s.height - 40)
    ..lineTo(s.width, 0)
    ..close();
  @override
  bool shouldReclip(_CurveClipper old) => false;
}

/// One ring split into the module thirds; each arc fills by that module's progress.
class _ModuleRing extends StatelessWidget {
  const _ModuleRing({
    required this.values,
    required this.tones,
    required this.overall,
  });
  final List<double> values;
  final List<LearnTone> tones;
  final double overall;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        color: p.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // Intro: each module arc sweeps in turn and the % counts up.
      child: LearnIntroSlice(
        from: 120,
        to: 760,
        builder: (context, t, _) => CustomPaint(
          painter: _RingPainter(
            values: values,
            colors: [for (final tone in tones) toneFg(p, tone)],
            sweep: t,
          ),
          child: Center(
            child: Text(
              '${(overall * 100 * t.clamp(0.0, 1.0)).round()}%',
              style: context.text.headlineSmall?.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.values, required this.colors, this.sweep = 1});
  final List<double> values;
  final List<Color> colors;

  /// Intro 0..1: arc i fills during its own slice, one after another.
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    const stroke = 10.0, gap = 0.16;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 7 - stroke / 2,
    );
    final part = 2 * math.pi / n;
    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * part + gap / 2;
      final sweep = part - gap;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        paint..color = colors[i].withValues(alpha: 0.18),
      );
      final own = ((sweep * (n + 1) - i) / 2).clamp(0.0, 1.0);
      final v = values[i].clamp(0.0, 1.0) * own;
      if (v > 0) {
        canvas.drawArc(rect, start, sweep * v, false, paint..color = colors[i]);
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.values != values || old.colors != colors || old.sweep != sweep;
}

/// Lays the child out normally but lifts it [dy] up over the previous sibling
/// and reports [dy] less height. Hit tests follow the painted position.
class _Lift extends SingleChildRenderObjectWidget {
  const _Lift({required this.dy, super.child});
  final double dy;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLift(dy);
  @override
  void updateRenderObject(BuildContext context, _RenderLift r) => r.dy = dy;
}

class _RenderLift extends RenderProxyBox {
  _RenderLift(this._dy);
  double _dy;
  set dy(double v) {
    if (v == _dy) return;
    _dy = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(
      Size(child!.size.width, math.max(0, child!.size.height - _dy)),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      context.paintChild(child!, offset.translate(0, -_dy));

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.translateByDouble(0.0, -_dy, 0.0, 1.0);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintOffset(
        offset: Offset(0, -_dy),
        position: position,
        hitTest: (r, p) => child!.hitTest(r, position: p),
      );
}

// ---------------------------------------------------------------- ticket

/// Today's Guide as a ticket: side notches, tear line, polaroid sticking out.
class GuideTicket extends ConsumerWidget {
  const GuideTicket({super.key, required this.guide, required this.onOpen});
  final DailyGuide guide;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final lang = guide.lang(guideLangOf(ref));
    final progress = ref.watch(
      guideProgressProvider.select((s) => s.of(guide.date)),
    );
    final done = progress.stopsDone;
    final title = guide.title[lang]!;
    return Semantics(
      container: true,
      label: context.l10n.g4TodayLabel(title, done),
      // Card 17: each new stop chimes and pops its dot; finishing the guide
      // tears the ticket stub, pops the XP sticker and sways the polaroid.
      child: RiseWatcher(
        value: done,
        onRise: (_, to) => to >= 3
            ? elioFeedback(ElioSfx.sparkle, ElioHaptics.success)
            : elioFeedback(ElioSfx.chime, ElioHaptics.select),
        builder: (context, bump) {
          final finished = done >= 3 ? bump : 0;
          // Intro: the ticket rises in, then its polaroid swings into place.
          return LearnIntroRise(
            from: 250,
            to: 650,
            rise: 32,
            scale: 0.96,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: ShapeDecoration(
                    color: p.surface,
                    shape: learnShape(26),
                    shadows: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: guideContinue(onOpen),
                      customBorder: learnShape(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(112, 14, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        guide.issue == null
                                            ? context.l10n.g4TodaysGuide
                                            : context.l10n.g4TodaysGuideIssue(
                                                guide.issue!,
                                              ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.text.labelSmall
                                            ?.copyWith(
                                              color: p.primaryText,
                                              letterSpacing: 1.2,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Replay(
                                      trigger: finished,
                                      duration: ElioMotion.celebrate,
                                      curve: ElioMotion.bounce,
                                      builder: (context, v, child) =>
                                          Transform.scale(
                                            scale: v,
                                            child: child,
                                          ),
                                      child: LearnIntroRise(
                                        from: 900,
                                        to: 1350,
                                        rise: 0,
                                        scale: 0,
                                        curve: ElioMotion.bounce,
                                        child: GuideChip(
                                          context.l10n.g4PlusXp(guide.xp.total),
                                          fill: p.secondaryText,
                                          color: p.surface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.titleMedium,
                                ),
                              ],
                            ),
                          ),
                          _TearLine(notch: p.background, line: p.borderMedium),
                          // The stub below the perforation slides 8 px and turns 2°.
                          TweenAnimationBuilder<double>(
                            tween: Tween(end: done >= 3 ? 1 : 0),
                            duration:
                                finished > 0 && !ElioMotion.reduced(context)
                                ? ElioMotion.slow
                                : Duration.zero,
                            curve: ElioMotion.emphasized,
                            builder: (context, v, child) => Transform.translate(
                              offset: Offset(8 * v, 0),
                              child: Transform.rotate(
                                angle: 2 * v * math.pi / 180,
                                alignment: Alignment.topLeft,
                                child: child,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                12,
                                14,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          done == 3
                                              ? context.l10n.g4AllStopsDone
                                              : context.l10n.g4StopsDoneNext(
                                                  done,
                                                  nextStopLabel(progress),
                                                ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.text.labelMedium
                                              ?.copyWith(
                                                color: p.textSecondary,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        LearnIntroSlice(
                                          from: 620,
                                          to: 1080,
                                          curve: Curves.linear,
                                          builder: (context, t, _) => _StopDots(
                                            done: done,
                                            bump: bump,
                                            reveal: t,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ExcludeSemantics(
                                    // Continue: squeeze (ElioPress), S2 + H-medium,
                                    // then the polaroid flies into the issue.
                                    child: ElioPress(
                                      pressed: 0.94,
                                      child: FilledButton(
                                        onPressed: guideContinue(onOpen),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(48, 44),
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            0,
                                            10,
                                            0,
                                          ),
                                          shape: const StadiumBorder(),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(context.l10n.lnContinue),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: -20,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Replay(
                        trigger: finished,
                        duration: ElioMotion.expressive,
                        builder: (context, v, child) => Transform.rotate(
                          angle: 3 * math.sin(v * 2 * math.pi) * math.pi / 180,
                          child: child,
                        ),
                        child: LearnIntroSlice(
                          from: 400,
                          to: 950,
                          curve: ElioMotion.pop,
                          builder: (context, t, child) => Transform.translate(
                            offset: Offset(-12 * (1 - t), -24 * (1 - t)),
                            child: Transform.rotate(
                              angle: -16 * (1 - t) * math.pi / 180,
                              child: child,
                            ),
                          ),
                          child: GuidePolaroidHero(
                            polaroid: GuidePolaroid(
                              guide: guide,
                              width: 86,
                              angle: -7,
                              thumb: true,
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
        },
      ),
    );
  }
}

class _TearLine extends StatelessWidget {
  const _TearLine({required this.notch, required this.line});
  final Color notch, line;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 24,
    child: CustomPaint(painter: _TearPainter(notch, line)),
  );
}

class _TearPainter extends CustomPainter {
  _TearPainter(this.notch, this.line);
  final Color notch, line;
  @override
  void paint(Canvas canvas, Size s) {
    final y = s.height / 2;
    final dash = Paint()
      ..color = line
      ..strokeWidth = 1.5;
    for (double x = 20; x < s.width - 20; x += 10) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 5, s.width - 20), y),
        dash,
      );
    }
    // Notches cut into the ticket only, never past its edge.
    canvas.clipRect(Offset.zero & s);
    final fill = Paint()..color = notch;
    canvas.drawCircle(Offset(0, y), 12, fill);
    canvas.drawCircle(Offset(s.width, y), 12, fill);
  }

  @override
  bool shouldRepaint(_TearPainter old) =>
      old.notch != notch || old.line != line;
}

class _StopDots extends StatelessWidget {
  const _StopDots({required this.done, this.bump = 0, this.reveal = 1});
  final int done, bump;

  /// Intro 0..1: the done stops fill one after another along the path.
  final double reveal;
  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final lit = done * reveal;
    Widget dot(int i) {
      final fill = (lit - i).clamp(0.0, 1.0);
      final isDone = i < done && fill > 0, now = i == done && reveal >= 1;
      final d = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDone ? p.primary : p.surface,
          border: isDone
              ? null
              : Border.all(color: now ? p.primary : p.borderMedium, width: 3),
          boxShadow: now
              ? [
                  BoxShadow(
                    color: p.primary.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: isDone
            ? Icon(Icons.check_rounded, size: 14, color: p.onPrimary)
            : null,
      );
      if (isDone && fill < 1) {
        return Transform.scale(
          scale: 0.4 + 0.6 * ElioMotion.pop.transform(fill),
          child: d,
        );
      }
      // The stop that was just done fills with spring/pop.
      if (i != done - 1) return d;
      return Replay(
        trigger: bump,
        duration: ElioMotion.slow,
        curve: ElioMotion.pop,
        builder: (context, v, child) =>
            Transform.scale(scale: 0.4 + 0.6 * v, child: child),
        child: d,
      );
    }

    Widget line(int i) {
      final bar = Container(
        height: 3,
        color: i <= done ? p.primary : p.borderSubtle,
      );
      if (reveal < 1 && i <= done) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Stack(
              children: [
                Container(height: 3, color: p.borderSubtle),
                FractionallySizedBox(
                  widthFactor: (lit - i + 1).clamp(0.0, 1.0),
                  child: bar,
                ),
              ],
            ),
          ),
        );
      }
      // The path to the stop just done draws in (ease/standard).
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: i != done
              ? bar
              : Stack(
                  children: [
                    Container(height: 3, color: p.borderSubtle),
                    Replay(
                      trigger: bump,
                      duration: ElioMotion.expressive,
                      curve: ElioMotion.standard,
                      builder: (context, v, child) =>
                          FractionallySizedBox(widthFactor: v, child: child),
                      child: bar,
                    ),
                  ],
                ),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[if (i > 0) line(i), dot(i)],
      ],
    );
  }
}

/// Continue into a guide: S2 seed pop and a firm tap, then [open].
VoidCallback guideContinue(VoidCallback open) => () {
  elioFeedback(ElioSfx.pop, ElioHaptics.medium);
  open();
};

// ---------------------------------------------------------------- bubbles

class LearnBubble {
  const LearnBubble({
    required this.label,
    required this.asset,
    required this.tone,
    required this.onTap,
    this.badge,
  });
  final String label, asset;
  final LearnTone tone;
  final VoidCallback onTap;
  final int? badge;
}

class LearnBubbles extends StatelessWidget {
  const LearnBubbles({super.key, required this.items});
  final List<LearnBubble> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 24, 12, 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, b) in items.indexed)
          Expanded(
            // Intro: bubbles pop in left to right (spring/pop).
            child: LearnIntroRise(
              from: 800 + 60 * i,
              to: 1200 + 60 * i,
              rise: 14,
              scale: 0.4,
              curve: ElioMotion.pop,
              child: _Bubble(b),
            ),
          ),
      ],
    ),
  );
}

/// Card 18: press scales 0.92 and springs back, the art hops 4 px; S2 + H-light.
/// A badge count change pops 1.4 → 1.
class _Bubble extends StatefulWidget {
  const _Bubble(this.b);
  final LearnBubble b;
  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final b = widget.b;
    final reduced = ElioMotion.reduced(context);
    void tap() {
      elioFeedback(ElioSfx.pop, ElioHaptics.light);
      b.onTap();
    }

    return Semantics(
      button: true,
      label: b.badge == null ? b.label : '${b.label}, ${b.badge}',
      excludeSemantics: true,
      onTap: tap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              AnimatedScale(
                scale: _down && !reduced ? 0.92 : 1,
                duration: _down ? ElioMotion.instant : ElioMotion.slow,
                curve: _down ? Curves.linear : ElioMotion.pop,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: toneBg(p, b.tone),
                        border: Border.all(
                          color: toneBorder(p, b.tone),
                          width: 2,
                        ),
                      ),
                      child: AnimatedSlide(
                        offset: Offset(0, _down && !reduced ? -0.1 : 0),
                        duration: _down ? ElioMotion.instant : ElioMotion.slow,
                        curve: ElioMotion.pop,
                        child: SvgPicture.asset(
                          b.asset,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                    if (b.badge != null && b.badge! > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: LearnIntroRise(
                          from: 1100,
                          to: 1400,
                          rise: 0,
                          scale: 0,
                          curve: ElioMotion.bounce,
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(b.badge),
                            tween: Tween(begin: reduced ? 1 : 1.4, end: 1),
                            duration: ElioMotion.slow,
                            curve: ElioMotion.pop,
                            builder: (context, s, child) =>
                                Transform.scale(scale: s, child: child),
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              height: 22,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              alignment: Alignment.center,
                              decoration: ShapeDecoration(
                                color: p.primary,
                                shape: StadiumBorder(
                                  side: BorderSide(color: p.surface, width: 2),
                                ),
                              ),
                              child: Text(
                                '${b.badge}',
                                style: context.text.labelSmall?.copyWith(
                                  color: p.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                b.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: captionStyle(context, p.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- explore

class ExploreItem {
  const ExploreItem({
    required this.title,
    required this.meta,
    required this.tag,
    required this.art,
    required this.tone,
    required this.progress,
    required this.sticker,
    required this.onTap,
    this.highlight = false,
    this.done = false,
  });
  final String title, meta, tag, sticker;
  final Widget art;
  final LearnTone tone;
  final double progress;
  final VoidCallback onTap;
  final bool highlight, done;
}

/// "Explore" with the squiggle, tabs with counts, and the skyline carousel.
class ExploreSection extends ConsumerWidget {
  const ExploreSection({
    super.key,
    required this.subtitle,
    required this.counts,
    required this.items,
    required this.onSeeAll,
    this.loading = false,
    this.initialPage = 0,
    this.onSettled,
  });

  final String subtitle;
  final Map<LearnExploreTab, int> counts;
  final List<ExploreItem> items;
  final VoidCallback? onSeeAll;
  final bool loading;

  /// First page for this tab (the open module on the Modules tab).
  final int initialPage;

  /// The page the carousel settled on after a swipe (card 19 / 20c).
  final ValueChanged<int>? onSettled;

  static String tabLabel(LearnExploreTab t) => switch (t) {
    LearnExploreTab.modules => l10n.lnModules,
    LearnExploreTab.videos => l10n.lnVideos,
    LearnExploreTab.simulations => l10n.lnSimulations,
    LearnExploreTab.guides => l10n.lnPdfGuides,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final tab = ref.watch(learnExploreTabProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.lnExplore,
                        style: context.text.displaySmall,
                      ),
                    ),
                    const LearnIntroSquiggle(from: 900, to: 1300, width: 104),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.text.labelMedium?.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: p.primaryText,
                  ),
                  child: Text(l10n.lnSeeAll),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final t in LearnExploreTab.values) ...[
                if (t != LearnExploreTab.modules) const SizedBox(width: 8),
                LearnIntroRise(
                  from: 900 + 40 * t.index,
                  to: 1250 + 40 * t.index,
                  rise: 0,
                  dx: 24,
                  child: LearnTabPill(
                    label: tabLabel(t),
                    count: counts[t],
                    selected: t == tab,
                    onTap: () =>
                        ref.read(learnExploreTabProvider.notifier).state = t,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: LearnSkeleton(height: 220),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LearnHintCard(text: l10n.lnNothingHere),
          )
        else
          _ExploreCarousel(
            key: ValueKey(tab),
            items: items,
            initialPage: initialPage.clamp(0, items.length - 1),
            onSettled: onSettled,
          ),
      ],
    );
  }
}

/// Card 19: the skyline carousel snaps per card with spring/soft; the card
/// snapped to the left is the focused one (the open module on Modules) and
/// shows at the Large size, neighbours at the Small size (152 / 204) and 90 %
/// opacity, bottom-aligned like Figma. Dots morph 6 → 18 px.
class _ExploreCarousel extends StatefulWidget {
  const _ExploreCarousel({
    super.key,
    required this.items,
    required this.initialPage,
    this.onSettled,
  });
  final List<ExploreItem> items;
  final int initialPage;
  final ValueChanged<int>? onSettled;

  @override
  State<_ExploreCarousel> createState() => _ExploreCarouselState();
}

class _ExploreCarouselState extends State<_ExploreCarousel> {
  static const _small = 152 / 204;
  late int _settled = widget.initialPage;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Column(
      children: [
        SnapRail(
          itemCount: items.length,
          first: 218,
          extent: 218,
          height: 276,
          initialIndex: _settled,
          onSnap: (i) {
            setState(() => _settled = i);
            widget.onSettled?.call(i);
          },
          itemBuilder: (context, i, d) {
            final t = d.clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Opacity(
                  opacity: 1 - 0.1 * t,
                  child: Transform.scale(
                    scale: 1 - (1 - _small) * t,
                    alignment: Alignment.bottomLeft,
                    child: LearnIntroRise(
                      from: 950 + 80 * i,
                      to: 1400,
                      rise: 40,
                      scale: 0.9,
                      curve: ElioMotion.pop,
                      alignment: Alignment.bottomLeft,
                      child: PopCard(item: items[i], large: true),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        if (items.length > 1)
          LearnPageDots(count: items.length, active: _settled),
      ],
    );
  }
}

/// Leaf-shaped card (corners 30/10/30/10) with the art popping out of the top
/// edge and a tilted progress sticker (Figma `Learn3 / Pop card` 569:5172).
class PopCard extends StatelessWidget {
  const PopCard({super.key, required this.item, this.large = false});
  final ExploreItem item;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final w = large ? 204.0 : 152.0;
    final h = large ? 262.0 : 214.0;
    final artH = large ? 112.0 : 84.0;
    final sticker = large ? 48.0 : 40.0;
    final fg = toneFg(p, item.tone);
    const leaf = BorderRadius.only(
      topLeft: Radius.circular(30),
      topRight: Radius.circular(10),
      bottomRight: Radius.circular(30),
      bottomLeft: Radius.circular(10),
    );
    final filled = item.done || item.progress > 0;
    return Semantics(
      button: true,
      label: '${item.tag}, ${item.title}, ${item.meta}, ${item.sticker}',
      excludeSemantics: true,
      onTap: item.onTap,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: 30,
              child: Material(
                color: Color.alphaBlend(fg.withValues(alpha: 0.10), p.surface),
                shape: RoundedSuperellipseBorder(
                  borderRadius: leaf,
                  side: BorderSide(
                    color: item.highlight
                        ? p.primary
                        : fg.withValues(alpha: 0.35),
                    width: item.highlight ? 2.5 : 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: item.onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: ShapeDecoration(
                            color: item.highlight ? p.primary : p.surface,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            item.tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall?.copyWith(
                              color: item.highlight
                                  ? p.onPrimary
                                  : p.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: large
                              ? context.text.titleMedium
                              : context.text.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: item.done
                                ? 1
                                : item.progress.clamp(0.0, 1.0),
                            minHeight: 6,
                            color: p.primary,
                            backgroundColor: p.surface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 0,
              child: IgnorePointer(
                child: SizedBox(
                  width: w - 28 - sticker / 2,
                  height: artH,
                  child: item.art,
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 14,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: 10 * math.pi / 180,
                  child: Container(
                    width: sticker,
                    height: sticker,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? p.primary : p.surface,
                      border: Border.all(color: p.surface, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0F172A,
                          ).withValues(alpha: 0.16),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          item.sticker,
                          style: context.text.labelMedium?.copyWith(
                            color: filled ? p.onPrimary : p.primaryText,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

/// Art for a card: an illustration, or a tilted photo frame for thumbnails.
Widget popArt({
  String? svg,
  String? url,
  String? fallback,
  bool rounded = false,
}) {
  if (svg != null) {
    final art = SvgPicture.asset(
      svg,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
    return Align(
      alignment: Alignment.bottomLeft,
      // Simulation canvases carry their own background; round it off.
      child: rounded
          ? ClipRRect(borderRadius: BorderRadius.circular(16), child: art)
          : art,
    );
  }
  return Align(
    alignment: Alignment.bottomLeft,
    child: Transform.rotate(
      angle: -4 * math.pi / 180,
      child: Builder(
        builder: (context) => Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.elio.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: LearnThumbnail(
                url: url ?? '',
                fallbackAsset: fallback ?? LearnArt.coverIntro,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Simulation done flags for the Explore tab.
Set<String> viewedSimulations(WidgetRef ref) =>
    ref.watch(physicsProgressProvider).valueOrNull?.viewedModuleIds.toSet() ??
    const {};

/// Sticker text and done flag for a lesson-like item.
({String text, bool done}) stickerFor(double progress, {bool done = false}) =>
    done || progress >= 1
    ? (text: '✓', done: true)
    : progress > 0
    ? (text: l10n.lnPctDone((progress * 100).round()), done: false)
    : (text: l10n.lnNew, done: false);

/// Content pop card sticker: Done, 40 %, or New.
String popSticker(double progress, {bool done = false}) => done || progress >= 1
    ? l10n.lnDone
    : progress > 0
    ? '${(progress * 100).round()}%'
    : l10n.lnNew;
