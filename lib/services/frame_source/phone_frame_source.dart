import 'package:elio/l10n/l10n.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

import 'frame_source.dart';
import 'yuv_jpeg.dart';

/// Android reads photos from the image stream only (the latest YUV frame, turned
/// into a JPEG in an isolate); `takePicture` is never mixed with the stream
/// because CameraX rebinds its use cases between the two (decision 0040).
class PhoneFrameSource extends FrameSource {
  /// Config → Settings → Resolution ('480p' / '720p'); null keeps the platform
  /// default (Android 720p, others 480p).
  PhoneFrameSource({this.resolutionPreset});

  final String? resolutionPreset;

  /// Camera frames seen so far (Android image stream only), for the FPS overlay.
  int frameCount = 0;

  /// The preview size the camera picked, or null before it opens / on macOS.
  Size? get previewSize => _controller?.value.previewSize;

  final bool _useStream =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  CameraImage? _latest;
  final bool _useMacCamera =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  CameraController? _controller;
  CameraMacOSController? _macController;

  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  String? _errorMsg;
  bool _initialized = false;
  bool _macPaused = false;

  final StreamController<CapturedFrame> _frameController =
      StreamController<CapturedFrame>.broadcast();

  @override
  bool get isInitialized => _useMacCamera ? _initialized : _controller != null;

  /// Which camera is showing, for the scan screen's chip.
  String get cameraName => _useMacCamera
      ? 'Mac camera'
      : (_cameras.isNotEmpty &&
                _cameras[_cameraIndex].lensDirection ==
                    CameraLensDirection.front
            ? 'Front camera'
            : 'Back camera');

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
      final back = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
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

    _latest = null;
    final controller = CameraController(
      _cameras[index],
      switch (resolutionPreset) {
        '720p' => ResolutionPreset.high,
        '480p' => ResolutionPreset.medium,
        _ => _useStream ? ResolutionPreset.high : ResolutionPreset.medium,
      },
      enableAudio: false,
      imageFormatGroup: _useStream ? ImageFormatGroup.yuv420 : null,
    );
    try {
      await controller.initialize();
      if (_useStream) {
        await controller.startImageStream((image) {
          _latest = image;
          frameCount++;
        });
      }
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
      } else if (_useStream) {
        final shot = await _jpegFromLatest();
        bytes = shot.bytes;
        width = shot.width;
        height = shot.height;
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

  Future<({Uint8List bytes, int width, int height})> _jpegFromLatest() async {
    final image = _latest;
    final controller = _controller!;
    if (image == null || image.planes.length < 3) {
      throw StateError('Kamera belum mengirim gambar');
    }
    final yPlane = image.planes[0];
    final degrees = switch (controller.value.deviceOrientation) {
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
      _ => 0,
    };
    final description = _cameras[_cameraIndex];
    return yuvToJpegInIsolate(
      YuvFrame(
        width: image.width,
        height: image.height,
        y: yPlane.bytes,
        u: image.planes[1].bytes,
        v: image.planes[2].bytes,
        yRowStride: yPlane.bytesPerRow,
        uvRowStride: image.planes[1].bytesPerRow,
        uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
      ),
      rotation: yuvRotation(
        sensorOrientation: description.sensorOrientation,
        deviceDegrees: degrees,
        frontFacing: description.lensDirection == CameraLensDirection.front,
      ),
    );
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
        // Stop the stream too: nothing needs frames while the quiz covers the preview.
        if (_useStream && _controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
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
        if (_useStream && !_controller!.value.isStreamingImages) {
          await _controller!.startImageStream((image) => _latest = image);
        }
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
                      l10n.camMacFailed(error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
          );
        },
      );
    } else {
      if (_controller != null && _controller!.value.isInitialized) {
        // previewSize is always sensor-landscape (w > h); CameraPreview rotates
        // itself, so only swap the box when the device is held upright.
        final value = _controller!.value;
        final landscape =
            (value.lockedCaptureOrientation ?? value.deviceOrientation) ==
                DeviceOrientation.landscapeLeft ||
            (value.lockedCaptureOrientation ?? value.deviceOrientation) ==
                DeviceOrientation.landscapeRight;
        final ps = value.previewSize;
        return ClipRect(
          child: FittedBox(
            fit: fit,
            child: SizedBox(
              width: ps == null ? 640 : (landscape ? ps.width : ps.height),
              height: ps == null ? 480 : (landscape ? ps.height : ps.width),
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
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
    }
  }
}
