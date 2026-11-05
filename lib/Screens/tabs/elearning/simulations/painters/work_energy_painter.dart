import 'package:elio/l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/elio_learning_colors.dart';

class WorkEnergyPainter extends CustomPainter {
  final double heightM;
  final double massKg;

  WorkEnergyPainter({required this.heightM, required this.massKg});

  @override
  void paint(Canvas canvas, Size size) {
    // Logical 200 x 300
    final scale = size.height / 300.0;
    canvas.save();
    canvas.scale(scale);
    final width = size.width / scale;

    // Draw ruler on the left
    final paintRuler = Paint()
      ..color = elioMuted
      ..strokeWidth = 2;

    // Ruler axis
    final axisX = 30.0;
    canvas.drawLine(Offset(axisX, 20), Offset(axisX, 280), paintRuler);

    // Ruler ticks (0 to 1.5m)
    for (int i = 0; i <= 5; i++) {
      final val = 1.5 - (i * 0.3); // 1.5, 1.2, 0.9, 0.6, 0.3, 0.0
      final y = 30 + (i * 50.0);
      canvas.drawLine(Offset(axisX - 5, y), Offset(axisX + 5, y), paintRuler);

      final textSpan = TextSpan(
        text: '${fmtNum(val, 1)}m',
        style: const TextStyle(color: elioMuted, fontSize: 10),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(axisX - 30, y - 5));
    }

    // Draw rail
    final railX = width / 2;
    final paintRail = Paint()
      ..color = elioBorder
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(railX, 20), Offset(railX, 280), paintRail);

    // Calculate lifter position
    // heightM ranges from 0.0 to 1.5. 1.5m -> y=30, 0.0m -> y=280
    final lifterY = 280 - (heightM / 1.5) * 250;

    // Draw payload (scales visually with massKg: 0.5 to 5.0)
    // base size = 30, max size = 80
    final payloadSize = 30 + (massKg / 5.0) * 50;
    final payloadRect = Rect.fromCenter(
      center: Offset(railX, lifterY - payloadSize / 2),
      width: payloadSize,
      height: payloadSize,
    );
    final paintPayload = Paint()
      ..color = elioPrimary
      ..style = PaintingStyle.fill;
    canvas.drawRect(payloadRect, paintPayload);

    // Draw "stack of newspaper" lines on payload
    final paintLine = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.5;
    for (int i = 1; i < 4; i++) {
      final ly = payloadRect.top + i * (payloadSize / 4);
      canvas.drawLine(
        Offset(payloadRect.left + 2, ly),
        Offset(payloadRect.right - 2, ly),
        paintLine,
      );
    }

    // Draw lifter platform
    final paintPlatform = Paint()
      ..color = elioInk
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(railX - payloadSize / 2 - 10, lifterY),
      Offset(railX + payloadSize / 2 + 10, lifterY),
      paintPlatform,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WorkEnergyPainter oldDelegate) {
    return oldDelegate.heightM != heightM || oldDelegate.massKg != massKg;
  }
}
