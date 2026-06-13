import 'dart:async';
import 'dart:developer';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class SegmentationService {
  factory SegmentationService() => _instance;
  SegmentationService._internal();

  static final SegmentationService _instance = SegmentationService._internal();

  static const String _modelAssetPath = 'assets/models/yolo11_seg.tflite';

  Future<void>? _initFuture;
  Uint8List? _modelBytes;
  bool _isAvailable = false;

  Future<void> init() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final modelData = await rootBundle.load(_modelAssetPath);
      _modelBytes = modelData.buffer.asUint8List();

      final interpreter = await Interpreter.fromAsset(_modelAssetPath);
      interpreter.close();
      _isAvailable = true;
    } catch (error) {
      _modelBytes = null;
      _isAvailable = false;
      debugPrint('Segmentation model not found. AI segmentation is disabled.');
      debugPrint('Segmentation model loading error: $error');
    }
  }

  Future<Uint8List?> runInference(Uint8List jpegBytes) async {
    await init();
    if (!_isAvailable) {
      return jpegBytes;
    }

    return Isolate.run(() async {
      final modelBytes = _modelBytes;
      if (modelBytes == null) {
        return jpegBytes;
      }

      final interpreter = Interpreter.fromBuffer(modelBytes);
      try {
        final decoded = img.decodeJpg(jpegBytes);
        if (decoded == null) {
          return jpegBytes;
        }

        final resized = img.copyResize(decoded, width: 640, height: 640);

        final input = List.generate(
          1,
          (_) => List.generate(
            640,
            (y) => List.generate(640, (x) {
              final pixel = resized.getPixel(x, y);
              return <double>[
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            }),
          ),
        );

        final outputShape = interpreter.getOutputTensor(0).shape;
        final output = _createBuffer(outputShape);

        interpreter.run(input, output);

        log('Output Tensor Shape: ${interpreter.getOutputTensor(0).shape}');
        log('Output Tensor First Values: ${_flattenValues(output, 12)}');

        return jpegBytes;
      } finally {
        interpreter.close();
      }
    });
  }

  dynamic _createBuffer(List<int> shape, [int depth = 0]) {
    final length = shape[depth];
    if (depth == shape.length - 1) {
      return List<double>.filled(length, 0);
    }

    return List.generate(length, (_) => _createBuffer(shape, depth + 1));
  }

  List<double> _flattenValues(dynamic values, int limit) {
    final flattened = <double>[];

    void visit(dynamic value) {
      if (flattened.length >= limit) {
        return;
      }

      if (value is List) {
        for (final item in value) {
          if (flattened.length >= limit) {
            break;
          }
          visit(item);
        }
        return;
      }

      if (value is num) {
        flattened.add(value.toDouble());
      }
    }

    visit(values);
    return flattened;
  }
}
