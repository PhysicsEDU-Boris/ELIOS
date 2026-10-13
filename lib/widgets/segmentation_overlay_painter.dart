// Copyright (c) Boris Agung, Irham Fajar

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/websocket_service.dart';

class SegmentationOverlayPainter extends CustomPainter {
  final List<Detection> detections;
  final Size imageSize;

  const SegmentationOverlayPainter({
    required this.detections,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty || imageSize.isEmpty) return;

    final transform = _CoverTransform(imageSize, size);
    final boxPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final labelPaint = Paint()
      ..color = const Color(0xDD003D2B)
      ..style = PaintingStyle.fill;

    for (final detection in detections) {
      // MaixCAM2 sends the box centre (x, y) with width/height
      // (elio_maixcam2.py converts top-left to centre for the wire).
      final imageRect = Rect.fromCenter(
        center: Offset(detection.x, detection.y),
        width: detection.w,
        height: detection.h,
      );
      final box = transform.mapRect(imageRect);
      canvas.drawRect(box, boxPaint);
      _drawLabel(canvas, box, detection.label, detection.score, labelPaint);
    }
  }

  void _drawLabel(
    Canvas canvas,
    Rect box,
    String label,
    double score,
    Paint background,
  ) {
    final displayText = label.isNotEmpty
        ? '$label ${(score * 100).toStringAsFixed(0)}%'
        : '${(score * 100).toStringAsFixed(0)}%';

    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelRect = Rect.fromLTWH(
      box.left,
      math.max(0, box.top - textPainter.height - 8),
      textPainter.width + 12,
      textPainter.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
      background,
    );
    textPainter.paint(canvas, Offset(labelRect.left + 6, labelRect.top + 3));
  }

  @override
  bool shouldRepaint(covariant SegmentationOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.imageSize != imageSize;
  }
}

class _CoverTransform {
  final Size imageSize;
  final double scale;
  final Offset offset;

  _CoverTransform(this.imageSize, Size canvasSize)
    : scale = math.max(
        canvasSize.width / imageSize.width,
        canvasSize.height / imageSize.height,
      ),
      offset = Offset(
        (canvasSize.width -
                imageSize.width *
                    math.max(
                      canvasSize.width / imageSize.width,
                      canvasSize.height / imageSize.height,
                    )) /
            2,
        (canvasSize.height -
                imageSize.height *
                    math.max(
                      canvasSize.width / imageSize.width,
                      canvasSize.height / imageSize.height,
                    )) /
            2,
      );

  Rect mapRect(Rect rect) {
    return Rect.fromLTRB(
      (rect.left * scale) + offset.dx,
      (rect.top * scale) + offset.dy,
      (rect.right * scale) + offset.dx,
      (rect.bottom * scale) + offset.dy,
    );
  }
}
