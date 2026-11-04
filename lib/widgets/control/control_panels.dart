// R2 Control panels (Figma 358:2358): the camera HUD with its waiting and
// disconnected states, the yellow quiz button and the bottom cards (mission,
// "This drive", ELIO tip, toggles). Display only; data comes from the screen.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/control_session.dart';
import '../../models/home_stats.dart' show HomeBin;
import '../../providers/waste_quiz_provider.dart';
import '../../services/robot/r1_constants.dart' show pickBandMaxCm, pickBandMinCm;
import '../../services/websocket_service.dart' show Detection;
import '../../theme/elio_tokens.dart';
import '../learn/learn_ui.dart' show LearnTheme;
import 'r2_controls.dart';
import 'package:elio/l10n/l10n.dart';

// The camera overlay is the one place with fixed colours (dark glass on video).
const _glass = Color(0xCC0F172A);
const _hudText = Color(0xFFF1F5F9);
const _hudMuted = Color(0xFF94A3B8);
const _hudGreen = Color(0xFF4ADE80);
const _hudAmber = Color(0xFFFBBF24);
const _hudRed = Color(0xFFF87171);
const _cameraBg = Color(0xFF1E293B);

/// Floor bands drawn when the firmware sends `dist_cm` (decision 0022).
const hudBandsCm = [20.0, 30.0, 40.0, 60.0];

// Nominal level-camera geometry from decision 0022 (lens 86.2 mm up, V-FOV 51 deg).
// ponytail: uncalibrated, like the firmware's own dist_cm; replace with the
// calibrated f_y and pitch once the camera is calibrated.
const _lensHeightCm = 8.62;
const _halfVFovDeg = 25.5;

/// The image row (0..1 of the height) where the floor is [cm] ahead.
double floorRowFraction(double cm) => 0.5 + 0.5 * (_lensHeightCm / cm) / math.tan(_halfVFovDeg * math.pi / 180);

/// The object to tag: the highest-score detection that is not a hand.
Detection? hudTarget(List<Detection> detections) {
  Detection? best;
  for (final d in detections) {
    if (d.label.trim().isEmpty || d.label == 'Human_Hand') continue;
    if (best == null || d.score > best.score) best = d;
  }
  return best;
}

class ControlCameraHud extends StatelessWidget {
  const ControlCameraHud({
    super.key,
    required this.frame,
    required this.imageSize,
    required this.detections,
    required this.link,
    required this.fps,
    required this.retry,
    required this.onReconnect,
    this.onWifiSettings,
    this.diagnostics,
    this.debugBoxes,
    this.quizButton,
  });

  final Uint8List? frame;
  final Size imageSize;
  final List<Detection> detections;
  final ControlLink link;
  final double fps;
  final RetryInfo retry;
  final VoidCallback onReconnect;
  final VoidCallback? onWifiSettings;
  final Widget? diagnostics;
  final Widget? debugBoxes;
  final Widget? quizButton;

  @override
  Widget build(BuildContext context) {
    final live = link == ControlLink.connected && frame != null;
    final target = live ? hudTarget(detections) : null;
    final showFloor = live && imageSize.width > 0 && detections.any((d) => d.distCm != null);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: _cameraBg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (frame != null && link == ControlLink.connected)
              Image.memory(frame!, fit: BoxFit.cover, gaplessPlayback: true)
            else if (link == ControlLink.connected)
              const Center(
                child: _HudLine(icon: Icons.videocam_outlined, text: 'Connected. Waiting for camera frames...'),
              ),
            ?debugBoxes,
            if (live)
              CustomPaint(
                painter: HudFloorPainter(imageSize: imageSize, showFloor: showFloor, target: target),
              ),
            if (target != null) _TargetTag(target: target, imageSize: imageSize),
            if (link == ControlLink.waiting) const _WaitingPanel(),
            if (link == ControlLink.disconnected)
              _DisconnectedPanel(retry: retry, onReconnect: onReconnect, onWifiSettings: onWifiSettings),
            Positioned(
              left: 12,
              top: 12,
              child: _HudChip(dot: live ? _hudRed : _hudMuted, text: live ? 'LIVE · ${fps.round()} fps' : 'NO VIDEO'),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: _HudChip(
                dot: switch (link) {
                  ControlLink.connected => _hudGreen,
                  ControlLink.waiting => _hudAmber,
                  ControlLink.disconnected => _hudRed,
                },
                text: switch (link) {
                  ControlLink.connected => 'MaixCAM2 connected',
                  ControlLink.waiting => 'Connecting...',
                  ControlLink.disconnected => 'Disconnected',
                },
              ),
            ),
            if (diagnostics != null) Positioned(left: 12, bottom: 12, child: diagnostics!),
            if (quizButton != null) Positioned(right: 12, bottom: 12, child: quizButton!),
          ],
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.dot, required this.text});
  final Color dot;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const ShapeDecoration(color: _glass, shape: StadiumBorder()),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: _hudText, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _HudLine extends StatelessWidget {
  const _HudLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: _hudMuted),
      const SizedBox(height: 8),
      Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _hudMuted, fontSize: 13),
      ),
    ],
  );
}

