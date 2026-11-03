import 'dart:convert';
import 'dart:typed_data';

import 'package:elio/services/detection_crop.dart';
import 'package:elio/services/detection_stabilizer.dart';
import 'package:elio/services/frame_source/frame_source.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _pixels(int r, int g, int b) => Uint8List.fromList(
  img.encodePng(
    img.fill(img.Image(width: 40, height: 20), color: img.ColorRgb8(r, g, b)),
  ),
);

const _box = TrackedDetection(label: 'E_Waste', x: 20, y: 10, w: 20, h: 10);
const _detection = {
  'label': 'E_Waste',
  'x': 20,
  'y': 10,
  'w': 20,
  'h': 10,
  'score': .9,
};

CapturedFrame _parse(Map<String, dynamic> message) =>
    CapturedFrame.fromRobotMessage(
      message,
      previewBytes: _pixels(255, 0, 0),
      width: 40,
      height: 20,
      previewDetections: [Detection.fromJson(_detection)],
    );

Map<String, dynamic> _message() => {
  'vision_protocol': 1,
  'frame_id': 42,
  'detection_frame_id': 42,
  'img_w': 40,
  'img_h': 20,
  'clean_image': base64Encode(_pixels(0, 0, 255)),
  'clean_detections': [_detection],
  'firmware_sha256': 'test-firmware',
};

void main() {
  test(
    'same-message original pixels are cropped, annotated preview stays intact',
    () {
      final frame = _parse(_message());
      final later = _parse({
        ..._message(),
        'frame_id': 43,
        'detection_frame_id': 43,
        'clean_image': base64Encode(_pixels(0, 255, 0)),
      });
      expect(later.frameId, 43);
      final crop = img.decodeJpg(cropDetection((frame, _box))!)!;
      expect((crop.width, crop.height), (20, 10));
      expect(crop.getPixel(5, 5).b, greaterThan(240));
      expect(crop.getPixel(5, 5).r, lessThan(10));
      expect(img.decodeImage(frame.bytes)!.getPixel(5, 5).r, 255);
      expect(frame.detections!.single.label, 'E_Waste');
      expect(frame.firmwareSha256, 'test-firmware');
    },
  );

  for (final dimensions in [(80, 160), (160, 80), (2, 1)]) {
    test('padded $dimensions crop keeps clean pixels at native size and quality 100', () {
      final source = img.Image(width: dimensions.$1, height: dimensions.$2);
      for (final pixel in source) {
        pixel.setRgb(pixel.x % 256, pixel.y % 256, 180);
      }
      final frame = CapturedFrame(
        bytes: _pixels(255, 0, 0),
        cleanBytes: Uint8List.fromList(img.encodePng(source)),
        frameId: 5, detectionFrameId: 5,
        width: source.width, height: source.height, timestamp: DateTime(2026),
      );
      final crop = prepareDetectionCrop((frame, TrackedDetection(
        label: 'Plastic', x: source.width / 2, y: source.height / 2,
        w: source.width / 2, h: source.height / 2,
      )));
      final details = crop.details;
      final identify = img.copyCrop(source,
        x: details['left'] as int, y: details['top'] as int,
        width: details['cropWidth'] as int, height: details['cropHeight'] as int);
      expect(crop.bytes, orderedEquals(img.encodeJpg(identify)));
      final left = (source.width * .225).floor();
      final top = (source.height * .225).floor();
      final right = (source.width * .775).ceil();
      final bottom = (source.height * .775).ceil();
      final expected = img.copyCrop(source, x: left, y: top,
        width: right - left, height: bottom - top);
      expect(crop.historyBytes, orderedEquals(img.encodeJpg(expected, quality: 100)));
      final decoded = img.decodeJpg(crop.historyBytes!)!;
      expect(decoded.width, lessThanOrEqualTo(source.width));
      expect(decoded.height, lessThanOrEqualTo(source.height));
      expect(decoded.width, greaterThan(source.width / 2));
      expect(decoded.height, greaterThan(source.height / 2));
    });
  }

  test('legacy firmware keeps preview but cannot supply a vision crop', () {
    final frame = _parse({});
    expect(frame.bytes, isNotEmpty);
    expect(frame.detections!.single.label, 'E_Waste');
    expect(cropDetection((frame, _box)), isNull);
    expect(prepareDetectionCrop((frame, _box)).historyBytes, isNull);
  });

  test(
    'preview-only frames do not count as empty scenes or reuse clean bytes',
    () {
      expect(_parse(_message()).hasPairedCleanImage, isTrue);
      final preview = _parse({'vision_protocol': 1, 'frame_id': 43});
      expect(preview.detections, isNull);
      expect(preview.cleanBytes, isNull);
      expect(preview.bytes, isNotEmpty);
      final empty = _parse({
        ..._message(),
        'clean_detections': [],
        'clean_image': null,
      });
      expect(empty.detections, isEmpty);
    },
  );

  test(
    'mismatched IDs, dimensions, malformed data and unknown versions fail closed',
    () {
      for (final patch in <Map<String, dynamic>>[
        {'detection_frame_id': 41},
        {'frame_id': null},
        {'frame_id': -1, 'detection_frame_id': -1},
        {'frame_id': 42.5},
        {'img_w': 80},
        {'img_h': null},
        {'vision_protocol': 2},
        {'clean_image': '%%%broken'},
        {
          'clean_detections': ['broken'],
        },
        {
          'clean_detections': [
            {..._detection, 'x': 'invalid'},
          ],
        },
      ]) {
        final frame = _parse({..._message(), ...patch});
        expect(frame.bytes, isNotEmpty);
        expect(frame.detections, isNull, reason: '$patch');
        expect(cropDetection((frame, _box)), isNull, reason: '$patch');
      }
      final missing = _parse({..._message(), 'clean_image': null});
      expect(
        missing.detections,
        isNotEmpty,
      ); // reaches the firmware-update notice
      expect(cropDetection((missing, _box)), isNull);
    },
  );
}
