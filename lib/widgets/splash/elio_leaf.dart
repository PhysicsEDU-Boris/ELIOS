import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The ELIOS leaf (two blade halves and the terminal cursor), drawn from the
/// Figma "leaf art" vector (node 208:1144). Coordinates are the SVG's, minus
/// its filter margin, so the art sits in a 150 x 150 box.
abstract final class ElioLeaf {
  static const box = 150.0;

  static final Path _blades = Path()
    ..moveTo(17.6954, 122.7)
    ..cubicTo(12.7454, 66.0, 59.9954, 18.0, 128.6954, 14.7)
    ..lineTo(17.6954, 122.7)
    ..close()
    ..moveTo(135.2954, 21.3)
    ..cubicTo(137.9954, 90.0, 92.9954, 135.0, 24.2954, 129.3)
    ..lineTo(135.2954, 21.3)
    ..close();

  static final Path _cursor = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(92.9954, 126.0, 131.9954, 138.0),
        const Radius.circular(2.25),
      ),
    );

  /// Paints the leaf into a [size] square at the canvas origin. [glow] (0 to 1)
  /// adds the dark-mode halo: 1.5 dp dilate, 9 dp sigma, 20 % alpha.
  static void paint(
    Canvas canvas,
    double size,
    Color color, {
    double glow = 0,
  }) {
    canvas.save();
    canvas.scale(size / box);
    if (glow > 0) {
      final halo = Paint()
        ..color = color.withValues(alpha: 0.2 * glow)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      final dilate = Paint.from(halo)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (final p in [_blades, _cursor]) {
        canvas.drawPath(p, halo);
        canvas.drawPath(p, dilate);
      }
    }
    final fill = Paint()..color = color;
    canvas.drawPath(_blades, fill);
    canvas.drawPath(_cursor, fill);
    canvas.restore();
  }

  /// Rotates by [degrees] about the centre of a [size] square at the origin.
  static void paintRotated(
    Canvas canvas,
    double size,
    Color color,
    double degrees,
  ) {
    canvas.save();
    canvas.translate(size / 2, size / 2);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-size / 2, -size / 2);
    paint(canvas, size, color);
    canvas.restore();
  }
}

/// The static leaf mark, used by the login screens (48 dp phone, 150 dp panel).
class ElioMark extends StatelessWidget {
  const ElioMark({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _MarkPainter(color)),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      ElioLeaf.paint(canvas, size.width, color);

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
