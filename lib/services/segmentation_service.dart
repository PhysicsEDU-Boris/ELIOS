import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/segmentation_result.dart';

class SegmentationService {
  factory SegmentationService() => _instance;
  SegmentationService._internal();

  static final SegmentationService _instance = SegmentationService._internal();

  static const String _modelAssetPath = 'assets/models/yolo11_seg.tflite';
  static const int _inputSize = 320;
  static const int _maskSize = 80;
  static const double _confidenceThreshold = 0.70;
  static const double _iouThreshold = 0.35;

  Future<void>? _initFuture;
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _workerSendPort;
  StreamSubscription<dynamic>? _receiveSub;
  int _nextRequestId = 0;
  bool _isAvailable = false;
  final Map<int, Completer<Map<String, dynamic>?>> _pending = {};

  Future<void> init() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      final modelData = await rootBundle.load(_modelAssetPath);
      final modelBytes = Uint8List.fromList(
        modelData.buffer.asUint8List(
          modelData.offsetInBytes,
          modelData.lengthInBytes,
        ),
      );

      final ready = Completer<void>();
      final receivePort = ReceivePort();
      _receivePort = receivePort;
      _receiveSub = receivePort.listen((message) {
        if (message is SendPort) {
          _workerSendPort = message;
          _isAvailable = true;
          if (!ready.isCompleted) ready.complete();
          return;
        }

        if (message is Map) {
          final id = message['id'];
          if (id is int) {
            final completer = _pending.remove(id);
            if (completer != null && !completer.isCompleted) {
              final result = message['result'];
              if (result is Map) {
                completer.complete(Map<String, dynamic>.from(result));
              } else {
                completer.complete(null);
              }
            }
          }
        }
      });

