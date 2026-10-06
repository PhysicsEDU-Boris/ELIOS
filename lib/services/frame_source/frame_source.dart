import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

import '../websocket_service.dart' show Detection;

class CapturedFrame {
  final Uint8List bytes;
  final int width;
  final int height;
  final DateTime timestamp;
  final List<Detection>? detections;

  const CapturedFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.timestamp,
    this.detections,
  });
}

abstract class FrameSource extends ChangeNotifier {
  Future<void> initialize();
  Future<CapturedFrame?> capture();
  
  @override
  void dispose();
  
  Future<void> pausePreview();
  Future<void> resumePreview();
  
  void switchCamera() {} // Default empty implementation for sources that don't support it

  bool get isInitialized;
  String? get error;
  
  Stream<CapturedFrame> get frames;
  
  Widget buildPreview({BoxFit fit = BoxFit.cover});
}
