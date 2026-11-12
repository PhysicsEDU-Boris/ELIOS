// Shared pieces of the H1 v4 Home (decision 0144): card, art, bin colours and
// the two mini charts. Colours come from the palette only; the SVG art is fixed.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/home_stats.dart';
import '../../services/elio_feedback.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/auth/auth_widgets.dart' show authPalette;
import '../../widgets/history_ui.dart' show HistoryTone, historyTint;

const homeRadiusL = 20.0;
const homeRadiusM = 12.0;

Widget homeArt(String name, {double? width, double? height}) =>
    SvgPicture.asset(
      'assets/illustrations/home/$name.svg',
      width: width,
      height: height,
      excludeFromSemantics: true,
    );

OutlinedBorder homeShape(double radius, [Color? side]) =>
    RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: side == null ? BorderSide.none : BorderSide(color: side),
    );

/// Organic leaf corners (30 on one diagonal, 10 on the other).
const homeLeaf = BorderRadius.only(
  topLeft: Radius.circular(30),
  topRight: Radius.circular(10),
  bottomRight: Radius.circular(30),
  bottomLeft: Radius.circular(10),
);
const homeLeafFlip = BorderRadius.only(
  topLeft: Radius.circular(10),
  topRight: Radius.circular(30),
  bottomRight: Radius.circular(10),
  bottomLeft: Radius.circular(30),
);

/// Weight on the variable font: copyWith(fontWeight:) alone keeps the old
/// 'wght' axis, so bold text rendered regular.
TextStyle homeWeight(TextStyle s, int weight) => s.copyWith(
  fontWeight: FontWeight.values[weight ~/ 100 - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
);

/// Section title: 20 bold (Figma L3 Home).
TextStyle homeTitle(ElioPalette p) =>
    homeWeight(ElioTokens.subhead, 700).copyWith(color: p.textPrimary);

TextStyle homeOverline(Color color) =>
    ElioTokens.label.copyWith(color: color, letterSpacing: 1.6);

TextStyle homeSmall(ElioPalette p, {Color? color, FontWeight? weight}) {
  final s = ElioTokens.bodySmall.copyWith(color: color ?? p.textSecondary);
  return weight == null ? s : homeWeight(s, weight.value);
}

/// ELIOS/Caption 12 medium.
TextStyle homeCaption(ElioPalette p, {Color? color, int weight = 500}) =>
    homeWeight(
      ElioTokens.caption,
      weight,
    ).copyWith(color: color ?? p.textSecondary);

/// ELIOS/Headline numbers (28 bold by default).
TextStyle homeNumber(ElioPalette p, double size) =>
    ElioTokens.headline.copyWith(
      fontSize: size,
      letterSpacing: -0.01 * size,
      color: p.textPrimary,
    );

Color binColor(ElioPalette p, HomeBin b) => switch (b) {
  HomeBin.organik => p.primary,
  HomeBin.anorganik => p.tertiaryText,
  HomeBin.b3 => p.error,
};

/// Text colour on a light tint of [binColor].
Color binText(ElioPalette p, HomeBin b) => switch (b) {
  HomeBin.organik => p.primaryText,
  HomeBin.anorganik => p.tertiaryText,
  HomeBin.b3 => p.errorText,
};

class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.child,
    this.padding = 16,
    this.color,
  });

  final Widget child;
  final double padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? p.surface,
        shape: homeShape(homeRadiusL, color == null ? p.borderSubtle : null),
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}

class BinChip extends StatelessWidget {
  const BinChip(this.bin, {super.key});
  final HomeBin bin;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: binColor(p, bin).withValues(alpha: 0.12),
        shape: homeShape(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          bin.label,
          style: homeSmall(p, color: binText(p, bin), weight: FontWeight.w600),
        ),
      ),
    );
  }
}

class TrophyAmount extends StatelessWidget {
  const TrophyAmount(this.text, {super.key, this.chip = false});
  final String text;
  final bool chip;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.emoji_events_outlined,
          size: chip ? 14 : 16,
          color: p.secondaryText,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: chip
              ? homeCaption(p, color: p.secondaryText, weight: 700)
              : homeSmall(p, color: p.secondaryText, weight: FontWeight.w600),
        ),
      ],
    );
    if (!chip) return row;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: historyTint(p, HistoryTone.warning).bg,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: row,
      ),
    );
  }
}

