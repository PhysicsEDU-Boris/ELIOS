// ELIOS 3 celebration (Figma 13 · 38, decision 0203): level up and medal
// unlocked. The art scales 0.6 → 1.1 → 1 (spring/bounce), 24 leaves fall
// (900 ms), the title rises 12 px (320, delay 200); S9 + H-celebrate. It
// closes after 2.4 s or on tap; at most one per 3 s (the rest wait). Reduced
// motion: a 200 ms fade and a still picture.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/elio_feedback.dart';
import '../theme/elio_motion.dart';
import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;

class ElioCelebration {
  ElioCelebration._();

  static final _queue = <({Widget art, String title, String? subtitle})>[];
  static bool _showing = false;
  static DateTime _lastEnd = DateTime(0);

  /// Shows (or queues) one celebration over [context]'s overlay.
  static void show(
    BuildContext context, {
    required Widget art,
    required String title,
    String? subtitle,
  }) {
    _queue.add((art: art, title: title, subtitle: subtitle));
    _next(Overlay.of(context, rootOverlay: true));
  }

  static void _next(OverlayState overlay) {
    if (_showing || _queue.isEmpty || !overlay.mounted) return;
    final gap =
        const Duration(seconds: 3) - DateTime.now().difference(_lastEnd);
    if (!gap.isNegative && gap > Duration.zero && _lastEnd.year > 1) {
      // Max one per 3 s: try again when the gap has passed.
      Future<void>.delayed(gap, () => _next(overlay));
      return;
    }
    final item = _queue.removeAt(0);
    _showing = true;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CelebrationView(
        art: item.art,
        title: item.title,
        subtitle: item.subtitle,
        onDone: () {
          entry.remove();
          _showing = false;
          _lastEnd = DateTime.now();
          _next(overlay);
        },
      ),
    );
    overlay.insert(entry);
    ElioSound.instance.play(ElioSfx.sparkle);
    ElioHaptics.celebrate();
  }
}

class _CelebrationView extends StatefulWidget {
  const _CelebrationView({
    required this.art,
    required this.title,
    required this.onDone,
    this.subtitle,
  });
  final Widget art;
  final String title;
  final String? subtitle;
  final VoidCallback onDone;

  @override
  State<_CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<_CelebrationView>
    with SingleTickerProviderStateMixin {
  // 2.4 s on screen + 150 ms fade-out, as one animation (no timers).
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2550),
  )..forward().whenComplete(_close);
  bool _closed = false;

  void _close() {
    if (_closed) return;
    _closed = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final reduced = ElioMotion.reduced(context);
    const total = 2550.0;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final ms = _c.value * total;
        final fadeIn = (ms / (reduced ? 200 : 150)).clamp(0.0, 1.0);
        final fadeOut = ((total - ms) / 150).clamp(0.0, 1.0);
        final art = reduced
            ? 1.0
            : 0.6 + 0.4 * ElioMotion.bounce.transform((ms / 600).clamp(0, 1));
        final rise = reduced
            ? 0.0
            : 12 *
                  (1 -
                      ElioMotion.emphasized.transform(
                        ((ms - 200) / 320).clamp(0, 1),
                      ));
        return Opacity(
          opacity: math.min(fadeIn, fadeOut),
          child: Material(
            color: Colors.black.withValues(alpha: 0.32),
            child: InkWell(
              onTap: _close,
              child: Stack(
                children: [
                  if (!reduced)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: ElioLeafConfetti(
                            t: (ms / 900).clamp(0.0, 1.0),
                            colors: [
                              p.primary,
                              p.primaryHover,
                              p.secondaryText,
                            ],
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Semantics(
                      liveRegion: true,
                      label: [widget.title, ?widget.subtitle].join('. '),
                      excludeSemantics: true,
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: art,
                              child: SizedBox(
                                width: 140,
                                height: 140,
                                child: widget.art,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Transform.translate(
                              offset: Offset(0, rise),
                              child: Column(
                                children: [
                                  Text(
                                    widget.title,
                                    textAlign: TextAlign.center,
                                    style: ElioTokens.body.copyWith(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                  if (widget.subtitle != null)
                                    Text(
                                      widget.subtitle!,
                                      textAlign: TextAlign.center,
                                      style: ElioTokens.bodySmall.copyWith(
                                        color: p.textSecondary,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.celebrateTap,
                                    style: ElioTokens.caption.copyWith(
                                      color: p.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [count] leaves falling with gravity and a little sway (seeded, so stable).
class ElioLeafConfetti extends CustomPainter {
  ElioLeafConfetti({required this.t, required this.colors, this.count = 24});
  final int count;
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final rnd = math.Random(7);
    for (var i = 0; i < count; i++) {
      final x0 = rnd.nextDouble() * size.width;
      final y0 = -20 - rnd.nextDouble() * size.height * 0.2;
      final vy = size.height * (0.5 + rnd.nextDouble() * 0.5);
      final sway = 20 + rnd.nextDouble() * 30;
      final spin = rnd.nextDouble() * math.pi * 2;
      final y = y0 + vy * t + 0.5 * size.height * t * t;
      final x = x0 + math.sin(t * math.pi * 2 + spin) * sway;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin + t * 4);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 1 - t * 0.6);
      canvas.drawPath(
        Path()
          ..moveTo(0, -7)
          ..quadraticBezierTo(6, 0, 0, 7)
          ..quadraticBezierTo(-6, 0, 0, -7),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ElioLeafConfetti old) => old.t != t;
}
