// App onboarding tour (Figma ELIOS 3 · section 18, decision 0238).
// One engine for the main tour, the first-visit screen tours and the robot
// Control guide: a scrim with a hole over the target, a dashed green ring and
// the ELIO coach card. Targets are GlobalKeys on the real widgets.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../learn/learn_ui.dart' show LearnTheme;
import 'package:elio/l10n/l10n.dart';

/// Spotlight targets of the main tour (one widget each, in the tab screens).
abstract final class TourKeys {
  static final homeTop = GlobalKey(debugLabel: 'tour_home_top');
  static final homeHero = GlobalKey(debugLabel: 'tour_home_hero');
  static final homeStats = GlobalKey(debugLabel: 'tour_home_stats');
  static final homeQuests = GlobalKey(debugLabel: 'tour_home_quests');
  static final homeBins = GlobalKey(debugLabel: 'tour_home_bins');
  static final nav = GlobalKey(debugLabel: 'tour_nav');
  static final learnRing = GlobalKey(debugLabel: 'tour_learn_ring');
  static final learnTicket = GlobalKey(debugLabel: 'tour_learn_ticket');
  static final learnArchive = GlobalKey(debugLabel: 'tour_learn_archive');
  static final learnBubbles = GlobalKey(debugLabel: 'tour_learn_bubbles');
  static final learnExplore = GlobalKey(debugLabel: 'tour_learn_explore');
  static final scanPhone = GlobalKey(debugLabel: 'tour_scan_phone');
  static final scanRobot = GlobalKey(debugLabel: 'tour_scan_robot');
  static final scanContribute = GlobalKey(debugLabel: 'tour_scan_contribute');
  static final historyBins = GlobalKey(debugLabel: 'tour_history_bins');
  static final historyRecent = GlobalKey(debugLabel: 'tour_history_recent');
  static final historyReview = GlobalKey(debugLabel: 'tour_history_review');
  static final profileTour = GlobalKey(debugLabel: 'tour_profile_tour');
}

/// Lists a tour runs over build this far past the screen, so a step's widget
/// exists on a short (landscape) screen and the tour can scroll to it.
const tourCacheExtent = ScrollCacheExtent.pixels(2400);

class TourStep {
  const TourStep(this.target, this.title, this.body, {this.round = false});

  /// The widget to spotlight. Null (or not on screen) shows the card centred.
  final GlobalKey? target;
  final String title, body;

  /// Pill/circle spotlight instead of a rounded rectangle.
  final bool round;
}

class AppTour {
  AppTour._();

  /// Profile ▸ App tour ▸ "Show tips on new screens" (default on).
  static const tipsEnabledKey = 'tour_tips_enabled';

  /// Welcome + main tour seen (or skipped) once.
  static const welcomeSeenKey = 'tour_welcome_seen';
  static const _tipPrefix = 'tour_tip_';

  /// True while any tour is on screen, so a screen tip never stacks on it.
  static bool running = false;

  /// Live value of the Profile switch. Off until [load] reads it at start-up
  /// (HomeShell), so screens built alone (tests) never start a tour.
  static final tipsOn = ValueNotifier<bool>(false);

  /// Profile asks the shell to run the tour: 'all' or one part ('home', 'learn',
  /// 'scan', 'history', 'profile'). The shell clears it once started.
  static final request = ValueNotifier<String?>(null);

  static Future<void> load() async => tipsOn.value =
      (await SharedPreferences.getInstance()).getBool(tipsEnabledKey) ?? true;

  static Future<void> setTipsEnabled(bool on) async {
    tipsOn.value = on;
    await (await SharedPreferences.getInstance()).setBool(tipsEnabledKey, on);
  }

  /// Forget which screen tours were seen, so each shows again on next open.
  static Future<void> resetTips() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_tipPrefix))) {
      await prefs.remove(k);
    }
  }

  /// Shows [steps] over the whole app. Resolves true when the last step was
  /// finished, false when the user tapped Skip.
  static Future<bool> run(
    BuildContext context,
    List<TourStep> steps, {
    required String label,
    String? doneLabel,
  }) {
    // A step whose widget is not on this screen (an empty History, a closed
    // sheet) is dropped, so every card points at something real.
    steps = [
      for (final s in steps)
        if (s.target == null || s.target!.currentContext != null) s,
    ];
    if (steps.isEmpty) return Future.value(true);
    final overlay = Overlay.of(context, rootOverlay: true);
    final done = Completer<bool>();
    running = true;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => ElioTheme.wrap(
        Material(
          type: MaterialType.transparency,
          child: _TourOverlay(
            steps: steps,
            label: label,
            doneLabel: doneLabel ?? l10n.tourGotIt,
            onEnd: (finished) {
              entry.remove();
              running = false;
              if (!done.isCompleted) done.complete(finished);
            },
          ),
        ),
      ),
    );
    overlay.insert(entry);
    return done.future;
  }

  /// A screen's own short tour, the first time it opens (and tips are on).
  static Future<void> tipOnce(
    BuildContext context,
    String id,
    String label,
    List<TourStep> Function() steps,
  ) async {
    if (running || !tipsOn.value) return;
    final prefs = await SharedPreferences.getInstance();
    if (running ||
        !tipsOn.value ||
        (prefs.getBool('$_tipPrefix$id') ?? false)) {
      return;
    }
    // Let the screen's first layout and page transition settle.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!context.mounted || running) return;
    await prefs.setBool('$_tipPrefix$id', true);
    if (!context.mounted) return;
    await run(context, steps(), label: label);
  }
}

