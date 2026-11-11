// Learn L3 building blocks (Figma ELIOS 3 · 04 Learn, decision 0206): curved
// header, round buttons, stickers, stat bubbles, leaf shapes, the ELIO robot
// buddy and the content pop card. Colours come only from [ElioPalette].
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/elio_feedback.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_tokens.dart';
import 'learn_ui.dart';

const _deg = math.pi / 180;

/// Leaf corners 30/10/30/10 (cards) and 22/8/22/8 (rows, answers, results).
const leafL = BorderRadius.only(
  topLeft: Radius.circular(30),
  topRight: Radius.circular(10),
  bottomRight: Radius.circular(30),
  bottomLeft: Radius.circular(10),
);
const leafS = BorderRadius.only(
  topLeft: Radius.circular(22),
  topRight: Radius.circular(8),
  bottomRight: Radius.circular(22),
  bottomLeft: Radius.circular(8),
);

Color toneFg(ElioPalette p, LearnTone t) => switch (t) {
  LearnTone.success => p.primaryText,
  LearnTone.warning => p.secondaryText,
  LearnTone.error => p.errorText,
  LearnTone.info => p.tertiaryText,
  LearnTone.neutral => p.textSecondary,
};

/// `color/chip/<tone>-bg`: the tone over the surface, tuned per mode.
Color toneBg(ElioPalette p, LearnTone t) =>
    Color.alphaBlend(toneFg(p, t).withValues(alpha: 0.10), p.surface);

/// `color/chip/<tone>-border` at 35 %.
Color toneBorder(ElioPalette p, LearnTone t) =>
    toneFg(p, t).withValues(alpha: 0.35);

TextStyle captionStyle(BuildContext context, [Color? color]) =>
    ElioTokens.caption.copyWith(color: color ?? context.elio.textSecondary);

/// Drop shadow of polaroids and stickers (same in Light and Dark).
const l3Shadow = [
  BoxShadow(color: Color(0x240F172A), blurRadius: 14, offset: Offset(0, 6)),
];

// ---------------------------------------------------------------- robot

/// Art/ELIO robot buddy (Figma 674:26769).
enum RobotMood { happy, excited, thinking, talking, sad, searching, sleepy }

class RobotBuddy extends StatelessWidget {
  const RobotBuddy({super.key, this.mood = RobotMood.happy, this.height = 64});
  final RobotMood mood;
  final double height;

  static String asset(RobotMood m) =>
      'assets/illustrations/robot/robot_${m.name}.svg';

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: ElioMotion.fast,
    child: SvgPicture.asset(
      asset(mood),
      key: ValueKey(mood),
      height: height,
      width: height * 56 / 64,
      excludeFromSemantics: true,
    ),
  );
}

// ---------------------------------------------------------------- header

/// Curved green header: an 880 px wide ellipse whose bottom edge sits at
/// [curveBottom], plus the fill-hover bubbles. [child] paints on top.
class L3Hero extends StatelessWidget {
  const L3Hero({
    super.key,
    required this.curveBottom,
    required this.child,
    this.radiusY = 280,
    this.bubble = 150,
    this.sparkles = const [],
  });

  final double curveBottom, radiusY, bubble;
  final Widget child;

  /// Sparkle positions as (left, top, size).
  final List<(double, double, double)> sparkles;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: curveBottom,
          child: CustomPaint(
            painter: _CurvePainter(p.primary, p.primaryHover, radiusY, bubble),
          ),
        ),
        for (final (x, y, s) in sparkles)
          Positioned(
            left: x,
            top: y,
            child: Icon(Icons.auto_awesome, size: s, color: p.onPrimary),
          ),
        child,
      ],
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter(this.fill, this.hover, this.ry, this.bubble);
  final Color fill, hover;
  final double ry, bubble;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.clipRect(Rect.fromLTWH(0, -400, s.width, s.height + 400));
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s.width / 2, s.height - ry),
        width: 880,
        height: ry * 2,
      ),
      Paint()..color = fill,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & s);
    canvas.drawCircle(
      Offset(s.width - 110 + bubble / 2, -60 + bubble / 2),
      bubble / 2,
      Paint()..color = hover,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CurvePainter o) =>
      o.fill != fill || o.hover != hover || o.ry != ry || o.bubble != bubble;
}

