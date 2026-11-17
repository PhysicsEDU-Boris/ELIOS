// Full-screen Scan & quiz pages for the phone camera (Figma 06 · Scan:
// identified 629:90773, question 629:90816, landscape 659:25791 / 659:25857;
// motion 13 · 27 and 28; decision 0216). Same provider calls as the popup;
// states with no full-page design (hazard, mismatch, essay, review, result)
// show the popup's own views on the page.
part of '../waste_quiz_popup.dart';

TextStyle _sq(TextStyle base, int weight, Color color) =>
    homeWeight(base, weight).copyWith(color: color);

/// The robot control screen's settings for the pages (Figma 815:31496,
/// 815:31579, 821:28687): robot wording, the emergency stop in every header,
/// "Scan again" restarts the live scan, and close minimises so the student
/// can keep driving.
class _Robot extends InheritedWidget {
  const _Robot({
    required this.robot,
    required this.onStop,
    required this.onRescan,
    required super.child,
  });
  final bool robot;
  final VoidCallback? onStop;
  final VoidCallback? onRescan;

  static _Robot? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Robot>();

  @override
  bool updateShouldNotify(_Robot old) => false;
}

bool _isRobot(BuildContext context) => _Robot.of(context)?.robot ?? false;

/// The compact STOP of the robot pages; nothing on the phone.
List<Widget> _stopPill(BuildContext context) {
  final stop = _Robot.of(context)?.onStop;
  return stop == null
      ? const []
      : [_CompactStop(onStop: stop), const SizedBox(width: 8)];
}

class ScanQuizPages extends ConsumerStatefulWidget {
  const ScanQuizPages({
    super.key,
    this.robot = false,
    this.onStop,
    this.onRescan,
  });

  /// Robot control: see [_Robot].
  final bool robot;
  final VoidCallback? onStop;
  final VoidCallback? onRescan;

  @override
  ConsumerState<ScanQuizPages> createState() => _ScanQuizPagesState();
}

class _ScanQuizPagesState extends ConsumerState<ScanQuizPages> {
  /// "Start quiz" was tapped for this scan.
  bool _started = false;

  /// The pages are showing (not idle, not minimised).
  bool _open = false;

  /// Counts the times the pages opened; restarts the scan-start reveal.
  int _opens = 0;

  /// The answered question stays up while its right / wrong feedback plays.
  bool _hold = false;
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  bool _leaveOpen = false;

  /// Back (system, swipe or the page's own button) during a quiz: confirm
  /// first. Only "Leave" ends the quiz; the quiz state is never touched
  /// otherwise, so the student returns to exactly the same place.
  Future<void> _confirmLeave() async {
    if (_leaveOpen) return;
    _leaveOpen = true;
    final p = context.elio;
    final leave = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: p.surface,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            key: const ValueKey('quiz_leave_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.quizLeaveTitle,
                  style: _sq(ElioTokens.subhead, 600, p.textPrimary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.quizLeaveBody,
                style: ElioTokens.body.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('quiz_leave_keep'),
                autofocus: true,
                onPressed: () => Navigator.of(sheet).pop(false),
                child: Text(l10n.quizLeaveKeep),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('quiz_leave_leave'),
                onPressed: () => Navigator.of(sheet).pop(true),
                child: Text(l10n.quizLeaveLeave),
              ),
            ],
          ),
        ),
      ),
    );
    _leaveOpen = false;
    if (leave == true && mounted) {
      ref.read(wasteQuizProvider.notifier).dismiss();
    }
  }

  /// Robot bin check (decision 0224): the three bars, in Figma order.
  static const _bins = [
    ScanCategory.organic,
    ScanCategory.recyclable,
    ScanCategory.b3,
  ];

  /// The bar picked in the bin check, while its right / wrong feedback plays.
  int? _binPicked;

  void _answerBin(int i) {
    final right = _bins[i] == ref.read(wasteQuizProvider).binAnswer;
    // Right: success cue. Wrong: the gentle knock.
    quizFeedback(
      right ? ElioSfx.chime : ElioSfx.knock,
      right ? ElioHaptics.success : ElioHaptics.warning,
    );
    ref.read(wasteQuizProvider.notifier).answerBinCheck(_bins[i]);
    _holdTimer?.cancel();
    setState(() {
      _hold = true;
      _binPicked = i;
    });
    _holdTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _hold = false);
    });
  }

  void _answer(int i) {
    ref.read(wasteQuizProvider.notifier).selectOption(i);
    _holdTimer?.cancel();
    setState(() => _hold = true);
    _holdTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _hold = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WasteQuizUiState>(wasteQuizProvider, (prev, next) {
      final fresh =
          next.phase == WasteQuizPhase.idle ||
          next.phase == WasteQuizPhase.identifying;
      if (fresh) _essayKeys.clear();
      if (fresh) _binPicked = null;
      if (fresh && (_started || _hold)) {
        _holdTimer?.cancel();
        setState(() => _started = _hold = false);
      }
    });
    final s = ref.watch(wasteQuizProvider);
    if (s.phase == WasteQuizPhase.idle || (widget.robot && s.minimized)) {
      _open = false;
      return const SizedBox.shrink();
    }
    // First frame after being hidden: the scan-start reveal plays.
    if (!_open) _opens++;
    _open = true;
    final p = context.elio;
    final n = ref.read(wasteQuizProvider.notifier);
    final robot = widget.robot;
    // Robot: the quiz waits behind the Quiz button while the student drives.
    final close = robot ? n.minimize : n.dismiss;
    // Phone: closing a question or its review would throw the quiz away.
    final quizClose = robot ? n.minimize : _confirmLeave;
    void rescan() {
      if (robot) {
        n.logRescanTapped();
        widget.onRescan?.call();
      }
      n.dismiss();
    }

    final q = s.question;
    final mc = q != null && q.type == QuizQuestionType.multipleChoice;
    final loading = s.phase == WasteQuizPhase.loadingQuestion;
    final active = s.phase == WasteQuizPhase.active;
    // Robot: one bin check before the quiz, then its result ticket on the
    // identified page until "Got it" (Figma 860:28986, 860:29035, 861:29181).
    final binStage =
        robot &&
        s.binAnswer != null &&
        !_started &&
        s.questionIndex == 0 &&
        (loading || active || s.phase == WasteQuizPhase.confirmingHazard);
    final binAsk =
        binStage &&
        (s.binPick == null || (_hold && _binPicked != null && !s.binAcked));
    final binResult = binStage && !binAsk && !s.binAcked;
    final (String kind, Widget page) = switch (s.phase) {
      _ when s.notice != null => (
        'failed',
        _ScanFailedPage(notice: s.notice!, onRetake: rescan),
      ),
      WasteQuizPhase.identifying => (
        'identified',
        _IdentifiedPage(
          state: s,
          onClose: close,
          onRetake: rescan,
          onStart: null,
        ),
      ),
      _ when binAsk => (
        'bincheck',
        _ScanQuestionPage(
          state: s.copyWith(
            phase: WasteQuizPhase.active,
            question: GeneratedQuestion(
              type: QuizQuestionType.multipleChoice,
              question: l10n.binCheckQuestion,
              options: [l10n.binOrganik, l10n.binAnorganik, l10n.binB3],
              correctIndex: _bins.indexOf(s.binAnswer!),
            ),
            selectedOption: s.binPick == null ? null : _binPicked,
          ),
          onClose: close,
          onAnswer: _answerBin,
          onBinSkip: n.skipBinCheck,
        ),
      ),
      _ when binResult => (
        'identified',
        _IdentifiedPage(
          state: s,
          onClose: close,
          onRetake: rescan,
          onStart: null,
          onGotIt: n.ackBinCheck,
        ),
      ),
      _ when (loading || active) && !_started && s.questionIndex == 0 => (
        'identified',
        _IdentifiedPage(
          state: s,
          onClose: close,
          onRetake: rescan,
          onStart: active ? () => setState(() => _started = true) : null,
        ),
      ),
      _
          when loading ||
              (q != null && !mc && active) ||
              (mc &&
                  (active ||
                      (_hold && s.phase == WasteQuizPhase.explaining))) =>
        (
          'question-${s.questionIndex}',
          _ScanQuestionPage(state: s, onClose: quizClose, onAnswer: _answer),
        ),
      // Hazardous (B3) item: the identified page with a caution note; the
      // quiz starts straight from its ticket (851:28659, 852:28687).
      WasteQuizPhase.confirmingHazard => (
        'identified',
        _IdentifiedPage(
          state: s,
          hazard: true,
          onClose: close,
          onRetake: rescan,
          onStart: () {
            n.confirmHazard();
            setState(() => _started = true);
          },
        ),
      ),
      WasteQuizPhase.finished => (
        'done',
        _ScanDonePage(state: s, onClose: n.dismiss, onRescan: rescan),
      ),
      WasteQuizPhase.explaining when q != null => (
        'review-${s.questionIndex}',
        _ScanReviewPage(state: s, onClose: quizClose),
      ),
      _ => (
        'popup-${s.phase.name}',
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: _QuizBody(
              state: s,
              onStop: widget.onStop,
              onRescan: widget.onRescan,
            ),
          ),
        ),
      ),
    };
    // The camera controls under the page stay out of the screen reader.
    final pages = Material(
      color: p.background,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _Robot(
          robot: robot,
          onStop: robot ? widget.onStop : null,
          onRescan: robot ? widget.onRescan : null,
          child: AnimatedSwitcher(
            duration: ElioMotion.reduced(context)
                ? Duration.zero
                : ElioMotion.base,
            switchInCurve: ElioMotion.emphasized,
            switchOutCurve: ElioMotion.exit,
            // Pages fill the screen from the top (the default centres them).
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, children: [...previous, ?current]),
            child: KeyedSubtree(
              key: ValueKey(kind),
              child: robot ? _ScanStart(child: page) : page,
            ),
          ),
        ),
      ),
    );
    final inQuiz = kind.startsWith('question-') || kind.startsWith('review-');
    return PopScope(
      canPop: !inQuiz,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: BlockSemantics(
        child: robot
            ? _ScanStart(key: ValueKey(_opens), grow: true, child: pages)
            : pages,
      ),
    );
  }
}

