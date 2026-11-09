// Learn hub L2 v3 "organic" (Figma 570:5147, decision 0195): curved green
// header, Today's Guide ticket, shortcut bubbles, Explore with leaf cards.
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
import '../../../theme/elio_tokens.dart';
import '../../../widgets/learn/learn_ui.dart';
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

Color toneFg(ElioPalette p, LearnTone t) => switch (t) {
  LearnTone.success => p.primaryText,
  LearnTone.warning => p.secondaryText,
  LearnTone.error => p.errorText,
  LearnTone.info => p.tertiaryText,
  LearnTone.neutral => p.textSecondary,
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
  });

  final List<ElearningModule> modules;
  final List<double> moduleValues;
  final double overall;
  final String title, subtitle;
  final VoidCallback onOpenProgress;
  final Widget? ticket;

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
              child: _Blob(size: 190, color: p.primaryHover),
            ),
            Positioned(
              left: -24,
              bottom: 30,
              child: _Blob(size: 64, color: p.primaryHover),
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
                      _ModuleRing(
                        values: moduleValues,
                        tones: [for (final m in modules) moduleTone(m.id)],
                        overall: overall,
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
                                  _LegendDot(
                                    color: toneFg(p, moduleTone(modules[i].id)),
                                    label:
                                        '${binLabel(modules[i].id)} ${(moduleValues[i] * 100).round()}',
                                  ),
                              ],
                            ),
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
      child: CustomPaint(
        painter: _RingPainter(
          values: values,
          colors: [for (final t in tones) toneFg(p, t)],
        ),
        child: Center(
          child: Text(
            '${(overall * 100).round()}%',
            style: context.text.headlineSmall?.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;

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
      final v = values[i].clamp(0.0, 1.0);
      if (v > 0) {
        canvas.drawArc(rect, start, sweep * v, false, paint..color = colors[i]);
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.values != values || old.colors != colors;
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
      label: l10n.g4TodayLabel(title, done),
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
                onTap: onOpen,
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
                                      ? l10n.g4TodaysGuide
                                      : l10n.g4TodaysGuideIssue(guide.issue!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelSmall?.copyWith(
                                    color: p.primaryText,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              GuideChip(
                                l10n.g4PlusXp(guide.xp.total),
                                fill: p.secondaryText,
                                color: p.surface,
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  done == 3
                                      ? l10n.g4AllStopsDone
                                      : l10n.g4StopsDoneNext(
                                          done,
                                          nextStopLabel(progress),
                                        ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelMedium?.copyWith(
                                    color: p.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _StopDots(done: done),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ExcludeSemantics(
                            child: FilledButton(
                              onPressed: onOpen,
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
                                  Text(l10n.lnContinue),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                child: GuidePolaroid(
                  guide: guide,
                  width: 86,
                  angle: -7,
                  thumb: true,
                ),
              ),
            ),
          ),
        ],
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
  const _StopDots({required this.done});
  final int done;
  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    Widget dot(int i) {
      final isDone = i < done, now = i == done;
      return Container(
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
    }

    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                color: i <= done ? p.primary : p.borderSubtle,
              ),
            ),
          dot(i),
        ],
      ],
    );
  }
}

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
  Widget build(BuildContext context) {
    final p = context.elio;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in items)
            Expanded(
              child: Semantics(
                button: true,
                label: b.badge == null ? b.label : '${b.label}, ${b.badge}',
                excludeSemantics: true,
                onTap: b.onTap,
                child: InkWell(
                  onTap: b.onTap,
                  customBorder: learnShape(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: toneFg(
                                  p,
                                  b.tone,
                                ).withValues(alpha: 0.10),
                                border: Border.all(
                                  color: toneFg(
                                    p,
                                    b.tone,
                                  ).withValues(alpha: 0.35),
                                  width: 2,
                                ),
                              ),
                              child: SvgPicture.asset(
                                b.asset,
                                excludeFromSemantics: true,
                              ),
                            ),
                            if (b.badge != null && b.badge! > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 22,
                                  ),
                                  height: 22,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: ShapeDecoration(
                                    color: p.errorText,
                                    shape: StadiumBorder(
                                      side: BorderSide(
                                        color: p.surface,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${b.badge}',
                                    style: context.text.labelSmall?.copyWith(
                                      color: p.surface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          b.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelMedium?.copyWith(
                            color: p.textPrimary,
                          ),
                        ),
                      ],
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
  });

  final String subtitle;
  final Map<LearnExploreTab, int> counts;
  final List<ExploreItem> items;
  final VoidCallback? onSeeAll;
  final bool loading;

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
                        style: context.text.headlineMedium,
                      ),
                    ),
                    SizedBox(
                      width: 104,
                      height: 10,
                      child: CustomPaint(painter: _SquigglePainter(p.primary)),
                    ),
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
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
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
                _TabPill(
                  label: tabLabel(t),
                  count: counts[t],
                  selected: t == tab,
                  onTap: () =>
                      ref.read(learnExploreTabProvider.notifier).state = t,
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
          SingleChildScrollView(
            key: ValueKey(tab),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  PopCard(item: items[i], large: i == 0),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final fg = selected ? p.onPrimary : p.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? p.primary : p.surface,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : BorderSide(color: p.borderSubtle),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: context.text.labelLarge?.copyWith(color: fg),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: ShapeDecoration(
                        color: selected ? p.surface : p.surfaceRaised,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        '$count',
                        style: context.text.labelSmall?.copyWith(
                          color: selected ? p.primaryText : p.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()..moveTo(2, s.height * 0.6);
    const waves = 4;
    final w = (s.width - 4) / waves;
    for (var i = 0; i < waves; i++) {
      final x = 2 + i * w;
      path.quadraticBezierTo(
        x + w / 4,
        i.isEven ? 0 : s.height,
        x + w / 2,
        s.height * 0.6,
      );
      path.quadraticBezierTo(
        x + 3 * w / 4,
        i.isEven ? s.height : 0,
        x + w,
        s.height * 0.6,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SquigglePainter old) => old.color != color;
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
