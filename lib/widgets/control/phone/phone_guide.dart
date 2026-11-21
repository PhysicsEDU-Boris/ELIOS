// The 5-step Guide overlay for the phone Control screen (Figma 400:4769 ...
// 400:5883). A scrim with a hole over the part each step names, a dashed
// spotlight ring and a card. STOP stays tappable through the scrim.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../learn/learn_ui.dart' show LearnTheme;
import '../../tour/app_tour.dart';
import 'package:elio/l10n/l10n.dart';

class _Step {
  const _Step(this.title, this.body);
  final String title, body;
}

List<_Step> get _steps => [
  _Step(l10n.guideDriveTitle, l10n.guideDriveBody),
  _Step(l10n.guideStopTitle, l10n.guideStopBody),
  _Step(l10n.guideGrabTitle, l10n.guideGrabBody),
  _Step(l10n.guideQuizTitle, l10n.guideQuizBody),
];

const guideStepCount = 5;

/// Saved per device once the Guide has opened by itself (decision 0174).
const controlGuideShownKey = 'r3_phone_guide_shown';

class PhoneGuide extends StatefulWidget {
  const PhoneGuide({
    super.key,
    required this.driveKey,
    required this.stopKey,
    required this.actionKey,
    required this.quizKey,
    required this.onStop,
    required this.onClose,
    this.initialStep = 0,
  });

  /// The parts steps 1-4 point at, in the layout underneath.
  final GlobalKey driveKey, stopKey, actionKey, quizKey;
  final VoidCallback onStop, onClose;
  final int initialStep;

  @override
  State<PhoneGuide> createState() => _PhoneGuideState();
}

class _PhoneGuideState extends State<PhoneGuide> {
  late int _step = widget.initialStep;

  GlobalKey get _target => [
    widget.driveKey,
    widget.stopKey,
    widget.actionKey,
    widget.quizKey,
  ][_step];

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final mine = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || mine == null) {
      return null;
    }
    try {
      return mine.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
    } catch (_) {
      return null; // not laid out yet: the post-frame pass measures again
    }
  }

  @override
  void initState() {
    super.initState();
    // The layout under us may be laid out in this same frame: measure again after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _next() {
    if (_step == guideStepCount - 1) {
      widget.onClose();
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return LayoutBuilder(
      builder: (context, c) {
        final screen = Size(c.maxWidth, c.maxHeight);
        final last = _step == guideStepCount - 1;
        final hole = last ? null : _rectOf(_target)?.inflate(6);
        final stopRect = _rectOf(widget.stopKey);
        return Stack(
          key: const ValueKey('phone_guide_overlay'),
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(
                  painter: TourScrimPainter(
                    hole: hole,
                    scrim: (p.isDark ? Colors.black : p.textPrimary).withValues(
                      alpha: p.isDark ? 0.62 : 0.5,
                    ),
                    ring: p.primary,
                    radius: _step == 1 || _step == 0 ? 999 : 20,
                  ),
                ),
              ),
            ),
            // STOP stays live under the guide, whatever step it is on.
            if (stopRect != null)
              Positioned.fromRect(
                rect: stopRect,
                child: Semantics(
                  button: true,
                  label: l10n.ctlEmergencyStop,
                  excludeSemantics: true,
                  onTap: widget.onStop,
                  child: GestureDetector(
                    key: const ValueKey('guide_stop'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onStop,
                  ),
                ),
              ),
            if (last)
              Center(child: _FinalCard(onDone: _next))
            else
              _positionedCard(
                screen,
                hole,
                _StepCard(step: _step, onSkip: widget.onClose, onNext: _next),
              ),
          ],
        );
      },
    );
  }

  /// Beside the spotlight: right, left, below, then above; clamped on screen.
  Widget _positionedCard(Size screen, Rect? hole, Widget card) {
    const w = 288.0, h = 168.0, gap = 12.0, edge = 8.0;
    double clampX(double x) =>
        x.clamp(edge, math.max(edge, screen.width - w - edge));
    double clampY(double y) =>
        y.clamp(edge, math.max(edge, screen.height - h - edge));
    Offset at;
    if (hole == null) {
      at = Offset((screen.width - w) / 2, (screen.height - h) / 2);
    } else if (hole.right + gap + w <= screen.width - edge) {
      at = Offset(hole.right + gap, clampY(hole.center.dy - h / 2));
    } else if (hole.left - gap - w >= edge) {
      at = Offset(hole.left - gap - w, clampY(hole.center.dy - h / 2));
    } else if (hole.bottom + gap + h <= screen.height - edge) {
      at = Offset(clampX(hole.center.dx - w / 2), hole.bottom + gap);
    } else {
      // Above the spotlight: anchored by its bottom edge, so a taller card grows upward.
      return Positioned(
        left: clampX(hole.center.dx - w / 2),
        bottom: screen.height - (hole.top - gap),
        width: w,
        child: card,
      );
    }
    return Positioned(left: at.dx, top: at.dy, width: w, child: card);
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.onSkip,
    required this.onNext,
  });
  final int step;
  final VoidCallback onSkip, onNext;

  @override
  Widget build(BuildContext context) => TourCard(
    step: step,
    count: guideStepCount,
    label: '',
    title: _steps[step].title,
    body: _steps[step].body,
    nextLabel: l10n.guideNext,
    onSkip: onSkip,
    onNext: onNext,
  );
}

class _FinalCard extends StatelessWidget {
  const _FinalCard({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: const ValueKey('guide_step_5'),
    child: TourFinishCard(
      title: l10n.guideReady,
      body: l10n.guideIntro,
      buttonLabel: l10n.guideGo,
      onDone: onDone,
    ),
  );
}
