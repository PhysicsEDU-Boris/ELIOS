import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

import '../websocket_service.dart' show Detection;

class CapturedFrame {
  /// Human preview, which may include firmware annotations.
  final Uint8List bytes;
  final int width;
  final int height;
  final DateTime timestamp;
  final List<Detection>? detections;
  /// Original camera JPEG paired with the fresh detection frame.
  final Uint8List? cleanBytes;
  final int? frameId;
  final int? detectionFrameId;
  final String? firmwareSha256;

  bool get hasPairedCleanImage =>
      cleanBytes != null &&
      cleanBytes!.isNotEmpty &&
      frameId != null &&
      frameId! >= 0 &&
      frameId == detectionFrameId;

  const CapturedFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.timestamp,
    this.detections,
    this.cleanBytes,
    this.frameId,
    this.detectionFrameId,
    this.firmwareSha256,
  });

  /// Preview always survives missing/malformed clean data. Never cache across messages.
  factory CapturedFrame.fromRobotMessage(
    Map<String, dynamic> message, {
    required Uint8List previewBytes,
    required int width,
    required int height,
    required List<Detection>? previewDetections,
  }) {
    Uint8List? clean;
    final frameId = message['frame_id'] is int
        ? message['frame_id'] as int
        : null;
    final detectionId = message['detection_frame_id'] is int
        ? message['detection_frame_id'] as int
        : null;
    var detections = previewDetections;
    if (message.containsKey('vision_protocol')) {
      // A preview-only message is not an observation of an empty detector scene.
      detections = null;
      if (message['vision_protocol'] == 1 &&
          frameId != null &&
          frameId >= 0 &&
          frameId == detectionId &&
          message['img_w'] == width &&
          message['img_h'] == height &&
          width > 0 &&
          height > 0) {
        try {
          final raw = message['clean_detections'];
          if (raw is List && raw.every((d) => d is Map<String, dynamic>)) {
            final fresh = raw
                .map((d) => Detection.fromJson(d as Map<String, dynamic>))
                .toList();
            if (message['clean_image'] is String) {
              clean = base64Decode(message['clean_image'] as String);
            }
            // Nonempty observations without an image must fail visibly at lock.
            detections = fresh;
          }
        } catch (_) {
          clean = null;
          detections = null;
        }
      }
    }
    return CapturedFrame(
      bytes: previewBytes,
      width: width,
      height: height,
      timestamp: DateTime.now(),
      detections: detections,
      cleanBytes: clean,
      frameId: frameId,
      detectionFrameId: detectionId,
      firmwareSha256: message['firmware_sha256'] is String
          ? message['firmware_sha256'] as String
          : null,
    );
  }
}

abstract class FrameSource extends ChangeNotifier {
  Future<void> initialize();
  Future<CapturedFrame?> capture();

  @override
  void dispose();

  Future<void> pausePreview();
  Future<void> resumePreview();

  void switchCamera() {}

  bool get isInitialized;
  String? get error;

  Stream<CapturedFrame> get frames;

  Widget buildPreview({BoxFit fit = BoxFit.cover});
}
