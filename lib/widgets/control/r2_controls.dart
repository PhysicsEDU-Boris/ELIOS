import 'dart:async';
// R2 gamified Control components (Figma 358:2358): joystick 358:2400,
// faders 358:2360 / 358:2380, rocker toggle 358:2429, glow button 358:2446,
// transport key 358:2495. Colours come only from the active ElioPalette; the
// callers' handlers are unchanged (every motion goes through MotionGate, 0026).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/control_session.dart';
import '../../services/elio_feedback.dart';
import '../../theme/elio_tokens.dart';
import '../learn/learn_ui.dart' show LearnTheme;
import 'package:elio/l10n/l10n.dart';

/// Feel for every Control input (decision 0188): a light haptic tick plus the
/// S1 tick through the one audio service (0201): off with Profile → Sound
/// effects, scaled by Master volume, silent when the phone is on silent.
void controlFeedback() {
  HapticFeedback.selectionClick();
  unawaited(ElioSound.instance.play(ElioSfx.tick));
}

/// [onTap] with [controlFeedback] first; null stays null (disabled).
VoidCallback? withFeedback(VoidCallback? onTap) => onTap == null
    ? null
    : () {
        controlFeedback();
        onTap();
      };

/// Dimmed and inert: disabled controls send nothing (R2, waiting/disconnected).
Widget controlEnabled(bool enabled, Widget child) => Opacity(
  opacity: enabled ? 1 : ElioTokens.disabledOpacity + 0.15,
  child: AbsorbPointer(absorbing: !enabled, child: child),
);

/// Keeps [child]'s width and scales it down when it is taller than the room,
/// so a long word or a large font never overflows a fixed-height card.
Widget fitDown(Widget child, {Alignment alignment = Alignment.centerLeft}) => LayoutBuilder(
  builder: (context, c) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: SizedBox(width: c.maxWidth, child: child),
  ),
);

/// A decorative illustration, hidden from screen readers.
Widget controlArt(String name, {double? width, double? height}) => ExcludeSemantics(
  child: SvgPicture.asset('assets/illustrations/control/$name.svg', width: width, height: height),
);

/// Small caps label ("DRIVE", "SPEED (PWM)").
class ControlCaps extends StatelessWidget {
  const ControlCaps(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: color ?? context.elio.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );
}

/// The status pill in a card header ("Forward", "Waiting", "Offline").
class ControlStatusChip extends StatelessWidget {
  const ControlStatusChip({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(color: color.withValues(alpha: 0.12), shape: const StadiumBorder()),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

/// A rounded card with its faint "Deco" curve, clipped by the card.
class ControlCard extends StatelessWidget {
  const ControlCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.border});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border ?? p.borderSubtle),
        boxShadow: p.isDark ? null : ElioLightEffects.card,
      ),
      child: CustomPaint(
        painter: _DecoPainter(p.primary.withValues(alpha: p.isDark ? 0.10 : 0.08)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _DecoPainter extends CustomPainter {
  _DecoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.55, size.height + 10)
      ..quadraticBezierTo(size.width * 0.95, size.height * 0.55, size.width + 20, size.height * 0.15);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DecoPainter old) => old.color != color;
}

/// Joystick (358:2400): a new input for the D-pad's commands. Quantised to the
/// four D-pad directions with a dead zone; a change of direction is the old
/// release + press, and letting go (or going back to the dead zone) is
/// [onRelease] (motor 0,0). Nothing is sent while the knob stays in the dead zone.
class DriveJoystick extends StatefulWidget {
  const DriveJoystick({super.key, required this.enabled, required this.onDirection, required this.onRelease});
  final bool enabled;
  final ValueChanged<DriveDir> onDirection;
  final VoidCallback onRelease;

  @override
  State<DriveJoystick> createState() => _DriveJoystickState();
}

class _DriveJoystickState extends State<DriveJoystick> {
  Offset _knob = Offset.zero;
  DriveDir? _dir;
  int? _pointer;

  void _move(Offset local, double radius) {
    var d = local - Offset(radius, radius);
    if (d.distance > radius * 0.55) d = d / d.distance * radius * 0.55;
    final dir = quantiseJoystick(local - Offset(radius, radius), radius);
    setState(() => _knob = d);
    if (dir == _dir) return;
    if (_dir != null) widget.onRelease();
    _dir = dir;
    if (dir != null) {
      controlFeedback();
      widget.onDirection(dir);
    }
  }

