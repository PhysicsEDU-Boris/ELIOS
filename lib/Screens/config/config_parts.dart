// C1 Config screen pieces (decision 0145, Figma page 337:2358): ELIOS AI logo
// and card, choice tile, status tile, card and buttons. Colours come from the
// active palette only; the bulb is the shared Home illustration.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/ai_quiz_service.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/learn/learn_ui.dart';
import '../home/home_parts.dart' show homeArt, homeRadiusL;
import 'package:elio/l10n/l10n.dart';

TextStyle configTitle(ElioPalette p) =>
    ElioTokens.bodyLarge.copyWith(fontSize: 19, fontWeight: FontWeight.w600, height: 1.3, color: p.textPrimary);

TextStyle configBody(ElioPalette p, {Color? color, FontWeight? weight}) =>
    ElioTokens.bodySmall.copyWith(color: color ?? p.textSecondary, fontWeight: weight, height: 1.45);

TextStyle configStrong(ElioPalette p, {Color? color}) =>
    ElioTokens.bodySmall.copyWith(color: color ?? p.textPrimary, fontWeight: FontWeight.w700, height: 1.35);

TextStyle configCaption(ElioPalette p, {Color? color}) =>
    ElioTokens.caption.copyWith(color: color ?? p.textSecondary, fontWeight: FontWeight.w400);

/// In-card divider: dark borderSubtle equals the card fill, so it would vanish.
Color configDivider(ElioPalette p) => p.isDark ? p.borderMedium : p.borderSubtle;

/// Section heading outside the cards ("Camera source" + one line).
class ConfigSectionHeader extends StatelessWidget {
  const ConfigSectionHeader(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: configTitle(p)),
          const SizedBox(height: 2),
          Text(subtitle, style: configCaption(p)),
        ],
      ),
    );
  }
}

/// Surface card; [tint] gives the tinted AI-card look (fill + border).
class ConfigCard extends StatelessWidget {
  const ConfigCard({super.key, required this.child, this.tint, this.padding = 16});
  final Widget child;
  final Color? tint;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tint == null ? p.surface : Color.alphaBlend(tint!.withValues(alpha: 0.08), p.surface),
        shape: learnShape(homeRadiusL, BorderSide(color: tint?.withValues(alpha: 0.45) ?? p.borderSubtle)),
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}

/// Round icon chip used in card headers and settings rows.
class ConfigIconChip extends StatelessWidget {
  const ConfigIconChip(this.icon, {super.key, this.size = 40, this.color, this.background});
  final IconData icon;
  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(color: background ?? p.surfaceRaised, shape: const CircleBorder()),
      child: Icon(icon, size: size * 0.5, color: color ?? p.primaryText),
    );
  }
}

