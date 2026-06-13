import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/segmentation_service.dart';
import '../services/websocket_service.dart';

class SegmentationState {
  final bool isProcessing;
  final List<Map<String, dynamic>> detections;

  const SegmentationState({
    this.isProcessing = false,
    this.detections = const [],
  });

  SegmentationState copyWith({
    bool? isProcessing,
    List<Map<String, dynamic>>? detections,
  }) {
    return SegmentationState(
      isProcessing: isProcessing ?? this.isProcessing,
      detections: detections ?? this.detections,
    );
  }
}

class SegmentationNotifier extends StateNotifier<SegmentationState> {
  SegmentationNotifier() : super(const SegmentationState()) {
    unawaited(_service.init());
    _frameSubscription = WebSocketService().frames.listen(_handleFrame);
  }

  final SegmentationService _service = SegmentationService();
  late final StreamSubscription<Uint8List> _frameSubscription;
  Uint8List? _pendingFrame;
  bool _isProcessing = false;

  void _handleFrame(Uint8List frame) {
    _pendingFrame = frame;
    if (_isProcessing) {
      return;
    }

    unawaited(_drainFrames());
  }

  Future<void> _drainFrames() async {
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;
    state = state.copyWith(isProcessing: true);

    try {
      while (_pendingFrame != null && mounted) {
        final frame = _pendingFrame!;
        _pendingFrame = null;
        await _service.runInference(frame);
      }
    } finally {
      _isProcessing = false;
      if (mounted) {
        state = state.copyWith(isProcessing: false, detections: const []);
      }

      if (_pendingFrame != null && mounted) {
        unawaited(_drainFrames());
      }
    }
  }

  @override
  void dispose() {
    _frameSubscription.cancel();
    super.dispose();
  }
}

final segmentationProvider =
    StateNotifierProvider.autoDispose<SegmentationNotifier, SegmentationState>(
      (ref) => SegmentationNotifier(),
    );
