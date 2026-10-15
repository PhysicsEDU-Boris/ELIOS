import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'detection_stabilizer.dart';
import 'frame_source/frame_source.dart';

/// Crop the locked box from its own frame, scaling image-space coordinates
/// to the decoded image rather than assuming the JPEG matches stream metadata.
Uint8List? cropDetection((CapturedFrame, TrackedDetection) input) {
  final (frame, box) = input;
  if (frame.width <= 0 ||
      frame.height <= 0 ||
      ![box.x, box.y, box.w, box.h].every((v) => v.isFinite) ||
      box.w <= 0 ||
      box.h <= 0) {
    return null;
  }
  try {
    final image = img.decodeImage(frame.bytes);
    if (image == null) return null;
    final sx = image.width / frame.width;
    final sy = image.height / frame.height;
    final left = ((box.x - box.w / 2) * sx).floor().clamp(0, image.width);
    final top = ((box.y - box.h / 2) * sy).floor().clamp(0, image.height);
    final right = ((box.x + box.w / 2) * sx).ceil().clamp(0, image.width);
    final bottom = ((box.y + box.h / 2) * sy).ceil().clamp(0, image.height);
    if (right <= left || bottom <= top) return null;
    return Uint8List.fromList(
      img.encodeJpg(
        img.copyCrop(
          image,
          x: left,
          y: top,
          width: right - left,
          height: bottom - top,
        ),
      ),
    );
  } catch (_) {
    return null;
  }
}
