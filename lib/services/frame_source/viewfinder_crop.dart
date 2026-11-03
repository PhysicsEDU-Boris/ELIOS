import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// The JPEG region the on-screen viewfinder box covers. The preview fills
/// [panel] with BoxFit.cover and the box is centred in it, so the box's pixels
/// are [box] / scale around the image centre; [margin] adds a little slack.
Future<Uint8List> cropToViewfinder(Uint8List jpeg, {required Size panel, required Size box, double margin = 1.2}) =>
    compute(_crop, (jpeg, panel.width, panel.height, box.width, box.height, margin));

/// The crop ([x], [y], [w], [h] in image pixels) for an image of [imageW] x [imageH].
({int x, int y, int w, int h}) viewfinderCropRect(int imageW, int imageH, {required Size panel, required Size box, double margin = 1.2}) {
  final scale = panel.width / imageW > panel.height / imageH ? panel.width / imageW : panel.height / imageH;
  final w = (box.width * margin / scale).round().clamp(1, imageW);
  final h = (box.height * margin / scale).round().clamp(1, imageH);
  return (x: (imageW - w) ~/ 2, y: (imageH - h) ~/ 2, w: w, h: h);
}

Uint8List _crop((Uint8List, double, double, double, double, double) a) {
  final (jpeg, pw, ph, bw, bh, margin) = a;
  final image = img.decodeJpg(jpeg);
  if (image == null) return jpeg;
  final r = viewfinderCropRect(image.width, image.height, panel: Size(pw, ph), box: Size(bw, bh), margin: margin);
  final cropped = img.copyCrop(image, x: r.x, y: r.y, width: r.w, height: r.h);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
}

/// [jpeg] shrunk so its longest side is at most [maxSide]; the same bytes when
/// it is already small enough or cannot be decoded.
Future<Uint8List> downscaleJpeg(Uint8List jpeg, {required int maxSide}) =>
    jpeg.isEmpty ? Future.value(jpeg) : compute(_downscale, (jpeg, maxSide));

Uint8List _downscale((Uint8List, int) a) {
  final (jpeg, maxSide) = a;
  try {
    final image = img.decodeJpg(jpeg);
    if (image == null || (image.width <= maxSide && image.height <= maxSide)) return jpeg;
    final small = image.width >= image.height
        ? img.copyResize(image, width: maxSide)
        : img.copyResize(image, height: maxSide);
    return Uint8List.fromList(img.encodeJpg(small, quality: 85));
  } catch (_) {
    return jpeg; // a bad photo is the AI's to refuse, not the resize's
  }
}