class _TourOverlay extends StatefulWidget {
  const _TourOverlay({
    required this.steps,
    required this.label,
    required this.doneLabel,
    required this.onEnd,
  });
  final List<TourStep> steps;
  final String label, doneLabel;
  final ValueChanged<bool> onEnd;

  @override
  State<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<_TourOverlay> {
  int _step = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  /// Scrolls the target into view, then measures it on the next frame.
  Future<void> _reveal() async {
    setState(() => _ready = false);
    final ctx = widget.steps[_step].target?.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.3,
          duration: const Duration(milliseconds: 250),
        );
      } catch (_) {}
      // Sections that rise in as they scroll into view need a moment.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) setState(() => _ready = true);
  }

  Rect? _rectOf(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    final mine = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize || mine == null) {
      return null;
    }
    try {
      final r = mine.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
      return r.overlaps(Offset.zero & mine.size) ? r : null;
    } catch (_) {
      return null;
    }
  }

  void _next() {
    if (_step == widget.steps.length - 1) {
      widget.onEnd(true);
    } else {
      _step++;
      _reveal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final s = widget.steps[_step];
    final last = _step == widget.steps.length - 1;
    return LayoutBuilder(
      builder: (context, c) {
        final screen = Size(c.maxWidth, c.maxHeight);
        final hole = _ready ? _rectOf(s.target)?.inflate(6) : null;
        final card = TourCard(
          step: _step,
          count: widget.steps.length,
          label: widget.label,
          title: s.title,
          body: s.body,
          nextLabel: last ? widget.doneLabel : l10n.guideNext,
          onSkip: last ? null : () => widget.onEnd(false),
          onNext: _next,
        );
        return Stack(
          key: const ValueKey('app_tour_overlay'),
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(
                  painter: TourScrimPainter(
                    hole: hole,
                    scrim: tourScrimColor(p),
                    ring: p.primary,
                    radius: s.round ? 999 : 24,
                  ),
                ),
              ),
            ),
            if (_ready) tourCardBeside(screen, hole, card, width: 342),
          ],
        );
      },
    );
  }
}

Color tourScrimColor(ElioPalette p) => p.isDark
    ? const Color(0xFF020617).withValues(alpha: 0.82)
    : p.textPrimary.withValues(alpha: 0.6);

/// Places [card] below or above the spotlight on a portrait phone, and to the
/// side of it when there is room (landscape). Centred when there is no hole.
Widget tourCardBeside(
  Size screen,
  Rect? hole,
  Widget card, {
  double width = 288,
}) {
  const h = 176.0, gap = 14.0, edge = 12.0;
  final w = math.min(width, screen.width - 2 * edge);
  double clampX(double x) =>
      x.clamp(edge, math.max(edge, screen.width - w - edge));
  double clampY(double y) =>
      y.clamp(edge, math.max(edge, screen.height - h - edge));
  if (hole == null) {
    return Positioned.fill(
      child: Center(
        child: SizedBox(width: w, child: card),
      ),
    );
  }
  final portrait = screen.height > screen.width;
  if (!portrait && hole.right + gap + w <= screen.width - edge) {
    return Positioned(
      left: hole.right + gap,
      top: clampY(hole.center.dy - h / 2),
      width: w,
      child: card,
    );
  }
  if (!portrait && hole.left - gap - w >= edge) {
    return Positioned(
      left: hole.left - gap - w,
      top: clampY(hole.center.dy - h / 2),
      width: w,
      child: card,
    );
  }
  final below = screen.height - hole.bottom >= hole.top;
  if (below && hole.bottom + gap + h <= screen.height - edge) {
    return Positioned(
      left: clampX(hole.center.dx - w / 2),
      top: hole.bottom + gap,
      width: w,
      child: card,
    );
  }
  if (!below && hole.top - gap - h >= edge) {
    // Anchored by its bottom edge, so a taller card grows upward.
    return Positioned(
      left: clampX(hole.center.dx - w / 2),
      bottom: screen.height - (hole.top - gap),
      width: w,
      child: card,
    );
  }
  // Huge target: the card sits over its lower part.
  return Positioned(
    left: clampX(hole.center.dx - w / 2),
    bottom: edge + 72,
    width: w,
    child: card,
  );
}

