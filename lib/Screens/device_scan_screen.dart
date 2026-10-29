import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/waste_quiz_provider.dart';
import '../services/frame_source/phone_frame_source.dart';
import '../services/frame_source/viewfinder_crop.dart';
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

  static const _sidebarWidth = 240.0;
  static const _boxWidth = 260.0;
  static const _boxHeight = 200.0;

  final PhoneFrameSource _source = PhoneFrameSource();
  bool _capturing = false;
  late final WasteQuizNotifier _quiz;

  @override
  void initState() {
    super.initState();
    _quiz = ref.read(wasteQuizProvider.notifier);
    _source.addListener(_onSourceChanged);
    
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
    GemmaQuizService.instance.warmUp(vision: true, scanScreen: true);
    _source.initialize();
  }

  void _onSourceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    if (!_source.isInitialized || _capturing) return;
    final screen = MediaQuery.sizeOf(context);
    setState(() => _capturing = true);
    try {
      final frame = await _source.capture();
      if (frame == null) throw StateError('kamera tidak mengembalikan foto');
      // Gemma and Scan History get only what is inside the viewfinder box: a
      // small battery in a wide frame was misread as a can (A1 phone test).
      final photo = await cropToViewfinder(frame.bytes,
          panel: Size(screen.width - _sidebarWidth, screen.height), box: const Size(_boxWidth, _boxHeight));
      if (await GemmaQuizService.instance.modelMissing()) {
        await _pickItemWithoutModel(photo);
        return;
      }
      _quiz.onPhotoCaptured(photo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memotret: $e')));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// No model file: the photo can't be named, so the user picks the item and
  /// the photo still goes to Scan History. The quiz uses the bank.
  Future<void> _pickItemWithoutModel(Uint8List photo) async {
    if (!mounted) return;
    final label = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Model belum ada'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text('Pilih bendanya. Foto tetap disimpan di riwayat, soal dari bank.'),
          ),
          for (final l in _sampleLabels) SimpleDialogOption(onPressed: () => Navigator.pop(context, l), child: Text(l)),
        ],
      ),
    );
    if (label != null) _quiz.startForLabel(label, photo: photo);
  }

  @override
  void dispose() {
    _source.removeListener(_onSourceChanged);
    _source.dispose();
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
    if (covered) {
      _source.pausePreview();
    } else {
      _source.resumePreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WasteQuizUiState>(wasteQuizProvider, (prev, next) {
      final was = prev != null && prev.phase != WasteQuizPhase.idle && !prev.minimized;
      final now = next.phase != WasteQuizPhase.idle && !next.minimized;
      if (was != now) _onQuizCoverChanged(now);
    });
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
                    if (_source.isInitialized && _source.error == null)
                      _source.buildPreview()
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
                      child: _source.error != null
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _source.error!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            )
                          : !_source.isInitialized
                              ? const CircularProgressIndicator(color: Colors.white)
                              : IgnorePointer(
                                  child: SizedBox(width: _boxWidth, height: _boxHeight, child: CustomPaint(painter: _ViewfinderPainter())),
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
                    if (_source.error == null && _source.isInitialized)
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
                              enabled: _source.isInitialized && !_capturing,
                              busy: _capturing,
                              onTap: _capture,
                            ),
                            const SizedBox(height: 8),
                            Text('Scan & Buat Kuis', style: GoogleFonts.inter(color: elioPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: !_source.isInitialized ? null : _source.switchCamera,
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
          GemmaStatus.missing => ('Model belum ada · mode bank', elioWarning),
          GemmaStatus.paused => ('Ponsel panas · Gemma dijeda', elioWarning),
          GemmaStatus.killed => ('Gemma dihentikan sistem · mode bank', elioDanger),
          GemmaStatus.idle => ('AI belum dimuat', elioOutline),
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
