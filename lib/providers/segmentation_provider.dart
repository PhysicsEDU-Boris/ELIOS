import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/segmentation_result.dart';
import '../services/segmentation_service.dart';
import '../services/websocket_service.dart';

class SegmentationState {
  final bool isProcessing;
  final SegmentationFrameResult? result;

  const SegmentationState({this.isProcessing = false, this.result});
}

class SegmentationNotifier extends StateNotifier<SegmentationState> {
  SegmentationNotifier() : super(const SegmentationState()) {
    unawaited(_service.init());
    _frameSub = WebSocketService().frames.listen(_onFrame);
  }

  final SegmentationService _service = SegmentationService();
  late final StreamSubscription<Uint8List> _frameSub;
  bool _busy = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  void _onFrame(Uint8List jpeg) {
    final now = DateTime.now();
    if (_busy || now.difference(_lastRun).inMilliseconds < 80) {
      return;
    }

    _busy = true;
    _lastRun = now;
    if (mounted) {
      state = SegmentationState(isProcessing: true, result: state.result);
    }

    unawaited(_run(jpeg));
  }

  Future<void> _run(Uint8List jpeg) async {
    try {
      final result = await _service.runInference(jpeg);
      if (mounted) {
        state = SegmentationState(isProcessing: false, result: result);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _frameSub.cancel();
    _service.dispose();
    super.dispose();
  }
}

final segmentationProvider =
    StateNotifierProvider.autoDispose<SegmentationNotifier, SegmentationState>(
      (ref) => SegmentationNotifier(),
    );
