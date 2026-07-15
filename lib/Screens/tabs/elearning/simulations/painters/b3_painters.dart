import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../../theme/elio_learning_colors.dart';

class VaporPressurePainter extends CustomPainter {
  final double temperatureC;
  final double relativePressure;
  
  VaporPressurePainter({required this.temperatureC, required this.relativePressure});

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
    
    // Draw approximate Clausius-Clapeyron curve up to 100C
    final path = Path();
    bool first = true;
    
    double maxPressure = exp(15.0 - (4000.0 / (100.0 + 273.15)));
    
    for (double t = 0; t <= 100; t += 2) {
      final x = 20 + (t / 100) * (width - 40);
      final p = exp(15.0 - (4000.0 / (t + 273.15)));
      
      final y = (height - 20) - (p / maxPressure) * (height - 40);
      
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paintCurve);
    
    // Draw current point
    final currX = 20 + (temperatureC / 100) * (width - 40);
    final currY = (height - 20) - (relativePressure / maxPressure) * (height - 40);
    
    canvas.drawCircle(Offset(currX, currY), 6, Paint()..color = elioDanger);
    
    // Draw lines to axes
    final paintDotLine = Paint()
      ..color = elioDanger.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
      
    // Simple dashed line implementation for the point
    canvas.drawLine(Offset(currX, currY), Offset(currX, height - 20), paintDotLine);
    canvas.drawLine(Offset(currX, currY), Offset(20, currY), paintDotLine);
  }

  @override
  bool shouldRepaint(covariant VaporPressurePainter oldDelegate) {
    return oldDelegate.temperatureC != temperatureC;
  }
}

class IncineratorPainter extends CustomPainter {
  final double temperatureC;
  final bool isDestroyed;
  
  IncineratorPainter({required this.temperatureC, required this.isDestroyed});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    
    // Chamber
    final rect = Rect.fromLTWH(width/2 - 40, height/2 - 40, 80, 80);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(8)), Paint()..color = Colors.grey.shade200);
    
    // Draw flame size based on temp
    final flameScale = temperatureC / 1200.0;
    if (flameScale > 0) {
      final flamePaint = Paint()
        ..color = isDestroyed ? elioWarning : elioDanger
        ..style = PaintingStyle.fill;
        
      final flameHeight = 20 + (40 * flameScale);
      final flamePath = Path()
        ..moveTo(width/2, height/2 + 30)
        ..quadraticBezierTo(width/2 - 20 * flameScale, height/2 + 10 - flameHeight/2, width/2, height/2 + 30 - flameHeight)
        ..quadraticBezierTo(width/2 + 20 * flameScale, height/2 + 10 - flameHeight/2, width/2, height/2 + 30);
        
      canvas.drawPath(flamePath, flamePaint);
    }
    
    // Draw chemical bond icon (destroyed or intact)
    final bondPaint = Paint()
      ..color = elioInk
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
      
    if (isDestroyed) {
      // Broken bond
      canvas.drawLine(Offset(width/2 - 15, height/2 - 15), Offset(width/2 - 5, height/2 - 5), bondPaint);
      canvas.drawLine(Offset(width/2 + 5, height/2 - 15), Offset(width/2 + 15, height/2 - 5), bondPaint);
      
      canvas.drawCircle(Offset(width/2 - 15, height/2 - 15), 4, Paint()..color = elioDanger);
      canvas.drawCircle(Offset(width/2 + 15, height/2 - 5), 4, Paint()..color = elioWarning);
    } else {
      // Intact bond
      canvas.drawLine(Offset(width/2 - 10, height/2 - 10), Offset(width/2 + 10, height/2 - 10), bondPaint);
      canvas.drawCircle(Offset(width/2 - 10, height/2 - 10), 4, Paint()..color = elioInk);
      canvas.drawCircle(Offset(width/2 + 10, height/2 - 10), 4, Paint()..color = elioInk);
    }
    
    // Gauge
    final gaugePaint = Paint()
      ..color = elioBorder
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
      
    canvas.drawLine(Offset(20, height - 10), Offset(width - 20, height - 10), gaugePaint);
    
    final fillPaint = Paint()
      ..color = isDestroyed ? elioOk : elioDanger
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
      
    final progressX = 20 + ((temperatureC - 200) / 1000) * (width - 40);
    canvas.drawLine(Offset(20, height - 10), Offset(progressX, height - 10), fillPaint);
  }

  @override
  bool shouldRepaint(covariant IncineratorPainter oldDelegate) {
    return oldDelegate.temperatureC != temperatureC;
  }
}

class RadiationPainter extends CustomPainter {
  final double thicknessCm;
  final double transmittedPercent;
  
  RadiationPainter({required this.thicknessCm, required this.transmittedPercent});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    
    // Shield material
    final maxShieldWidth = 60.0;
    final currentShieldWidth = (thicknessCm / 20.0) * maxShieldWidth;
    
    final shieldX = width / 2 - currentShieldWidth / 2;
    
    if (thicknessCm > 0) {
      final shieldPaint = Paint()..color = Colors.grey.shade400;
      canvas.drawRect(Rect.fromLTWH(shieldX, 20, currentShieldWidth, height - 40), shieldPaint);
    }
    
    // Incoming radiation
    final incomingPaint = Paint()
      ..color = elioWarning
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
      
    // Draw incoming wave (left side)
    canvas.drawLine(Offset(10, height/2), Offset(width/2 - 40, height/2), incomingPaint);
    
    // Transmitted radiation (right side)
    final transmitOpacity = (transmittedPercent / 100.0).clamp(0.1, 1.0);
    final transmitPaint = Paint()
      ..color = elioWarning.withValues(alpha: transmitOpacity)
      ..strokeWidth = 4 * (transmittedPercent / 100.0).clamp(0.2, 1.0)
      ..strokeCap = StrokeCap.round;
      
    if (transmittedPercent > 0.1) {
      canvas.drawLine(Offset(width/2 + 40, height/2), Offset(width - 10, height/2), transmitPaint);
    }
    
    // Text labels
    final tp = TextPainter(
      text: const TextSpan(text: '100%', style: TextStyle(color: elioInk, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(20, height/2 - 20));
    
    final tp2 = TextPainter(
      text: TextSpan(text: '${transmittedPercent.toStringAsFixed(1)}%', style: TextStyle(color: elioInk, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(width - 50, height/2 - 20));
  }

  @override
  bool shouldRepaint(covariant RadiationPainter oldDelegate) {
    return oldDelegate.thicknessCm != thicknessCm || oldDelegate.transmittedPercent != transmittedPercent;
  }
}
