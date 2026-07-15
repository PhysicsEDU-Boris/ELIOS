import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../../theme/elio_learning_colors.dart';

class HookeSpringPainter extends CustomPainter {
  final double compressionCm; // 2 to 20
  
  HookeSpringPainter({required this.compressionCm});

  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()
      ..color = elioInk
      ..strokeWidth = 4;
      
    final paintSpring = Paint()
      ..color = elioPrimary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
      
    final paintBlock = Paint()
      ..color = elioMuted
      ..style = PaintingStyle.fill;

    // Draw fixed wall on left
    canvas.drawLine(Offset(10, 10), Offset(10, size.height - 10), paintBase);

    // Spring logic
    final maxSpringLength = size.width - 60; // Leave room for block
    final minSpringLength = 40.0;
    
    // Map compression (2-20) to spring length (max to min)
    // At x=0 (uncompressed), length = max
    // At x=20 (max compress), length = min
    final compressionRatio = compressionCm / 20.0;
    final currentSpringLength = maxSpringLength - (maxSpringLength - minSpringLength) * compressionRatio;
    
    final path = Path();
    final startX = 10.0;
    final endX = startX + currentSpringLength;
    final midY = size.height / 2;
    
    path.moveTo(startX, midY);
    
    final int coils = 8;
    final double coilWidth = currentSpringLength / coils;
    
    for (int i = 0; i < coils; i++) {
      final cx = startX + (i * coilWidth);
      if (i % 2 == 0) {
        path.lineTo(cx + coilWidth / 2, midY - 20);
      } else {
        path.lineTo(cx + coilWidth / 2, midY + 20);
      }
      path.lineTo(cx + coilWidth, midY);
    }
    
    canvas.drawPath(path, paintSpring);
    
    // Draw the pushing block
    final blockRect = Rect.fromLTWH(endX, midY - 25, 40, 50);
    canvas.drawRRect(RRect.fromRectAndRadius(blockRect, const Radius.circular(8)), paintBlock);
    
    // Draw force arrow if compressed
    if (compressionCm > 0) {
      final arrowPaint = Paint()
        ..color = elioDanger
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      
      final arrowLength = 20 + (compressionCm * 3);
      final arrowEndX = endX + 40 + arrowLength;
      
      canvas.drawLine(Offset(endX + 45, midY), Offset(arrowEndX, midY), arrowPaint);
      
      // Arrow head (pushing left) -> wait, Hooke's force pushes left against compression?
      // Actually, external force pushes right to compress, restoring force pushes left.
      // Let's draw restoring force pushing left.
      final restoreEndX = startX + currentSpringLength + 5;
      final restoreStartX = restoreEndX + arrowLength;
      
      canvas.drawLine(Offset(restoreStartX, midY), Offset(restoreEndX, midY), arrowPaint);
      canvas.drawLine(Offset(restoreEndX, midY), Offset(restoreEndX + 10, midY - 10), arrowPaint);
      canvas.drawLine(Offset(restoreEndX, midY), Offset(restoreEndX + 10, midY + 10), arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HookeSpringPainter oldDelegate) {
    return oldDelegate.compressionCm != compressionCm;
  }
}

class NirCurvePainter extends CustomPainter {
  final double peakNm;
  
  NirCurvePainter({required this.peakNm});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    
    final paintBgLine = Paint()
      ..color = elioBorder
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final paintCurve = Paint()
      ..color = elioPrimary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
      
    // Draw axes
    canvas.drawLine(Offset(20, height - 20), Offset(width - 20, height - 20), paintBgLine);
    canvas.drawLine(Offset(20, height - 20), Offset(20, 20), paintBgLine);
    
    // x range: 1300 to 1900 nm
    final minNm = 1300.0;
    final maxNm = 1900.0;
    
    double nmToX(double nm) {
      return 20 + ((nm - minNm) / (maxNm - minNm)) * (width - 40);
    }
    
    final path = Path();
    bool first = true;
    
    for (double x = 20; x <= width - 20; x += 2) {
      final nm = minNm + ((x - 20) / (width - 40)) * (maxNm - minNm);
      // Gaussian: e^(-(x-mu)^2 / (2*sigma^2))
      final sigma = 30.0; // peak width
      final intensity = exp(-pow(nm - peakNm, 2) / (2 * pow(sigma, 2)));
      
      final y = (height - 20) - (intensity * (height - 40));
      
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paintCurve);
    
    // Draw peak line
    final peakX = nmToX(peakNm);
    final paintPeakLine = Paint()
      ..color = elioWarning
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    final dashHeight = 5.0;
    for (double y = height - 20; y > 20; y -= dashHeight * 2) {
      canvas.drawLine(Offset(peakX, y), Offset(peakX, y - dashHeight), paintPeakLine);
    }
  }

  @override
  bool shouldRepaint(covariant NirCurvePainter oldDelegate) {
    return oldDelegate.peakNm != peakNm;
  }
}

class EddyCurrentPainter extends CustomPainter {
  final double animationValue; // 0 to 1 for infinite movement loop
  
  EddyCurrentPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    
    // Draw metallic conveyor / plate
    final paintPlate = Paint()
      ..color = elioBorder
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(20, height - 40, width - 40, 20), paintPlate);
    
    // Magnet moving over plate (left to right)
    final magnetX = 20 + (width - 80) * animationValue;
    final paintMagnet = Paint()
      ..color = elioDanger
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Rect.fromLTWH(magnetX, height - 90, 40, 40), paintMagnet);
    
    // Draw "N" for North Pole
    final textPainter = TextPainter(
      text: const TextSpan(text: 'N', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(magnetX + 15, height - 80));
    
    // Draw eddy currents (circular arrows in the plate below the magnet)
    final eddyPaint = Paint()
      ..color = elioPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    canvas.drawArc(Rect.fromLTWH(magnetX, height - 35, 40, 10), 0, pi, false, eddyPaint);
    canvas.drawArc(Rect.fromLTWH(magnetX + 5, height - 32, 30, 4), 0, pi, false, eddyPaint);
    
    // Draw opposing magnetic field arrow (pushing away)
    final repelPaint = Paint()
      ..color = elioWarning
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
      
    canvas.drawLine(Offset(magnetX + 20, height - 45), Offset(magnetX + 20, height - 65), repelPaint);
    canvas.drawLine(Offset(magnetX + 20, height - 65), Offset(magnetX + 15, height - 55), repelPaint);
    canvas.drawLine(Offset(magnetX + 20, height - 65), Offset(magnetX + 25, height - 55), repelPaint);
  }

  @override
  bool shouldRepaint(covariant EddyCurrentPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