/// QQ / Round button (Back, Close, Volume, Search, Share): 48 px surface circle.
class L3RoundButton extends StatelessWidget {
  const L3RoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ElioPress(
      pressed: 0.92,
      child: Material(
        color: p.surface,
        shape: CircleBorder(side: BorderSide(color: p.borderSubtle)),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap == null
              ? null
              : () {
                  elioFeedback(ElioSfx.pop, ElioHaptics.light);
                  onTap!();
                },
          icon: Icon(icon, size: 22, color: p.textPrimary),
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        ),
      ),
    );
  }
}

/// The back button every L3 sub-page shows.
class L3BackButton extends StatelessWidget {
  const L3BackButton({super.key});
  @override
  Widget build(BuildContext context) => L3RoundButton(
    icon: Icons.arrow_back_rounded,
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onTap: () => Navigator.of(context).maybePop(),
  );
}

/// QQ / Squiggle under headings.
class LearnSquiggle extends StatelessWidget {
  const LearnSquiggle({
    super.key,
    this.width = 120,
    this.color,
    this.progress = 1,
  });
  final double width;
  final Color? color;

  /// 0..1 of the line drawn, left to right.
  final double progress;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 9,
    child: CustomPaint(
      painter: _SquigglePainter(color ?? context.elio.primary, progress),
    ),
  );
}

/// A squiggle that draws itself in during the Learn intro.
class LearnIntroSquiggle extends StatelessWidget {
  const LearnIntroSquiggle({
    super.key,
    required this.from,
    required this.to,
    this.width = 120,
    this.color,
  });
  final int from, to;
  final double width;
  final Color? color;
  @override
  Widget build(BuildContext context) => LearnIntroSlice(
    from: from,
    to: to,
    curve: ElioMotion.standard,
    builder: (context, t, _) =>
        LearnSquiggle(width: width, color: color, progress: t),
  );
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter(this.color, [this.progress = 1]);
  final Color color;
  final double progress;
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()..moveTo(2, s.height * 0.6);
    final waves = math.max(2, (s.width / 26).round());
    final w = (s.width - 4) / waves;
    for (var i = 0; i < waves; i++) {
      final x = 2 + i * w;
      path.quadraticBezierTo(x + w / 4, 0, x + w / 2, s.height * 0.6);
      path.quadraticBezierTo(x + 3 * w / 4, s.height, x + w, s.height * 0.6);
    }
    if (progress <= 0) return;
    final shown = progress >= 1
        ? path
        : (Path()..addPath(
            path.computeMetrics().first.extractPath(
              0,
              path.computeMetrics().first.length * progress,
            ),
            Offset.zero,
          ));
    canvas.drawPath(
      shown,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SquigglePainter old) =>
      old.color != color || old.progress != progress;
}

/// Overline, Headline title and squiggle (module, lesson, simulation).
class L3TitleBlock extends StatelessWidget {
  const L3TitleBlock({
    super.key,
    required this.overline,
    required this.title,
    this.overlineColor,
    this.titleColor,
    this.squiggle = 200,
    this.squiggleColor,
  });
  final String overline, title;
  final Color? overlineColor, titleColor, squiggleColor;
  final double squiggle;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: overlineColor ?? p.primaryText,
          ),
        ),
        const SizedBox(height: 2),
        Semantics(
          header: true,
          child: Text(
            title,
            style: context.text.displaySmall?.copyWith(
              color: titleColor ?? p.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        LearnSquiggle(width: squiggle, color: squiggleColor),
      ],
    );
  }
}

/// Section title with squiggle and an optional trailing action (Figma
/// "Section · Lessons"): Headline text, squiggle, action on the right.
class L3SectionTitle extends StatelessWidget {
  const L3SectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.squiggle = 110,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final double squiggle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: context.text.displaySmall),
            ),
            LearnSquiggle(width: squiggle),
          ],
        ),
      ),
      if (action != null)
        onAction == null
            ? Text(
                action!,
                style: context.text.labelLarge?.copyWith(
                  color: context.elio.primaryText,
                ),
              )
            : TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: context.elio.primaryText,
                ),
                child: Text(action!),
              ),
    ],
  );
}

