// Full-screen Scan & quiz pages for the phone camera (Figma 06 · Scan:
// identified 629:90773, question 629:90816, landscape 659:25791 / 659:25857;
// motion 13 · 27 and 28; decision 0216). Same provider calls as the popup;
// states with no full-page design (hazard, mismatch, essay, review, result)
// show the popup's own views on the page.
part of '../waste_quiz_popup.dart';

TextStyle _sq(TextStyle base, int weight, Color color) =>
    homeWeight(base, weight).copyWith(color: color);

class ScanQuizPages extends ConsumerStatefulWidget {
  const ScanQuizPages({super.key});

  @override
  ConsumerState<ScanQuizPages> createState() => _ScanQuizPagesState();
}

class _ScanQuizPagesState extends ConsumerState<ScanQuizPages> {
  /// "Start quiz" was tapped for this scan.
  bool _started = false;

  /// The answered question stays up while its right / wrong feedback plays.
  bool _hold = false;
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
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
      if (fresh && (_started || _hold)) {
        _holdTimer?.cancel();
        setState(() => _started = _hold = false);
      }
    });
    final s = ref.watch(wasteQuizProvider);
    if (s.phase == WasteQuizPhase.idle) return const SizedBox.shrink();
    final p = context.elio;
    final n = ref.read(wasteQuizProvider.notifier);
    final q = s.question;
    final mc = q != null && q.type == QuizQuestionType.multipleChoice;
    final loading = s.phase == WasteQuizPhase.loadingQuestion;
    final active = s.phase == WasteQuizPhase.active;
    final (String kind, Widget page) = switch (s.phase) {
      _ when s.notice != null => (
        'failed',
        _ScanFailedPage(notice: s.notice!, onRetake: n.dismiss),
      ),
      WasteQuizPhase.identifying => (
        'identified',
        _IdentifiedPage(state: s, onClose: n.dismiss, onStart: null),
      ),
      _ when (loading || active) && !_started && s.questionIndex == 0 => (
        'identified',
        _IdentifiedPage(
          state: s,
          onClose: n.dismiss,
          onStart: active ? () => setState(() => _started = true) : null,
        ),
      ),
      _
          when loading ||
              (mc &&
                  (active ||
                      (_hold && s.phase == WasteQuizPhase.explaining))) =>
        (
          'question-${s.questionIndex}',
          _ScanQuestionPage(state: s, onClose: n.dismiss, onAnswer: _answer),
        ),
      WasteQuizPhase.finished => (
        'done',
        _ScanDonePage(state: s, onClose: n.dismiss),
      ),
      WasteQuizPhase.explaining when mc => (
        'review-${s.questionIndex}',
        _ScanReviewPage(state: s, onClose: n.dismiss),
      ),
      _ => (
        'popup-${s.phase.name}',
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: _QuizBody(state: s),
          ),
        ),
      ),
    };
    // The camera controls under the page stay out of the screen reader.
    return BlockSemantics(
      child: Material(
        color: p.background,
        child: AnimatedSwitcher(
          duration: ElioMotion.reduced(context)
              ? Duration.zero
              : ElioMotion.base,
          switchInCurve: ElioMotion.emphasized,
          switchOutCurve: ElioMotion.exit,
          // Pages fill the screen from the top (the default centres them).
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: KeyedSubtree(key: ValueKey(kind), child: page),
        ),
      ),
    );
  }
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
          elioFeedback(ElioSfx.tick, ElioHaptics.light);
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
    required this.onStart,
  });
  final WasteQuizUiState state;
  final VoidCallback onClose;

  /// Null until the first question is ready.
  final VoidCallback? onStart;

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
    if (widget.onStart != null && old.onStart == null) {
      elioFeedback(ElioSfx.tick, ElioHaptics.select);
    }
  }

  // Figma 13 · 27: S2 when the buddy pops, H-light when the result shows.
  void _cue() => elioFeedback(ElioSfx.pop, ElioHaptics.light);

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final s = widget.state;
    final category = ScanCategory.fromString(s.scan?.category?.id);
    final reduced = ElioMotion.reduced(context);

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
                l10n.scanJustNowPhone,
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
                  l10n.scanIdentified.toUpperCase(),
                  style: _sq(
                    ElioTokens.overline,
                    600,
                    p.primaryText,
                  ).copyWith(letterSpacing: 1.1),
                ),
                const SizedBox(height: 10),
                Semantics(
                  header: true,
                  child: Text(
                    s.scan?.displayName ?? l10n.wasteGeneric,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _sq(ElioTokens.display, 700, p.textPrimary),
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
                    // _InfoChip is flexible: it needs a Row around it.
                    if (s.canCorrectItem)
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
            child: _QuizTicket(
              state: s,
              onRetake: widget.onClose,
              onStart: widget.onStart,
            ),
          );

    final header = Row(
      children: [
        _RoundClose(onTap: widget.onClose),
        const SizedBox(width: 12),
        Text(
          l10n.scanResultTitle,
          style: _sq(ElioTokens.subhead, 700, p.textPrimary),
        ),
      ],
    );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth > box.maxHeight) {
            // Landscape (659:25791): photo left, result and ticket right.
            return Padding(
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

/// "Your quiz is ready" ticket (629:90795): notched sides, dashed tear line,
/// Retake and Start quiz.
class _QuizTicket extends ConsumerWidget {
  const _QuizTicket({
    required this.state,
    required this.onRetake,
    required this.onStart,
  });
  final WasteQuizUiState state;
  final VoidCallback onRetake;
  final VoidCallback? onStart;

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
                                  ready
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
                              elioFeedback(ElioSfx.pop, ElioHaptics.light);
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
                              l10n.scanRetake,
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
                                    elioFeedback(
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
                                  l10n.scanStartQuiz,
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
                Text(
                  l10n.scanResultTitle,
                  style: _sq(ElioTokens.subhead, 700, p.textPrimary),
                ),
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
                              elioFeedback(ElioSfx.pop, ElioHaptics.light);
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
                              l10n.scanRetake,
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
  });
  final WasteQuizUiState state;
  final VoidCallback onClose;
  final ValueChanged<int> onAnswer;

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

    final header = Row(
      children: [
        _RoundClose(onTap: onClose),
        const SizedBox(width: 12),
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
        if (seconds != null && q != null && picked == null)
          QuizCountdown(
            key: ValueKey('quiz_timer_${state.questionIndex}'),
            seconds: seconds,
            onTimeUp: n.timeUp,
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
                        l10n.qzQuestionOfCaps(
                          state.questionIndex + 1,
                          state.totalQuestions,
                          (state.scan?.displayName ?? '').toUpperCase(),
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

    final answers = Column(
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
        if (q != null && prefs.skipAllowed && picked == null) ...[
          const SizedBox(height: 12),
          TextButton(
            key: const ValueKey('quiz_skip'),
            onPressed: () {
              elioFeedback(ElioSfx.tick, ElioHaptics.light);
              n.skipQuestion();
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
          ),
        ],
      ],
    );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
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
  String? _speaking;
  bool _chat = false;

  @override
  void initState() {
    super.initState();
    QuizTtsService.instance.status.addListener(_onTts);
  }

  void _onTts() {
    if (QuizTtsService.instance.status.value != TtsStatus.speaking &&
        mounted &&
        _speaking != null) {
      setState(() => _speaking = null);
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
            elioFeedback(ElioSfx.tick, ElioHaptics.light);
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
    final ex = s.currentExplanation;
    final picked = s.selectedOption;
    final correct = picked == q.correctIndex;
    final category = ScanCategory.fromString(s.scan?.category?.id);
    final top = MediaQuery.paddingOf(context).top;
    final why = [
      if (ex != null) ...[
        ex.summary,
        if (!correct && ex.selectedAnswerFeedback.isNotEmpty)
          ex.selectedAnswerFeedback,
      ] else if (q.bankId == null || q.bankReviewed)
        q.explanation,
    ].where((t) => t.isNotEmpty).join('\n\n');

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
                          : '${l10n.qzQuestionOf(s.questionIndex + 1, s.totalQuestions)} · ${s.scan?.displayName ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _sq(ElioTokens.caption, 500, p.onPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _round(
                p,
                Icons.volume_up_outlined,
                l10n.qzListenExplanation,
                () => _listen(why.isEmpty ? q.question : why),
              ),
            ],
          ),
        ),
      ),
    );

    if (_chat) {
      return Column(
        key: const ValueKey('scan_coach'),
        children: [
          header,
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: _Coach(
                  state: s,
                  ask: _ask,
                  speaking: _speaking,
                  onListen: _listen,
                  onSend: _send,
                ),
              ),
            ),
          ),
        ],
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
                  (correct ? l10n.qzCorrect : l10n.qzNotQuite).toUpperCase(),
                  style: _sq(
                    ElioTokens.overline,
                    600,
                    tone.fg,
                  ).copyWith(letterSpacing: 1.1),
                ),
                const SizedBox(height: 2),
                Text(
                  q.options[q.correctIndex],
                  style: _sq(ElioTokens.subhead, 600, p.textPrimary),
                ),
                if (picked != null && !correct) ...[
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
                  homeArt(
                    correct ? 'medal_gold' : 'medal_locked',
                    width: 20,
                    height: 24,
                  ),
                  const SizedBox(width: 4),
                  ElioCountUp(
                    value: correct ? 10 : 0,
                    builder: (context, v) => Text(
                      '+$v',
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
        if (why.isEmpty && s.explanationLoading)
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
        else
          Text(
            why.isEmpty ? q.options[q.correctIndex] : why,
            style: ElioTokens.body.copyWith(color: p.textSecondary),
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
              elioFeedback(ElioSfx.pop, ElioHaptics.light);
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
                  elioFeedback(ElioSfx.pop, ElioHaptics.light);
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
    Widget enter(int i, Widget child) =>
        ElioPopIn(key: ValueKey('review-in-$i'), index: i, child: child);

    return Column(
      key: const ValueKey('scan_review'),
      children: [
        header,
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth > box.maxHeight * 1.3) {
                // Landscape (662:26256): review left, bins + coach + next right.
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
                            children: [
                              enter(0, verdict),
                              const SizedBox(height: 14),
                              enter(1, whyBlock),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              enter(2, bins),
                              const SizedBox(height: 12),
                              enter(3, coach),
                              const SizedBox(height: 12),
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
                        enter(0, verdict),
                        const SizedBox(height: 20),
                        enter(1, whyBlock),
                        const SizedBox(height: 20),
                        enter(2, bins),
                        const SizedBox(height: 20),
                        enter(3, coach),
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
                        child: next,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Curved green page header. Wider than the 880 px curve (landscape): a
/// green band with a rounded bottom instead, so no gap shows at the sides.
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
    return Container(
      decoration: BoxDecoration(
        color: p.primary,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.elliptical(420, 26),
        ),
      ),
      child: child,
    );
  }
}

// ── Quiz complete ───────────────────────────────────────────────────────────

/// End of the scan's quiz as a full page: score, XP earned (counts up),
/// level bar, Scan again / Export PDF / Done. No Figma frame exists for this
/// state; it follows the answer-review page.
class _ScanDonePage extends StatelessWidget {
  const _ScanDonePage({required this.state, required this.onClose});
  final WasteQuizUiState state;
  final VoidCallback onClose;

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
            elioFeedback(ElioSfx.pop, ElioHaptics.light);
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
                  value: earned,
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
        button(
          l10n.scanAgain,
          Icons.qr_code_scanner_rounded,
          onClose,
          primary: true,
          key: const Key('result_card_rescan_button'),
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
                Navigator.of(context).maybePop();
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