/// Scan-start animation of the robot pages (MaixCAM2 viewfinder): every page
/// (identified, question, essay, review, result) arrives under a green scan
/// line and the camera's corner brackets; when the pages [open] from the
/// control screen they also grow out of the 4:3 camera frame in the middle.
class _ScanStart extends StatefulWidget {
  const _ScanStart({super.key, this.grow = false, required this.child});

  /// Grow out of the camera frame (pages opening) instead of the scan line.
  final bool grow;
  final Widget child;

  @override
  State<_ScanStart> createState() => _ScanStartState();
}

class _ScanStartState extends State<_ScanStart>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.grow ? 420 : 560),
  );
  late final bool _grow = widget.grow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ElioMotion.reduced(context)) {
        _c.value = 1;
        return;
      }
      if (_grow) quizFeedback(ElioSfx.blip, ElioHaptics.light);
      _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.elio.primary;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      // The tree keeps one shape before and after: swapping the wrapper
      // away would rebuild the page under it and lose its state.
      builder: (context, child) {
        final done = _c.isCompleted;
        final t = _c.value;
        return _grow
            ? ClipPath(
                clipper: done
                    ? null
                    : _FrameClip(ElioMotion.emphasized.transform(t)),
                child: child,
              )
            : CustomPaint(
                foregroundPainter: done ? null : _ScanStartPainter(t, color),
                child: child,
              );
      },
    );
  }
}

/// The MaixCAM2 frame (4:3, 45 % of the height) in the middle of [size],
/// grown by [t] to the whole page.
RRect _cameraFrame(Size size, double t) {
  final h = size.height * 0.45, w = h * 4 / 3;
  final from = Rect.fromCenter(
    center: size.center(Offset.zero),
    width: w,
    height: h,
  );
  return RRect.fromRectAndRadius(
    Rect.lerp(from, Offset.zero & size, t)!,
    Radius.circular(24 * (1 - t)),
  );
}

class _FrameClip extends CustomClipper<Path> {
  _FrameClip(this.t);
  final double t;

  @override
  Path getClip(Size size) => Path()..addRRect(_cameraFrame(size, t));

  @override
  bool shouldReclip(_FrameClip old) => old.t != t;
}

class _ScanStartPainter extends CustomPainter {
  _ScanStartPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - t).clamp(0.0, 1.0);
    // Scan line: top to bottom, with a soft trail above it.
    final y = size.height * Curves.easeInOut.transform(t);
    canvas.drawRect(
      Rect.fromLTRB(0, y - 60, size.width, y),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.28 * fade),
          ],
        ).createShader(Rect.fromLTRB(0, y - 60, size.width, y)),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, y - 1.5, size.width, y + 1.5),
      Paint()..color = color.withValues(alpha: fade),
    );
    // Viewfinder brackets on the growing camera frame.
    final f = _cameraFrame(
      size,
      ElioMotion.emphasized.transform(t),
    ).outerRect.deflate(10);
    const len = 28.0;
    final pen = Paint()
      ..color = color.withValues(alpha: fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final (x, y, sx, sy) in [
      (f.left, f.top, 1.0, 1.0),
      (f.right, f.top, -1.0, 1.0),
      (f.left, f.bottom, 1.0, -1.0),
      (f.right, f.bottom, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + sy * len)
          ..lineTo(x, y)
          ..lineTo(x + sx * len, y),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_ScanStartPainter old) => old.t != t || old.color != color;
}

/// Round close / back button of the scan pages: 44 dp, surface, subtle edge.
class _RoundClose extends StatelessWidget {
  const _RoundClose({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ElioPress(
      pressed: 0.94,
      child: IconButton(
        key: const ValueKey('scan_page_close'),
        tooltip: l10n.commonClose,
        onPressed: () {
          quizFeedback(ElioSfx.tick, ElioHaptics.light);
          onTap();
        },
        style: IconButton.styleFrom(
          backgroundColor: p.surface,
          fixedSize: const Size.square(44),
          minimumSize: const Size.square(44),
          padding: EdgeInsets.zero,
          side: BorderSide(color: p.borderSubtle),
        ),
        icon: Icon(Icons.close_rounded, size: 22, color: p.textPrimary),
      ),
    );
  }
}

String _binAsset(ScanCategory c) => switch (c) {
  ScanCategory.b3 => 'bin_b3',
  ScanCategory.organic => 'bin_organik',
  _ => 'bin_anorganik',
};

/// The scanned photo, or the raised placeholder while there is none.
Widget _scanPhoto(BuildContext context, Uint8List? bytes) => bytes == null
    ? ColoredBox(color: context.elio.surfaceRaised)
    : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);

// ── Identified (629:90773) ──────────────────────────────────────────────────

class _IdentifiedPage extends StatefulWidget {
  const _IdentifiedPage({
    required this.state,
    required this.onClose,
    required this.onRetake,
    required this.onStart,
    this.hazard = false,
    this.onGotIt,
  });
  final WasteQuizUiState state;
  final VoidCallback onClose;
  final VoidCallback onRetake;

  /// Null until the first question is ready.
  final VoidCallback? onStart;

  /// Hazardous (B3) item waiting for "Continue quiz" (851:28659).
  final bool hazard;

  /// Set while the bin check result ticket shows instead of the quiz ticket.
  final VoidCallback? onGotIt;

  @override
  State<_IdentifiedPage> createState() => _IdentifiedPageState();
}

class _IdentifiedPageState extends State<_IdentifiedPage> {
  bool get _known => widget.state.phase != WasteQuizPhase.identifying;

  @override
  void initState() {
    super.initState();
    if (_known) _cue();
  }

  @override
  void didUpdateWidget(_IdentifiedPage old) {
    super.didUpdateWidget(old);
    if (_known && old.state.phase == WasteQuizPhase.identifying) _cue();
    if (widget.onStart != null &&
        old.onStart == null &&
        !widget.hazard &&
        widget.onGotIt == null) {
      quizFeedback(ElioSfx.tick, ElioHaptics.select);
    }
  }

  // Figma 13 · 27: S2 when the buddy pops, H-light when the result shows.
  void _cue() => quizFeedback(ElioSfx.pop, ElioHaptics.light);

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final s = widget.state;
    final category = ScanCategory.fromString(s.scan?.category?.id);
    final reduced = ElioMotion.reduced(context);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > size.height;
    // Hazard, landscape: the voice / minimise actions sit top right of the
    // screen (852:28649), so the item name stays clear of them.
    final cornerActions = widget.hazard && wide;
    final titleInset = cornerActions ? 170.0 : 0.0;