/// Card header: icon chip, title, one line.
class ConfigCardHeader extends StatelessWidget {
  const ConfigCardHeader({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Row(
      children: [
        ConfigIconChip(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: configStrong(p)),
              Text(subtitle, style: configCaption(p)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Choice tile 337:2479: green fill and check when selected, ring otherwise;
/// 50 % when disabled.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.iconWidget,
  });

  final IconData icon;
  final Widget? iconWidget;
  final String title;
  final String description;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final fg = selected ? p.onPrimary : p.textPrimary;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Semantics(
        button: true,
        inMutuallyExclusiveGroup: true,
        selected: selected,
        enabled: enabled,
        label: '$title. $description',
        onTap: enabled ? onTap : null,
        excludeSemantics: true,
        child: Material(
          color: selected ? p.primary : p.surface,
          shape: learnShape(learnRadiusL, selected ? BorderSide.none : BorderSide(color: p.borderSubtle)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        iconWidget ??
                            ConfigIconChip(icon, color: p.textPrimary, background: selected ? p.surface : p.surfaceRaised),
                        const Spacer(),
                        selected
                            ? Container(
                                width: 24,
                                height: 24,
                                decoration: ShapeDecoration(color: p.onPrimary, shape: const CircleBorder()),
                                child: Icon(Icons.check_rounded, size: 16, color: p.primary),
                              )
                            : Container(
                                width: 24,
                                height: 24,
                                decoration: ShapeDecoration(
                                  shape: CircleBorder(side: BorderSide(color: p.formBorder, width: 2)),
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(title, style: configStrong(p, color: fg)),
                    const SizedBox(height: 4),
                    Text(description, style: configCaption(p, color: selected ? p.onPrimary : p.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero status tile ("Status · Online").
class StatusTile extends StatelessWidget {
  const StatusTile({super.key, required this.label, required this.value, this.leading, this.semanticsValue});
  final String label;
  final String value;
  final Widget? leading;

  /// Read instead of [value] when the visible text is a symbol ("—").
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      label: '$label: ${semanticsValue ?? value}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: ShapeDecoration(color: p.surface, shape: learnShape(learnRadiusM)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: configCaption(p), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Flexible(
                  child: Text(value, style: configStrong(p), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill button 337:2512. [destructive] = red outline (Disconnect).
class ConfigButton extends StatelessWidget {
  const ConfigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.destructive = false,
    this.busy = false,
    this.semanticsLabel,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;
  final bool busy;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final dim = ElioTokens.disabledOpacity;
    final Widget? leading = busy
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: primary ? p.onPrimary : p.primaryText),
          )
        : icon == null
            ? null
            : Icon(icon, size: 20);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
    final shape = WidgetStatePropertyAll<OutlinedBorder>(const StadiumBorder());
    const size = WidgetStatePropertyAll(Size(0, 48));
    final ButtonStyle style;
    if (primary) {
      style = ButtonStyle(shape: shape, minimumSize: size);
    } else {
      final c = destructive ? p.errorText : p.textPrimary;
      final side = destructive ? p.error : p.formBorder;
      style = ButtonStyle(
        shape: shape,
        minimumSize: size,
        backgroundColor: WidgetStatePropertyAll(p.surface),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.withValues(alpha: dim) : c),
        side: WidgetStateProperty.resolveWith((s) =>
            BorderSide(color: s.contains(WidgetState.disabled) ? side.withValues(alpha: dim) : side)),
      );
    }
    final button = primary
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
    return Semantics(label: semanticsLabel, button: true, child: button);
  }
}

// ── ELIOS AI ─────────────────────────────────────────────────────────────

/// Card states 343:3076. Cloud AI has nothing to load or cool down, so the
/// Figma Loading and Paused states are gone (decision 0179).
enum AiCardState { off, active, error }

AiCardState aiCardState(AiStatus status) => switch (status) {
      AiStatus.idle => AiCardState.off,
      AiStatus.ready => AiCardState.active,
      AiStatus.offline => AiCardState.error,
    };

/// ELIOS AI card 343:3076, driven by the last cloud call ([AiQuizService.status]).
class EliosAiCard extends StatelessWidget {
  const EliosAiCard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AiQuizService.instance;
    return ValueListenableBuilder<AiStatus>(
      valueListenable: service.status,
      builder: (context, status, _) {
        final p = context.elio;
        final state = aiCardState(status);
        return ConfigCard(
          tint: state == AiCardState.error ? p.error : p.tertiaryText,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        EliosAiLogo(state: state),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(header: true, child: Text('ELIOS AI', style: configTitle(p))),
                              Text(context.l10n.aiNeedsInternet, style: configCaption(p)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Semantics(liveRegion: true, container: true, child: _body(context, p, state, service)),
                  ],
                ),
              ),
              if (state != AiCardState.error) ...[
                const SizedBox(width: 8),
                Padding(padding: const EdgeInsets.only(top: 40), child: homeArt('bulb_buddy', width: 56, height: 59)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, ElioPalette p, AiCardState state, AiQuizService service) => switch (state) {
        AiCardState.off => Text(context.l10n.aiOffHint,
            style: configBody(p)),
        AiCardState.active => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.aiActiveHint, style: configBody(p)),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: ShapeDecoration(shape: StadiumBorder(side: BorderSide(color: p.primaryText))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 16, color: p.primaryText),
                      const SizedBox(width: 4),
                      Text(context.l10n.aiActive(service.lastModel ?? context.l10n.aiCloud), style: configCaption(p, color: p.primaryText)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        AiCardState.error => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _alertLine(p, Icons.cloud_off_rounded, l10n.cfgAiUnreachable, p.errorText),
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text(context.l10n.aiUnavailable, style: configCaption(p, color: p.textPrimary)),
              ),
            ],
          ),
      };

  Widget _alertLine(ElioPalette p, IconData icon, String text, Color color) => Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: configStrong(p, color: color))),
        ],
      );
}

/// ELIOS AI logo 347:4439: the centre leaf stays still, the small leaf orbits
/// clockwise at constant speed and the outline opens where it passes.
/// Active 3.6 s per orbit; other states and reduced motion
/// rest at Frame 01 (small leaf on the left).
class EliosAiLogo extends StatefulWidget {
  const EliosAiLogo({super.key, required this.state, this.size = 48});
  final AiCardState state;
  final double size;

  static Duration? periodFor(AiCardState state) => switch (state) {
        AiCardState.active => const Duration(milliseconds: 3600),
        _ => null,
      };

  @override
  State<EliosAiLogo> createState() => _EliosAiLogoState();
}

class _EliosAiLogoState extends State<EliosAiLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(vsync: this);

  void _sync() {
    final period = context.reduceMotion ? null : EliosAiLogo.periodFor(widget.state);
    if (period == null) {
      _orbit
        ..stop()
        ..value = 0;
    } else if (_orbit.duration != period || !_orbit.isAnimating) {
      _orbit
        ..duration = period
        ..repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(EliosAiLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: LeafOrbitPainter(_orbit, color: p.primaryText, glow: p.isDark),
        ),
      ),
    );
  }
}

class LeafOrbitPainter extends CustomPainter {
  LeafOrbitPainter(this.progress, {required this.color, required this.glow}) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final bool glow;

  // The Figma outline: an ellipse (rx 12.5, ry 20.5) round the centre, traced
  // clockwise from its left point so progress 0 is Frame 01.
  static final _outline = () {
    final path = Path();
    const steps = 120;
    for (var i = 0; i <= steps; i++) {
      final t = math.pi + 2 * math.pi * i / steps;
      final pt = Offset(24 + 12.5 * math.cos(t), 24 + 20.5 * math.sin(t));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path.computeMetrics().first;
  }();

  /// Half the opening in the outline, along the path (Frame 01: ~8.4 units).
  static const _halfGap = 8.4;

  static final _centreLeaf = Path()
    ..fillType = PathFillType.evenOdd
    ..moveTo(24, 11)
    ..cubicTo(33.9996, 16.1724, 33.9997, 29.9653, 24, 35.1377)
    ..cubicTo(14.0003, 29.9653, 14.0003, 16.1724, 24, 11)
    ..close()
    ..moveTo(24, 16.2002)
    ..cubicTo(23.5582, 16.2002, 23.2002, 16.5582, 23.2002, 17)
    ..lineTo(23.2002, 22.0361)
    ..lineTo(21.5039, 20.6914)
    ..cubicTo(21.2228, 20.4685, 20.814, 20.5151, 20.5908, 20.7959)
    ..cubicTo(20.3681, 21.077, 20.4146, 21.4859, 20.6953, 21.709)
    ..lineTo(23.2002, 23.6953)
    ..lineTo(23.2002, 33)
    ..cubicTo(23.2002, 33.4418, 23.5582, 33.7998, 24, 33.7998)
    ..cubicTo(24.4418, 33.7998, 24.7998, 33.4418, 24.7998, 33)
    ..lineTo(24.7998, 27.6943)
    ..lineTo(27.3037, 25.709)
    ..cubicTo(27.5847, 25.4859, 27.6322, 25.077, 27.4092, 24.7959)
    ..cubicTo(27.1861, 24.5147, 26.7773, 24.4684, 26.4961, 24.6914)
    ..lineTo(24.7998, 26.0361)
    ..lineTo(24.7998, 17)
    ..cubicTo(24.7998, 16.5582, 24.4418, 16.2002, 24, 16.2002)
    ..close();

  // Small leaf, long axis along x (it is turned to the path's tangent).
  static final _smallLeaf = Path()
    ..moveTo(-6, 0)
    ..cubicTo(-3.45, 5, 3.45, 5, 6, 0)
    ..cubicTo(3.45, -5, -3.45, -5, -6, 0)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final len = _outline.length;
    final at = (progress.value % 1) * len;

    final start = (at + _halfGap) % len;
    final end = start + len - 2 * _halfGap;
    if (end <= len) {
      canvas.drawPath(_outline.extractPath(start, end), stroke);
    } else {
      canvas
        ..drawPath(_outline.extractPath(start, len), stroke)
        ..drawPath(_outline.extractPath(0, end - len), stroke);
    }

    if (glow) {
      canvas.drawPath(_centreLeaf,
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    canvas.drawPath(_centreLeaf, fill);

    final tangent = _outline.getTangentForOffset(at)!;
    canvas
      ..save()
      ..translate(tangent.position.dx, tangent.position.dy)
      ..rotate(math.atan2(tangent.vector.dy, tangent.vector.dx))
      ..drawPath(_smallLeaf, fill)
      ..restore();
  }

  @override
  bool shouldRepaint(LeafOrbitPainter old) => old.color != color || old.glow != glow || old.progress != progress;
}
