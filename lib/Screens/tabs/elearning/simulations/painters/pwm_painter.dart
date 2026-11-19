import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../../theme/elio_learning_colors.dart';

class PwmWavePainter extends CustomPainter {
  final double dutyPercent;
  final double time;

  PwmWavePainter({required this.dutyPercent, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Grid background
    final paintGrid = Paint()
      ..color = elioBorder.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    for (double x = 0; x <= width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), paintGrid);
    }
    for (double y = 0; y <= height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(width, y), paintGrid);
    }

    final paintLine = Paint()
      ..color = elioPrimary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();

    final period = 100.0; // pixels per cycle
    final speed = 100.0; // pixels per second

    // Shift left based on time
    final shift = (time * speed) % period;

    bool isFirst = true;
    final dRatio = dutyPercent / 100.0;

    // Start drawing from just outside the left edge
    for (double x = -period; x <= width + period; x += period) {
      final startX = x - shift;
      final highWidth = period * dRatio;

      // We draw the square wave:
      // (startX) go up to high
      // (startX + highWidth) go down to low
      // (startX + period) end of cycle low

      final yLow = height - 10.0;
      final yHigh = 10.0;

      if (isFirst) {
        path.moveTo(startX, yLow);
        isFirst = false;
      } else {
        path.lineTo(startX, yLow);
      }

      path.lineTo(startX, yHigh);
      path.lineTo(startX + highWidth, yHigh);
      path.lineTo(startX + highWidth, yLow);
      path.lineTo(startX + period, yLow);
    }

    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant PwmWavePainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.dutyPercent != dutyPercent;
  }
}

class PwmWheelPainter extends CustomPainter {
  final double angle;

  PwmWheelPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4;

    // Draw wheel outer
    final paintOuter = Paint()
      ..color = elioMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, paintOuter);

    // Draw wheel fill
    final paintFill = Paint()
      ..color = elioBackground
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paintFill);

    // Draw spokes
    final paintSpoke = Paint()
      ..color = elioPrimary
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Cross shape
    canvas.drawLine(
      Offset(-radius + 10, 0),
      Offset(radius - 10, 0),
      paintSpoke,
    );
    canvas.drawLine(
      Offset(0, -radius + 10),
      Offset(0, radius - 10),
      paintSpoke,
    );

    // Center dot
    canvas.drawCircle(Offset.zero, 8, Paint()..color = elioInk);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PwmWheelPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