  void _end(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    setState(() => _knob = Offset.zero);
    if (_dir != null) {
      _dir = null;
      widget.onRelease();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return LayoutBuilder(
      builder: (context, c) {
        final size = math.min(c.maxWidth, c.maxHeight).clamp(80.0, 260.0);
        final r = size / 2;
        final knob = size * 0.4;
        Widget chevron(IconData icon, Alignment a) => Align(
          alignment: a,
          child: Padding(
            padding: EdgeInsets.all(size * 0.03),
            child: Icon(icon, size: size * 0.09, color: p.textSecondary),
          ),
        );
        return Center(
          child: Semantics(
            label: l10n.r2JoystickHint,
            // Claims the drag first, so a scrolling page (portrait) doesn't move under the thumb.
            child: GestureDetector(
              onVerticalDragStart: (_) {},
              onHorizontalDragStart: (_) {},
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  if (!widget.enabled || _pointer != null) return;
                  _pointer = e.pointer;
                  _move(e.localPosition, r);
                },
                onPointerMove: (e) {
                  if (e.pointer == _pointer) _move(e.localPosition, r);
                },
                onPointerUp: _end,
                onPointerCancel: _end,
                child: SizedBox.square(
                  dimension: size,
                  child: Stack(
                    children: [
                      // Base: rim = border/medium (Figma rim shadow).
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.surfaceRaised,
                            border: Border.all(color: p.borderMedium, width: 2),
                            boxShadow: [BoxShadow(color: p.borderMedium, offset: const Offset(0, 4))],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.all(size * 0.12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(shape: BoxShape.circle, color: p.surface),
                          ),
                        ),
                      ),
                      chevron(Icons.keyboard_arrow_up_rounded, Alignment.topCenter),
                      chevron(Icons.keyboard_arrow_down_rounded, Alignment.bottomCenter),
                      chevron(Icons.keyboard_arrow_left_rounded, Alignment.centerLeft),
                      chevron(Icons.keyboard_arrow_right_rounded, Alignment.centerRight),
                      Positioned(
                        left: r - knob / 2 + _knob.dx,
                        top: r - knob / 2 + _knob.dy,
                        child: Container(
                          key: const ValueKey('joystick_knob'),
                          width: knob,
                          height: knob,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.primary,
                            border: Border.all(color: p.primaryActive, width: 2),
                            boxShadow: [
                              BoxShadow(color: p.primaryActive, offset: const Offset(0, 4)),
                              if (_dir != null) ...ElioGlow.medium,
                            ],
                          ),
                          child: Icon(
                            switch (_dir) {
                              DriveDir.back => Icons.keyboard_arrow_down_rounded,
                              DriveDir.left => Icons.keyboard_arrow_left_rounded,
                              DriveDir.right => Icons.keyboard_arrow_right_rounded,
                              _ => Icons.keyboard_arrow_up_rounded,
                            },
                            color: p.onPrimary,
                            size: knob * 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fader (358:2360 vertical, 358:2380 horizontal): a Material [Slider] in
/// the R2 skin, so taps and drags behave exactly as the old sliders did.
class ControlFader extends StatelessWidget {
  const ControlFader({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 1,
    this.vertical = false,
    this.semanticLabel,
  });

  final double value;
  final double max;
  final ValueChanged<double>? onChanged;
  final bool vertical;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final slider = SliderTheme(
      data: SliderThemeData(
        trackHeight: 10,
        activeTrackColor: p.primary,
        inactiveTrackColor: p.borderSubtle,
        disabledActiveTrackColor: p.primary,
        disabledInactiveTrackColor: p.borderSubtle,
        thumbShape: _CapThumb(p.surface, p.borderStrong, p.textTertiary),
        disabledThumbColor: p.surface,
        overlayColor: p.primary.withValues(alpha: 0.12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: value.clamp(0, max),
        max: max,
        onChanged: onChanged,
        onChangeStart: onChanged == null ? null : (_) => controlFeedback(),
        semanticFormatterCallback: (v) => '${(v / max * 100).round()}%',
      ),
    );
    final track = DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderSubtle),
      ),
      child: vertical ? RotatedBox(quarterTurns: 3, child: slider) : slider,
    );
    return semanticLabel == null ? track : Semantics(label: semanticLabel, child: track);
  }
}

/// The fader cap: rim = border/strong (Figma rim shadow), three grip lines.
class _CapThumb extends SliderComponentShape {
  const _CapThumb(this.fill, this.rim, this.grip);
  final Color fill, rim, grip;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(28, 40);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final c = context.canvas;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 22, height: 36),
      const Radius.circular(8),
    );
    c.drawRRect(rect.shift(const Offset(0, 3)), Paint()..color = rim);
    c.drawRRect(rect, Paint()..color = fill);
    c.drawRRect(
      rect,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final line = Paint()
      ..color = grip
      ..strokeWidth = 1.5;
    for (final dx in [-5.0, 0.0, 5.0]) {
      c.drawLine(center + Offset(dx, -8), center + Offset(dx, 8), line);
    }
  }
}

/// Gear chips: set the speed fader to 25/50/75/100; the fader still allows any value.
class GearChips extends StatelessWidget {
  const GearChips({super.key, required this.speed, required this.onSelect});
  final double speed;
  final ValueChanged<double>? onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Row(
      children: [
        for (final g in speedGears) ...[
          if (g != speedGears.first) const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              button: true,
              selected: speed.round() == g,
              label: l10n.r2SpeedValue(g),
              excludeSemantics: true,
              child: Material(
                color: speed.round() == g ? p.primary : p.surfaceRaised,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: speed.round() == g ? p.primaryActive : p.borderSubtle),
                ),
                child: InkWell(
                  key: ValueKey('gear_$g'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: onSelect == null ? null : withFeedback(() => onSelect!(g.toDouble())),
                  enableFeedback: false,
                  child: SizedBox(
                    height: 32,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.signal_cellular_alt_rounded,
                            size: 14,
                            color: speed.round() == g ? p.onPrimary : p.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$g',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: speed.round() == g ? p.onPrimary : p.textSecondary,
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
        ],
      ],
    );
  }
}

/// Transport key (358:2495): a round key with its label below.
class TransportKey extends StatelessWidget {
  const TransportKey({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.size = 60,
    this.progress = 0,
    this.showLabel = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final double size;

  /// Hold-to-confirm fill (HOME), 0..1.
  final double progress;

  /// False draws the circle only (short screens); screen readers still get [label].
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final fill = primary ? p.primary : p.surface;
    final rim = primary ? p.primaryActive : p.borderMedium;
    // The key and its label are one target, as the old labelled buttons were.
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: withFeedback(onTap),
        enableFeedback: false,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: Border.all(color: rim, width: 1.5),
                boxShadow: [BoxShadow(color: rim, offset: const Offset(0, 3))],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (progress > 0)
                    Positioned.fill(
                      child: CircularProgressIndicator(value: progress, strokeWidth: 4, color: p.primaryText),
                    ),
                  Icon(icon, size: size * 0.42, color: primary ? p.onPrimary : p.textPrimary),
                ],
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(color: p.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Robot power glow button (358:2446): the link state; tap = the existing
/// connect / disconnect action.
class PowerGlowButton extends StatelessWidget {
  const PowerGlowButton({super.key, required this.link, required this.onTap, this.size = 64});
  final ControlLink link;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final on = link == ControlLink.connected;
    final (word, color) = switch (link) {
      ControlLink.connected => (l10n.cfgOnline, p.primaryText),
      ControlLink.waiting => (l10n.ctlConnecting, p.secondaryText),
      ControlLink.disconnected => (l10n.ctlOffline, p.errorText),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: on || link == ControlLink.waiting ? l10n.ctlDisconnectRobot : l10n.ctlConnectRobot,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: on ? ElioGlow.large : null),
            child: Material(
              color: on ? p.primary : p.surface,
              shape: CircleBorder(side: BorderSide(color: on ? p.primaryActive : p.formBorder, width: 3)),
              child: InkWell(
                key: const ValueKey('robot_power'),
                customBorder: const CircleBorder(),
                onTap: withFeedback(onTap),
                enableFeedback: false,
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: size * 0.45,
                  color: on ? p.onPrimary : p.textSecondary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: l10n.r2RobotPrefix,
                  style: TextStyle(color: p.textSecondary),
                ),
                TextSpan(
                  text: word,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            maxLines: 1,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Rocker toggle (358:2429): ON/OFF with its label.
class RockerToggle extends StatelessWidget {
  const RockerToggle({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: value ? p.primary : p.borderStrong, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: (v) {
              controlFeedback();
              onChanged(v);
            },
            activeThumbColor: p.surface,
            activeTrackColor: p.primary,
            inactiveThumbColor: p.textTertiary,
            inactiveTrackColor: p.surfaceRaised,
            trackOutlineColor: WidgetStatePropertyAll(p.borderMedium),
          ),
        ],
      ),
    );
  }
}