/// Rail / archive header: Subhead title, Caption subtitle, See all.
class L3RailHeader extends StatelessWidget {
  const L3RailHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onSeeAll,
    this.seeAll,
  });
  final String title, subtitle;
  final String? seeAll;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: context.text.titleLarge),
            ),
            AnimatedSwitcher(
              duration: ElioMotion.fast,
              child: Text(
                subtitle,
                key: ValueKey(subtitle),
                style: captionStyle(context),
              ),
            ),
          ],
        ),
      ),
      if (onSeeAll != null && seeAll != null)
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: context.elio.primaryText,
          ),
          child: Text(seeAll!),
        ),
    ],
  );
}

/// Tilted stadium sticker on the surface ("Beginner friendly", "Selesai").
class L3Sticker extends StatelessWidget {
  const L3Sticker({
    super.key,
    required this.label,
    this.angle = -4,
    this.color,
    this.icon,
    this.border = false,
  });
  final String label;
  final double angle;
  final Color? color;
  final IconData? icon;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final fg = color ?? p.primaryText;
    return Transform.rotate(
      angle: angle * _deg,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: ShapeDecoration(
          color: p.surface,
          shape: StadiumBorder(
            side: border ? BorderSide(color: p.borderSubtle) : BorderSide.none,
          ),
          shadows: l3Shadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 4),
            ],
            Text(label, style: context.text.labelLarge?.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Round percentage / New / Done sticker (56 or 60 px, tilted).
class L3RoundSticker extends StatelessWidget {
  const L3RoundSticker({
    super.key,
    required this.label,
    this.size = 56,
    this.angle = 12,
    this.big = false,
  });
  final String label;
  final double size, angle;

  /// Subhead text (hero percentage stickers) instead of Button.
  final bool big;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Transform.rotate(
      angle: angle * _deg,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.surface,
          border: Border.all(color: p.borderSubtle),
          boxShadow: l3Shadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            child: Text(
              label,
              style: (big ? context.text.titleLarge : context.text.labelLarge)
                  ?.copyWith(color: p.primaryText),
            ),
          ),
        ),
      ),
    );
  }
}

/// One stat bubble (lesson and simulation pages).
class L3Stat {
  const L3Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
    this.count,
  });
  final IconData icon;
  final String value, label;
  final LearnTone tone;

  /// Counts up once (ElioCountUp) when set; [value] is then a template where
  /// `#` is the number.
  final int? count;
}

class L3StatBubbles extends StatelessWidget {
  const L3StatBubbles({super.key, required this.stats});
  final List<L3Stat> stats;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    Widget one(L3Stat s) {
      final value = s.count == null
          ? Text(s.value, style: context.text.titleLarge)
          : ElioCountUp(
              value: s.count!,
              duration: ElioMotion.slow,
              builder: (context, v) => Text(
                s.value.replaceFirst('#', '$v'),
                style: context.text.titleLarge,
              ),
            );
      return Semantics(
        label: '${s.label}: ${s.value.replaceFirst('#', '${s.count}')}',
        excludeSemantics: true,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: toneBg(p, s.tone),
              ),
              child: Icon(s.icon, size: 24, color: toneFg(p, s.tone)),
            ),
            const SizedBox(height: 4),
            FittedBox(child: value),
            Text(s.label, style: captionStyle(context)),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final s in stats) Flexible(child: one(s))],
    );
  }
}

