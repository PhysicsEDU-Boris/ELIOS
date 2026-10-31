import 'package:flutter/material.dart';

import '../../theme/elio_tokens.dart';
import 'elio_leaf.dart';

/// Splash "Growth v2" (Figma 208:799, 214:799, motion spec 208:1551).
/// Keyframes F0..F11 at the times below; [t] is milliseconds since F0.
abstract final class SplashGrowthSpec {
  static const f1 = 500, f2 = 1100, f3 = 1700, textStart = 1950;
  static const letterMs = 160, taglineStart = 2750, taglineMs = 350;
  static const f11 = 3300;

  /// F11 + 100 ms wait; the 250 ms dissolve is the route transition (ends 3650).
  static const navigateAt = 3400;
  static const dissolveMs = 250;
  static const reducedHoldMs = 600;

  static const word = 'ELIOS';
  static const tagline = 'Environment Learning Intelligent Object Sorter';
  static const slotHeight = 46.0;
}

double _seg(double t, int from, int ms, Curve c) =>
    c.transform(((t - from) / ms).clamp(0.0, 1.0));

/// Draws the whole splash for time [t]. Static (reduced motion) = t 3300.
class SplashGrowth extends StatelessWidget {
  const SplashGrowth({super.key, required this.t, required this.palette});

  final double t;
  final ElioPalette palette;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final s = size.width >= 900 ? 170.0 : 150.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final lettersTop = cy - 60 + s / 2 + 28;
    final p = palette;
    final noScale = MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.noScaling);
    // The wordmark font is proportional (Figma: E 22, L 21, I 12, O 30, S 22 in
    // Google Sans Flex), so each slot is the measured advance of its letter.
    final style = ElioTokens.display.copyWith(color: p.textPrimary);
    final widths = [
      for (final l in SplashGrowthSpec.word.split(''))
        (TextPainter(
          text: TextSpan(text: l, style: style),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling,
        )..layout()).width.ceilToDouble(),
    ];
    final lefts = [
      for (
        var i = 0, x = cx - widths.reduce((a, b) => a + b) / 2;
        i < 5;
        x += widths[i], i++
      )
        x,
    ];

    return MediaQuery(
      data: noScale,
      child: Semantics(
        label: '${SplashGrowthSpec.word}, ${SplashGrowthSpec.tagline}',
        child: ExcludeSemantics(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _PlantPainter(t, s, p)),
              ),
              for (var i = 0; i < 5; i++)
                Positioned(
                  left: lefts[i],
                  top: lettersTop,
                  width: widths[i],
                  height: SplashGrowthSpec.slotHeight,
                  child: _letter(i, style),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: lettersTop + 54 + (1 - _tag) * 10,
                child: Opacity(
                  opacity: _tag,
                  child: Text(
                    SplashGrowthSpec.tagline,
                    textAlign: TextAlign.center,
                    style: ElioTokens.caption.copyWith(color: p.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _tag => _seg(
    t,
    SplashGrowthSpec.taglineStart,
    SplashGrowthSpec.taglineMs,
    Curves.easeInOut,
  );

  Widget _letter(int i, TextStyle style) {
    final e = _seg(
      t,
      SplashGrowthSpec.textStart + i * SplashGrowthSpec.letterMs,
      SplashGrowthSpec.letterMs,
      Curves.easeOutCubic,
    );
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 0,
        maxWidth: double.infinity,
        child: Transform.translate(
          offset: Offset(0, (1 - e) * 48),
          child: Opacity(
            opacity: e,
            child: Text(
              SplashGrowthSpec.word[i],
              softWrap: false,
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlantPainter extends CustomPainter {
  _PlantPainter(this.t, this.s, this.p);

  final double t, s;
  final ElioPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final p1 = _seg(t, 0, SplashGrowthSpec.f1, Curves.easeOut);
    final p2 = _seg(
      t,
      SplashGrowthSpec.f1,
      SplashGrowthSpec.f2 - SplashGrowthSpec.f1,
      Curves.easeInOut,
    );
    final p3 = _seg(
      t,
      SplashGrowthSpec.f2,
      SplashGrowthSpec.f3 - SplashGrowthSpec.f2,
      Curves.easeInOut,
    );
    final color = p.primaryText;
    final ground = cy + 0.15 * s;

    // Seed: 10 dp dot at the ground, gone by F1.
    if (p1 < 1) {
      canvas.drawCircle(
        Offset(cx, ground),
        5,
        Paint()..color = color.withValues(alpha: 1 - p1),
      );
    }

    // Stem: 0 -> 0.3375 S -> 0.75 S, then fades out in F3.
    final stemH = s * (p2 > 0 ? _lerp(0.3375, 0.75, p2) : 0.3375 * p1);
    final stemA = 1 - p3;
    if (stemH > 0 && stemA > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 3, ground - stemH, 6, stemH),
          const Radius.circular(3),
        ),
        Paint()..color = color.withValues(alpha: stemA),
      );
    }

    // Buds: two small leaves at +-40 deg, scale 0.02 -> 0.3 in F2, gone in F3.
    final budA = p2 * (1 - p3);
    if (budA > 0) {
      final bud = s * _lerp(0.02, 0.3, p2);
      for (final side in [-1, 1]) {
        canvas.save();
        canvas.translate(
          cx + side * 0.2 * s - bud / 2,
          cy - 0.225 * s - bud / 2,
        );
        _paintRotated(canvas, bud, color.withValues(alpha: budA), side * 40.0);
        canvas.restore();
      }
    }

    // Leaf: scale 0.05 -> 0.3 -> 0.6 -> 1; centre (in S) +0.15 -> -0.2675 -> -0.78 -> -0.4.
    final scale = p3 > 0
        ? _lerp(0.6, 1, p3)
        : p2 > 0
        ? _lerp(0.3, 0.6, p2)
        : _lerp(0.05, 0.3, p1);
    final centre = p3 > 0
        ? _lerp(-0.78, -0.4, p3)
        : p2 > 0
        ? _lerp(-0.2675, -0.78, p2)
        : _lerp(0.15, -0.2675, p1);
    final leaf = s * scale;
    canvas.save();
    canvas.translate(cx - leaf / 2, cy + centre * s - leaf / 2);
    ElioLeaf.paint(
      canvas,
      leaf,
      color.withValues(alpha: p1),
      // Dark glow only on the leaf, from F3.
      glow: p.isDark ? p3 : 0,
    );
    canvas.restore();
  }

  static void _paintRotated(Canvas c, double size, Color color, double deg) =>
      ElioLeaf.paintRotated(c, size, color, deg);

  static double _lerp(double a, double b, double x) => a + (b - a) * x;

  @override
  bool shouldRepaint(_PlantPainter old) =>
      old.t != t || old.s != s || old.p != p;
}
