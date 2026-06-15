import 'dart:typed_data';
import 'dart:ui';

class SegmentationMask {
  final int width;
  final int height;
  final Uint8List data;

  const SegmentationMask({
    required this.width,
    required this.height,
    required this.data,
  });

  bool isActive(int x, int y) => data[y * width + x] != 0;
}

class SegmentationDetection {
  final Rect boundingBox;
  final double score;
  final SegmentationMask? mask;
  final Offset graspPoint;
  final double graspAngle;

  const SegmentationDetection({
    required this.boundingBox,
    required this.score,
    this.mask,
    required this.graspPoint,
    required this.graspAngle,
  });
}

class SegmentationFrameResult {
  final Size imageSize;
  final List<SegmentationDetection> detections;

  const SegmentationFrameResult({
    required this.imageSize,
    required this.detections,
  });

  bool get isEmpty => detections.isEmpty;
  bool get hasDetections => detections.isNotEmpty;
}