/// Learn2 / Tab pill with an optional count.
class LearnTabPill extends StatelessWidget {
  const LearnTabPill({
    super.key,
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
          onTap: () {
            if (!selected) elioFeedback(ElioSfx.tick, ElioHaptics.select);
            onTap();
          },
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 6, count == null ? 14 : 8, 6),
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

/// QQ / Button: 56 px pill, Subhead label, chevron. Disabled = 40 % opacity.
class L3Button extends StatelessWidget {
  const L3Button({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.chevron = true,
    this.height = 56,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, chevron;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final fg = secondary ? p.textPrimary : p.onPrimary;
    final enabled = onPressed != null;
    return AnimatedOpacity(
      duration: ElioMotion.fast,
      opacity: enabled ? 1 : 0.4,
      child: ElioPress(
        pressed: 0.97,
        child: Material(
          color: secondary ? p.surface : p.primary,
          shape: StadiumBorder(
            side: secondary
                ? BorderSide(color: p.borderMedium, width: 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: enabled
                ? () {
                    elioFeedback(ElioSfx.pop, ElioHaptics.medium);
                    onPressed!();
                  }
                : null,
            child: SizedBox(
              height: height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (height >= 56
                                  ? context.text.titleLarge
                                  : context.text.labelLarge)
                              ?.copyWith(color: fg),
                    ),
                  ),
                  if (chevron) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, size: 22, color: fg),
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

// ---------------------------------------------------------------- pop card

enum PopKind { video, guide, simulation, quiz }

LearnTone? popTone(PopKind k) => switch (k) {
  PopKind.video => LearnTone.success,
  PopKind.guide => LearnTone.warning,
  PopKind.simulation => LearnTone.info,
  PopKind.quiz => null,
};

/// L3 / Content pop card (Figma 688:28286, cards 20c and 20d). [entrance]
/// plays the module-sync pop-in after that delay; null shows it at rest.
class ContentPopCard extends StatefulWidget {
  const ContentPopCard({
    super.key,
    required this.kind,
    required this.tag,
    required this.title,
    required this.meta,
    required this.cover,
    required this.progress,
    required this.onTap,
    this.sticker,
    this.large = false,
    this.entrance,
    this.highlight = false,
  });

  final PopKind kind;
  final String tag, title, meta;
  final Widget cover;
  final double progress;
  final VoidCallback onTap;

  /// "New", "40%", "Done"; null hides it.
  final String? sticker;
  final bool large, highlight;
  final Duration? entrance;

  @override
  State<ContentPopCard> createState() => _ContentPopCardState();
}

class _ContentPopCardState extends State<ContentPopCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this);
  bool _pressed = false;
  bool _started = false;

  static const _popS = 0.38; // spring/pop ~380 ms
  static const _stickerS = 0.6;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final delay = widget.entrance;
    if (delay == null) {
      _atRest = true;
      _in.value = 1;
      return;
    }
    final reduced = ElioMotion.reduced(context);
    final total = reduced
        ? ElioMotion.fast
        : delay + Duration(milliseconds: ((_popS + _stickerS) * 1000).round());
    _in.duration = total;
    _delayFrac = reduced ? 0 : delay.inMicroseconds / total.inMicroseconds;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _in.forward();
    });
  }

  double _delayFrac = 0;
  bool _atRest = false;

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  /// Local 0..1 of a phase that starts after the delay, offset by [from]
  /// seconds and lasting [len] seconds.
  double _phase(double from, double len) {
    final t = _in.value;
    if (_atRest || _in.isCompleted) return 1;
    if (_delayFrac >= 1) return t;
    final total = _in.duration?.inMicroseconds ?? 1;
    final sec = (t - _delayFrac) * total / 1e6;
    return ((sec - from) / len).clamp(0.0, 1.0);
  }

  void _down() {
    setState(() => _pressed = true);
    ElioHaptics.light();
  }

  void _up() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final reduced = ElioMotion.reduced(context);
    final large = widget.large;
    final w = large ? 212.0 : 164.0;
    final h = large ? 257.0 : 233.0;
    final bodyTop = large ? 50.0 : 40.0;
    final thumbW = large ? 164.0 : 124.0;
    final thumbH = large ? 96.0 : 73.0;
    final sticker = large ? 56.0 : 48.0;
    final tone = popTone(widget.kind);
    final bg = tone == null ? p.surface : toneBg(p, tone);
    final edge = widget.highlight
        ? BorderSide(color: p.primary, width: 2.5)
        : BorderSide(
            color: tone == null ? p.borderMedium : toneBorder(p, tone),
            width: 1.5,
          );
    // Pressed overlay: text/primary 4 % in Light, surface 8 % in Dark.
    final overlay = p.isDark
        ? p.surface.withValues(alpha: 0.08)
        : p.textPrimary.withValues(alpha: 0.04);

    return Semantics(
      button: true,
      label: [
        widget.tag,
        widget.title,
        widget.meta,
        if (widget.sticker != null) widget.sticker!,
      ].join(', '),
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        onTapDown: (_) => _down(),
        onTapCancel: _up,
        onTapUp: (_) => _up(),
        onTap: () {
          unawaited(ElioSound.instance.play(ElioSfx.pop));
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _in,
          builder: (context, _) {
            final cardT = reduced
                ? _in.value
                : ElioMotion.pop.transform(_phase(0, _popS));
            final fade = reduced ? _in.value : _phase(0, 0.12);
            final thumbT = reduced
                ? 1.0
                : ElioMotion.pop.transform(_phase(0.06, _popS));
            final stickT = reduced
                ? 1.0
                : ElioMotion.bounce.transform(_phase(_popS * 0.7, _stickerS));
            final scale = reduced ? 1.0 : 0.6 + 0.4 * cardT;
            final thumbAngle =
                (-12 + 8 * thumbT) + (_pressed ? -3 : 0); // −12 → −4 (−7 held)
            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: AnimatedScale(
                  scale: _pressed ? 0.97 : 1,
                  duration: _pressed ? ElioMotion.instant : ElioMotion.slow,
                  curve: _pressed ? Curves.linear : ElioMotion.soft,
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          top: bodyTop,
                          width: w - 8,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: Color.alphaBlend(
                                _pressed ? overlay : Colors.transparent,
                                bg,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: leafL,
                                side: edge,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 12, 17),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _TypeTag(widget.tag),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.titleLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.meta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.labelLarge?.copyWith(
                                      color: p.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _Bar(value: widget.progress),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          top:
                              (reduced ? 0 : 24 * (1 - thumbT)) -
                              (_pressed ? 4 : 0),
                          child: AnimatedRotation(
                            turns: thumbAngle / 360,
                            duration: _pressed
                                ? ElioMotion.instant
                                : (_in.isAnimating
                                      ? Duration.zero
                                      : ElioMotion.slow),
                            curve: ElioMotion.soft,
                            child: _Thumb(
                              width: thumbW,
                              height: thumbH,
                              cover: widget.cover,
                              play: widget.kind == PopKind.video,
                            ),
                          ),
                        ),
                        if (widget.sticker != null)
                          Positioned(
                            left: large ? 152 : 112,
                            top: large ? 26 : 16,
                            child: Transform.scale(
                              scale: stickT,
                              // A lesson turning Done swaps it (spring/pop).
                              child: AnimatedSwitcher(
                                duration: ElioMotion.slow,
                                switchInCurve: ElioMotion.pop,
                                transitionBuilder: (child, a) =>
                                    ScaleTransition(scale: a, child: child),
                                child: L3RoundSticker(
                                  key: ValueKey(widget.sticker),
                                  label: widget.sticker!,
                                  size: sticker,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: ShapeDecoration(
      color: context.elio.surface,
      shape: const StadiumBorder(),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.labelLarge,
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    // Back from a lesson the bar fills to the new value (slow, standard).
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: ElioMotion.slow,
      curve: ElioMotion.standard,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 6,
          color: p.primary,
          backgroundColor: p.surface,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.width,
    required this.height,
    required this.cover,
    required this.play,
  });
  final double width, height;
  final Widget cover;
  final bool play;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.borderSubtle),
        boxShadow: l3Shadow,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: cover),
          if (play)
            Positioned(
              left: 6,
              bottom: 4,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: p.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 18,
                  color: p.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- rise

/// Calls [onRise] and bumps the counter passed to [builder] each time [value]
/// goes up after the first build. Never fires on first show (cards 17, 20).
class RiseWatcher extends StatefulWidget {
  const RiseWatcher({
    super.key,
    required this.value,
    required this.builder,
    this.onRise,
  });
  final int value;
  final void Function(int from, int to)? onRise;
  final Widget Function(BuildContext context, int bump) builder;

  @override
  State<RiseWatcher> createState() => _RiseWatcherState();
}

class _RiseWatcherState extends State<RiseWatcher> {
  int _bump = 0;

  @override
  void didUpdateWidget(RiseWatcher old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value) {
      _bump++;
      final from = old.value, to = widget.value;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onRise?.call(from, to),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _bump);
}

/// One-shot 0 → 1 animation that replays whenever [trigger] changes and is
/// at rest (1) on first show and under reduced motion.
class Replay extends StatelessWidget {
  const Replay({
    super.key,
    required this.trigger,
    required this.duration,
    required this.builder,
    this.curve = Curves.linear,
    this.child,
  });
  final int trigger;
  final Duration duration;
  final Curve curve;
  final Widget? child;
  final Widget Function(BuildContext context, double t, Widget? child) builder;

  @override
  Widget build(BuildContext context) {
    final still = trigger == 0 || ElioMotion.reduced(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: still ? Duration.zero : duration,
      curve: curve,
      builder: builder,
      child: child,
    );
  }
}

// ---------------------------------------------------------------- snap rail

/// Horizontal card rail that snaps a card to the left edge with spring/soft.
/// The first card is [first] wide (gap included), the rest [extent]; a tail
/// pad lets the last card reach the left too. A new snapped card plays S1 +
/// H-select once and calls [onSnap]. [itemBuilder] gets the card's distance
/// in cards from the left slot (0 = snapped), for skyline scaling.
class SnapRail extends StatefulWidget {
  const SnapRail({
    super.key,
    required this.itemCount,
    required this.first,
    required this.extent,
    required this.height,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.onSnap,
    this.left = 16,
  });
  final int itemCount, initialIndex;
  final double first, extent, height, left;
  final Widget Function(BuildContext context, int index, double distance)
  itemBuilder;
  final ValueChanged<int>? onSnap;

  @override
  State<SnapRail> createState() => _SnapRailState();
}

class _SnapRailState extends State<SnapRail> {
  late int _index = widget.initialIndex;
  late final ScrollController _c = ScrollController(
    initialScrollOffset: _edge(widget.initialIndex),
  );

  double _edge(int i) => i <= 0 ? 0 : widget.first + (i - 1) * widget.extent;

  int _nearest(double offset) {
    var best = 0;
    for (var i = 1; i < widget.itemCount; i++) {
      if ((_edge(i) - offset).abs() < (_edge(best) - offset).abs()) best = i;
    }
    return best;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool _onEnd(ScrollEndNotification n) {
    if (n.depth != 0 || !_c.hasClients) return false;
    final i = _nearest(_c.offset);
    if (i != _index) {
      setState(() => _index = i);
      elioFeedback(ElioSfx.tick, ElioHaptics.select);
      widget.onSnap?.call(i);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final n = widget.itemCount;
      final last = n <= 1 ? widget.first : widget.extent;
      final tail = math.max(0.0, box.maxWidth - widget.left - last);
      return SizedBox(
        height: widget.height,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: _onEnd,
          child: ListView.builder(
            controller: _c,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: widget.left, right: tail),
            physics: _SnapPhysics(edge: _edge, count: n),
            itemCount: n,
            itemBuilder: (context, i) => SizedBox(
              width: i == 0 ? widget.first : widget.extent,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final off = _c.hasClients ? _c.offset : _edge(_index);
                  final d = ((_edge(i) - off) / widget.extent).abs();
                  return widget.itemBuilder(context, i, d);
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.edge, required this.count, super.parent});
  final double Function(int) edge;
  final int count;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPhysics(edge: edge, count: count, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange || count == 0) {
      return super.createBallisticSimulation(position, velocity);
    }
    final x = position.pixels;
    var lo = 0;
    for (var i = 0; i < count; i++) {
      if (edge(i) <= x) lo = i;
    }
    final hi = math.min(lo + 1, count - 1);
    final pick = velocity > 300
        ? hi
        : velocity < -300
        ? lo
        : (x - edge(lo) < edge(hi) - x ? lo : hi);
    final target = edge(pick).clamp(0.0, position.maxScrollExtent);
    if ((target - x).abs() < 0.5) return null;
    return SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 380, damping: 30),
      x,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

// ---------------------------------------------------------------- intro

/// Tests only: true skips the Learn entrance.
bool _learnIntroPlayed = false;

/// One shared 1.4 s timeline for the Learn hub entrance (decision 0206):
/// every element reads its own slice with [LearnIntroSlice], so the reveal
/// lands as one choreography. Three quiet sounds mark the beats: S2 as Today's Guide lands, S4 as the module ring
/// closes, S9-short as the clover lands. Replays on every Learn open
/// (owner choice, 11 Nov); Reduce Motion shows everything at rest.
class LearnIntroHost extends StatefulWidget {
  const LearnIntroHost({super.key, required this.child});
  final Widget child;

  static const total = Duration(milliseconds: 1400);

  /// Tests: false plays the intro on the next hub, true skips it.
  @visibleForTesting
  static set played(bool v) => _learnIntroPlayed = v;

  @override
  State<LearnIntroHost> createState() => _LearnIntroHostState();
}

class _LearnIntroHostState extends State<LearnIntroHost>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;
  final _beats = <(int, ElioSfx, double)>[
    (560, ElioSfx.pop, 0.6),
    (760, ElioSfx.chime, 0.7),
    (1000, ElioSfx.sparkleShort, 0.5),
  ];
  int _next = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null || _learnIntroPlayed || ElioMotion.reduced(context)) {
      return;
    }
    final c = _c = AnimationController(
      vsync: this,
      duration: LearnIntroHost.total,
    )..addListener(_beat);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.forward();
    });
  }

  void _beat() {
    final ms = _c!.value * LearnIntroHost.total.inMilliseconds;
    while (_next < _beats.length && ms >= _beats[_next].$1) {
      final (_, sfx, gain) = _beats[_next++];
      unawaited(ElioSound.instance.play(sfx, gain: gain));
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _LearnIntro(animation: _c, child: widget.child);
}

class _LearnIntro extends InheritedWidget {
  const _LearnIntro({required this.animation, required super.child});
  final Animation<double>? animation;

  @override
  bool updateShouldNotify(_LearnIntro old) => old.animation != animation;
}

/// Builds [child] with t = 0..1 over [from]..[to] ms of the Learn intro,
/// shaped by [curve]. Outside an intro (or after it) t is 1.
class LearnIntroSlice extends StatelessWidget {
  const LearnIntroSlice({
    super.key,
    required this.from,
    required this.to,
    required this.builder,
    this.curve = ElioMotion.emphasized,
    this.child,
  });
  final int from, to;
  final Curve curve;
  final Widget? child;
  final Widget Function(BuildContext context, double t, Widget? child) builder;

  /// Ms into the Learn intro, or null when none is running (none started,
  /// or it already finished). Widgets built later read null and rest.
  static int? elapsedMs(BuildContext context) {
    final a = context.getInheritedWidgetOfExactType<_LearnIntro>()?.animation;
    if (a == null || a.isCompleted) return null;
    return (a.value * LearnIntroHost.total.inMilliseconds).round();
  }

  @override
  Widget build(BuildContext context) {
    final a = context
        .dependOnInheritedWidgetOfExactType<_LearnIntro>()
        ?.animation;
    if (a == null) return builder(context, 1, child);
    final total = LearnIntroHost.total.inMilliseconds;
    final interval = Interval(from / total, to / total);
    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (context, child) =>
          builder(context, curve.transform(interval.transform(a.value)), child),
    );
  }
}

/// Common intro move: fade in, rise [rise] px and scale from [scale].
class LearnIntroRise extends StatelessWidget {
  const LearnIntroRise({
    super.key,
    required this.from,
    required this.to,
    required this.child,
    this.rise = 24,
    this.scale = 1,
    this.dx = 0,
    this.curve = ElioMotion.emphasized,
    this.alignment = Alignment.center,
  });
  final int from, to;
  final double rise, scale, dx;
  final Curve curve;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => LearnIntroSlice(
    from: from,
    to: to,
    curve: curve,
    child: child,
    builder: (context, t, child) => Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(dx * (1 - t), rise * (1 - t)),
        child: Transform.scale(
          scale: scale + (1 - scale) * t,
          alignment: alignment,
          child: child,
        ),
      ),
    ),
  );
}
