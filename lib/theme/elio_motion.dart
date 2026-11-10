// ELIOS 3 motion (Figma section 13, decision 0202): durations, curves, the
// three springs and small reusable motion widgets. Every widget here honours
// reduced motion: springs become a 150 ms fade, the shimmer stays still.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

abstract final class ElioMotion {
  static const instant = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 320);
  static const expressive = Duration(milliseconds: 480);
  static const celebrate = Duration(milliseconds: 900);

  /// ease/standard: default enter / move.
  static const standard = Cubic(0.2, 0, 0, 1);

  /// ease/exit: things leaving (always shorter than enter).
  static const exit = Cubic(0.4, 0, 1, 1);

  /// ease/emphasized: sheets, container transforms, entrances.
  static const emphasized = Cubic(0.3, 0, 0, 1);

  /// spring/soft ≈ 5 % overshoot: toggles, tabs, sheets.
  static const soft = ElioSpringCurve(
    SpringDescription(mass: 1, stiffness: 380, damping: 30),
  );

  /// spring/pop ≈ 12 % overshoot: stickers, art pop-out, badges.
  static const pop = ElioSpringCurve(
    SpringDescription(mass: 1, stiffness: 520, damping: 22),
  );

  /// spring/bounce ≈ 25 % overshoot: rewards only.
  static const bounce = ElioSpringCurve(
    SpringDescription(mass: 1, stiffness: 300, damping: 14),
  );

  /// Reduced motion (system setting): no springs, sweeps or loops.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

/// A spring as a [Curve] over a fixed duration, so implicit animations can
/// use it. The tail is pinned to 1 so the animation always ends at rest.
class ElioSpringCurve extends Curve {
  const ElioSpringCurve(this.spring, {this.seconds = 0.6});
  final SpringDescription spring;

  /// Simulated time mapped onto the curve's 0..1.
  final double seconds;

  @override
  double transformInternal(double t) {
    if (t >= 1) return 1;
    final sim = SpringSimulation(spring, 0, 1, 0);
    return sim.x(t * seconds);
  }
}

/// Entrance (Figma rule 7): opacity 0 → 1, y +[rise] → 0, scale 0.96 → 1,
/// 320 ms emphasized, after [index] × [stagger]. Plays once per element.
class ElioPopIn extends StatefulWidget {
  const ElioPopIn({
    super.key,
    required this.child,
    this.index = 0,
    this.stagger = const Duration(milliseconds: 40),
    this.rise = 12,
    this.scale = 0.96,
    this.duration = ElioMotion.slow,
    this.curve = ElioMotion.emphasized,
    this.delay = Duration.zero,
    this.play = true,
  });

  /// False shows the child at rest (e.g. an entrance already seen).
  final bool play;

  final Widget child;
  final int index;
  final Duration stagger, duration, delay;
  final double rise, scale;
  final Curve curve;

  @override
  State<ElioPopIn> createState() => _ElioPopInState();
}

class _ElioPopInState extends State<ElioPopIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Curve _interval = const Interval(0, 1);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.play) {
      _c.value = 1;
      return;
    }
    if (ElioMotion.reduced(context)) {
      _c.duration = ElioMotion.fast;
    } else {
      // The stagger is part of the animation (no timers); max 6 items wait,
      // then all at once (Figma "stagger").
      final wait = widget.delay + widget.stagger * math.min(widget.index, 6);
      final total = wait + widget.duration;
      _c.duration = total;
      _interval = Interval(wait.inMicroseconds / total.inMicroseconds, 1);
    }
    // Start once the first frame is on screen: a heavy screen's first frame
    // can take longer than the animation (debug builds), which hid it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = ElioMotion.reduced(context);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final local = _interval.transform(_c.value);
        if (reduced) return Opacity(opacity: local, child: child);
        final t = widget.curve.transform(local);
        return Opacity(
          opacity: local.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, widget.rise * (1 - t)),
            child: Transform.scale(
              scale: widget.scale + (1 - widget.scale) * t,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Press feel (Figma rules 3 and 7): scales to [pressed] while held (90 ms),
/// springs back on release. Taps still go to the child.
class ElioPress extends StatefulWidget {
  const ElioPress({super.key, required this.child, this.pressed = 0.98});
  final Widget child;
  final double pressed;

  @override
  State<ElioPress> createState() => _ElioPressState();
}

class _ElioPressState extends State<ElioPress> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (ElioMotion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressed : 1,
        duration: _down ? ElioMotion.instant : ElioMotion.slow,
        curve: _down ? ElioMotion.standard : ElioMotion.soft,
        child: widget.child,
      ),
    );
  }
}

/// Skeleton shimmer (Figma rule 8): a white band sweeps left → right in a
/// 1200 ms linear loop, 28 % peak (15 % in dark). Static under reduced motion.
class ElioShimmer extends StatefulWidget {
  const ElioShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<ElioShimmer> createState() => _ElioShimmerState();
}

class _ElioShimmerState extends State<ElioShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ElioMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ElioMotion.reduced(context)) return widget.child;
    final peak = Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.28;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          final x = -1.0 + 3.0 * _c.value; // band travels past both edges
          return LinearGradient(
            begin: Alignment(x - 1, 0),
            end: Alignment(x + 1, 0),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: peak),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(rect);
        },
        child: child,
      ),
    );
  }
}

/// Counts an integer up from 0 the first time it shows (600 ms, standard),
/// starting after the first frame is on screen.
class ElioCountUp extends StatelessWidget {
  const ElioCountUp({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 600),
    this.play = true,
  });
  final bool play;
  final int value;
  final Duration duration;
  final Widget Function(BuildContext context, int value) builder;

  @override
  Widget build(BuildContext context) {
    if (!play || ElioMotion.reduced(context)) return builder(context, value);
    return ElioAfterFirstFrame(
      builder: (context, ready) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ready ? value.toDouble() : 0),
        duration: duration,
        curve: ElioMotion.standard,
        builder: (context, v, _) => builder(context, v.round()),
      ),
    );
  }
}

/// Builds with ready = false for the first frame, then true: implicit
/// animations whose target depends on [ready] start once the screen shows.
class ElioAfterFirstFrame extends StatefulWidget {
  const ElioAfterFirstFrame({super.key, required this.builder});
  final Widget Function(BuildContext context, bool ready) builder;

  @override
  State<ElioAfterFirstFrame> createState() => _ElioAfterFirstFrameState();
}

class _ElioAfterFirstFrameState extends State<ElioAfterFirstFrame> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _ready);
}
