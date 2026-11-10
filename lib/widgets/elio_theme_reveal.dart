// ELIOS 3 dark-mode switch (Figma 13 · 36, decision 0203): the new theme is
// revealed in a circle growing from the switch (radius 0 → screen diagonal,
// 400 ms emphasized). Reduced motion: a plain 220 ms cross-fade.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/elio_motion.dart';

class ThemeSwitchReveal extends StatefulWidget {
  const ThemeSwitchReveal({super.key, required this.child});
  final Widget child;

  static _ThemeSwitchRevealState? _host;

  /// Snapshots the screen, runs [change] (the theme switch), then reveals the
  /// new look from [center] (global position). Without a host it just runs.
  static Future<void> run(Offset center, VoidCallback change) async {
    final host = _host;
    if (host == null || !host.mounted) {
      change();
      return;
    }
    await host._reveal(center, change);
  }

  @override
  State<ThemeSwitchReveal> createState() => _ThemeSwitchRevealState();
}

class _ThemeSwitchRevealState extends State<ThemeSwitchReveal>
    with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final AnimationController _c;
  ui.Image? _old;
  Offset _center = Offset.zero;
  bool _fadeOnly = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this);
    ThemeSwitchReveal._host = this;
  }

  @override
  void dispose() {
    if (ThemeSwitchReveal._host == this) ThemeSwitchReveal._host = null;
    _c.dispose();
    _old?.dispose();
    super.dispose();
  }

  Future<void> _reveal(Offset center, VoidCallback change) async {
    final box = _boundary.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || _c.isAnimating) {
      change();
      return;
    }
    final ratio = MediaQuery.devicePixelRatioOf(context);
    ui.Image image;
    try {
      image = await box.toImage(pixelRatio: ratio);
    } catch (_) {
      change();
      return;
    }
    if (!mounted) return;
    _fadeOnly = ElioMotion.reduced(context);
    setState(() {
      _old?.dispose();
      _old = image;
      _center = (box.globalToLocal(center));
    });
    change();
    _c.duration = _fadeOnly
        ? ElioMotion.base
        : const Duration(milliseconds: 400);
    await _c.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _old?.dispose();
      _old = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final old = _old;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (old != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _fadeOnly
                      ? _c.value
                      : ElioMotion.emphasized.transform(_c.value);
                  final picture = RawImage(image: old, fit: BoxFit.fill);
                  if (_fadeOnly) {
                    return Opacity(opacity: 1 - t, child: picture);
                  }
                  return ClipPath(
                    clipper: _OutsideCircle(_center, t),
                    child: picture,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Everything outside a circle at [center] whose radius grows with [t] to
/// the farthest corner: the old screen shrinks away from the new one.
class _OutsideCircle extends CustomClipper<Path> {
  _OutsideCircle(this.center, this.t);
  final Offset center;
  final double t;

  @override
  Path getClip(Size size) {
    final far = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => (c - center).distance).reduce(math.max);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: far * t));
  }

  @override
  bool shouldReclip(_OutsideCircle old) => old.t != t || old.center != center;
}