/// Rounded horizontal progress bar.
class HomeBar extends StatelessWidget {
  const HomeBar({
    super.key,
    required this.value,
    required this.color,
    required this.track,
    this.height = 8,
  });
  final double value;
  final Color color, track;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: track),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0, 1).toDouble(),
            // A dot shows on an empty bar, like Figma.
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
          if (value <= 0)
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox.square(
                dimension: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Monday-first stacked bars of this week's scans, split by bin: 12 px
/// bars at the left of seven equal slots, a 4 px stub on days without scans.
/// [t] grows the bars from the baseline, one after the other.
class WeekBarsPainter extends CustomPainter {
  WeekBarsPainter(this.week, this.colors, {required this.stub, this.t = 1});
  final List<Map<HomeBin, int>> week;
  final Map<HomeBin, Color> colors;
  final Color stub;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final maxDay = week
        .map((d) => d.values.fold(0, (a, b) => a + b))
        .fold(0, math.max);
    final slot = size.width / 7;
    const barW = 12.0, r = Radius.circular(2);
    for (var i = 0; i < 7; i++) {
      final x = slot * i;
      final grow = ((t - i * 0.07) / 0.58).clamp(0.0, 1.0);
      final parts = [
        for (final b in HomeBin.values)
          if (week[i][b]! > 0) (b, week[i][b]!),
      ];
      if (parts.isEmpty) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - 4, barW, 4),
            r,
          ),
          Paint()..color = stub,
        );
        continue;
      }
      var y = size.height;
      for (var k = 0; k < parts.length; k++) {
        final h = math.max(
          size.height *
              parts[k].$2 /
              maxDay *
              Curves.easeOutCubic.transform(grow),
          k == 0 ? 4.0 : 0.0,
        );
        final top = k == parts.length - 1 ? r : Radius.zero;
        final bottom = k == 0 ? r : Radius.zero;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, y - h, barW, h),
            topLeft: top,
            topRight: top,
            bottomLeft: bottom,
            bottomRight: bottom,
          ),
          Paint()..color = colors[parts[k].$1]!,
        );
        y -= h;
      }
    }
  }

  @override
  bool shouldRepaint(WeekBarsPainter old) =>
      old.week != week || old.colors != colors || old.t != t;
}

/// Quiz % per scan (0..100), oldest first; [t] draws the line left → right.
class SparklinePainter extends CustomPainter {
  SparklinePainter(this.points, this.line, {this.t = 1});
  final List<int> points;
  final Color line;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || t <= 0) return;
    // 2 px inset keeps the round caps inside (Figma 629:80643).
    final w = size.width - 4, h = size.height - 4;
    Offset at(int i) => Offset(
      2 + (points.length == 1 ? w / 2 : w * i / (points.length - 1)),
      2 + h - h * points[i] / 100,
    );
    final paint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    if (points.length == 1) {
      canvas.drawCircle(at(0), 3, Paint()..color = line);
      return;
    }
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t.clamp(0.0, 1.0)), paint);
    }
  }

  @override
  bool shouldRepaint(SparklinePainter old) =>
      old.points != points || old.line != line || old.t != t;
}

/// A 2 px round stroke along [path], which is drawn in a 390-wide design
/// space (x is scaled to the widget); [t] draws it left → right.
class HomeStrokePainter extends CustomPainter {
  HomeStrokePainter(this.path, this.color, {this.t = 1});
  final Path path;
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final scaled = path.transform(
      Matrix4.diagonal3Values(size.width / 390, 1, 1).storage,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final m in scaled.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t.clamp(0.0, 1.0)), paint);
    }
  }

  @override
  bool shouldRepaint(HomeStrokePainter old) => old.color != color || old.t != t;
}

// ---------------------------------------------------------------- motion

/// [a] over [from]..[to], shaped by [curve]; [to] may run past 1.
double homeSlice(
  Animation<double> a,
  double from,
  double to, [
  Curve curve = ElioMotion.emphasized,
]) {
  final x = ((a.value - from) / (to - from)).clamp(0.0, 1.0);
  return x >= 1 ? 1 : curve.transform(x);
}