/// Image coordinates -> widget coordinates for BoxFit.cover.
({double scale, Offset offset}) _cover(Size image, Size box) {
  final scale = math.max(box.width / image.width, box.height / image.height);
  return (scale: scale, offset: Offset((box.width - image.width * scale) / 2, (box.height - image.height * scale) / 2));
}

/// Floor bands, pick zone (only with dist_cm) and the tagged box's brackets.
class HudFloorPainter extends CustomPainter {
  HudFloorPainter({required this.imageSize, required this.showFloor, required this.target});
  final Size imageSize;
  final bool showFloor;
  final Detection? target;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return;
    final m = _cover(imageSize, size);
    double rowY(double cm) => m.offset.dy + floorRowFraction(cm) * imageSize.height * m.scale;
    if (showFloor) {
      final zoneTop = rowY(pickBandMaxCm), zoneBottom = rowY(pickBandMinCm);
      canvas.drawRect(
        Rect.fromLTRB(0, zoneTop, size.width, zoneBottom),
        Paint()..color = _hudGreen.withValues(alpha: 0.12),
      );
      for (final cm in hudBandsCm) {
        final y = rowY(cm);
        if (y < 0 || y > size.height) continue;
        final inZone = cm >= pickBandMinCm && cm <= pickBandMaxCm;
        // A dark under-stroke keeps the line visible on a bright floor.
        canvas.drawLine(
          Offset(0, y + 1),
          Offset(size.width, y + 1),
          Paint()
            ..color = _glass.withValues(alpha: 0.35)
            ..strokeWidth = 1.2,
        );
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          Paint()
            ..color = (inZone ? _hudGreen : _hudText).withValues(alpha: inZone ? 0.9 : 0.6)
            ..strokeWidth = 1.2,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '${cm.round()} cm',
            style: const TextStyle(color: _hudText, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final at = Offset(14, y - tp.height - 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            (at - const Offset(5, 1)) & Size(tp.width + 10, tp.height + 2),
            const Radius.circular(6),
          ),
          Paint()..color = _glass,
        );
        tp.paint(canvas, at);
      }
      final tp = TextPainter(
        text: const TextSpan(
          text: 'PICK ZONE',
          style: TextStyle(color: _hudGreen, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 14, (zoneTop + zoneBottom) / 2 - tp.height / 2));
    }
    final t = target;
    if (t == null) return;
    // Corner brackets around the tagged box (x, y = box centre).
    final r = Rect.fromCenter(
      center: m.offset + Offset(t.x, t.y) * m.scale,
      width: t.w * m.scale,
      height: t.h * m.scale,
    );
    final p = Paint()
      ..color = _hudGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final k = math.min(18.0, r.shortestSide / 3);
    for (final (c, dx, dy) in [
      (r.topLeft, 1, 1),
      (r.topRight, -1, 1),
      (r.bottomLeft, 1, -1),
      (r.bottomRight, -1, -1),
    ]) {
      canvas.drawLine(c, c + Offset(k * dx, 0), p);
      canvas.drawLine(c, c + Offset(0, k * dy), p);
    }
  }

  @override
  bool shouldRepaint(HudFloorPainter old) => true;
}

/// `<label> · <n> cm` above the box; the label alone without dist_cm.
class _TargetTag extends StatelessWidget {
  const _TargetTag({required this.target, required this.imageSize});
  final Detection target;
  final Size imageSize;