    // Polaroid drops in: y −40 → 0, −8° → 3° (spring/pop, 420 ms).
    final polaroid = TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: ElioMotion.pop,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -40 * (1 - v)),
          child: Transform.rotate(
            angle: (-8 + 11 * v) * math.pi / 180,
            child: child,
          ),
        ),
      ),
      child: Container(
        width: 262,
        height: 250,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x29000000),
              offset: Offset(0, 6),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 238,
                height: 190,
                child: _scanPhoto(context, s.cropBytes),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                !_isRobot(context)
                    ? l10n.scanJustNowPhone
                    : l10n.scanJustNowRobot,
                style: _sq(ElioTokens.caption, 500, p.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );

    final photo = SizedBox(
      width: 358,
      height: 280,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 41, top: 8, child: polaroid),
          if (_known)
            Positioned(
              left: 264,
              top: 182,
              // The bin buddy of the item's waste type pops from behind the
              // photo (0.6 → 1, spring/bounce, delay 200).
              child: ElioPopIn(
                key: ValueKey('buddy-${category.name}'),
                rise: 0,
                scale: 0.6,
                curve: ElioMotion.bounce,
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 200),
                child: homeArt(_binAsset(category), width: 76.8, height: 91.2),
              ),
            ),
        ],
      ),
    );

    final tint = historyTint(p, switch (category) {
      ScanCategory.b3 => HistoryTone.error,
      ScanCategory.organic => HistoryTone.success,
      ScanCategory.recyclable => HistoryTone.info,
      _ => HistoryTone.neutral,
    });
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(h / 2),
      ),
    );
    final result = !_known
        ? ElioShimmer(
            child: Column(
              key: const ValueKey('scan_identifying'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.scanIdentifying.toUpperCase(),
                  style: _sq(
                    ElioTokens.overline,
                    600,
                    p.primaryText,
                  ).copyWith(letterSpacing: 1.1),
                ),
                const SizedBox(height: 14),
                bar(220, 36),
                const SizedBox(height: 14),
                bar(190, 44),
              ],
            ),
          )
        : ElioPopIn(
            key: const ValueKey('scan_identified'),
            rise: 8,
            scale: 1,
            duration: ElioMotion.base,
            delay: const Duration(milliseconds: 260),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (widget.hazard
                          ? l10n.scanHazardOverline
                          : l10n.scanIdentified)
                      .toUpperCase(),
                  style: _sq(
                    ElioTokens.overline,
                    600,
                    widget.hazard ? p.errorText : p.primaryText,
                  ).copyWith(letterSpacing: 1.1),
                ),
                const SizedBox(height: 10),
                Semantics(
                  header: true,
                  child: Padding(
                    padding: EdgeInsets.only(right: titleInset),
                    child: Text(
                      s.scan?.displayName ?? l10n.wasteGeneric,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _sq(ElioTokens.display, 700, p.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                      decoration: ShapeDecoration(
                        color: tint.bg,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: tint.border ?? p.borderSubtle,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: p.surface,
                              shape: BoxShape.circle,
                            ),
                            child: homeArt(_binAsset(category)),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              switch (category) {
                                ScanCategory.b3 => l10n.scanBinB3,
                                ScanCategory.organic => l10n.scanBinOrganic,
                                ScanCategory.recyclable =>
                                  l10n.scanBinRecyclable,
                                _ => l10n.scanBinResidu,
                              },
                              style: _sq(
                                ElioTokens.bodySmall,
                                600,
                                tint.fg,
                              ).copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Caution note (852:28634): error tint, warning icon.
                    if (widget.hazard)
                      Container(
                        key: const ValueKey('scan_hazard_note'),
                        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                        decoration: BoxDecoration(
                          color: tint.bg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              size: 22,
                              color: p.error,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.scanHazardNote,
                                style: _sq(
                                  ElioTokens.bodySmall,
                                  400,
                                  p.textSecondary,
                                ).copyWith(height: 20 / 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // _InfoChip is flexible: it needs a Row around it.
                    // After a bin check the item is settled (its XP was given).
                    if (s.canCorrectItem && !widget.hazard && s.binPick == null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ?_notThisChip(
                            context,
                            s,
                            ProviderScope.containerOf(
                              context,
                            ).read(wasteQuizProvider.notifier),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          );

    final ticket = !_known
        ? const SizedBox(height: 150)
        : ElioPopIn(
            key: const ValueKey('scan_ticket'),
            rise: 40,
            scale: 1,
            delay: const Duration(milliseconds: 320),
            // "Got it" flips the result ticket to the quiz ticket in place.
            child: AnimatedSwitcher(
              duration: reduced ? Duration.zero : ElioMotion.base,
              switchInCurve: ElioMotion.emphasized,
              switchOutCurve: ElioMotion.exit,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: AnimatedBuilder(
                  animation: a,
                  builder: (context, c) => Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX((1 - a.value) * math.pi / 2),
                    child: c,
                  ),
                  child: child,
                ),
              ),
              child: SizedBox(
                key: ValueKey(widget.onGotIt != null),
                width: double.infinity,
                child: widget.onGotIt != null
                    ? _BinTicket(state: s, onGotIt: widget.onGotIt!)
                    : _QuizTicket(
                        state: s,
                        onRetake: widget.onRetake,
                        onStart: widget.onStart,
                        hazard: widget.hazard,
                      ),
              ),
            ),
          );

    final header = Row(
      children: [
        _RoundClose(onTap: widget.onClose),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            !_isRobot(context) ? l10n.scanResultTitle : l10n.scanRobotTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _sq(ElioTokens.subhead, 700, p.textPrimary),
          ),
        ),
        ..._stopPill(context),
        if (widget.hazard && !cornerActions) const _HazardActions(),
      ],
    );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth > box.maxHeight) {
            // Landscape (659:25791): photo left, result and ticket right.
            final page = Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 9,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        header,
                        Expanded(
                          child: FittedBox(fit: BoxFit.scaleDown, child: photo),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 10,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 16, right: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [result, const SizedBox(height: 18), ticket],
                      ),
                    ),
                  ),
                ],
              ),
            );
            return cornerActions
                ? Stack(
                    children: [
                      page,
                      const Positioned(
                        top: 8,
                        right: 16,
                        child: _HazardActions(),
                      ),
                    ],
                  )
                : page;
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 12),
                Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: photo),
                ),
                const SizedBox(height: 8),
                result,
                const SizedBox(height: 24),
                ticket,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Top-right actions of the hazard page (852:28649): the quiz voice switch,
