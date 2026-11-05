import 'package:elio/l10n/l10n.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../../physics/torque/torque_state.dart';

const Size torqueLogicalSize = Size(340, 300);

const Offset torqueShoulder = Offset(95, 235);
const double torquePxPerMeter = 130;

Offset torqueArmEnd(TorqueState state) {
  final rad = state.angleDeg * math.pi / 180;
  return Offset(
    torqueShoulder.dx + math.cos(rad) * state.armLength * torquePxPerMeter,
    torqueShoulder.dy - math.sin(rad) * state.armLength * torquePxPerMeter,
  );
}

class TorquePainter extends CustomPainter {
  final TorqueState state;
  final bool shake;
  static final _rng = math.Random();

  TorquePainter({required this.state, required this.shake});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / torqueLogicalSize.width;
    canvas.save();
    canvas.scale(scale);

    if (shake) {
      canvas.translate(
        (_rng.nextDouble() - 0.5) * 4,
        (_rng.nextDouble() - 0.5) * 4,
      );
    }

    _drawGround(canvas);
    _drawRobotBase(canvas);
    final status = state.motorStatus;
    _drawShoulder(canvas, _statusColor(status));
    final end = torqueArmEnd(state);
    _drawArm(canvas, end);
    _drawGripperAndPayload(canvas, end);
    _drawAngleArc(canvas);
    _drawLengthLabel(canvas, end);
    _drawGauge(canvas, state.torque);

    canvas.restore();
  }

  void _drawGround(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 260, 340, 40),
      Paint()..color = const Color(0xFFE6F2EC),
    );
    canvas.drawLine(
      const Offset(0, 260),
      const Offset(340, 260),
      Paint()
        ..color = const Color(0xFF3D4943)
        ..strokeWidth = 2,
    );
  }

  void _drawRobotBase(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF3D4943);
    canvas.drawRect(const Rect.fromLTWH(55, 245, 90, 22), paint);
    canvas.drawRect(const Rect.fromLTWH(70, 218, 55, 30), paint);
    canvas.drawCircle(const Offset(70, 260), 10, paint);
    canvas.drawCircle(const Offset(125, 260), 10, paint);
  }

  void _drawShoulder(Canvas canvas, Color color) {
    canvas.drawCircle(torqueShoulder, 14, Paint()..color = color);
    canvas.drawCircle(
      torqueShoulder,
      14,
      Paint()
        ..color = const Color(0xFF191C1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawArm(Canvas canvas, Offset end) {
    canvas.drawLine(
      torqueShoulder + const Offset(2, 3),
      end + const Offset(2, 3),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.1)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      torqueShoulder,
      end,
      Paint()
        ..color = const Color(0xFF00694C)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      torqueShoulder,
      end,
      Paint()
        ..color = const Color(0xFF7BC4A4)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawGripperAndPayload(Canvas canvas, Offset end) {
    canvas.drawCircle(end, 9, Paint()..color = const Color(0xFF3D4943));
    canvas.drawCircle(
      end,
      16,
      Paint()
        ..color = const Color(0xFFFFD66B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final boxSize = 14 + state.load * 1.2;
    final boxRect = Rect.fromLTWH(
      end.dx - boxSize / 2,
      end.dy + 7,
      boxSize,
      boxSize,
    );
    canvas.drawRect(boxRect, Paint()..color = const Color(0xFF8B6F47));
    canvas.drawRect(
      boxRect,
      Paint()
        ..color = const Color(0xFF3D4943)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    _drawText(
      canvas,
      '${fmtNum(state.load, 1)}N',
      boxRect.center,
      color: Colors.white,
      bold: true,
      fontSize: 9,
      center: true,
      verticalCenter: true,
    );
  }

  void _drawAngleArc(Canvas canvas) {
    canvas.drawArc(
      Rect.fromCircle(center: torqueShoulder, radius: 34),
      -(state.angleDeg * math.pi / 180),
      state.angleDeg * math.pi / 180,
      false,
      Paint()
        ..color = const Color(0xFF00694C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    _drawText(
      canvas,
      '${fmtNum(state.angleDeg, 0)}°',
      Offset(torqueShoulder.dx + 40, torqueShoulder.dy - 12),
      color: const Color(0xFF00694C),
      bold: true,
    );
  }

  void _drawLengthLabel(Canvas canvas, Offset end) {
    final mid = Offset(
      (torqueShoulder.dx + end.dx) / 2,
      (torqueShoulder.dy + end.dy) / 2,
    );
    final angle = math.atan2(
      end.dy - torqueShoulder.dy,
      end.dx - torqueShoulder.dx,
    );
    canvas.save();
    canvas.translate(mid.dx, mid.dy);
    canvas.rotate(angle);
    _drawText(
      canvas,
      'r = ${fmtNum(state.armLength, 2)}m',
      const Offset(0, -16),
      color: const Color(0xFF191C1C),
      bold: true,
      center: true,
    );
    canvas.restore();
  }

  void _drawGauge(Canvas canvas, double tau) {
    const gx = 300.0, gy = 150.0;
    final rect = Rect.fromLTWH(gx - 22, gy - 80, 44, 160);
    canvas.drawRect(rect, Paint()..color = const Color(0xFFF0F5F2));
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF3D4943)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final fillHeight = math.min(160.0, (tau / 12) * 160);
    final fillRect = Rect.fromLTWH(
      gx - 22,
      gy + 80 - fillHeight,
      44,
      fillHeight,
    );
    canvas.drawRect(
      fillRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFF2EA36B), Color(0xFFE8A33D), Color(0xFFD14B3D)],
        ).createShader(rect),
    );

    final threshY = gy + 80 - (8 / 12) * 160;
    canvas.drawLine(
      Offset(gx - 22, threshY),
      Offset(gx + 22, threshY),
      Paint()
        ..color = const Color(0xFFD14B3D)
        ..strokeWidth = 2,
    );

    _drawText(
      canvas,
      l10n.simTorquePainter1,
      Offset(gx, gy - 100),
      color: const Color(0xFF191C1C),
      bold: true,
      center: true,
      fontSize: 10,
    );
    _drawText(
      canvas,
      tau.toStringAsFixed(2),
      Offset(gx, gy + 88),
      color: const Color(0xFF191C1C),
      bold: true,
      center: true,
      fontSize: 12,
    );
    _drawText(
      canvas,
      'N·m',
      Offset(gx, gy + 102),
      color: const Color(0xFF3D4943),
      center: true,
      fontSize: 9,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    Color color = Colors.black,
    bool bold = false,
    double fontSize = 11,
    bool center = false,
    bool verticalCenter = false,
  }) {
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
    final dy = verticalCenter ? offset.dy - tp.height / 2 : offset.dy;
    tp.paint(canvas, Offset(dx, dy));
  }

  Color _statusColor(MotorStatus status) {
    switch (status) {
      case MotorStatus.safe:
        return const Color(0xFF2EA36B);
      case MotorStatus.warning:
        return const Color(0xFFE8A33D);
      case MotorStatus.critical:
        return const Color(0xFFD14B3D);
    }
  }

  @override
  bool shouldRepaint(covariant TorquePainter oldDelegate) {
    return oldDelegate.state.armLength != state.armLength ||
        oldDelegate.state.load != state.load ||
        oldDelegate.state.angleDeg != state.angleDeg ||
        oldDelegate.shake != shake;
  }
}
