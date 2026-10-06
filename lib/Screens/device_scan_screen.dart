import 'dart:async';

import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/waste_quiz_provider.dart';
import '../services/gemma_quiz_service.dart';
import '../theme/elio_learning_colors.dart';
import '../widgets/desktop_viewport.dart';
import '../widgets/waste_quiz_popup.dart';

/// Scan waste with this device's own camera (no robot needed) and get the
/// offline Gemma quiz. Figma: "Device Scan · Kamera perangkat (landscape)".
class DeviceScanScreen extends ConsumerStatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  ConsumerState<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends ConsumerState<DeviceScanScreen> {
  static const _sampleLabels = ['Botol plastik', 'Kulit pisang', 'Kaleng minuman', 'Baterai bekas'];

  // The `camera` plugin has no macOS implementation, so the Mac webcam goes
  // through camera_macos instead.
  final bool _useMacCamera = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  CameraMacOSController? _macController;

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  String? _cameraError;
  bool _capturing = false;
  late final WasteQuizNotifier _quiz;

  @override
  void initState() {
    super.initState();
    _quiz = ref.read(wasteQuizProvider.notifier);
    setDesktopLandscape(true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } catch (_) {}
    });
    // No robot video here, so it's safe to load the model (with the image
    // encoder, since scans are photos) while the user frames the shot.
    GemmaQuizService.instance.warmUp(vision: true);
    if (!_useMacCamera) _initCamera();
  }

  bool get _cameraReady => _useMacCamera ? _macController != null : _controller != null;

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('none', 'No camera found');
      final back = cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _cameras = cameras;
      await _openCamera(back >= 0 ? back : 0);
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = 'Kamera tidak tersedia di perangkat ini. '
            'Gunakan "Uji tanpa kamera" untuk mencoba kuis AI.');
      }
    }
  }

  Future<void> _openCamera(int index) async {
    final old = _controller;
    setState(() {
      _controller = null;
      _cameraIndex = index;
    });
    await old?.dispose();
    final controller = CameraController(_cameras[index], ResolutionPreset.medium, enableAudio: false);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraError = null;
      });
    } catch (e) {
      await controller.dispose();
      if (mounted) setState(() => _cameraError = 'Gagal membuka kamera: $e');
    }
  }

  Future<void> _capture() async {
    if (!_cameraReady || _capturing) return;
    setState(() => _capturing = true);
    try {
      final Uint8List? bytes;
      if (_useMacCamera) {
        bytes = (await _macController!.takePicture())?.bytes;
      } else {
        bytes = await (await _controller!.takePicture()).readAsBytes();
      }
      if (bytes == null) throw StateError('kamera tidak mengembalikan foto');
      _quiz.onPhotoCaptured(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memotret: $e')));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    unawaited(_macController?.destroy());
    Future.microtask(_quiz.dismiss);
    unawaited(GemmaQuizService.instance.dispose());
    setDesktopLandscape(false);
    unawaited(SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  /// The live preview is stopped while the quiz popup covers it (saves CPU
  /// and battery for Gemma) and comes back when the popup is closed or
  /// minimized.
  void _onQuizCoverChanged(bool covered) {
    if (_useMacCamera) {
      if (covered) {
        final mac = _macController;
        _macController = null;
        unawaited(mac?.destroy());
      }
      return; // the view is rebuilt (and re-opened) when uncovered
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    unawaited((covered ? controller.pausePreview() : controller.resumePreview())
        .catchError((Object e) => debugPrint('camera pause/resume failed: $e')));
  }

  @override
  Widget build(BuildContext context) {
    final quiz = ref.watch(wasteQuizProvider);
    final quizCoversCamera = quiz.phase != WasteQuizPhase.idle && !quiz.minimized;
    ref.listen<WasteQuizUiState>(wasteQuizProvider, (prev, next) {
      final was = prev != null && prev.phase != WasteQuizPhase.idle && !prev.minimized;
      final now = next.phase != WasteQuizPhase.idle && !next.minimized;
      if (was != now) _onQuizCoverChanged(now);
    });
    final controller = _controller;
    return Scaffold(
      backgroundColor: const Color(0xFF121413),
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_useMacCamera && quizCoversCamera)
                      const ColoredBox(color: Color(0xFF121413))
                    else if (_useMacCamera)
                      CameraMacOSView(
                        key: const ValueKey('elios-mac-camera'),
                        fit: BoxFit.cover,
                        cameraMode: CameraMacOSMode.photo,
                        enableAudio: false,
                        // camera_macos only maps "jpg" to JPEG; anything else
                        // falls back to TIFF, which LiteRT-LM can't decode.
                        pictureFormat: PictureFormat.jpg,
                        resolution: PictureResolution.medium,
                        onCameraInizialized: (c) {
                          if (mounted) setState(() => _macController = c);
                        },
                        onCameraLoading: (error) => Center(
                          child: error == null
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Kamera Mac tidak bisa dibuka ($error). Izinkan akses kamera di '
                                    'System Settings → Privacy & Security → Camera, atau pakai "Uji tanpa kamera".',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                        ),
                      )
                    else if (controller != null && controller.value.isInitialized)
                      ClipRect(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.previewSize?.height ?? 640,
                            height: controller.value.previewSize?.width ?? 480,
                            child: CameraPreview(controller),
                          ),
                        ),
                      )
                    else
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2E3D35), Color(0xFF0F1412)],
                          ),
                        ),
                      ),
                    Center(
                      child: _cameraError != null
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _cameraError!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            )
                          : !_cameraReady
                              ? (_useMacCamera
                                  ? const SizedBox.shrink() // camera_macos shows its own loading/error
                                  : const CircularProgressIndicator(color: Colors.white))
                              : const IgnorePointer(
                                  child: SizedBox(width: 260, height: 200, child: CustomPaint(painter: _ViewfinderPainter())),
                                ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      right: 12,
                      child: SafeArea(
                        child: Row(
                          children: [
                            _PillButton(
                              icon: Icons.arrow_back_rounded,
                              label: 'Exit',
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                            const _AiStatusChip(),
                          ],
                        ),
                      ),
                    ),
                    if (_cameraError == null && _cameraReady)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 14,
                        child: Center(
                          child: _DarkChip(text: 'Arahkan kamera ke sampah di dalam kotak'),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 240,
                child: ColoredBox(
                  color: elioBackground,
                  child: SafeArea(
                    left: false,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        child: Column(
                          children: [
                            Text('Scan Sampah', style: GoogleFonts.inter(color: elioInk, fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                              'Tekan Scan untuk memotret. Gemma akan mengenali sampah dan membuat kuis — semuanya offline.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: elioOutline, fontSize: 11, height: 1.45, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 14),
                            _ShutterButton(
                              enabled: _cameraReady && !_capturing,
                              busy: _capturing,
                              onTap: _capture,
                            ),
                            const SizedBox(height: 8),
                            Text('Scan & Buat Kuis', style: GoogleFonts.inter(color: elioPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            if (_cameras.length > 1)
                              OutlinedButton.icon(
                                onPressed: controller == null ? null : () => _openCamera((_cameraIndex + 1) % _cameras.length),
                                icon: const Icon(Icons.cameraswitch_rounded, size: 16),
                                label: const Text('Ganti kamera'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: elioMuted,
                                  visualDensity: VisualDensity.compact,
                                  side: const BorderSide(color: elioOutlineVariant),
                                ),
                              ),
                            PopupMenuButton<String>(
                              tooltip: 'Uji kuis AI tanpa kamera',
                              onSelected: _quiz.startForLabel,
                              itemBuilder: (context) => [
                                for (final label in _sampleLabels) PopupMenuItem(value: label, child: Text(label)),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.science_outlined, size: 16, color: elioMuted),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Uji tanpa kamera',
                                        style: GoogleFonts.inter(color: elioMuted, fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const WasteQuizPopup(),
        ],
      ),
    );
  }
}

class _AiStatusChip extends StatelessWidget {
  const _AiStatusChip();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GemmaProgress>(
      valueListenable: GemmaQuizService.instance.progress,
      builder: (context, p, _) {
        final (text, color) = switch (p.status) {
          GemmaStatus.installing => ('AI: menyiapkan ${p.installPercent}%', elioWarning),
          GemmaStatus.loading => ('AI: memuat model…', elioWarning),
          GemmaStatus.ready => ('AI offline · Siap', elioOk),
          GemmaStatus.error => ('AI belum siap', elioDanger),
          GemmaStatus.idle => ('AI offline', elioOutline),
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }
}

class _DarkChip extends StatelessWidget {
  const _DarkChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: elioInk),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.inter(color: elioInk, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.enabled, required this.busy, required this.onTap});
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled || busy ? 1 : 0.4,
      child: Material(
        color: elioPrimary,
        shape: CircleBorder(side: BorderSide(color: elioPrimary.withValues(alpha: 0.25), width: 6)),
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 80,
            height: 80,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(26),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded frame showing where to place the item.
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 24) {
        canvas.drawPath(metric.extractPath(d, d + 14), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