/// Entrance move over [from]..[to] of [a]: fades in while it settles from
/// [dx]/[rise] px away, [turn] radians off and [scale] small. At rest (and
/// under reduced motion, where [a] is complete) it is just the child.
class HomeRise extends StatelessWidget {
  const HomeRise(
    this.a,
    this.from,
    this.to, {
    super.key,
    required this.child,
    this.rise = 16,
    this.dx = 0,
    this.scale = 1,
    this.turn = 0,
    this.curve = ElioMotion.emphasized,
    this.alignment = Alignment.center,
  });
  final Animation<double> a;
  final double from, to, rise, dx, scale, turn;
  final Curve curve;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: a,
    child: child,
    builder: (context, child) {
      final x = homeSlice(a, from, to, Curves.linear);
      final t = x >= 1 ? 1.0 : curve.transform(x);
      return Opacity(
        opacity: (x * 2.5).clamp(0.0, 1.0),
        // Screen readers get the content before it is scrolled into view.
        alwaysIncludeSemantics: true,
        child: Transform.translate(
          offset: Offset(dx * (1 - t), rise * (1 - t)),
          child: Transform.rotate(
            angle: turn * (1 - t),
            alignment: alignment,
            child: Transform.scale(
              scale: scale + (1 - scale) * t,
              alignment: alignment,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// Runs a 0..1 timeline the first time its child scrolls into view; when it
/// is already in view as Home opens it waits [delay] first. [seen] keeps the
/// ids that already played, so a rebuilt section (search opened and closed)
/// does not replay. [cues] fire once as the timeline passes their position.
class HomeReveal extends StatefulWidget {
  const HomeReveal({
    super.key,
    required this.id,
    required this.seen,
    required this.builder,
    this.duration = const Duration(milliseconds: 900),
    this.delay = Duration.zero,
    this.cues = const [],
  });
  final Object id;
  final Set<Object> seen;
  final Duration duration, delay;
  final List<(double, VoidCallback)> cues;
  final Widget Function(BuildContext context, Animation<double> a) builder;

  @override
  State<HomeReveal> createState() => _HomeRevealState();
}

class _HomeRevealState extends State<HomeReveal>
    with SingleTickerProviderStateMixin {
  // Not lazy: dispose() must not be the first to touch it.
  late final AnimationController _c;
  Animation<double> _a = kAlwaysCompleteAnimation;
  ScrollPosition? _pos;
  bool _init = false, _first = true, _queued = false;
  int _cue = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    if (widget.seen.contains(widget.id) || ElioMotion.reduced(context)) return;
    _a = _c..addListener(_cues);
    _pos = Scrollable.maybeOf(context)?.position?..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _check();
      _first = false;
    });
  }

  // A scroll event comes before its frame: look once that frame is laid out.
  void _onScroll() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      _check();
    });
  }

  void _check() {
    if (!mounted || _c.isAnimating || _c.value > 0) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    // Starts once a good part shows above the bottom bar.
    final line =
        MediaQuery.sizeOf(context).height -
        96 -
        math.min(box.size.height * 0.3, 120);
    if (top > line) return;
    _pos?.removeListener(_onScroll);
    widget.seen.add(widget.id);
    if (_first && widget.delay > Duration.zero) {
      final total = widget.delay + widget.duration;
      _c.duration = total;
      setState(
        () => _a = CurvedAnimation(
          parent: _c,
          curve: Interval(
            widget.delay.inMicroseconds / total.inMicroseconds,
            1,
          ),
        ),
      );
    }
    _c.forward();
  }

  void _cues() {
    while (_cue < widget.cues.length && _a.value >= widget.cues[_cue].$1) {
      widget.cues[_cue++].$2();
    }
  }

  @override
  void dispose() {
    _pos?.removeListener(_onScroll);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _a);
}

/// Row thumbnail (Figma 739:30806): 70 × 44 surface frame, the cover inset 3
/// with radius 7. Search results and the selected day's scans.
class HomeThumb extends StatelessWidget {
  const HomeThumb({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Container(
      width: 70,
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.borderSubtle),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: ColoredBox(
          color: p.surfaceRaised,
          child: SizedBox.expand(child: ExcludeSemantics(child: child)),
        ),
      ),
    );
  }
}

/// Tap reaction: the child springs (scale ±[amp], wobble ±[turn] radians,
/// 500 ms) with [sfx] and [haptic]. Reduced motion keeps only the feedback.
class HomeBoing extends StatefulWidget {
  const HomeBoing({
    super.key,
    required this.child,
    this.amp = 0.1,
    this.turn = 0,
    this.sfx = ElioSfx.pop,
    this.haptic = ElioHaptics.light,
    this.alignment = Alignment.center,
  });
  final Widget child;
  final double amp, turn;
  final ElioSfx sfx;
  final void Function() haptic;
  final Alignment alignment;

  @override
  State<HomeBoing> createState() => _HomeBoingState();
}

class _HomeBoingState extends State<HomeBoing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    elioFeedback(widget.sfx, widget.haptic);
    if (!ElioMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _tap,
    child: AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value, fade = 1 - t;
        return Transform.rotate(
          angle: widget.turn * math.sin(t * math.pi * 4) * fade,
          alignment: widget.alignment,
          child: Transform.scale(
            scale: 1 + widget.amp * math.sin(t * math.pi * 3) * fade,
            alignment: widget.alignment,
            child: child,
          ),
        );
      },
    ),
  );
}
