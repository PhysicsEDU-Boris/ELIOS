import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/segmentation_result.dart';

class SegmentationOverlayPainter extends CustomPainter {
  final SegmentationFrameResult? result;

  const SegmentationOverlayPainter({required this.result});

  @override
  void paint(Canvas canvas, Size size) {
    final frame = result;
    if (frame == null || frame.imageSize.isEmpty) return;

    final transform = _CoverTransform(frame.imageSize, size);
    final maskPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    final boxPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final labelPaint = Paint()
      ..color = const Color(0xDD003D2B)
      ..style = PaintingStyle.fill;

    for (final detection in frame.detections) {
      final mask = detection.mask;
      if (mask != null) {
        _drawMask(canvas, transform, detection.boundingBox, mask, maskPaint);
      }

      final box = transform.mapRect(detection.boundingBox);
      canvas.drawRect(box, boxPaint);
      _drawLabel(canvas, box, detection.score, labelPaint);
    }
  }

  void _drawMask(
    Canvas canvas,
    _CoverTransform transform,
    Rect boundingBox,
    SegmentationMask mask,
    Paint paint,
  ) {
    final cellWidth = transform.imageSize.width / mask.width;
    final cellHeight = transform.imageSize.height / mask.height;
    for (var y = 0; y < mask.height; y++) {
      for (var x = 0; x < mask.width; x++) {
        if (!mask.isActive(x, y)) continue;

        final imageRect = Rect.fromLTWH(
          x * cellWidth,
          y * cellHeight,
          cellWidth,
          cellHeight,
        );
        if (!imageRect.overlaps(boundingBox)) continue;
        canvas.drawRect(transform.mapRect(imageRect), paint);
      }
    }
  }

  void _drawLabel(Canvas canvas, Rect box, double score, Paint background) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(score * 100).toStringAsFixed(0)}%',
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
    return oldDelegate.result != result;
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