class TourScrimPainter extends CustomPainter {
  TourScrimPainter({
    required this.hole,
    required this.scrim,
    required this.ring,
    required this.radius,
  });
  final Rect? hole;
  final Color scrim, ring;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(path, Paint()..color = scrim);
      return;
    }
    final r = RRect.fromRectAndRadius(
      hole!,
      Radius.circular(math.min(radius, hole!.shortestSide / 2)),
    );
    path
      ..addRRect(r)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = scrim);
    // Dashed spotlight ring.
    final dash = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final m in (Path()..addRRect(r)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), dash);
      }
    }
  }

  @override
  bool shouldRepaint(TourScrimPainter old) =>
      old.hole != hole || old.scrim != scrim || old.radius != radius;
}

BoxDecoration tourCardDecoration(ElioPalette p) => BoxDecoration(
  color: p.surface,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: p.primary, width: 2),
  boxShadow: [BoxShadow(color: p.borderMedium, offset: const Offset(0, 4))],
);

Widget tourRobot(ElioPalette p, double size) => Container(
  width: size,
  height: size,
  clipBehavior: Clip.antiAlias,
  decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
  child: ExcludeSemantics(
    child: SvgPicture.asset(
      'assets/illustrations/control/elio_robot.svg',
      fit: BoxFit.cover,
    ),
  ),
);

class TourGreenButton extends StatelessWidget {
  const TourGreenButton({required this.label, required this.onTap, super.key});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      decoration: BoxDecoration(
        color: p.primary,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(color: p.primaryActive, offset: const Offset(0, 3)),
        ],
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ELIO coach card: "LABEL · STEP n OF m", title, body, dots, Skip, Next.
class TourCard extends StatelessWidget {
  const TourCard({
    super.key,
    required this.step,
    required this.count,
    required this.label,
    required this.title,
    required this.body,
    required this.nextLabel,
    required this.onNext,
    this.onSkip,
  });
  final int step, count;
  final String label, title, body, nextLabel;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final caps = count > 1
        ? (label.isEmpty
              ? l10n.guideStepOf(step + 1, count)
              : '$label · ${l10n.guideStepOf(step + 1, count)}')
        : label;
    return Container(
      key: ValueKey('guide_step_${step + 1}'),
      padding: const EdgeInsets.all(14),
      decoration: tourCardDecoration(p),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              tourRobot(p, 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caps,
                      style: TextStyle(
                        color: p.primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(color: p.textSecondary, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (count > 1)
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Container(
                    width: i == step ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= step ? p.primary : p.borderMedium,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              const Spacer(),
              if (onSkip != null)
                TextButton(
                  key: const ValueKey('guide_skip'),
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: p.primaryText,
                    backgroundColor: Colors.transparent,
                    minimumSize: const Size(44, 40),
                  ),
                  child: Text(
                    l10n.guideSkip,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 4),
              TourGreenButton(
                key: const ValueKey('guide_next'),
                label: nextLabel,
                onTap: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "You're ready!" card with the excited robot (Figma Tour / Finish card).
class TourFinishCard extends StatelessWidget {
  const TourFinishCard({
    super.key,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onDone,
  });
  final String title, body, buttonLabel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      decoration: tourCardDecoration(p),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: SvgPicture.asset(
              'assets/illustrations/control/elio_robot.svg',
              height: 84,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          TourGreenButton(
            key: const ValueKey('guide_done'),
            label: buttonLabel,
            onTap: onDone,
          ),
        ],
      ),
    );
  }
}

/// Wraps a screen (or a state of one) and runs its short tour the first time
/// it appears. [builder] gets the spotlight keys to put on the real widgets.
class TourTip extends StatefulWidget {
  const TourTip({
    super.key,
    required this.id,
    required this.label,
    required this.steps,
    required this.builder,
    this.show = true,
  });
  final String id;

  /// False keeps the tour off (robot screens: the overlay would cover STOP).
  final bool show;
  final String Function() label;
  final List<TourStep> Function(List<GlobalKey> k) steps;
  final Widget Function(BuildContext context, List<GlobalKey> k) builder;

  @override
  State<TourTip> createState() => _TourTipState();
}

class _TourTipState extends State<TourTip> {
  final _keys = List.generate(5, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    if (!widget.show) return;
    AppTour.tipOnce(
      context,
      widget.id,
      widget.label(),
      () => widget.steps(_keys),
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _keys);
}
