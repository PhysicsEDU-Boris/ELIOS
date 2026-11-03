import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

import 'detection_stabilizer.dart';
import 'frame_source/frame_source.dart';

/// Crop the locked box from its own frame, scaling image-space coordinates
/// to the decoded image rather than assuming the JPEG matches stream metadata.
Uint8List? cropDetection((CapturedFrame, TrackedDetection) input) {
  return prepareDetectionCrop(input).bytes;
}

({Uint8List? bytes, Uint8List? historyBytes, Uint8List? identifyBytes, Map<String, Object?> details}) prepareDetectionCrop(
  (CapturedFrame, TrackedDetection) input,
) {
  final (frame, box) = input;
  final details = <String, Object?>{};
  if (!frame.hasPairedCleanImage ||
      frame.width <= 0 ||
      frame.height <= 0 ||
      ![box.x, box.y, box.w, box.h].every((v) => v.isFinite) ||
      box.w <= 0 ||
      box.h <= 0) {
    return (bytes: null, historyBytes: null, identifyBytes: null, details: details);
  }
  try {
    final image = img.decodeImage(frame.cleanBytes!);
    if (image == null) return (bytes: null, historyBytes: null, identifyBytes: null, details: details);
    details.addAll({
      'decodedWidth': image.width,
      'decodedHeight': image.height,
      'boxRotationApplied': false,
      'decodeOrientation':
          'image decoder applies JPEG EXIF; box assumes matching axes',
    });
    final sx = image.width / frame.width;
    final sy = image.height / frame.height;
    final left = ((box.x - box.w / 2) * sx).floor().clamp(0, image.width);
    final top = ((box.y - box.h / 2) * sy).floor().clamp(0, image.height);
    final right = ((box.x + box.w / 2) * sx).ceil().clamp(0, image.width);
    final bottom = ((box.y + box.h / 2) * sy).ceil().clamp(0, image.height);
    if (right <= left || bottom <= top) return (bytes: null, historyBytes: null, identifyBytes: null, details: details);
    details.addAll({
      'scaleX': sx,
      'scaleY': sy,
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
      'cropWidth': right - left,
      'cropHeight': bottom - top,
    });
    // History gets its own padded crop; identification bounds and encoding stay unchanged.
    final photoLeft = ((box.x - box.w * .55) * sx).floor().clamp(0, image.width);
    final photoTop = ((box.y - box.h * .55) * sy).floor().clamp(0, image.height);
    final photoRight = ((box.x + box.w * .55) * sx).ceil().clamp(0, image.width);
    final photoBottom = ((box.y + box.h * .55) * sy).ceil().clamp(0, image.height);
    final historyBytes = Uint8List.fromList(img.encodeJpg(
      img.copyCrop(image, x: photoLeft, y: photoTop,
        width: photoRight - photoLeft, height: photoBottom - photoTop),
      quality: 100,
    ));
    // Gemini gets room around the box (decision 0180): a box that cuts the object can still be fixed.
    final padLeft = ((box.x - box.w * .75) * sx).floor().clamp(0, image.width);
    final padTop = ((box.y - box.h * .75) * sy).floor().clamp(0, image.height);
    final padRight = ((box.x + box.w * .75) * sx).ceil().clamp(0, image.width);
    final padBottom = ((box.y + box.h * .75) * sy).ceil().clamp(0, image.height);
    return (
      historyBytes: historyBytes,
      identifyBytes: Uint8List.fromList(img.encodeJpg(img.copyCrop(image, x: padLeft, y: padTop,
          width: padRight - padLeft, height: padBottom - padTop))),
      bytes: Uint8List.fromList(
        img.encodeJpg(
          img.copyCrop(
            image,
            x: left,
            y: top,
            width: right - left,
            height: bottom - top,
          ),
        ),
      ),
      details: details,
    );
  } catch (_) {
    return (bytes: null, historyBytes: null, identifyBytes: null, details: details);
  }
}

/// Gemini's box ([Rect] in 0..1 of [input]'s photo) cut from that photo with a
/// 5 % margin, as the popup and History photo (decision 0180); null if unusable.
Uint8List? cropToBox((Uint8List, Rect) input) {
  final (bytes, box) = input;
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final mx = box.width * .05, my = box.height * .05;
    final left = ((box.left - mx) * image.width).floor().clamp(0, image.width);
    final top = ((box.top - my) * image.height).floor().clamp(0, image.height);
    final right = ((box.right + mx) * image.width).ceil().clamp(0, image.width);
    final bottom = ((box.bottom + my) * image.height).ceil().clamp(0, image.height);
    if (right <= left || bottom <= top) return null;
    return Uint8List.fromList(img.encodeJpg(
      img.copyCrop(image, x: left, y: top, width: right - left, height: bottom - top),
      quality: 100,
    ));
  } catch (_) {
    return null;
  }
}
