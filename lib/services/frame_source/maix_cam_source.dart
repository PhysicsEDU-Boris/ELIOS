import 'package:flutter/widgets.dart';
import '../websocket_service.dart';
import 'frame_source.dart';

class MaixCamSource extends FrameSource {
  final WebSocketService _ws = WebSocketService();
  
  @override
  bool get isInitialized => _ws.isConnected;
  
  @override
  String? get error => _ws.connectionStatus.value == 'Disconnected' ? 'Disconnected from MaixCAM2' : null;

  @override
  Stream<CapturedFrame> get frames => _ws.capturedFrames;

  @override
  Future<void> initialize() async {
    // The connection is managed by RobotControlNotifier in the broader app.
    // We just report whether it's initialized.
    notifyListeners();
  }

  @override
  Future<CapturedFrame?> capture() async {
    // Not explicitly supported on demand without stream, but we could wait for the next frame.
    // Since MaixCam is continuous, this source is mainly used for stream processing.
    return null;
  }

  @override
  Future<void> pausePreview() async {
    _ws.sendStopStreamCommand();
  }

  @override
  Future<void> resumePreview() async {
    _ws.sendStartStreamCommand();
  }

  @override
  Widget buildPreview({BoxFit fit = BoxFit.cover}) {
    return StreamBuilder<CapturedFrame>(
      stream: frames,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!.bytes,
            fit: fit,
            gaplessPlayback: true,
          );
        }
        return const Center(child: Text('Waiting for MaixCAM2 stream...', style: TextStyle(color: Color(0xFF7F8C8D))));
      },
    );
  }
}
