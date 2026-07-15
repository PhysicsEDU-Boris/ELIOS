import 'package:flutter/material.dart';

class DensityPainter extends CustomPainter {
  final double activeVolumeCm3;
  final double activeDensity;
  final double refVolumeCm3;
  final double refDensity;

  DensityPainter({
    required this.activeVolumeCm3,
    required this.activeDensity,
    required this.refVolumeCm3,
    required this.refDensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 340x300 logical size
    final scale = size.width / 340.0;
    canvas.save();
    canvas.scale(scale);

    // Draw reference bottle
    _drawBottle(canvas, const Offset(60, 250), refVolumeCm3, refDensity, 'Referensi', true);
    
    // Draw active bottle
    _drawBottle(canvas, const Offset(200, 250), activeVolumeCm3, activeDensity, 'Objek', false);

    canvas.restore();
  }

  void _drawBottle(Canvas canvas, Offset bottomCenter, double volume, double density, String label, bool isReference) {
    // Volume scales height. max 1000cm3 -> 150px height
    final height = (volume / 1000) * 150 + 20; 
    final width = 50.0;
    
    final rect = Rect.fromCenter(
      center: Offset(bottomCenter.dx, bottomCenter.dy - height / 2),
      width: width,
      height: height,
    );

    // Fill color based on density
    // For density, we'll map color from light blue (low density) to dark gray/brown (high density)
    final clampedDensity = density.clamp(0.0, 5.0);
    final colorVal = (255 - (clampedDensity / 5.0) * 150).toInt();
    final fillColor = Color.fromARGB(200, colorVal, colorVal, colorVal + (isReference ? 50 : 0));

    final paintFill = Paint()..color = fillColor;
    final paintStroke = Paint()
      ..color = const Color(0xFF3D4943)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw bottle body (simple rounded rect with a neck)
    final bodyRect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(bodyRect, paintFill);
    canvas.drawRRect(bodyRect, paintStroke);

    // Draw neck
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(bottomCenter.dx, bottomCenter.dy - height - 10),
        width: 20,
        height: 20,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(neckRect, paintFill);
    canvas.drawRRect(neckRect, paintStroke);

    // Label
    _drawText(canvas, label, Offset(bottomCenter.dx, bottomCenter.dy + 15), bold: true, center: true);
    _drawText(canvas, 'ρ = ${density.toStringAsFixed(2)}', Offset(bottomCenter.dx, bottomCenter.dy - height / 2), center: true, color: Colors.white, bold: true);
    _drawText(canvas, 'V = ${volume.toStringAsFixed(0)}', Offset(bottomCenter.dx, bottomCenter.dy - height / 2 + 15), center: true, color: Colors.white, fontSize: 9);
  }

  void _drawText(Canvas canvas, String text, Offset offset, {Color color = Colors.black, bool bold = false, double fontSize = 11, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? offset.dx - tp.width / 2 : offset.dx;
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant DensityPainter oldDelegate) {
    return oldDelegate.activeVolumeCm3 != activeVolumeCm3 ||
           oldDelegate.activeDensity != activeDensity ||
           oldDelegate.refVolumeCm3 != refVolumeCm3 ||
           oldDelegate.refDensity != refDensity;
  }
}
