import 'package:elio/l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/elio_learning_colors.dart';

class KinematicsPainter extends CustomPainter {
  final double robotX;
  final double distanceM;

  KinematicsPainter({required this.robotX, required this.distanceM});

  @override
  void paint(Canvas canvas, Size size) {
    // We'll map 0..20 meters to the canvas width (minus margins)
    final margin = 20.0;
    final usableWidth = size.width - margin * 2;
    // Maximum possible distance is 20m.
    final pixelsPerMeter = usableWidth / 20.0;

    // Draw track background (dashed line)
    final paintTrack = Paint()
      ..color = elioBorder
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final trackY = size.height / 2;
    _drawDashedLine(
      canvas,
      Offset(margin, trackY),
      Offset(margin + usableWidth, trackY),
      paintTrack,
    );

    // Draw markers (Start = 0m, Target = distanceM)
    final paintMarker = Paint()
      ..color = elioMuted
      ..strokeWidth = 2;

    // Start Marker
    canvas.drawLine(
      Offset(margin, trackY - 10),
      Offset(margin, trackY + 10),
      paintMarker,
    );
    _drawText(canvas, '0 m', Offset(margin, trackY + 15));

    // Target Marker
    final targetX = margin + distanceM * pixelsPerMeter;
    final paintTarget = Paint()
      ..color = elioOk
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(targetX, trackY - 15),
      Offset(targetX, trackY + 15),
      paintTarget,
    );
    _drawText(
      canvas,
      '${fmtNum(distanceM, 1)} m',
      Offset(targetX, trackY + 20),
      color: elioOk,
    );

    // Draw Robot Sprite
    final currentX = margin + robotX * pixelsPerMeter;
    final paintRobot = Paint()..color = elioPrimary;
    final robotRect = Rect.fromCenter(
      center: Offset(currentX, trackY),
      width: 30,
      height: 20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(robotRect, const Radius.circular(4)),
      paintRobot,
    );

    // Draw wheel indicators
    final paintWheel = Paint()..color = elioInk;
    canvas.drawCircle(Offset(currentX - 8, trackY + 10), 4, paintWheel);
    canvas.drawCircle(Offset(currentX + 8, trackY + 10), 4, paintWheel);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    var distance = (p2 - p1).distance;
    var direction = (p2 - p1) / distance;
    var start = p1;
    while (distance >= 0) {
      final end =
          start + direction * (dashWidth < distance ? dashWidth : distance);
      canvas.drawLine(start, end, paint);
      distance -= (dashWidth + dashSpace);
      start = end + direction * dashSpace;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    Color color = elioMuted,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    );
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(covariant KinematicsPainter oldDelegate) {
    return oldDelegate.robotX != robotX || oldDelegate.distanceM != distanceM;
  }
}
