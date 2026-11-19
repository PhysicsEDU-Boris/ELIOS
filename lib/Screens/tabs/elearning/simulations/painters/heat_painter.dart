import 'package:flutter/material.dart';
import '../../../../../theme/elio_learning_colors.dart';

class Particle {
  Offset position;
  Offset velocity;
  Particle({required this.position, required this.velocity});
}

class HeatCompostPainter extends CustomPainter {
  final List<Particle> particles;
  final double temp;

  HeatCompostPainter({required this.particles, required this.temp});

  @override
  void paint(Canvas canvas, Size size) {
    // 240x200 logical size for compost pile
    final scale = size.width / 240.0;
    canvas.save();
    canvas.scale(scale);

    // Draw compost pile (a triangle-like mound)
    final path = Path()
      ..moveTo(20, 180)
      ..quadraticBezierTo(120, 20, 220, 180)
      ..close();

    final compostColor = _getCompostColor(temp);
    final paintPile = Paint()..color = compostColor;
    canvas.drawPath(path, paintPile);

    // Draw particles
    final paintParticle = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    for (final p in particles) {
      canvas.drawCircle(p.position, 3, paintParticle);
    }

    canvas.restore();
  }

  Color _getCompostColor(double temp) {
    // Mesophilic: brown, Thermophilic: orange/red, Overheated: dark red/ash
    if (temp >= 60) return const Color(0xFF6A2B2B); // Dark red/brown
    if (temp >= 55) return const Color(0xFFB35900); // Orange brown
    return const Color(0xFF5D4037); // Standard brown
  }

  @override
  bool shouldRepaint(covariant HeatCompostPainter oldDelegate) {
    return true; // Particles update every frame
  }
}

class ThermometerPainter extends CustomPainter {
  final double temp;

  ThermometerPainter({required this.temp});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Background glass tube
    final paintGlass = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final paintOutline = Paint()
      ..color = elioBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final bulbRadius = width / 2;
    final tubeWidth = width * 0.4;
    final tubeLeft = (width - tubeWidth) / 2;

    // Draw bulb at bottom
    final bulbCenter = Offset(width / 2, height - bulbRadius - 2);
    canvas.drawCircle(bulbCenter, bulbRadius, paintGlass);
    canvas.drawCircle(bulbCenter, bulbRadius, paintOutline);

    // Draw tube
    final tubeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tubeLeft, 0, tubeWidth, height - bulbRadius * 1.5),
      Radius.circular(tubeWidth / 2),
    );
    canvas.drawRRect(tubeRect, paintGlass);
    canvas.drawRRect(tubeRect, paintOutline);

    // Fill
    final fillPaint = Paint()
      ..color = temp >= 60
          ? Colors.red
          : (temp >= 55 ? Colors.orange : Colors.blue);
    canvas.drawCircle(bulbCenter, bulbRadius - 2, fillPaint);

    // Fill rect
    final minTemp = 25.0;
    final maxTemp = 65.0;
    final clampedTemp = temp.clamp(minTemp, maxTemp);
    final fillHeight =
        ((clampedTemp - minTemp) / (maxTemp - minTemp)) *
        (height - bulbRadius * 2);
    final tubeInnerRect = Rect.fromLTWH(
      tubeLeft + 2,
      height - bulbRadius * 1.5 - fillHeight,
      tubeWidth - 4,
      fillHeight + bulbRadius, // Connect down to bulb
    );
    canvas.drawRect(tubeInnerRect, fillPaint);

    // Draw tick marks
    final tickPaint = Paint()
      ..color = elioMuted
      ..strokeWidth = 1;
    final ticks = [25, 35, 45, 55, 65];
    for (final t in ticks) {
      final y =
          height -
          bulbRadius * 1.5 -
          ((t - minTemp) / (maxTemp - minTemp)) * (height - bulbRadius * 2);
      canvas.drawLine(
        Offset(tubeLeft + tubeWidth, y),
        Offset(tubeLeft + tubeWidth + 5, y),
        tickPaint,
      );

      // Text
      final textSpan = TextSpan(
        text: '$t°',
        style: const TextStyle(color: elioMuted, fontSize: 10),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(tubeLeft + tubeWidth + 8, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant ThermometerPainter oldDelegate) {
    return oldDelegate.temp != temp;
  }
}