/// and on the robot the minimise button, as the popup's header had.
class _HazardActions extends ConsumerWidget {
  const _HazardActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final voiceOn = ref.watch(wasteQuizProvider.select((s) => s.voiceOn));
    final n = ref.read(wasteQuizProvider.notifier);
    void toggle() {
      quizFeedback(ElioSfx.tick, ElioHaptics.select);
      n.toggleVoice();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          toggled: voiceOn,
          label: l10n.ctlVoice,
          excludeSemantics: true,
          onTap: toggle,
          child: GestureDetector(
            key: const ValueKey('quiz_voice'),
            onTap: toggle,
            child: Container(
              height: 44,
              padding: const EdgeInsets.fromLTRB(12, 5, 5, 5),
              decoration: ShapeDecoration(
                color: p.surface,
                shape: StadiumBorder(side: BorderSide(color: p.borderSubtle)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.volume_up_outlined,
                    size: 20,
                    color: p.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  _MiniSwitch(on: voiceOn),
                ],
              ),
            ),
          ),
        ),
        if (_isRobot(context)) ...[
          const SizedBox(width: 10),
          ElioPress(
            pressed: 0.94,
            child: IconButton(
              key: const ValueKey('quiz_minimise'),
              tooltip: l10n.qzMinimiseQuiz,
              onPressed: () {
                quizFeedback(ElioSfx.tick, ElioHaptics.light);
                n.minimize();
              },
              style: IconButton.styleFrom(
                backgroundColor: p.surface,
                fixedSize: const Size.square(44),
                minimumSize: const Size.square(44),
                padding: EdgeInsets.zero,
                side: BorderSide(color: p.borderSubtle),
              ),
              icon: Icon(Icons.remove_rounded, size: 22, color: p.textPrimary),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bin check result on the identified page (860:29035 wrong, 861:29181
/// right): the picked bin buddy with a ✗ or ✓, why the item belongs in its
/// bin, the XP chip, "Your quiz is next" and Got it.
class _BinTicket extends StatelessWidget {
  const _BinTicket({required this.state, required this.onGotIt});
  final WasteQuizUiState state;
  final VoidCallback onGotIt;

  static String _short(ScanCategory c) => switch (c) {
    ScanCategory.organic => 'Organik',
    ScanCategory.b3 => 'B3',
    _ => 'Anorganik',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final right = state.binRight;
    final correct = state.binAnswer!;
    final picked = ScanCategory.values.asNameMap()[state.binPick] ?? correct;
    final item = state.scan?.displayName ?? l10n.wasteGeneric;
    final tone = historyTint(
      p,
      right ? HistoryTone.success : HistoryTone.error,
    );
    final chip = historyTint(
      p,
      right ? HistoryTone.success : HistoryTone.neutral,
    );
    Widget notch(bool left) => Positioned(
      left: left ? -13 : null,
      right: left ? null : -13,
      top: 0,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: p.background,
          shape: BoxShape.circle,
          border: Border.all(color: p.borderSubtle),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          key: const ValueKey('bin_ticket'),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The picked bin buddy, marked right or wrong.
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 48,
                        height: 52,
                        child: Stack(
                          children: [
                            homeArt(_binAsset(picked), width: 40, height: 48),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: ElioPopIn(
                                rise: 0,
                                scale: 0.4,
                                curve: ElioMotion.pop,
                                delay: const Duration(milliseconds: 200),
                                child: Container(
                                  key: ValueKey(
                                    right ? 'bin_mark_right' : 'bin_mark_wrong',
                                  ),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: right ? p.primaryActive : p.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: p.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    right
                                        ? Icons.check_rounded
                                        : Icons.close_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            right
                                ? l10n.binNice(_short(correct))
                                : l10n.binOops(_short(picked)),
                            style: _sq(ElioTokens.body, 700, tone.fg),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            switch (correct) {
                              ScanCategory.organic => l10n.binWhyOrganic(item),
                              ScanCategory.b3 => l10n.binWhyB3(item),
                              _ => l10n.binWhyAnorganik(item),
                            },
                            style: ElioTokens.bodySmall.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      key: const ValueKey('bin_xp_chip'),
                      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                      decoration: ShapeDecoration(
                        color: chip.bg,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: chip.border ?? p.borderSubtle,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: right ? 1 : 0.45,
                            child: SvgPicture.asset(
                              'assets/illustrations/history/icon_xp.svg',
                              width: 18,
                              height: 18,
                              excludeFromSemantics: true,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.trophiesEarned(state.binCheckXp),
                            style: _sq(
                              ElioTokens.bodySmall,
                              700,
                              right ? chip.fg : p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 24,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    notch(true),
                    notch(false),
                    Positioned(
                      left: 18,
                      right: 18,
                      top: 11,
                      child: CustomPaint(
                        size: const Size.fromHeight(2),
                        painter: _DashLine(p.borderMedium),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.binQuizNext,
                        style: _sq(ElioTokens.bodySmall, 500, p.textSecondary),
                      ),
                    ),
                    ElioPress(
                      pressed: 0.96,
                      child: FilledButton(
                        key: const ValueKey('bin_got_it'),
                        onPressed: () {
                          // The ticket flips: a tick.
                          quizFeedback(ElioSfx.tick, ElioHaptics.select);
                          onGotIt();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: p.primary,
                          foregroundColor: p.onPrimary,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: const StadiumBorder(),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.binGotIt,
                              style: _sq(ElioTokens.button, 600, p.onPrimary),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Your quiz is ready" ticket (629:90795): notched sides, dashed tear line,
/// Retake and Start quiz.
class _QuizTicket extends ConsumerWidget {
  const _QuizTicket({
    required this.state,
    required this.onRetake,
    required this.onStart,
    this.hazard = false,
  });
  final WasteQuizUiState state;
  final VoidCallback onRetake;
  final VoidCallback? onStart;

  /// "Keep learning about this item?" with Scan again / Continue quiz.
  final bool hazard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final ready = onStart != null;
    final seconds = int.tryParse(
      ref.watch(appPreferencesProvider).quizTimer.replaceAll('s', ''),
    );
    final ai = state.questionSource == QuestionSource.ai;
    Widget notch(bool left) => Positioned(
      left: left ? -13 : null,
      right: left ? null : -13,
      top: 77,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: p.background,
          shape: BoxShape.circle,
          border: Border.all(color: p.borderSubtle),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          key: const ValueKey('scan_quiz_ticket'),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.borderSubtle),
          ),
          child: Stack(
            children: [
              notch(true),
              notch(false),
              Positioned(
                left: 18,
                right: 18,
                top: 88,
                child: CustomPaint(
                  size: const Size.fromHeight(2),
                  painter: _DashLine(p.borderMedium),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 60,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Paper wiggles once when the quiz turns ready.
                          ElioJump(
                            trigger: ready ? 1 : null,
                            height: 6,
                            child: SvgPicture.asset(
                              'assets/illustrations/learn/quiz_paper.svg',
                              width: 48,
                              height: 48,
                              excludeFromSemantics: true,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hazard
                                      ? l10n.scanHazardKeepLearning
                                      : ready
                                      ? l10n.scanQuizReady
                                      : l10n.scanQuizWriting,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _sq(
                                    ElioTokens.body,
                                    700,
                                    p.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        [
                                          l10n.scanQuizQuestions(
                                            state.totalQuestions,
                                          ),
                                          _level(state.difficulty),
                                          if (seconds != null) '$seconds s',
                                        ].join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _sq(
                                          ElioTokens.caption,
                                          500,
                                          p.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: EdgeInsets.fromLTRB(
                                        ai ? 2 : 8,
                                        2,
                                        8,
                                        2,
                                      ),
                                      decoration: ShapeDecoration(
                                        color: p.textPrimary,
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (ai) ...[
                                            const EliosAiBadge(size: 16),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            ai ? 'AI' : l10n.testerBank,
                                            style: _sq(
                                              ElioTokens.caption,
                                              700,
                                              p.background,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElioPress(
                          pressed: 0.96,
                          child: TextButton.icon(
                            key: const ValueKey('scan_retake'),
                            onPressed: () {
                              quizFeedback(ElioSfx.pop, ElioHaptics.light);
                              onRetake();
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: p.surfaceRaised,
                              foregroundColor: p.textPrimary,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              !_isRobot(context) && !hazard
                                  ? l10n.scanRetake
                                  : l10n.scanAgain,
                              style: _sq(ElioTokens.button, 600, p.textPrimary),
                            ),
                          ),
                        ),
                        ElioPress(
                          pressed: 0.96,
                          child: FilledButton(
                            key: const ValueKey('scan_start_quiz'),
                            onPressed: ready
                                ? () {
                                    quizFeedback(
                                      ElioSfx.pop,
                                      ElioHaptics.medium,
                                    );
                                    onStart!();
                                  }
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: p.primary,
                              foregroundColor: p.onPrimary,
                              disabledBackgroundColor: p.surfaceRaised,
                              disabledForegroundColor: p.textSecondary,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hazard
                                      ? l10n.qzContinueQuiz
                                      : l10n.scanStartQuiz,
                                  style: _sq(
                                    ElioTokens.button,
                                    600,
                                    ready ? p.onPrimary : p.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ready
                                    ? const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                      )
                                    : SizedBox.square(
                                        dimension: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: p.textSecondary,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashLine extends CustomPainter {
  _DashLine(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, 1),
        Offset(math.min(x + 5, size.width), 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashLine old) => old.color != color;
}

// ── Scan did not work ───────────────────────────────────────────────────────

class _ScanFailedPage extends StatelessWidget {
  const _ScanFailedPage({required this.notice, required this.onRetake});
  final String notice;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _RoundClose(onTap: onRetake),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    !_isRobot(context)
                        ? l10n.scanResultTitle
                        : l10n.scanRobotTitle,
                    style: _sq(ElioTokens.subhead, 700, p.textPrimary),
                  ),
                ),
                ..._stopPill(context),
              ],
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: ElioPopIn(
                    child: Column(
                      children: [
                        // The buddy shakes its head: nothing recognised.
                        ElioAfterFirstFrame(
                          builder: (context, ready) => ElioShake(
                            trigger: ready ? notice : null,
                            distance: 4,
                            child: SvgPicture.asset(
                              'assets/illustrations/control/bottle_buddy_sad.svg',
                              height: 96,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.scanFailed,
                          textAlign: TextAlign.center,
                          style: _sq(ElioTokens.headline, 700, p.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notice,
                          textAlign: TextAlign.center,
                          style: _sq(
                            ElioTokens.bodySmall,
                            400,
                            p.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElioPress(
                          pressed: 0.96,
                          child: FilledButton.icon(
                            key: const Key('result_card_close_button'),
                            onPressed: () {
                              quizFeedback(ElioSfx.pop, ElioHaptics.light);
                              onRetake();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: p.primary,
                              foregroundColor: p.onPrimary,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              !_isRobot(context)
                                  ? l10n.scanRetake
                                  : l10n.scanAgain,
                              style: _sq(ElioTokens.button, 600, p.onPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Question (629:90816) ────────────────────────────────────────────────────

class _ScanQuestionPage extends ConsumerWidget {
  const _ScanQuestionPage({
    required this.state,
    required this.onClose,
    required this.onAnswer,
    this.onBinSkip,
  });
  final WasteQuizUiState state;
  final VoidCallback onClose;
  final ValueChanged<int> onAnswer;

  /// Set for the robot bin check (860:28986): a chip instead of the progress
  /// dashes, three full-width bars, skip and time-up end the check.
  final VoidCallback? onBinSkip;
  bool get _bin => onBinSkip != null;

  // Figma order: red triangle, blue diamond, yellow circle, green square.
  static const _fills = [
    ElioTokens.answerRed,
    ElioTokens.answerBlue,
    ElioTokens.answerYellow,
    ElioTokens.answerGreen,
  ];
  static const _onFills = [
    ElioTokens.onAnswerRed,
    ElioTokens.onAnswerBlue,
    ElioTokens.onAnswerYellow,
    ElioTokens.onAnswerGreen,
  ];
  static const _shapes = [
    Icons.change_history_rounded,
    Icons.diamond_rounded,
    Icons.circle,
    Icons.stop_rounded,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final n = ref.read(wasteQuizProvider.notifier);
    final prefs = ref.watch(appPreferencesProvider);
    final q = state.phase == WasteQuizPhase.loadingQuestion
        ? null
        : state.question;
    final picked = state.selectedOption;
    final seconds = int.tryParse(prefs.quizTimer.replaceAll('s', ''));
    final essay = q?.type == QuizQuestionType.essay;

    final header = Row(
      children: [
        _RoundClose(onTap: onClose),
        const SizedBox(width: 12),
        if (_bin)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                key: const ValueKey('bin_check_chip'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: ShapeDecoration(
                  color: historyTint(p, HistoryTone.success).bg,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color:
                          historyTint(p, HistoryTone.success).border ??
                          p.borderSubtle,
                    ),
                  ),
                ),
                child: Text(
                  l10n.binCheckChip,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _sq(
                    ElioTokens.caption,
                    600,
                    p.primaryText,
                  ).copyWith(fontSize: 13),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: Semantics(
              label: l10n.qzQuestionOf(
                state.questionIndex + 1,
                state.totalQuestions,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < state.totalQuestions; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 68),
                        // The dash of the current question fills (300 ms).
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: ElioMotion.standard,
                          height: 10,
                          decoration: BoxDecoration(
                            color: i <= state.questionIndex
                                ? p.primary
                                : p.surfaceRaised,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(width: 12),
        ..._stopPill(context),
        if (seconds != null && q != null && picked == null)
          QuizCountdown(
            key: ValueKey(
              _bin ? 'quiz_timer_bin' : 'quiz_timer_${state.questionIndex}',
            ),
            seconds: seconds,
            onTimeUp: onBinSkip ?? n.timeUp,
            chip: true,
          ),
      ],
    );

    final card = Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            key: const ValueKey('scan_question_card'),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 191),
            padding: const EdgeInsets.fromLTRB(18, 60, 18, 22),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.all(color: p.borderSubtle),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(36),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(36),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: q == null
                ? ElioShimmer(
                    child: Column(
                      key: const ValueKey('scan_question_loading'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final w in const [150.0, 300.0, 260.0, 180.0]) ...[
                          Container(
                            width: w,
                            height: w == 150 ? 12 : 20,
                            decoration: BoxDecoration(
                              color: p.surfaceRaised,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _bin
                            ? l10n.binCheckOverline(
                                (state.scan?.displayName ?? '').toUpperCase(),
                              )
                            : l10n.qzQuestionOfCaps(
                                state.questionIndex + 1,
                                state.totalQuestions,
                                '${essay ? '${l10n.scanEssay.toUpperCase()} · ' : ''}'
                                '${(state.scan?.displayName ?? '').toUpperCase()}',
                              ),
                        style: _sq(
                          ElioTokens.overline,
                          600,
                          p.primaryText,
                        ).copyWith(letterSpacing: 1.1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        q.question,
                        style: _sq(ElioTokens.subhead, 700, p.textPrimary),
                      ),
                    ],
                  ),
          ),
          // The scanned item, tilted 6°, pops onto the card's corner.
          Positioned(
            left: 15,
            top: -16,
            child: ElioPopIn(
              rise: 0,
              scale: 0.6,
              curve: ElioMotion.pop,
              child: Transform.rotate(
                angle: 6 * math.pi / 180,
                child: Container(
                  width: 64,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        offset: Offset(0, 3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: _scanPhoto(context, state.cropBytes),
                ),
              ),
            ),
          ),
          if (q != null)
            Positioned(
              right: 6,
              top: 6,
              child: IconButton(
                key: const ValueKey('quiz_read'),
                tooltip: l10n.qzReadToMe,
                onPressed: () => n.listen(
                  '${q.question} ${[for (var i = 0; i < q.options.length; i++) '${'ABCD'[i % 4]}. ${q.options[i]}'].join('. ')}',
                ),
                icon: Icon(
                  Icons.volume_up_outlined,
                  size: 20,
                  color: p.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );

    final count = q == null ? 4 : q.options.length.clamp(0, 4);
    Widget tile(int i) {
      if (q == null) {
        return Expanded(
          child: ElioShimmer(
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      }
      final right = i == q.correctIndex;
      final chosen = picked == i;
      final wrongPick = chosen && !right;
      Widget t = Semantics(
        button: true,
        label: q.options[i],
        excludeSemantics: true,
        child: Container(
          key: ValueKey('answer_$i'),
          constraints: const BoxConstraints(minHeight: 64),
          foregroundDecoration: wrongPick
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.error, width: 3),
                )
              : null,
          decoration: BoxDecoration(
            color: _fills[i],
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), offset: Offset(0, 3)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: picked == null ? () => onAnswer(i) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(_shapes[i], color: _onFills[i], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q.options[i],
                        style: _sq(
                          ElioTokens.bodySmall,
                          600,
                          _onFills[i],
                        ).copyWith(height: 1.35),
                      ),
                    ),
                    // Correct pick: a check badge pops on it.
                    if (chosen && right)
                      ElioPopIn(
                        rise: 0,
                        scale: 0.4,
                        curve: ElioMotion.pop,
                        child: Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: _fills[i],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (picked != null) {
        final wrong = picked != q.correctIndex;
        // Wrong: the right answer pulses once (1.04).
        if (wrong && right && !ElioMotion.reduced(context)) {
          t = TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            builder: (context, v, child) => Transform.scale(
              scale: 1 + 0.04 * math.sin(v * math.pi),
              child: child,
            ),
            child: t,
          );
        }
        // Correct: the other answers fade to 40 %.
        if (!wrong && !chosen) {
          t = TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0.4),
            duration: ElioMotion.base,
            builder: (context, v, child) => Opacity(opacity: v, child: child),
            child: t,
          );
        }
      }
      // Wrong pick shakes x ±6 × 3; the shake stays mounted so it sees the pick.
      t = ElioShake(
        trigger: wrongPick ? picked : null,
        child: ElioPress(pressed: picked == null ? 0.96 : 1, child: t),
      );
      return Expanded(
        child: ElioPopIn(
          key: ValueKey('answer-in-${state.questionIndex}-$i'),
          index: i,
          child: t,
        ),
      );
    }

    final skip = q != null && prefs.skipAllowed && picked == null;
    final answers = essay
        ? _EssayAnswer(
            key: _essayKeys.putIfAbsent(state.questionIndex, GlobalKey.new),
            state: state,
            skip: skip && !state.essaySubmitted,
          )
        : _bin
        // Bin check: three full-width bars (red, blue, yellow).
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < count; r++) ...[
                if (r > 0) const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [tile(r)],
                    ),
                  ),
                ),
              ],
              if (skip) ...[
                const SizedBox(height: 12),
                _SkipButton(onSkip: onBinSkip),
              ],
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < count; r += 2) ...[
                if (r > 0) const SizedBox(height: 14),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      tile(r),
                      const SizedBox(width: 16),
                      if (r + 1 < count) tile(r + 1) else const Spacer(),
                    ],
                  ),
                ),
              ],
              if (skip) ...[const SizedBox(height: 12), const _SkipButton()],
            ],
          );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          // Keyboard open on a short screen: the question in one line and
          // the answer field, nothing else to scroll past.
          if (essay && box.maxHeight < 250) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (box.maxHeight > 120)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        q!.question,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _sq(ElioTokens.bodySmall, 600, p.textPrimary),
                      ),
                    ),
                  Expanded(
                    child: _EssayAnswer(
                      key: _essayKeys.putIfAbsent(
                        state.questionIndex,
                        GlobalKey.new,
                      ),
                      state: state,
                      skip: false,
                      compact: true,
                    ),
                  ),
                ],
              ),
            );
          }
          if (box.maxWidth > box.maxHeight) {
            // Landscape (659:25857): question left, answers right.
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  header,
                  const SizedBox(height: 6),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 9,
                          child: SingleChildScrollView(child: card),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 11,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 20, bottom: 6),
                            child: answers,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              children: [
                header,
                const SizedBox(height: 14),
                card,
                const SizedBox(height: 24),
                answers,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SkipButton extends ConsumerWidget {
  const _SkipButton({this.onSkip});

  /// The bin check's own skip; null skips the quiz question.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    return TextButton(
      key: const ValueKey('quiz_skip'),
      onPressed: () {
        quizFeedback(ElioSfx.tick, ElioHaptics.light);
        (onSkip ?? ref.read(wasteQuizProvider.notifier).skipQuestion)();
      },
      style: TextButton.styleFrom(
        foregroundColor: p.textSecondary,
        minimumSize: const Size(0, 48),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.scanSkipQuestion,
            style: _sq(ElioTokens.button, 600, p.textSecondary),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 16),
        ],
      ),
    );
  }
}

/// One key per essay question of this scan: the answer keeps its state
/// (text, focus, so the keyboard) when the page moves it between its full
/// and compact layouts.
final _essayKeys = <int, GlobalKey>{};

/// Essay answer (Figma 821:28687): "Your answer" field with the word count,
/// Submit answer, Skip. [compact]: field and Submit side by side (keyboard
/// open on a short screen).
class _EssayAnswer extends ConsumerStatefulWidget {
  const _EssayAnswer({
    super.key,
    required this.state,
    required this.skip,
    this.compact = false,
  });
  final WasteQuizUiState state;
  final bool skip, compact;

  @override
  ConsumerState<_EssayAnswer> createState() => _EssayAnswerState();
}

class _EssayAnswerState extends ConsumerState<_EssayAnswer> {
  static const _limit = _EssayInputView.wordLimit;
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _fieldKey = GlobalKey(debugLabel: 'quiz_essay_field');
  int _over = 0;

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
    _focus.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _words {
    final t = _text.text.trim();
    return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
  }

  void _submit() {
    final s = widget.state;
    if (_words == 0 || s.sendingChat || s.essaySubmitted) return;
    if (_words > _limit) {
      quizFeedback(ElioSfx.knock, ElioHaptics.warning);
      setState(() => _over++);
      return;
    }
    quizFeedback(ElioSfx.pop, ElioHaptics.medium);
    _focus.unfocus();
    ref.read(wasteQuizProvider.notifier).submitEssay(_text.text);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final s = widget.state;
    final grading = s.essaySubmitted && s.sendingChat;
    final words = _words;
    final ready = words > 0 && !s.sendingChat && !s.essaySubmitted;
    final over = words > _limit;

    // Keyed globally: the two layouts hold the field at different depths.
    final field = TextField(
      key: _fieldKey,
      controller: _text,
      focusNode: _focus,
      enabled: !s.essaySubmitted,
      expands: widget.compact,
      minLines: widget.compact ? null : 3,
      maxLines: widget.compact ? null : 5,
      textAlignVertical: TextAlignVertical.top,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.newline,
      style: ElioTokens.bodySmall.copyWith(color: p.textPrimary),
      cursorColor: p.primary,
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintText: l10n.qzTypeAnswer,
        hintStyle: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
      ),
    );

    // The field's edge turns green with focus, red over the word limit.
    final box = ElioShake(
      trigger: _over == 0 ? null : _over,
      child: AnimatedContainer(
        duration: ElioMotion.fast,
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: over
                ? p.error
                : _focus.hasFocus
                ? p.primary
                : p.borderMedium,
            width: _focus.hasFocus || over ? 2 : 1,
          ),
        ),
        child: grading
            ? Row(
                key: const ValueKey('quiz_essay_grading'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EliosAiBadge(size: 28),
                  const SizedBox(width: 10),
                  Flexible(
                    child: ElioShimmer(
                      child: Text(
                        l10n.qzGrading,
                        style: _sq(ElioTokens.bodySmall, 600, p.textPrimary),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: widget.compact
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  if (!widget.compact) ...[
                    Text(
                      l10n.qzYourAnswer,
                      style: _sq(ElioTokens.caption, 500, p.textSecondary),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (widget.compact) Expanded(child: field) else field,
                  const SizedBox(height: 4),
                  Text(
                    l10n.qzWordCount(words, _limit),
                    key: const ValueKey('quiz_essay_words'),
                    style: _sq(
                      ElioTokens.caption,
                      500,
                      over ? p.errorText : p.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );

    final submit = ElioPress(
      pressed: 0.97,
      child: SizedBox(
        height: 52,
        child: FilledButton(
          key: const ValueKey('quiz_essay_submit'),
          onPressed: ready ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: p.primary,
            foregroundColor: p.onPrimary,
            disabledBackgroundColor: p.surfaceRaised,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: Text(
            widget.compact ? l10n.qzSubmit : l10n.scanSubmitAnswer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _sq(
              ElioTokens.subhead,
              600,
              ready ? p.onPrimary : p.textSecondary,
            ),
          ),
        ),
      ),
    );

    if (widget.compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: box),
          const SizedBox(width: 10),
          submit,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElioPopIn(index: 0, child: box),
        const SizedBox(height: 12),
        ElioPopIn(index: 1, child: submit),
        if (widget.skip) ...[
          const SizedBox(height: 4),
          const Center(child: _SkipButton()),
        ],
      ],
    );
  }
}

// ── Answer review + ELIOS AI coach (662:26004, 662:26171) ───────────────────

class _ScanReviewPage extends ConsumerStatefulWidget {
  const _ScanReviewPage({required this.state, required this.onClose});
  final WasteQuizUiState state;
  final VoidCallback onClose;

  @override
  ConsumerState<_ScanReviewPage> createState() => _ScanReviewPageState();
}

class _ScanReviewPageState extends ConsumerState<_ScanReviewPage> {
  final _ask = TextEditingController();

  /// The chat keeps its ask field (focus, so the keyboard) wherever the
  /// page puts it: beside the review, on its own page, or over the keyboard.
  final _chatKey = GlobalKey();
  String? _speaking;
  bool _chat = false;

  /// Essay review: the section being read (question, feedback, correct, steps).
  String? _essayPlaying;

  /// The explanation text last built, to stop its voice when it changes.
  String? _shownWhy;

  @override
  void initState() {
    super.initState();
    QuizTtsService.instance.status.addListener(_onTts);
  }

  void _onTts() {
    if (QuizTtsService.instance.status.value != TtsStatus.speaking &&
        mounted &&
        (_speaking != null || _essayPlaying != null)) {
      setState(() => _speaking = _essayPlaying = null);
    }
  }

  @override
  void dispose() {
    QuizTtsService.instance.status.removeListener(_onTts);
    _ask.dispose();
    super.dispose();
  }

  void _listen(String text) {
    setState(() => _speaking = text);
    ref.read(wasteQuizProvider.notifier).listen(text);
  }

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    ref.read(wasteQuizProvider.notifier).sendChatMessage(t);
    _ask.clear();
  }

  Widget _round(ElioPalette p, IconData icon, String tip, VoidCallback onTap) =>
      ElioPress(
        pressed: 0.94,
        child: IconButton(
          tooltip: tip,
          onPressed: () {
            quizFeedback(ElioSfx.tick, ElioHaptics.light);
            onTap();
          },
          style: IconButton.styleFrom(
            backgroundColor: p.surface,
            fixedSize: const Size.square(48),
            padding: EdgeInsets.zero,
            side: BorderSide(color: p.borderSubtle),
          ),
          icon: Icon(icon, size: 22, color: p.textPrimary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final s = widget.state;
    final q = s.question!;
    final n = ref.read(wasteQuizProvider.notifier);
    // The side written in the app language, when the reply has it (0185).
    final made = s.currentExplanation;
    final ex = made?.alt != null && made?.alt?.lang == l10n.localeName
        ? made!.alt
        : made;
    final picked = s.selectedOption;
    // Essay (Figma "8 Essay review"): the score is the verdict, the answer
    // and its rubric replace the explanation and the bins.
    final essay = q.type == QuizQuestionType.essay;
    final score = ex?.essayScore;
    final correct = essay ? (score ?? 0) >= 6 : picked == q.correctIndex;
    final category = ScanCategory.fromString(s.scan?.category?.id);
    final top = MediaQuery.paddingOf(context).top;
    // One explanation only; "why not my answer" is the coach's job.
    // Nothing is shown until the final text is ready: no text that is later
    // swapped (root cause in decision 0226).
    final why = s.explanationLoading
        ? ''
        : essay
        ? (ex?.essayFeedback ?? '')
        // "Unavailable" carries a placeholder sentence: it is the retry state.
        : ex != null
        ? (ex.summary == QuizExplanation.unavailable.summary ? '' : ex.summary)
        : (q.bankId == null || q.bankReviewed ? q.explanation : '');
    // The voice only ever reads the text on screen: a changed text (language
    // switch) stops the old speech.
    if ((_shownWhy ?? '').isNotEmpty && _shownWhy != why) {
      unawaited(QuizTtsService.instance.stop());
    }
    _shownWhy = why;
    final answerText = essay
        ? (score == null ? l10n.qzNotGradedYet : l10n.qzScoreOf10(score))
        : q.options[q.correctIndex];

    // Curved green header (662:26005): back, title, read aloud.
    final wide = MediaQuery.sizeOf(context).width > 800;
    final header = SizedBox(
      height: top + (wide ? 76 : 100),
      child: _GreenHeader(
        height: top + (wide ? 76 : 100),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, top + 6, 16, 0),
          child: Row(
            children: [
              _round(
                p,
                _chat ? Icons.chevron_left_rounded : Icons.close_rounded,
                _chat ? l10n.qzBack : l10n.commonClose,
                _chat ? () => setState(() => _chat = false) : widget.onClose,
              ),
              const SizedBox(width: 12),
              if (_chat) ...[
                const EliosAiBadge(size: 36),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        _chat ? l10n.qzCoach : l10n.qzAnswerReview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _sq(ElioTokens.subhead, 600, p.onPrimary),
                      ),
                    ),
                    Text(
                      _chat
                          ? l10n.scanAskCoachSub
                          : [
                              s.scan?.displayName ?? '',
                              l10n.qzQuestionOf(
                                s.questionIndex + 1,
                                s.totalQuestions,
                              ),
                            ].where((t) => t.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _sq(ElioTokens.caption, 500, p.onPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ..._stopPill(context),
              // Mute toggle: saved, stops the voice at once; unmuting reads
              // the explanation on screen.
              KeyedSubtree(
                key: const ValueKey('scan_review_mute'),
                child: _round(
                  p,
                  s.voiceOn
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                  s.voiceOn ? l10n.qzMute : l10n.qzUnmute,
                  () {
                    final unmuting = !s.voiceOn;
                    n.toggleVoice();
                    if (unmuting && why.isNotEmpty) _listen(why);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget coachChat({bool compact = false}) => KeyedSubtree(
      key: _chatKey,
      child: _Coach(
        state: s,
        ask: _ask,
        speaking: _speaking,
        onListen: _listen,
        onSend: _send,
        compact: compact,
      ),
    );
    final chat = coachChat();
    // Keyboard open on a short (landscape) screen: the chat only, so the
    // field being typed in is never under the keyboard or the header.
    Widget overKeyboard(Widget page) => LayoutBuilder(
      builder: (context, all) => all.maxHeight < 260
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: coachChat(compact: true),
              ),
            )
          : page,
    );
    if (_chat) {
      return overKeyboard(
        Column(
          key: const ValueKey('scan_coach'),
          children: [
            header,
            Expanded(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: chat,
                ),
              ),
            ),
          ],
        ),
      );
    }

    const leaf = BorderRadius.only(
      topLeft: Radius.circular(30),
      topRight: Radius.circular(10),
      bottomRight: Radius.circular(30),
      bottomLeft: Radius.circular(10),
    );
    final tone = historyTint(
      p,
      correct ? HistoryTone.success : HistoryTone.error,
    );
    // Verdict leaf (661:25901): buddy, the right answer, your pick, points.
    final verdict = Container(
      key: const ValueKey('scan_verdict'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.bg,
        border: Border.all(color: tone.border ?? p.borderSubtle, width: 1.5),
        borderRadius: leaf,
      ),
      child: Row(
        children: [
          // The buddy hops in: excited when right, sad when wrong.
          ElioPopIn(
            rise: 0,
            scale: 0.6,
            curve: ElioMotion.bounce,
            duration: const Duration(milliseconds: 600),
            child: RobotBuddy(
              mood: correct ? RobotMood.excited : RobotMood.sad,
              height: 50,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (essay
                          ? (score == null
                                ? l10n.qzWaitingGrading
                                : correct
                                ? l10n.qzGoodThinking
                                : l10n.qzNotQuite)
                          : correct
                          ? l10n.qzCorrect
                          : l10n.qzNotQuite)
                      .toUpperCase(),
                  style: _sq(
                    ElioTokens.overline,
                    600,
                    tone.fg,
                  ).copyWith(letterSpacing: 1.1),
                ),
                const SizedBox(height: 2),
                Text(
                  answerText,
                  style: _sq(
                    essay && score == null
                        ? ElioTokens.bodySmall
                        : ElioTokens.subhead,
                    600,
                    p.textPrimary,
                  ),
                ),
                if (essay && score != null)
                  Text(
                    l10n.qzCheckedByAi,
                    style: ElioTokens.bodySmall.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                if (!essay && picked != null && !correct) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.qzYouChose(q.options[picked]),
                    style: ElioTokens.bodySmall.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Points pop last (spring/pop, delay 300).
          ElioPopIn(
            rise: 0,
            scale: 0.6,
            curve: ElioMotion.pop,
            delay: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              decoration: ShapeDecoration(
                color: p.surface,
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/illustrations/history/icon_xp.svg',
                    width: 20,
                    height: 20,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 4),
                  ElioCountUp(
                    value: essay ? (score ?? 0) : (correct ? 10 : 0),
                    builder: (context, v) => Text(
                      l10n.trophiesEarned(v),
                      style: _sq(
                        ElioTokens.subhead,
                        600,
                        correct ? p.secondaryText : p.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Essay (853:28786, 853:28792): the student's words in a card, then the
    // model answer in a green leaf. The grader's rubric stays under the
    // answer; it returns no key points, so that Figma section is not shown.
    final whyBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.scanWhyWorks,
          style: _sq(ElioTokens.subhead, 600, p.textPrimary),
        ),
        const SizedBox(height: 6),
        SvgPicture.asset(
          'assets/illustrations/scan/squiggle.svg',
          width: 150,
          height: 9,
          fit: BoxFit.fill,
          excludeFromSemantics: true,
          colorFilter: ColorFilter.mode(p.primary, BlendMode.srcIn),
        ),
        const SizedBox(height: 6),
        if (s.explanationLoading)
          ElioShimmer(
            child: Column(
              key: const ValueKey('scan_review_loading'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final w in const [330.0, 300.0, 220.0])
                  Container(
                    width: w,
                    height: 14,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: p.surfaceRaised,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
              ],
            ),
          )
        else if (why.isEmpty)
          // AI failed and the question has no explanation of its own.
          Column(
            key: const ValueKey('scan_review_unavailable'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.qzExplanationUnavailable,
                style: ElioTokens.body.copyWith(color: p.textSecondary),
              ),
              TextButton.icon(
                key: const ValueKey('scan_review_retry'),
                onPressed: n.retryExplanation,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.cfgRetry),
              ),
            ],
          )
        else
          // As tall as the loading block at least, so the page below it
          // does not jump when the text arrives.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Text(
              essay
                  ? [
                      why,
                      ex?.learningTakeaway ?? '',
                    ].where((t) => t.isNotEmpty).join('\n\n')
                  : why,
              key: essay ? const ValueKey('scan_essay_why') : null,
              style: ElioTokens.body.copyWith(color: p.textSecondary),
            ),
          ),
      ],
    );

    Widget binTile(ScanCategory c, String name) {
      final fits = c == category;
      final t = historyTint(p, HistoryTone.success);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: fits ? t.bg : p.surface,
            border: Border.all(
              color: fits ? (t.border ?? p.primary) : p.borderSubtle,
              width: fits ? 2 : 1,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(22),
              bottomLeft: Radius.circular(8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The bin that fits jumps once.
              ElioAfterFirstFrame(
                builder: (context, ready) => ElioJump(
                  trigger: fits && ready ? c : null,
                  delay: const Duration(milliseconds: 400),
                  child: homeArt(_binAsset(c), width: 37, height: 44),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _sq(ElioTokens.bodySmall, 600, p.textPrimary),
              ),
              Row(
                children: [
                  Icon(
                    fits ? Icons.check_rounded : Icons.close_rounded,
                    size: 14,
                    color: fits ? p.primaryText : p.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    fits ? l10n.scanBinYes : l10n.scanBinNo,
                    style: _sq(
                      ElioTokens.caption,
                      500,
                      fits ? p.primaryText : p.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final bins = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.scanBinFits,
          style: _sq(ElioTokens.bodySmall, 600, p.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            binTile(ScanCategory.recyclable, 'Anorganik'),
            const SizedBox(width: 8),
            binTile(ScanCategory.organic, 'Organik'),
            const SizedBox(width: 8),
            binTile(ScanCategory.b3, 'B3'),
          ],
        ),
      ],
    );

    // Coach entry (661:26040): opens the full-page ELIOS AI chat.
    final coach = Semantics(
      button: true,
      label: '${l10n.scanAskCoach}. ${l10n.scanAskCoachSub}',
      excludeSemantics: true,
      child: ElioPress(
        child: Material(
          key: const ValueKey('scan_coach_entry'),
          color: historyTint(p, HistoryTone.info).bg,
          shape: const RoundedRectangleBorder(borderRadius: leaf),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              quizFeedback(ElioSfx.pop, ElioHaptics.light);
              setState(() => _chat = true);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  const EliosAiBadge(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.scanAskCoach,
                          style: _sq(ElioTokens.bodySmall, 600, p.textPrimary),
                        ),
                        Text(
                          l10n.scanAskCoachSub,
                          style: _sq(ElioTokens.caption, 500, p.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: p.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: p.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final next = ElioPress(
      pressed: 0.97,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('quiz_next'),
          onPressed: s.sendingChat
              ? null
              : () {
                  quizFeedback(ElioSfx.pop, ElioHaptics.light);
                  n.nextQuestion();
                },
          style: FilledButton.styleFrom(
            backgroundColor: p.primary,
            foregroundColor: p.onPrimary,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  s.isLastQuestion ? l10n.qzFinish : l10n.qzNextQuestion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _sq(ElioTokens.subhead, 600, p.onPrimary),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
    Widget enter(int i, Widget child) => ElioPopIn(
      key: ValueKey('review-in-$i'),
      index: i,
      rise: 10,
      child: child,
    );

    // Essay (Figma "16 · Essay answer review"): the History explanation
    // design, shared with History's own page (decision 0227).
    final essayBody = !essay
        ? const SizedBox.shrink()
        : s.explanationLoading
        ? const SizedBox(
            height: 420,
            child: HistorySkeleton(HistoryLoadingLayout.explanation),
          )
        : EssayReview(
            key: ValueKey('essay-${s.questionIndex}'),
            question: q.question,
            answer: s.essayAnswer ?? '',
            reference: ex?.referenceAnswer ?? q.explanation,
            explanation: ex,
            score: score,
            index: s.questionIndex,
            total: s.totalQuestions,
            playing: _essayPlaying,
            onListen: (id, text) {
              if (_essayPlaying == id) {
                unawaited(QuizTtsService.instance.stop());
                setState(() => _essayPlaying = null);
                return;
              }
              ElioHaptics.select();
              _listen(text);
              setState(() => _essayPlaying = id);
            },
          );
    final export = SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey('quiz_export_pdf'),
        style: historyOutlineStyle(p),
        onPressed: () {
          quizFeedback(ElioSfx.pop, ElioHaptics.light);
          unawaited(QuizTtsService.instance.stop());
          final record = n.previewRecord();
          if (record.questions.isEmpty) return;
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: p.surface,
            shape: const RoundedSuperellipseBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            builder: (_) => QuestionExportSheet(
              record: record,
              questionIndex: record.questions.length - 1,
            ),
          );
        },
        icon: const Icon(Icons.description_outlined),
        label: Text(l10n.h3ExportPdf, maxLines: 1),
      ),
    );

    return overKeyboard(
      Column(
        key: const ValueKey('scan_review'),
        children: [
          header,
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                if (box.maxWidth > box.maxHeight * 1.3) {
                  // Landscape (Figma "6/7 Answer review", "8 Essay review"):
                  // the review left, the ELIOS AI coach chat and Next right.
                  return SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: essay
                                  ? [essayBody]
                                  : [
                                      enter(0, verdict),
                                      const SizedBox(height: 14),
                                      enter(1, whyBlock),
                                      const SizedBox(height: 14),
                                      enter(2, bins),
                                    ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: essay
                                // Essay: the coach entry and Next (no inline
                                // chat; key points would sit above them).
                                ? Column(
                                    children: [
                                      enter(4, coach),
                                      const Spacer(),
                                      export,
                                      const SizedBox(height: 8),
                                      next,
                                    ],
                                  )
                                : Column(
                                    children: [
                                      Expanded(
                                        child: KeyedSubtree(
                                          key: const ValueKey(
                                            'scan_coach_inline',
                                          ),
                                          child: enter(3, chat),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      next,
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        children: [
                          if (essay) ...[
                            essayBody,
                            const SizedBox(height: 20),
                          ] else ...[
                            enter(0, verdict),
                            const SizedBox(height: 20),
                            enter(1, whyBlock),
                            const SizedBox(height: 20),
                            enter(2, bins),
                            const SizedBox(height: 20),
                          ],
                          enter(4, coach),
                        ],
                      ),
                    ),
                    // Action bar (662:26165).
                    Container(
                      decoration: BoxDecoration(
                        color: p.surface,
                        border: Border(top: BorderSide(color: p.borderSubtle)),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          // Essay (869:29775): Export PDF beside Next.
                          child: essay
                              ? Row(
                                  children: [
                                    Expanded(child: export),
                                    const SizedBox(width: 12),
                                    Expanded(child: next),
                                  ],
                                )
                              : next,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Curved green page header (portrait). Landscape: the top-left ellipse of
/// 662:26256 / 856:28871, kept above the content.
class _GreenHeader extends StatelessWidget {
  const _GreenHeader({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    if (MediaQuery.sizeOf(context).width <= 800) {
      return L3Hero(
        curveBottom: height,
        radiusY: 150,
        bubble: 120,
        child: child,
      );
    }
    // Landscape: Figma's ellipse 960×540 at (−300, −470) and its bubble, both
    // inside the header's own height so the curve never runs over the content.
    final top = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -300,
            top: top - 470,
            width: 960,
            height: 540,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: p.primary,
                shape: const OvalBorder(),
              ),
            ),
          ),
          Positioned(
            left: 313,
            top: top - 80,
            width: 150,
            height: 150,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: p.primaryHover,
                shape: const OvalBorder(),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ── Quiz complete ───────────────────────────────────────────────────────────

/// End of the scan's quiz as a full page: score, XP earned (counts up),
/// level bar, Scan again / Export PDF / Done. No Figma frame exists for this
/// state; it follows the answer-review page.
class _ScanDonePage extends StatelessWidget {
  const _ScanDonePage({
    required this.state,
    required this.onClose,
    required this.onRescan,
  });
  final WasteQuizUiState state;
  final VoidCallback onClose;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final top = MediaQuery.paddingOf(context).top;
    final wide = MediaQuery.sizeOf(context).width > 800;
    final earned = state.recordedQuestions.isNotEmpty
        ? state.recordedQuestions.fold<int>(0, (sum, q) => sum + q.trophies)
        : trophiesForScores(correctMcCount: state.correctCount);
    final total = state.totalQuestions;
    final pending = state.recordedQuestions.any((q) => q.gradingPending);
    final grade = gradeFor(trophies: earned, totalQuestions: total);
    final store = ScanRecordStore.instance;
    final good = state.correctCount * 2 >= total;

    Widget button(
      String label,
      IconData icon,
      VoidCallback onTap, {
      bool primary = false,
      Key? key,
    }) => ElioPress(
      pressed: 0.97,
      child: SizedBox(
        height: 52,
        child: FilledButton.icon(
          key: key,
          onPressed: () {
            quizFeedback(ElioSfx.pop, ElioHaptics.light);
            onTap();
          },
          style: FilledButton.styleFrom(
            backgroundColor: primary ? p.primary : p.surfaceRaised,
            foregroundColor: primary ? p.onPrimary : p.textPrimary,
            side: BorderSide.none,
            shape: const StadiumBorder(),
          ),
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _sq(
              ElioTokens.button,
              600,
              primary ? p.onPrimary : p.textPrimary,
            ),
          ),
        ),
      ),
    );

    final summary = Column(
      children: [
        // The buddy bounces in; excited for half or more right.
        ElioPopIn(
          rise: -30,
          scale: 0.6,
          curve: ElioMotion.bounce,
          duration: const Duration(milliseconds: 700),
          child: RobotBuddy(
            mood: good ? RobotMood.excited : RobotMood.thinking,
            height: 96,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          pending ? l10n.awaitingGrading : grade.label,
          textAlign: TextAlign.center,
          style: _sq(ElioTokens.headline, 700, p.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.wqCorrectOf(state.correctCount, total),
          key: const Key('scan_done_score'),
          style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 12),
        ElioPopIn(
          rise: 0,
          scale: 0.7,
          curve: ElioMotion.pop,
          delay: const Duration(milliseconds: 300),
          child: Container(
            key: const Key('result_card_trophies_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: ShapeDecoration(
              color: p.secondaryText.withValues(alpha: p.isDark ? 0.14 : 0.06),
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/illustrations/history/icon_xp.svg',
                  width: 20,
                  height: 20,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 6),
                ElioCountUp(
                  // With the bin check's XP, as saved in History (0224).
                  value: earned + state.binCheckXp,
                  builder: (context, v) => Text(
                    l10n.trophiesEarned(v),
                    style: _sq(ElioTokens.subhead, 700, p.secondaryText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final level = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.borderSubtle),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(30),
          bottomLeft: Radius.circular(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  store.userLevel.levelAndTitle,
                  key: const Key('result_card_level_text'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _sq(ElioTokens.bodySmall, 600, p.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.trophiesTotal(store.totalTrophies),
                style: _sq(ElioTokens.caption, 500, p.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The level bar fills from empty (600 ms).
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: ElioMotion.reduced(context) ? store.levelProgress : 0,
                end: store.levelProgress,
              ),
              duration: const Duration(milliseconds: 600),
              curve: ElioMotion.standard,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: p.surfaceRaised,
                valueColor: AlwaysStoppedAnimation(p.primary),
              ),
            ),
          ),
        ],
      ),
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Robot (R1): no new scan while the arm is still dropping the item.
        Consumer(
          builder: (context, ref, _) {
            final dropping =
                _isRobot(context) &&
                (_ResultCard.r1EnabledOverride ||
                    const bool.fromEnvironment('R1')) &&
                ref.watch(r1DropPendingProvider);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dropping) ...[
                  Container(
                    key: const Key('result_card_r1_drop_notice'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: historyTint(p, HistoryTone.warning).bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.robotDropping,
                            style: _sq(ElioTokens.caption, 600, p.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                IgnorePointer(
                  ignoring: dropping,
                  child: Opacity(
                    opacity: dropping ? 0.5 : 1,
                    child: button(
                      l10n.scanAgain,
                      Icons.qr_code_scanner_rounded,
                      onRescan,
                      primary: true,
                      key: const Key('result_card_rescan_button'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: button(
                l10n.exportPdf,
                Icons.picture_as_pdf_rounded,
                () => _exportQuizPdf(context, state, earned),
                key: const Key('result_card_export_pdf_button'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: button(l10n.notifDone, Icons.check_rounded, () {
                onClose();
                // Phone: back to the hub. Robot: stay on the control screen.
                if (!_isRobot(context)) {
                  Navigator.of(context).maybePop();
                }
              }),
            ),
          ],
        ),
      ],
    );

    return Column(
      key: const ValueKey('scan_done'),
      children: [
        SizedBox(
          height: top + (wide ? 76 : 100),
          child: _GreenHeader(
            height: top + (wide ? 76 : 100),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, top + 6, 16, 0),
              child: Row(
                children: [
                  _RoundClose(onTap: onClose),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.qzComplete,
                            style: _sq(ElioTokens.subhead, 600, p.onPrimary),
                          ),
                        ),
                        Text(
                          state.scan?.displayName ?? l10n.wasteGeneric,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _sq(ElioTokens.caption, 500, p.onPrimary),
                        ),
                      ],
                    ),
                  ),
                  ..._stopPill(context),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SafeArea(
            top: false,
            child: wide
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Expanded(child: SingleChildScrollView(child: summary)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                level,
                                const SizedBox(height: 12),
                                actions,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    children: [
                      summary,
                      const SizedBox(height: 20),
                      ElioPopIn(index: 2, child: level),
                      const SizedBox(height: 20),
                      ElioPopIn(index: 3, child: actions),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

Future<void> _exportQuizPdf(
  BuildContext context,
  WasteQuizUiState state,
  int earned,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final t = context.l10n;
  final record = ScanRecord(
    id: 'scan-${DateTime.now().millisecondsSinceEpoch}',
    time: DateTime.now(),
    itemName: state.scan?.displayName ?? l10n.wasteGeneric,
    category: ScanCategory.fromString(state.scan?.category?.id),
    cropPhotoPath: state.historyPhotoPath,
    difficulty: state.difficulty,
    questions: state.recordedQuestions,
    trophies: earned,
    lang: AiQuizService.replyLang,
  );
  try {
    await QuizPdfService.shareOrSave(record);
    messenger.showSnackBar(SnackBar(content: Text(t.pdfExported)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(t.pdfExportFailed(e))));
  }
}
