import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// One camera image-stream frame in plain, isolate-sendable fields (YUV_420_888).
class YuvFrame {
  const YuvFrame({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  final int width;
  final int height;
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
}

/// Degrees to rotate a sensor-oriented frame so it is upright, from the sensor
/// orientation and the device rotation in degrees (portraitUp 0, landscapeLeft 90, ...).
int yuvRotation({required int sensorOrientation, required int deviceDegrees, required bool frontFacing}) =>
    frontFacing ? (sensorOrientation + deviceDegrees) % 360 : (sensorOrientation - deviceDegrees + 360) % 360;

/// YUV420 -> upright JPEG. Pure CPU work: run it with [yuvToJpegInIsolate].
({Uint8List bytes, int width, int height}) yuvToJpeg(YuvFrame f, {int rotation = 0, int quality = 90}) {
  final rgb = Uint8List(f.width * f.height * 3);
  var o = 0;
  for (var row = 0; row < f.height; row++) {
    final yRow = row * f.yRowStride;
    final uvRow = (row >> 1) * f.uvRowStride;
    for (var col = 0; col < f.width; col++) {
      final uvIndex = uvRow + (col >> 1) * f.uvPixelStride;
      final yy = f.y[yRow + col];
      final uu = f.u[uvIndex] - 128;
      final vv = f.v[uvIndex] - 128;
      rgb[o++] = (yy + 1.402 * vv).round().clamp(0, 255);
      rgb[o++] = (yy - 0.344136 * uu - 0.714136 * vv).round().clamp(0, 255);
      rgb[o++] = (yy + 1.772 * uu).round().clamp(0, 255);
    }
  }
  var image = img.Image.fromBytes(width: f.width, height: f.height, bytes: rgb.buffer, numChannels: 3);
  if (rotation != 0) image = img.copyRotate(image, angle: rotation);
  return (bytes: Uint8List.fromList(img.encodeJpg(image, quality: quality)), width: image.width, height: image.height);
}

/// [yuvToJpeg] off the UI isolate, so a capture never janks the camera preview.
Future<({Uint8List bytes, int width, int height})> yuvToJpegInIsolate(YuvFrame f, {int rotation = 0}) =>
    Isolate.run(() => yuvToJpeg(f, rotation: rotation));
