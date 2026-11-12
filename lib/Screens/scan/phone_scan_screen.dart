// ELIOS 3 Scan & quiz with the phone, portrait (Figma 629:90736): full-screen
// camera, viewfinder corners, shutter and the question-source chip. The
// identify → quiz steps are the full-screen ScanQuizPages (decision 0216).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/app_preferences_provider.dart';
import '../../providers/esp_config_provider.dart';
import '../../providers/waste_quiz_provider.dart';
import '../../services/ai_quiz_service.dart';
import '../../services/frame_source/phone_frame_source.dart';
import '../../services/frame_source/viewfinder_crop.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/learn/learn_ui.dart';
import '../../widgets/waste_quiz_popup.dart';
import '../../services/elio_feedback.dart';

/// The square viewfinder; the AI and History get only what is inside it.
const phoneScanBox = Size(260, 260);

class PhoneScanScreen extends ConsumerStatefulWidget {
  const PhoneScanScreen({super.key, this.source});

  /// Test seam: a fake camera.
  final PhoneFrameSource? source;

  @override
  ConsumerState<PhoneScanScreen> createState() => _PhoneScanScreenState();
}

class _PhoneScanScreenState extends ConsumerState<PhoneScanScreen> {
  late final PhoneFrameSource _source =
      widget.source ??
      PhoneFrameSource(
        resolutionPreset: ref
            .read(espConfigProvider)
            .valueOrNull
            ?.resolutionPreset,
      );
  late final WasteQuizNotifier _quiz = ref.read(wasteQuizProvider.notifier);
  bool _capturing = false;
  int _shots = 0;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _source.addListener(_changed);
    _source.initialize();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    if (!_source.isInitialized || _capturing) return;
    elioFeedback(ElioSfx.shutter, ElioHaptics.medium); // Figma 13 · 26
    final screen = MediaQuery.sizeOf(context);
    setState(() {
      _capturing = true;
      _shots++;
    });
    try {
      final frame = await _source.capture();
      if (frame == null) throw StateError('no photo');
      final photo = await cropToViewfinder(
        frame.bytes,
        panel: screen,
        box: phoneScanBox,
      );
      _quiz.onPhotoCaptured(photo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.photoFailed(e))));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _source.removeListener(_changed);
    if (widget.source == null) _source.dispose();
    Future.microtask(_quiz.dismiss);
    unawaited(AiQuizService.instance.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The preview pauses while the quiz covers it (saves battery for the AI).
    ref.listen<WasteQuizUiState>(wasteQuizProvider, (prev, next) {
      final was =
          prev != null && prev.phase != WasteQuizPhase.idle && !prev.minimized;
      final now = next.phase != WasteQuizPhase.idle && !next.minimized;
      if (was == now) return;
      now ? _source.pausePreview() : _source.resumePreview();
    });
    final source = ref.watch(
      appPreferencesProvider.select((p) => p.questionSource),
    );
    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = context.elio;
          final ready = _source.isInitialized && _source.error == null;
          const scrim = Color(0x8C0F172A);
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                if (ready)
                  _source.buildPreview()
                else
                  Center(
                    child: _source.error != null
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _source.error!,
                              textAlign: TextAlign.center,
                              style: ElioTokens.bodySmall.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const CircularProgressIndicator(),
                  ),
                Center(
                  child: SizedBox.fromSize(
                    size: phoneScanBox,
                    // Searching: the brackets breathe 1 ↔ 1.02 (1.6 s).
                    child: ElioIdleLoop(
                      period: const Duration(milliseconds: 1600),
                      builder: (context, w, child) =>
                          Transform.scale(scale: 1 + 0.02 * w, child: child),
                      child: CustomPaint(painter: _Corners(p.primary)),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: l10n.commonClose,
                              onPressed: () => Navigator.of(context).maybePop(),
                              style: IconButton.styleFrom(
                                backgroundColor: scrim,
                                minimumSize: const Size.square(48),
                              ),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Semantics(
                              header: true,
                              child: Text(
                                l10n.scanPhoneTitle,
                                style: ElioTokens.subhead.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Flash (629:90736): lights dim rooms, glows when on.
                            IconButton(
                              key: const ValueKey('scan_flash'),
                              tooltip: l10n.scanFlash,
                              isSelected: _source.torch,
                              onPressed: ready
                                  ? () {
                                      _source.torch
                                          ? elioFeedback(
                                              ElioSfx.toggleOff,
                                              ElioHaptics.select,
                                            )
                                          : elioFeedback(
                                              ElioSfx.toggleOn,
                                              ElioHaptics.select,
                                            );
                                      _source.toggleTorch();
                                    }
                                  : null,
                              style: IconButton.styleFrom(
                                backgroundColor: _source.torch
                                    ? p.primary
                                    : scrim,
                                minimumSize: const Size.square(48),
                              ),
                              icon: AnimatedRotation(
                                turns: _source.torch ? 0.04 : 0,
                                duration: ElioMotion.base,
                                curve: ElioMotion.pop,
                                child: Icon(
                                  _source.torch
                                      ? Icons.flash_on_rounded
                                      : Icons.flash_off_rounded,
                                  color: _source.torch
                                      ? p.onPrimary
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      ElioPopIn(
                        rise: 12,
                        delay: const Duration(milliseconds: 120),
                        child: _Pill(text: l10n.scanHoldSteady, color: scrim),
                      ),
                      SizedBox(height: phoneScanBox.height + 48),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Row(
                          children: [
                            const Expanded(child: SizedBox()),
                            Semantics(
                              button: true,
                              label: l10n.scanTakePhoto,
                              excludeSemantics: true,
                              onTap: ready ? _capture : null,
                              child: GestureDetector(
                                onTap: ready ? _capture : null,
                                onTapDown: (_) => setState(() => _down = true),
                                onTapUp: (_) => setState(() => _down = false),
                                onTapCancel: () =>
                                    setState(() => _down = false),
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                  // Shutter: the inner circle scales 0.85 (90 ms).
                                  child: AnimatedScale(
                                    scale: _down || _capturing ? 0.85 : 1,
                                    duration: ElioMotion.instant,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: _capturing || !ready
                                            ? p.primary.withValues(alpha: 0.5)
                                            : p.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: ElioPopIn(
                                  rise: 12,
                                  delay: const Duration(milliseconds: 180),
                                  child: _Pill(
                                    text: source == QuestionSource.ai
                                        ? l10n.scanAiQuiz
                                        : l10n.questionBank,
                                    color: scrim,
                                    icon: source == QuestionSource.ai
                                        ? null
                                        : Icons.storage_rounded,
                                    leading: source == QuestionSource.ai
                                        ? const EliosAiBadge(size: 20)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Shutter flash: white 0 → 60 % → 0 over 180 ms.
                if (_shots > 0 && !ElioMotion.reduced(context))
                  IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_shots),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 180),
                      builder: (context, v, _) => ColoredBox(
                        color: Colors.white.withValues(
                          alpha: 0.6 * (1 - (2 * v - 1).abs()),
                        ),
                      ),
                    ),
                  ),
                if (_capturing)
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0x59000000)),
                  ),
                // Result, question and review fill the screen (decision 0216).
                const Positioned.fill(child: ScanQuizPages()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    this.icon,
    this.leading,
  });
  final Widget? leading;
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(leading == null ? 12 : 6, 7, 12, 7),
    decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        if (icon != null) ...[
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: ElioTokens.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Four rounded viewfinder corners.
class _Corners extends CustomPainter {
  _Corners(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 44.0, r = 16.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    for (final (x, y, sx, sy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + sy * len)
          ..lineTo(x, y + sy * r)
          ..quadraticBezierTo(x, y, x + sx * r, y)
          ..lineTo(x + sx * len, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Corners old) => old.color != color;
}