  @override
  Widget build(BuildContext context) {
    final cm = target.distCm;
    final text = cm == null ? target.label : '${target.label} · ${cm.round()} cm';
    return LayoutBuilder(
      builder: (context, c) {
        if (imageSize.width <= 0) return const SizedBox.shrink();
        final m = _cover(imageSize, c.biggest);
        final centre = m.offset + Offset(target.x, target.y - target.h / 2) * m.scale;
        return Stack(
          children: [
            Positioned(
              left: (centre.dx - 90).clamp(0, math.max(0, c.maxWidth - 180)),
              top: (centre.dy - 56).clamp(44, math.max(44, c.maxHeight - 30)), // above the firmware's own label
              width: 180,
              child: Center(
                child: DecoratedBox(
                  key: const ValueKey('hud_target_tag'),
                  decoration: const ShapeDecoration(color: _hudGreen, shape: StadiumBorder()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The real retry numbers from WebSocketService (2 s, 30 tries).
class RetryInfo {
  const RetryInfo({
    required this.attempt,
    required this.maxAttempts,
    required this.nextRetryAt,
    required this.autoReconnect,
  });
  final int attempt;
  final int maxAttempts;
  final DateTime? nextRetryAt;
  final bool autoReconnect;
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.art, required this.children});
  final Widget art;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // A phone's short camera keeps the text readable and drops the picture.
    builder: (context, c) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: math.min(440, math.max(240, c.maxWidth - 32))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [if (c.maxHeight >= 300) art, ...children]),
          ),
        ),
      ),
    ),
  );
}

const _title = TextStyle(color: _hudText, fontSize: 20, fontWeight: FontWeight.w700);
const _body = TextStyle(color: _hudMuted, fontSize: 14);

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel();

  @override
  Widget build(BuildContext context) => _HudPanel(
    art: Padding(padding: const EdgeInsets.only(bottom: 10), child: controlArt('elio_searching', height: 104)),
    children: [
      Text(context.l10n.lookingForMaixcam, style: _title, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      const Text(
        'Turn the robot on and keep this tablet on the ELIOS Wi-Fi.',
        style: _body,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      const SizedBox(
        width: 220,
        child: LinearProgressIndicator(color: _hudAmber, backgroundColor: Color(0x33F1F5F9), minHeight: 4),
      ),
    ],
  );
}

class _DisconnectedPanel extends StatefulWidget {
  const _DisconnectedPanel({required this.retry, required this.onReconnect, this.onWifiSettings});
  final RetryInfo retry;
  final VoidCallback onReconnect;
  final VoidCallback? onWifiSettings;

  @override
  State<_DisconnectedPanel> createState() => _DisconnectedPanelState();
}

class _DisconnectedPanelState extends State<_DisconnectedPanel> {
  // Ticks the countdown; only while this panel is on screen.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.retry;
    final next = r.nextRetryAt;
    final String retryLine;
    if (next != null) {
      final s = math.max(0, (next.difference(DateTime.now()).inMilliseconds / 1000).ceil());
      retryLine = 'Retrying in $s s · attempt ${r.attempt} of ${r.maxAttempts}';
    } else if (!r.autoReconnect) {
      retryLine = 'Auto-reconnect is off';
    } else if (r.attempt >= r.maxAttempts) {
      retryLine = 'Stopped retrying after ${r.maxAttempts} tries';
    } else {
      retryLine = 'Trying again · attempt ${r.attempt} of ${r.maxAttempts}';
    }
    return _HudPanel(
      art: Padding(padding: const EdgeInsets.only(bottom: 8), child: controlArt('elio_disconnected', height: 96)),
      children: [
        Text(context.l10n.lostConnection, style: _title, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        const Text(
          'The robot link dropped, so the robot stopped for safety.',
          style: _body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          retryLine,
          key: const ValueKey('retry_line'),
          style: const TextStyle(color: _hudAmber, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: widget.onReconnect,
              style: FilledButton.styleFrom(backgroundColor: _hudGreen, foregroundColor: const Color(0xFF0F172A)),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.reconnectNow),
            ),
            if (widget.onWifiSettings != null)
              OutlinedButton.icon(
                onPressed: widget.onWifiSettings,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _hudText,
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: _hudMuted),
                ),
                icon: const Icon(Icons.wifi_rounded),
                label: Text(context.l10n.wifiSettings),
              ),
          ],
        ),
      ],
    );
  }
}

