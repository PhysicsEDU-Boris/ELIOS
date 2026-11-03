import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/waste_quiz_provider.dart';
import '../services/frame_source/phone_frame_source.dart';

/// Debug-only stand-in for the MaixCAM2 camera: captures a still photo with
/// the phone's own camera and feeds it straight to the AI, so the popup-quiz
/// flow can be tested without the physical robot connected.
class DebugPhoneCameraSheet extends ConsumerStatefulWidget {
  const DebugPhoneCameraSheet({super.key});

  @override
  ConsumerState<DebugPhoneCameraSheet> createState() =>
      _DebugPhoneCameraSheetState();
}

class _DebugPhoneCameraSheetState extends ConsumerState<DebugPhoneCameraSheet> {
  final PhoneFrameSource _source = PhoneFrameSource();
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _source.addListener(_onSourceChanged);
    _source.initialize();
  }

  void _onSourceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    if (!_source.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final frame = await _source.capture();
      if (!mounted) return;
      if (frame != null) {
        ref.read(wasteQuizProvider.notifier).onPhotoCaptured(frame.bytes);
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Error is handled/shown by the source itself if possible, or just ignored
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _source.removeListener(_onSourceChanged);
    _source.dispose();
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
                child: _source.error != null
                    ? ColoredBox(
                        color: Colors.black12,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_source.error!, textAlign: TextAlign.center),
                          ),
                        ),
                      )
                    : !_source.isInitialized
                        ? const ColoredBox(
                            color: Colors.black12,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _source.buildPreview(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: !_source.isInitialized || _capturing ? null : _capture,
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
