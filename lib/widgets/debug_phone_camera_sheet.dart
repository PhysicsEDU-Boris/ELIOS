import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/waste_quiz_provider.dart';

/// Debug-only stand-in for the MaixCAM2 camera: captures a still photo with
/// the phone's own camera and feeds it straight to Gemma, so the popup-quiz
/// flow can be tested without the physical robot connected.
class DebugPhoneCameraSheet extends ConsumerStatefulWidget {
  const DebugPhoneCameraSheet({super.key});

  @override
  ConsumerState<DebugPhoneCameraSheet> createState() =>
      _DebugPhoneCameraSheetState();
}

class _DebugPhoneCameraSheetState extends ConsumerState<DebugPhoneCameraSheet> {
  CameraController? _controller;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera available on this device.');
        return;
      }
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera unavailable: $e');
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      ref
          .read(wasteQuizProvider.notifier)
          .onPhotoCaptured(bytes);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Capture failed: $e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFBEC9C2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Debug: Phone Camera Scan',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Stand-in for MaixCAM2 while testing without the robot.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF7F8C8D)),
            ),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _error != null
                    ? ColoredBox(
                        color: Colors.black12,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                        ),
                      )
                    : (_controller == null || !_controller!.value.isInitialized)
                        ? const ColoredBox(
                            color: Colors.black12,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : CameraPreview(_controller!),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _controller == null || _capturing ? null : _capture,
                icon: _capturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.camera_alt_rounded),
                label: Text(_capturing ? 'Scanning...' : 'Capture & Generate Quiz'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1D9E75)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