      _isolate = await Isolate.spawn(_inferenceEntry, [
        receivePort.sendPort,
        modelBytes,
      ], debugName: 'elio-segmentation-worker');
      await ready.future.timeout(const Duration(seconds: 5));
    } catch (error, stackTrace) {
      _isAvailable = false;
      debugPrint('Segmentation model loading error: $error');
      debugPrintStack(stackTrace: stackTrace);
      dispose();
    }
  }

  Future<SegmentationFrameResult?> runInference(Uint8List jpegBytes) async {
    await init();
    final worker = _workerSendPort;
    if (!_isAvailable || worker == null) return null;

    final id = _nextRequestId++;
    final completer = Completer<Map<String, dynamic>?>();
    _pending[id] = completer;
    worker.send({'id': id, 'jpeg': jpegBytes});

    final resultMap = await completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        _pending.remove(id);
        return null;
      },
    );
    if (resultMap == null) return null;
    return _toFrameResult(resultMap);
  }

  void dispose() {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _pending.clear();
    _receiveSub?.cancel();
    _receiveSub = null;
    _receivePort?.close();
    _receivePort = null;
    _workerSendPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _isAvailable = false;
    _initFuture = null;
  }

  SegmentationFrameResult? _toFrameResult(Map<String, dynamic> map) {
    final imageWidth = _asDouble(map['img_w']);
    final imageHeight = _asDouble(map['img_h']);
    if (imageWidth <= 0 || imageHeight <= 0) return null;

    final maskBytes = map['mask_bytes'];
    final detection = SegmentationDetection(
      boundingBox: Rect.fromLTRB(
        _asDouble(map['x1']),
        _asDouble(map['y1']),
        _asDouble(map['x2']),
        _asDouble(map['y2']),
      ),
      score: _asDouble(map['score']),
      mask: maskBytes is Uint8List
          ? SegmentationMask(
              width: _asInt(map['mask_w']),
              height: _asInt(map['mask_h']),
              data: maskBytes,
            )
          : null,
      graspPoint: Offset(_asDouble(map['grasp_x']), _asDouble(map['grasp_y'])),
      graspAngle: _asDouble(map['angle']),
    );

    return SegmentationFrameResult(
      imageSize: Size(imageWidth, imageHeight),
      detections: [detection],
    );
  }

  static double _asDouble(Object? value) =>
      value is num ? value.toDouble() : 0.0;

  static int _asInt(Object? value) => value is num ? value.toInt() : 0;

  static void _inferenceEntry(List<dynamic> args) {
    final mainSend = args[0] as SendPort;
    final modelBytes = args[1] as Uint8List;
    final receivePort = ReceivePort();

    late final Interpreter interpreter;
    try {
      interpreter = Interpreter.fromBuffer(modelBytes);
      final out0Shape = interpreter.getOutputTensor(0).shape;
      final out1Shape = interpreter.getOutputTensor(1).shape;
      debugPrint('Segmentation output[0] shape: $out0Shape');
      debugPrint('Segmentation output[1] shape: $out1Shape');
    } catch (error, stackTrace) {
      debugPrint('Segmentation worker failed to start: $error');
      debugPrintStack(stackTrace: stackTrace);
      receivePort.close();
      return;
    }

    mainSend.send(receivePort.sendPort);
    receivePort.listen((message) {
      if (message is! Map) return;
      final id = message['id'];
      final jpeg = message['jpeg'];
      if (id is! int || jpeg is! Uint8List) return;

      try {
        final result = _runWorkerInference(interpreter, jpeg);
        mainSend.send({'id': id, 'result': result});
      } catch (error, stackTrace) {
        debugPrint('Segmentation inference failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        mainSend.send({'id': id, 'result': null});
      }
    });
  }

  static Map<String, dynamic>? _runWorkerInference(
    Interpreter interpreter,
    Uint8List jpeg,
  ) {
    final decoded = img.decodeJpg(jpeg);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return null;
    }

    final resized = img.copyResize(
      decoded,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );
    final input = _buildNchwInput(resized);
    final pred = _createBuffer(interpreter.getOutputTensor(0).shape);
    final protos = _createBuffer(interpreter.getOutputTensor(1).shape);

    interpreter.runForMultipleInputs([input], {0: pred, 1: protos});

    return _decodeBestDetection(
      pred,
      protos,
      decoded.width.toDouble(),
      decoded.height.toDouble(),
    );
  }

  static List<List<List<List<double>>>> _buildNchwInput(img.Image image) {
    return [
      List.generate(3, (channel) {
        return List.generate(_inputSize, (y) {
          return List.generate(_inputSize, (x) {
            final pixel = image.getPixel(x, y);
            return switch (channel) {
              0 => pixel.r / 255.0,
              1 => pixel.g / 255.0,
              _ => pixel.b / 255.0,
            };
          });
        });
      }),
    ];
  }

  static dynamic _createBuffer(List<int> shape, [int depth = 0]) {
    final length = shape[depth];
    if (depth == shape.length - 1) {
      return List<double>.filled(length, 0);
    }
    return List.generate(length, (_) => _createBuffer(shape, depth + 1));
  }

  static Map<String, dynamic>? _decodeBestDetection(
    dynamic predOutput,
    dynamic protoOutput,
    double imageWidth,
    double imageHeight,
  ) {
    final pred = predOutput[0] as List;
    final protos = protoOutput[0] as List;
    if (pred.length < 37) return null;

    final count = (pred[0] as List).length;
    final candidates = <_Candidate>[];
    for (var i = 0; i < count; i++) {
      final score = _sigmoid(_valueAt(pred, 4, i));
      if (score < _confidenceThreshold) continue;

      var cx = _valueAt(pred, 0, i);
      var cy = _valueAt(pred, 1, i);
      var w = _valueAt(pred, 2, i);
      var h = _valueAt(pred, 3, i);
      if ([cx, cy, w, h].every((v) => v >= 0 && v <= 2)) {
        cx *= _inputSize;
        cy *= _inputSize;
        w *= _inputSize;
        h *= _inputSize;
      }

      final box = Rect.fromLTRB(
        (cx - (w / 2)).clamp(0.0, _inputSize.toDouble()),
        (cy - (h / 2)).clamp(0.0, _inputSize.toDouble()),
        (cx + (w / 2)).clamp(0.0, _inputSize.toDouble()),
        (cy + (h / 2)).clamp(0.0, _inputSize.toDouble()),
      );
      if (box.width <= 1 || box.height <= 1) continue;

      candidates.add(
        _Candidate(
          box: box,
          score: score,
          coefficients: List<double>.generate(
            32,
            (j) => _valueAt(pred, 5 + j, i),
          ),
        ),
      );
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final selected = _nonMaxSuppress(candidates).firstOrNull;
    if (selected == null) return null;

    final mask = Uint8List(_maskSize * _maskSize);
    var activeCount = 0;
    var sumX = 0.0;
    var sumY = 0.0;
    for (var y = 0; y < _maskSize; y++) {
      for (var x = 0; x < _maskSize; x++) {
        var logit = 0.0;
        for (var c = 0; c < selected.coefficients.length; c++) {
          logit += selected.coefficients[c] * _protoValue(protos, c, y, x);
        }
        if (_sigmoid(logit) > 0.5) {
          final index = (y * _maskSize) + x;
          mask[index] = 1;
          activeCount++;
          sumX += x + 0.5;
          sumY += y + 0.5;
        }
      }
    }

    final scaleX = imageWidth / _inputSize;
    final scaleY = imageHeight / _inputSize;
    final box = Rect.fromLTRB(
      selected.box.left * scaleX,
      selected.box.top * scaleY,
      selected.box.right * scaleX,
      selected.box.bottom * scaleY,
    );
    final graspX = activeCount > 0
        ? (sumX / activeCount) * (imageWidth / _maskSize)
        : box.center.dx;
    final graspY = activeCount > 0
        ? (sumY / activeCount) * (imageHeight / _maskSize)
        : box.center.dy;

    return {
      'img_w': imageWidth,
      'img_h': imageHeight,
      'x1': box.left.clamp(0.0, imageWidth),
      'y1': box.top.clamp(0.0, imageHeight),
      'x2': box.right.clamp(0.0, imageWidth),
      'y2': box.bottom.clamp(0.0, imageHeight),
      'score': selected.score,
      'grasp_x': graspX.clamp(0.0, imageWidth),
      'grasp_y': graspY.clamp(0.0, imageHeight),
      'angle': 0.0,
      'mask_w': _maskSize,
      'mask_h': _maskSize,
      'mask_bytes': mask,
    };
  }

  static List<_Candidate> _nonMaxSuppress(List<_Candidate> candidates) {
    final kept = <_Candidate>[];
    for (final candidate in candidates) {
      if (kept.every(
        (existing) => _iou(existing.box, candidate.box) < _iouThreshold,
      )) {
        kept.add(candidate);
      }
      if (kept.isNotEmpty) break;
    }
    return kept;
  }

  static double _iou(Rect a, Rect b) {
    final left = math.max(a.left, b.left);
    final top = math.max(a.top, b.top);
    final right = math.min(a.right, b.right);
    final bottom = math.min(a.bottom, b.bottom);
    final width = math.max(0.0, right - left);
    final height = math.max(0.0, bottom - top);
    final intersection = width * height;
    final union = (a.width * a.height) + (b.width * b.height) - intersection;
    return union <= 0 ? 0 : intersection / union;
  }

  static double _valueAt(List<dynamic> pred, int channel, int index) {
    final row = pred[channel] as List;
    final value = row[index];
    return value is num ? value.toDouble() : 0.0;
  }

  static double _protoValue(List<dynamic> protos, int channel, int y, int x) {
    final rows = protos[channel] as List;
    final row = rows[y] as List;
    final value = row[x];
    return value is num ? value.toDouble() : 0.0;
  }

  static double _sigmoid(double x) {
    if (x >= 0) {
      final z = math.exp(-x);
      return 1 / (1 + z);
    }
    final z = math.exp(x);
    return z / (1 + z);
  }
}

class _Candidate {
  final Rect box;
  final double score;
  final List<double> coefficients;

  const _Candidate({
    required this.box,
    required this.score,
    required this.coefficients,
  });
}
