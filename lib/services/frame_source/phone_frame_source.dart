import 'dart:async';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'frame_source.dart';

class PhoneFrameSource extends FrameSource {
  final bool _useMacCamera = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  
  CameraController? _controller;
  CameraMacOSController? _macController;
  
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  
  String? _errorMsg;
  bool _initialized = false;
  bool _macPaused = false;
  
  final StreamController<CapturedFrame> _frameController = StreamController<CapturedFrame>.broadcast();
  
  @override
  bool get isInitialized => _useMacCamera ? _initialized : _controller != null;
  
  @override
  String? get error => _errorMsg;

  @override
  Stream<CapturedFrame> get frames => _frameController.stream;

  @override
  Future<void> initialize() async {
    if (_useMacCamera) {
      // camera_macos is initialized via its view callback.
      // We just mark it as initialized for now so the UI can show the view.
      _initialized = true;
      _macPaused = false;
      notifyListeners();
      return;
    }
    
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('none', 'No camera found');
      }
      final back = cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _cameras = cameras;
      await _openCamera(back >= 0 ? back : 0);
    } catch (e) {
      _errorMsg = 'Kamera tidak tersedia di perangkat ini. ($e)';
      notifyListeners();
    }
  }

  Future<void> _openCamera(int index) async {
    final old = _controller;
    _controller = null;
    _cameraIndex = index;
    notifyListeners();
    
    await old?.dispose();
    
    final controller = CameraController(_cameras[index], ResolutionPreset.medium, enableAudio: false);
    try {
      await controller.initialize();
      _controller = controller;
      _errorMsg = null;
      notifyListeners();
    } catch (e) {
      await controller.dispose();
      _errorMsg = 'Gagal membuka kamera: $e';
      notifyListeners();
    }
  }
  
  @override
  void switchCamera() {
    if (_useMacCamera || _cameras.isEmpty) return;
    _openCamera((_cameraIndex + 1) % _cameras.length);
  }

  @override
  Future<CapturedFrame?> capture() async {
    if (!isInitialized) return null;
    try {
      final Uint8List? bytes;
      int width = 0;
      int height = 0;
      
      if (_useMacCamera) {
        final pic = await _macController!.takePicture();
        bytes = pic?.bytes;
        // Optional: Mac camera dimensions might not be easily accessible here. We'll set 0.
      } else {
        final file = await _controller!.takePicture();
        bytes = await file.readAsBytes();
        width = _controller!.value.previewSize?.width.toInt() ?? 0;
        height = _controller!.value.previewSize?.height.toInt() ?? 0;
      }
      
      if (bytes == null) throw StateError('Kamera tidak mengembalikan foto');
      
      final frame = CapturedFrame(
        bytes: bytes,
        width: width,
        height: height,
        timestamp: DateTime.now(),
      );
      _frameController.add(frame);
      return frame;
    } catch (e) {
      debugPrint('Failed to capture: $e');
      return null;
    }
  }

  @override
  Future<void> pausePreview() async {
    if (_useMacCamera) {
      final mac = _macController;
      _macController = null;
      _macPaused = true;
      await mac?.destroy();
      notifyListeners();
    } else {
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.pausePreview();
      }
    }
  }

  @override
  Future<void> resumePreview() async {
    if (_useMacCamera) {
      _macPaused = false;
      notifyListeners();
    } else {
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.resumePreview();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _macController?.destroy();
    _frameController.close();
    super.dispose();
  }

  @override
  Widget buildPreview({BoxFit fit = BoxFit.cover}) {
    if (_useMacCamera) {
      if (_macPaused) {
        return const ColoredBox(color: Color(0xFF121413));
      }
      return CameraMacOSView(
        key: const ValueKey('elios-mac-camera'),
        fit: fit,
        cameraMode: CameraMacOSMode.photo,
        enableAudio: false,
        pictureFormat: PictureFormat.jpg,
        resolution: PictureResolution.medium,
        onCameraInizialized: (c) {
          _macController = c;
          _errorMsg = null;
          notifyListeners();
        },
        onCameraLoading: (error) {
          if (error != null) {
            _errorMsg = error.toString();
            // Need to wrap notifyListeners in post frame to avoid build phase errors
            WidgetsBinding.instance.addPostFrameCallback((_) {
              notifyListeners();
            });
          }
          return Center(
            child: error == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Kamera Mac tidak bisa dibuka ($error).',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
          );
        },
      );
    } else {
      if (_controller != null && _controller!.value.isInitialized) {
        return ClipRect(
          child: FittedBox(
            fit: fit,
            child: SizedBox(
              width: _controller!.value.previewSize?.height ?? 640,
              height: _controller!.value.previewSize?.width ?? 480,
              child: CameraPreview(_controller!),
            ),
          ),
        );
      } else if (_errorMsg != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMsg!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      } else {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      }
    }
  }
}