/// The yellow quiz button: reopens a minimised quiz (replaces the old leaf).
class QuizReopenButton extends ConsumerWidget {
  const QuizReopenButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wasteQuizProvider);
    if (state.phase == WasteQuizPhase.idle || !state.minimized) return const SizedBox.shrink();
    return Tooltip(
      message: 'Buka kuis',
      child: SizedBox.square(
        dimension: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: ElioTokens.answerYellow,
                shape: const CircleBorder(side: BorderSide(color: Color(0xFFB45309), width: 2)),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => ref.read(wasteQuizProvider.notifier).restore(),
                  child: const Icon(Icons.help_outline_rounded, color: ElioTokens.onAnswerYellow, size: 30),
                ),
              ),
            ),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.elio.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: _hudText, width: 2),
                ),
                child: const Text(
                  '1',
                  style: TextStyle(color: _hudText, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom cards ────────────────────────────────────────────────────────────

const _binArt = {HomeBin.organik: 'bin_organik', HomeBin.anorganik: 'bin_anorganik', HomeBin.b3: 'bin_b3'};

Widget _bin(HomeBin b, {double size = 40}) => ExcludeSemantics(
  child: SvgPicture.asset('assets/illustrations/home/${_binArt[b]}.svg', width: size, height: size),
);

class MissionCard extends StatelessWidget {
  const MissionCard({super.key, required this.done});
  final int done;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final n = math.min(done, missionTarget);
    return ControlCard(
      child: Row(
        children: [
          controlArt('bottle_buddy', height: 84),
          const SizedBox(width: 14),
          Expanded(
            child: fitDown(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ControlCaps('MISSION'),
                  const SizedBox(height: 4),
                  Text(
                    'Sort $missionTarget items this drive',
                    maxLines: 2,
                    style: TextStyle(color: p.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var i = 0; i < missionTarget; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: i < n ? p.primary : p.surfaceRaised,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: i < n ? p.primaryActive : p.borderSubtle),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(context.l10n.missionProgress(n, missionTarget), style: TextStyle(color: p.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DriveTallyCard extends StatelessWidget {
  const DriveTallyCard({super.key, required this.bins, required this.trophies});
  final Map<HomeBin, int> bins;
  final int trophies;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ControlCard(
      child: fitDown(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: ControlCaps('THIS DRIVE')),
                if (trophies > 0)
                  Text(
                    '+$trophies trophies',
                    style: TextStyle(color: p.secondaryText, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final b in HomeBin.values)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _bin(b),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${bins[b] ?? 0}',
                                style: TextStyle(color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                b.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _tipArt(TipMood m) => switch (m) {
  TipMood.searching => 'elio_searching',
  TipMood.sad => 'elio_disconnected',
  _ => 'elio_robot',
};

class ElioTipCard extends StatelessWidget {
  const ElioTipCard({super.key, required this.text, required this.mood});
  final String text;
  final TipMood mood;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final accent = switch (mood) {
      TipMood.happy => p.primary,
      TipMood.searching => p.secondaryText,
      TipMood.sad => p.borderStrong,
      TipMood.alert => p.error,
    };
    return ControlCard(
      color: Color.alphaBlend(accent.withValues(alpha: 0.14), p.surface),
      border: accent,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          controlArt(_tipArt(mood), height: 92),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14)),
              child: fitDown(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ControlCaps('ELIO SAYS', color: p.primaryText),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      key: const ValueKey('elio_tip'),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textPrimary, fontSize: 14, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ControlTogglesCard extends StatelessWidget {
  const ControlTogglesCard({
    super.key,
    required this.scanQuiz,
    required this.voice,
    required this.onScanQuiz,
    required this.onVoice,
  });
  final bool scanQuiz, voice;
  final ValueChanged<bool> onScanQuiz, onVoice;

  @override
  Widget build(BuildContext context) => ControlCard(
    child: fitDown(
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          RockerToggle(
            key: const ValueKey('toggle_scan_quiz'),
            label: 'Scan quiz',
            value: scanQuiz,
            onChanged: onScanQuiz,
          ),
          RockerToggle(key: const ValueKey('toggle_voice'), label: 'Voice', value: voice, onChanged: onVoice),
        ],
      ),
      alignment: Alignment.centerRight,
    ),
  );
}

/// Phones in landscape: mission, tally, tip and toggles in one row.
class ControlCompactStrip extends StatelessWidget {
  const ControlCompactStrip({
    super.key,
    required this.missionDone,
    required this.bins,
    required this.tip,
    required this.scanQuiz,
    required this.voice,
    required this.onScanQuiz,
    required this.onVoice,
  });

  final int missionDone;
  final Map<HomeBin, int> bins;
  final String tip;
  final bool scanQuiz, voice;
  final ValueChanged<bool> onScanQuiz, onVoice;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final small = TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w600);
    Widget toggle(String label, IconData icon, bool v, ValueChanged<bool> on, Key key) => MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: v ? p.primaryText : p.textTertiary, semanticLabel: label),
          Transform.scale(
            scale: 0.7,
            child: Switch(key: key, value: v, onChanged: on, activeTrackColor: p.primary, activeThumbColor: p.surface),
          ),
        ],
      ),
    );
    return ControlCard(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          controlArt('bottle_buddy', height: 28),
          const SizedBox(width: 4),
          Text(
            '${math.min(missionDone, missionTarget)}/$missionTarget',
            style: small,
            semanticsLabel: 'Misi ${math.min(missionDone, missionTarget)} dari $missionTarget',
          ),
          const SizedBox(width: 10),
          for (final b in HomeBin.values) ...[
            _bin(b, size: 22),
            Text('${bins[b] ?? 0}', style: small),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 4),
          controlArt('elio_robot', height: 28),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              tip,
              key: const ValueKey('elio_tip'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.textPrimary, fontSize: 12, height: 1.2),
            ),
          ),
          toggle('Scan quiz', Icons.quiz_outlined, scanQuiz, onScanQuiz, const ValueKey('toggle_scan_quiz')),
          toggle('Voice', Icons.volume_up_outlined, voice, onVoice, const ValueKey('toggle_voice')),
        ],
      ),
    );
  }
}
