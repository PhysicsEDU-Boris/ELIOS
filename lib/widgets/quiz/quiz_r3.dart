// Q3 quiz popups (Figma 393:2358: question 398:3042, review 398:3300 / 417:6298,
// essay review 417:6944, loading 422:7322, skeleton 422:7792; decision 0175).
// One set of widgets for Control (phone and R2), the phone camera scan, tablets
// and the Mac. Same provider calls as before; only the look and the English UI
// are new. Question, answer and explanation text stay as the bank or the AI wrote it.
part of '../waste_quiz_popup.dart';

String _level(QuizDifficulty d) => switch (d) {
  QuizDifficulty.easy => 'Easy',
  QuizDifficulty.medium => 'Medium',
  QuizDifficulty.hard => 'Hard',
};

/// Green ring, filled core, white ELIOS leaf (Figma Brand/ELIOS AI badge 388:8631).
class EliosAiBadge extends StatelessWidget {
  const EliosAiBadge({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      'assets/illustrations/control/elios_ai_badge.svg',
      width: size,
      height: size,
    ),
  );
}

/// The rounded white popup (28 dp radius) around every quiz state.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Material(
      key: const ValueKey('quiz_popup'),
      color: p.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: child,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.text, {this.onTap, this.chipKey});
  final String text;
  final VoidCallback? onTap;
  final Key? chipKey;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: onTap == null ? p.surfaceRaised : p.surface,
        borderRadius: BorderRadius.circular(9999),
        border: onTap == null ? null : Border.all(color: p.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: onTap == null ? p.textSecondary : p.primaryText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return Flexible(
      child: onTap == null
          ? chip
          : Semantics(
              button: true,
              child: GestureDetector(key: chipKey, onTap: onTap, child: chip),
            ),
    );
  }
}

/// Voice switch, compact STOP, minimise and close: the right side of every header.
class _HeaderActions extends ConsumerWidget {
  const _HeaderActions({this.onStop});
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final voiceOn = ref.watch(wasteQuizProvider.select((s) => s.voiceOn));
    final n = ref.read(wasteQuizProvider.notifier);
    Widget round(IconData icon, String tip, VoidCallback onTap, Key k) =>
        Semantics(
          button: true,
          label: tip,
          excludeSemantics: true,
          child: InkResponse(
            key: k,
            onTap: onTap,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: p.textPrimary),
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          toggled: voiceOn,
          label: 'Voice',
          excludeSemantics: true,
          onTap: n.toggleVoice,
          child: GestureDetector(
            key: const ValueKey('quiz_voice'),
            onTap: n.toggleVoice,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: p.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volume_up_outlined,
                      size: 16,
                      color: p.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    _MiniSwitch(on: voiceOn),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onStop != null) ...[
          const SizedBox(width: 8),
          _CompactStop(onStop: onStop!),
        ],
        const SizedBox(width: 8),
        round(
          Icons.remove_rounded,
          'Minimise quiz',
          n.minimize,
          const ValueKey('quiz_minimise'),
        ),
        const SizedBox(width: 6),
        round(
          Icons.close_rounded,
          'Close quiz',
          n.dismiss,
          const ValueKey('quiz_close'),
        ),
      ],
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 34,
      height: 20,
      padding: const EdgeInsets.all(2),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? p.primary : p.borderMedium,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
      ),
    );
  }
}

/// The same emergency stop as the screen's own, always in reach while the quiz covers it (0026).
class _CompactStop extends StatelessWidget {
  const _CompactStop({required this.onStop});
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      button: true,
      label: 'Berhenti darurat',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('quiz_stop'),
        behavior: HitTestBehavior.opaque,
        onTap: onStop,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.error,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: p.onError,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'STOP',
                  style: TextStyle(
                    color: p.onError,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header row. [logo]: the ELIOS AI mark (question frame only, 398:3042).
class _Header extends StatelessWidget {
  const _Header({required this.chips, this.logo = false, this.onStop});
  final List<Widget> chips;
  final bool logo;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    // Portrait phones (under 520 dp): the mark without the wordmark, so the actions fit.
    final narrow = MediaQuery.sizeOf(context).width < 520;
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          if (logo && narrow) ...[
            const EliosAiBadge(size: 28),
            const SizedBox(width: 8),
          ],
          if (logo && !narrow) ...[
            const EliosAiBadge(size: 32),
            const SizedBox(width: 6),
            Text(
              'ELIOS',
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: p.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: p.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          // The chips share what the actions leave; the actions stay right-aligned.
          Expanded(
            child: Row(
              children: [
                for (final c in chips) ...[c, const SizedBox(width: 8)],
              ],
            ),
          ),
          _HeaderActions(onStop: onStop),
        ],
      ),
    );
  }
}

/// "Not this?" (Bukan ini?) while the item can still be corrected.
Widget? _notThisChip(
  BuildContext context,
  WasteQuizUiState s,
  WasteQuizNotifier n,
) => s.canCorrectItem
    ? _InfoChip(
        'Not this?',
        chipKey: const ValueKey('quiz_not_this'),
        onTap: () => _pickCorrectItem(context, n),
      )
    : null;

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.small = false,
    this.iconOnly = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool small;

  /// Narrow popups: the icon alone; the label stays the semantics label.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: p.borderSubtle),
            boxShadow: small
                ? null
                : [
                    BoxShadow(
                      color: p.borderMedium,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: small ? 8 : 14,
                vertical: small ? 4 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: small ? 12 : 16,
                    color: small ? p.primaryText : p.textPrimary,
                  ),
                  if (!iconOnly) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: small ? 11 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  const _GreenButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.arrow_forward_rounded,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 6),
                    Icon(icon, size: 16, color: p.onPrimary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Skeleton (422:7792) ─────────────────────────────────────────────────────

/// While the popup opens and no quiz state exists yet. The STOP in it is real.
class QuizPopupSkeleton extends StatelessWidget {
  const QuizPopupSkeleton({super.key, this.onStop});
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    Widget block(double? w, double h, [double r = 12]) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(r),
      ),
    );
    return _Shell(
      child: Column(
        key: const ValueKey('quiz_skeleton'),
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                block(170, 26, 13),
                const SizedBox(width: 8),
                block(162, 26, 13),
                const Spacer(),
                block(70, 30, 15),
                if (onStop != null) ...[
                  const SizedBox(width: 8),
                  _CompactStop(onStop: onStop!),
                ],
                const SizedBox(width: 8),
                block(32, 32, 16),
                const SizedBox(width: 6),
                block(32, 32, 16),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              block(44, 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    block(150, 10, 5),
                    const SizedBox(height: 8),
                    block(null, 20, 10),
                    const SizedBox(height: 8),
                    block(420, 20, 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < 2; r++) ...[
                  if (r > 0) const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: block(null, double.infinity)),
                        const SizedBox(width: 10),
                        Expanded(child: block(null, double.infinity)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              block(24, 8, 4),
              const SizedBox(width: 6),
              block(8, 8, 4),
              const SizedBox(width: 6),
              block(8, 8, 4),
              const SizedBox(width: 8),
              block(200, 26, 13),
              const Spacer(),
              block(120, 30, 15),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Body: picks the state's view ────────────────────────────────────────────

class _QuizBody extends ConsumerStatefulWidget {
  const _QuizBody({required this.state, this.onStop, this.onRescan});
  final WasteQuizUiState state;
  final VoidCallback? onStop;
  final VoidCallback? onRescan;

  @override
  ConsumerState<_QuizBody> createState() => _QuizBodyState();
}

class _QuizBodyState extends ConsumerState<_QuizBody> {
  final _answer = TextEditingController();
  final _ask = TextEditingController();
  Timer? _tick;

  /// The text TTS is reading (one slot), for "Playing" in the chat.
  String? _speaking;

  @override
  void initState() {
    super.initState();
    QuizTtsService.instance.status.addListener(_onTts);
    _answer.addListener(() => setState(() {}));
    // The loading timer shows real elapsed seconds.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final ph = widget.state.phase;
      if (mounted &&
          (ph == WasteQuizPhase.identifying ||
              ph == WasteQuizPhase.loadingQuestion ||
              widget.state.sendingChat)) {
        setState(() {});
      }
    });
  }

  void _onTts() {
    if (QuizTtsService.instance.status.value != TtsStatus.speaking &&
        mounted &&
        _speaking != null) {
      setState(() => _speaking = null);
    }
  }

  @override
  void didUpdateWidget(covariant _QuizBody old) {
    super.didUpdateWidget(old);
    if (old.state.questionIndex != widget.state.questionIndex ||
        old.state.scan != widget.state.scan) {
      _answer.clear();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    QuizTtsService.instance.status.removeListener(_onTts);
    _answer.dispose();
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

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final n = ref.read(wasteQuizProvider.notifier);
    final q = s.question;
    final Widget body = switch (s.phase) {
      WasteQuizPhase.identifying || WasteQuizPhase.loadingQuestion =>
        _LoadingView(state: s, since: n.loadingSince, onStop: widget.onStop),
      WasteQuizPhase.confirmingHazard => _HazardView(
        state: s,
        onStop: widget.onStop,
      ),
      WasteQuizPhase.confirmingMismatch => _MismatchView(
        state: s,
        onStop: widget.onStop,
      ),
      WasteQuizPhase.finished => _FinishedView(
        state: s,
        onStop: widget.onStop,
        onRescan: widget.onRescan,
      ),
      WasteQuizPhase.explaining when q != null => _ReviewView(
        state: s,
        onStop: widget.onStop,
        chat: _Coach(
          state: s,
          ask: _ask,
          speaking: _speaking,
          onListen: _listen,
          onSend: _send,
        ),
        onListen: _listen,
      ),
      _ when q != null && q.type == QuizQuestionType.essay => _EssayInputView(
        state: s,
        controller: _answer,
        since: n.loadingSince,
        onStop: widget.onStop,
      ),
      _ when q != null => _QuestionView(state: s, onStop: widget.onStop),
      _ => QuizPopupSkeleton(onStop: widget.onStop),
    };
    return body;
  }
}

// ── Loading (422:7322) ──────────────────────────────────────────────────────

class _LoadingView extends ConsumerWidget {
  const _LoadingView({required this.state, required this.since, this.onStop});
  final WasteQuizUiState state;
  final DateTime? since;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final n = ref.read(wasteQuizProvider.notifier);
    final identifying = state.phase == WasteQuizPhase.identifying;
    final elapsed = since == null
        ? Duration.zero
        : DateTime.now().difference(since!);
    final time =
        '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    final essay =
        questionTypeFor(state.questionIndex, essays: essayQuestionsEnabled) ==
        QuizQuestionType.essay;
    final ai = state.questionSource == QuestionSource.ai;
    final pool = state.scan == null
        ? null
        : QuestionBank.loaded?.selection(state.scan!).pool;
    // Steps tied to real events only: the scan is read (identify done), then the question is
    // written (topic or bank pool chosen as it starts). "Answer key checked" is not a separate
    // event in the code, so it is not shown (decision 0175).
    final steps = [
      (
        'Read the scan',
        state.scan == null
            ? 'ELIOS AI is looking'
            : '${state.scan!.displayName}${state.scan!.category == null ? '' : ' · ${ScanCategory.fromString(state.scan!.category!.id).badgeLabel}'}',
        identifying ? 1 : 2,
      ),
      (
        'Picked a topic',
        identifying
            ? 'After the scan'
            : ai
            ? 'ELIOS AI topic'
            : (pool == null ? 'Question bank' : 'Bank pool · $pool'),
        identifying ? 0 : 2,
      ),
      (
        'Writing the question',
        '${_level(state.difficulty)} · ${essay ? 'essay' : 'multiple choice'}',
        identifying ? 0 : 1,
      ),
    ];
    Widget step((String, String, int) st) {
      final (title, sub, status) = st; // 0 waiting, 1 running, 2 done
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: status == 1 ? p.surface : p.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: status == 1 ? p.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 20,
                child: switch (status) {
                  2 => Container(
                    decoration: BoxDecoration(
                      color: p.primaryActive,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: p.surface,
                    ),
                  ),
                  1 => CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: p.primary,
                  ),
                  _ => Icon(
                    Icons.radio_button_unchecked,
                    size: 20,
                    color: p.borderStrong,
                  ),
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: status == 0 ? p.textTertiary : p.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget placeholder(Color dot) => Expanded(
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Container(
                width: 160,
                height: 8,
                decoration: BoxDecoration(
                  color: p.isDark ? p.borderStrong : p.borderMedium,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return _Shell(
      child: Column(
        key: const ValueKey('quiz_loading'),
        children: [
          _Header(
            onStop: onStop,
            chips: [
              _InfoChip(
                'Question ${state.questionIndex + 1} of ${state.totalQuestions} · ${_level(state.difficulty)}',
              ),
              _InfoChip('Scanned: ${state.scan?.displayName ?? 'reading…'}'),
              ?_notThisChip(context, state, n),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.primary),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: p.primary,
                          backgroundColor: p.borderSubtle,
                        ),
                      ),
                      const EliosAiBadge(size: 32),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        identifying
                            ? 'ELIOS AI · READING THE SCAN'
                            : 'ELIOS AI · WRITING YOUR QUESTION',
                        style: TextStyle(
                          color: p.primaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        identifying
                            ? 'Reading the scan…'
                            : 'Preparing the next question…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        ai || identifying
                            ? 'ELIOS AI is writing it online. This usually takes 2–4 seconds.'
                            : 'From the reviewed question bank. This takes a moment.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      key: const ValueKey('quiz_loading_timer'),
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'elapsed',
                      style: TextStyle(color: p.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final st in steps) ...[
                if (st != steps.first) const SizedBox(width: 8),
                step(st),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 5,
              color: p.primary,
              backgroundColor: p.surfaceRaised,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  Row(
                    children: [
                      placeholder(ElioTokens.answerRed),
                      const SizedBox(width: 10),
                      placeholder(ElioTokens.answerBlue),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      placeholder(ElioTokens.answerGreen),
                      const SizedBox(width: 10),
                      placeholder(ElioTokens.answerYellow),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: p.primaryText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${onStop != null ? 'Keep driving. ' : ''}Minimise this and the Quiz button lights up when the question is ready.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                key: const ValueKey('quiz_loading_minimise'),
                icon: Icons.remove_rounded,
                label: 'Minimise',
                onTap: n.minimize,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Question (398:3042) ─────────────────────────────────────────────────────

class _QuestionView extends ConsumerWidget {
  const _QuestionView({required this.state, this.onStop});
  final WasteQuizUiState state;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final q = state.question!;
    final n = ref.read(wasteQuizProvider.notifier);
    const fills = [
      ElioTokens.answerRed,
      ElioTokens.answerBlue,
      ElioTokens.answerGreen,
      ElioTokens.answerYellow,
    ];
    const onFills = [
      ElioTokens.onAnswerRed,
      ElioTokens.onAnswerBlue,
      ElioTokens.onAnswerGreen,
      ElioTokens.onAnswerYellow,
    ];
    const shapes = [
      Icons.change_history_rounded,
      Icons.diamond_rounded,
      Icons.circle,
      Icons.stop_rounded,
    ];
    final count = q.options.length.clamp(0, 4);
    Widget tile(int i) => Expanded(
      child: Padding(
        padding: EdgeInsets.only(
          left: i.isOdd ? 6 : 0,
          right: i.isEven ? 6 : 0,
        ),
        child: Semantics(
          button: true,
          label: q.options[i],
          excludeSemantics: true,
          child: Container(
            key: ValueKey('answer_$i'),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: fills[i],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: HSLColor.fromColor(fills[i])
                      .withLightness(
                        HSLColor.fromColor(fills[i]).lightness * 0.7,
                      )
                      .toColor(),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => n.selectOption(i),
                child: SizedBox.expand(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Icon(shapes[i], color: onFills[i], size: 20),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            q.options[i],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onFills[i],
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
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
        ),
      ),
    );
    return _Shell(
      child: Column(
        key: const ValueKey('quiz_question'),
        children: [
          _Header(
            logo: true,
            onStop: onStop,
            chips: [
              _InfoChip(
                'Question ${state.questionIndex + 1} of ${state.totalQuestions}',
              ),
              _InfoChip('Scanned: ${state.scan?.displayName ?? '-'}'),
              ?_notThisChip(context, state, n),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: SvgPicture.asset(
                  'assets/illustrations/control/bottle_buddy_happy.svg',
                  height: 52,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MULTIPLE CHOICE · ${_level(state.difficulty).toUpperCase()}',
                      style: TextStyle(
                        color: p.primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      q.question,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < 2 && i < count; i++) tile(i),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 2; i < 4 && i < count; i++) tile(i),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _QuestionFooter(
            state: state,
            readText:
                '${q.question} ${[for (var i = 0; i < q.options.length; i++) '${'ABCD'[i % 4]}. ${q.options[i]}'].join('. ')}',
          ),
        ],
      ),
    );
  }
}

class _QuestionFooter extends ConsumerWidget {
  const _QuestionFooter({
    required this.state,
    required this.readText,
    this.trailing = const [],
  });
  final WasteQuizUiState state;
  final String readText;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Narrow popups: Read it to me shows its icon only.
    final compact = MediaQuery.sizeOf(context).width < 820;
    final p = context.elio;
    final n = ref.read(wasteQuizProvider.notifier);
    final skip =
        ref.watch(appPreferencesProvider).skipAllowed && !state.answered;
    final read = _Pill(
      key: const ValueKey('quiz_read'),
      icon: Icons.volume_up_outlined,
      label: 'Read it to me',
      iconOnly: compact,
      onTap: () => n.listen(readText),
    );
    if (MediaQuery.sizeOf(context).width < 520) {
      // Portrait: the actions wrap; progress and the trophy note are left out.
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          if (skip)
            TextButton(
              key: const ValueKey('quiz_skip'),
              onPressed: n.skipQuestion,
              child: Text(state.isLastQuestion ? 'Skip and finish' : 'Skip'),
            ),
          ...trailing.where((w) => w is! SizedBox),
          read,
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < state.totalQuestions; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Container(
                  width: i == state.questionIndex ? 22 : 10,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i <= state.questionIndex
                        ? p.primary
                        : p.borderMedium,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: ElioTokens.answerYellow,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    state.question?.type == QuizQuestionType.essay
                        ? 'Up to +10 trophies for a full answer'
                        : '+10 trophies for a right answer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (skip) ...[
          TextButton(
            key: const ValueKey('quiz_skip'),
            onPressed: n.skipQuestion,
            style: TextButton.styleFrom(
              foregroundColor: p.textSecondary,
              backgroundColor: Colors.transparent,
            ),
            child: Text(state.isLastQuestion ? 'Skip and finish' : 'Skip'),
          ),
          const SizedBox(width: 6),
        ],
        ...trailing,
        read,
      ],
    );
  }
}

// ── Essay input (not in Figma: the question shell with a text field) ────────

class _EssayInputView extends ConsumerWidget {
  const _EssayInputView({
    required this.state,
    required this.controller,
    required this.since,
    this.onStop,
  });
  final WasteQuizUiState state;
  final TextEditingController controller;
  final DateTime? since;
  final VoidCallback? onStop;

  static const wordLimit = 150;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final q = state.question!;
    final n = ref.read(wasteQuizProvider.notifier);
    final text = controller.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    final grading = state.essaySubmitted && state.sendingChat;
    final canSend =
        words > 0 &&
        words <= wordLimit &&
        !state.sendingChat &&
        !state.essaySubmitted;
    return _Shell(
      // The keyboard is open on a short screen when the popup has little height left
      // (Scaffold resizes the body, so the insets are already gone here).
      child: LayoutBuilder(
        builder: (context, c) {
          final typingShort = c.maxHeight < 200;
          return Column(
            key: const ValueKey('quiz_essay_input'),
            children: [
              _Header(
                logo: true,
                onStop: onStop,
                chips: [
                  _InfoChip(
                    'Question ${state.questionIndex + 1} of ${state.totalQuestions}',
                  ),
                  _InfoChip('Scanned: ${state.scan?.displayName ?? '-'}'),
                  ?_notThisChip(context, state, n),
                ],
              ),
              // Keyboard open on a short screen: the field and the actions only (the question is above it once closed).
              if (!typingShort) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: SvgPicture.asset(
                        'assets/illustrations/home/bulb_buddy.svg',
                        height: 48,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESSAY · ${_level(state.difficulty).toUpperCase()} · MAX $wordLimit WORDS',
                            style: TextStyle(
                              color: p.primaryText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            q.question,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              // Keep the editor mounted when keyboard resizing changes the layout.
              Expanded(
                key: const ValueKey('quiz_essay_editor'),
                child: grading
                    ? Container(
                        key: const ValueKey('quiz_essay_grading'),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.surfaceRaised,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: p.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'ELIOS AI is grading your answer…',
                              style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('quiz_essay_field'),
                              controller: controller,
                              enabled: !state.essaySubmitted,
                              expands: true,
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Type your answer here…',
                                filled: true,
                                fillColor: p.surfaceRaised,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          if (typingShort) ...[
                            const SizedBox(width: 8),
                            _GreenButton(
                              key: const ValueKey('quiz_essay_submit'),
                              label: 'Submit',
                              icon: Icons.send_rounded,
                              onTap: canSend
                                  ? () => n.submitEssay(controller.text)
                                  : null,
                            ),
                          ],
                        ],
                      ),
              ),
              if (!typingShort) ...[
                const SizedBox(height: 8),
                _QuestionFooter(
                  state: state,
                  readText: q.question,
                  trailing: [
                    Text(
                      '$words / $wordLimit words',
                      style: TextStyle(
                        color: words > wordLimit
                            ? p.errorText
                            : p.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      key: const ValueKey('quiz_essay_clear'),
                      icon: Icons.backspace_outlined,
                      label: 'Clear',
                      iconOnly: MediaQuery.sizeOf(context).width < 820,
                      onTap: state.essaySubmitted ? null : controller.clear,
                    ),
                    const SizedBox(width: 8),
                    _GreenButton(
                      key: const ValueKey('quiz_essay_submit'),
                      label: 'Submit',
                      icon: Icons.send_rounded,
                      onTap: canSend
                          ? () => n.submitEssay(controller.text)
                          : null,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Hazard and mismatch confirms (not in Figma: the same shell) ─────────────

class _ConfirmShell extends StatelessWidget {
  const _ConfirmShell({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.onStop,
    this.danger = false,
    this.state,
  });
  final String title, body;
  final List<Widget> actions;
  final VoidCallback? onStop;
  final bool danger;
  final WasteQuizUiState? state;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final c = danger ? p.error : p.primary;
    return _Shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            logo: true,
            onStop: onStop,
            chips: [
              if (state != null)
                _InfoChip('Scanned: ${state!.scan?.displayName ?? '-'}'),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      ),
    );
  }
}

class _HazardView extends ConsumerWidget {
  const _HazardView({required this.state, this.onStop});
  final WasteQuizUiState state;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(wasteQuizProvider.notifier);
    return _ConfirmShell(
      key: const ValueKey('quiz_hazard'),
      danger: true,
      onStop: onStop,
      state: state,
      title: 'Possibly hazardous (B3): ${state.scan?.displayName ?? ''}',
      body:
          "Don't take it apart or put it in a normal bin. Ask staff to handle it. Continue the quiz about this item?",
      actions: [
        _Pill(
          key: const ValueKey('quiz_scan_again'),
          icon: Icons.refresh_rounded,
          label: 'Scan again',
          onTap: n.dismiss,
        ),
        _GreenButton(
          key: const ValueKey('quiz_continue'),
          label: 'Continue quiz',
          onTap: n.confirmHazard,
        ),
      ],
    );
  }
}

class _MismatchView extends ConsumerWidget {
  const _MismatchView({required this.state, this.onStop});
  final WasteQuizUiState state;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(wasteQuizProvider.notifier);
    final detector = state.mismatchDetector ?? '-';
    final detectorCategory = ScannedWaste.detectorCategory(detector) ?? '-';
    final gemmaCategory = state.scan?.rawCategory ?? '-';
    return _ConfirmShell(
      key: const ValueKey('quiz_mismatch'),
      onStop: onStop,
      state: state,
      title: 'Which bin is right?',
      body:
          'The detector says $detector ($detectorCategory). ELIOS AI says ${state.scan?.displayName ?? '-'} ($gemmaCategory). Pick the right one.',
      actions: [
        _Pill(
          icon: Icons.refresh_rounded,
          label: 'Scan again',
          onTap: n.dismiss,
        ),
        _Pill(
          icon: Icons.auto_awesome,
          label: 'Use ELIOS AI ($gemmaCategory)',
          onTap: () => n.resolveMismatch(useDetector: false),
        ),
        _GreenButton(
          label: 'Use detector ($detectorCategory)',
          icon: null,
          onTap: () => n.resolveMismatch(useDetector: true),
        ),
      ],
    );
  }
}

/// The session result: the existing result card (trophies, PDF, Scan lagi) in the shell.
class _FinishedView extends StatelessWidget {
  const _FinishedView({required this.state, this.onStop, this.onRescan});
  final WasteQuizUiState state;
  final VoidCallback? onStop;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) => _Shell(
      child: Column(
        children: [
          _Header(
            logo: true,
            onStop: onStop,
            chips: [_InfoChip(state.notice != null ? 'Scan' : 'Quiz complete')],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: _ResultCard(
                state: state,
                onClose: ref.read(wasteQuizProvider.notifier).dismiss,
                onRescan: onRescan,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Review: MC right / wrong and essay (398:3300, 417:6298, 417:6944) ───────

class _ReviewView extends ConsumerWidget {
  const _ReviewView({
    required this.state,
    required this.chat,
    required this.onListen,
    this.onStop,
  });
  final WasteQuizUiState state;
  final Widget chat;
  final ValueChanged<String> onListen;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(wasteQuizProvider.notifier);
    final q = state.question!;
    final essay = q.type == QuizQuestionType.essay;
    final ex = state.currentExplanation;
    final listenText = [
      if (ex != null) ...[
        if (essay) ex.essayFeedback ?? ex.summary else ex.summary,
        if (ex.selectedAnswerFeedback.isNotEmpty) ex.selectedAnswerFeedback,
      ] else if (q.bankId == null || q.bankReviewed)
        q.explanation,
    ].join(' ');
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final left = Column(
      children: [
        _ResultBanner(state: state),
        const SizedBox(height: 8),
        Expanded(child: _Document(state: state)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _Pill(
                    key: const ValueKey('quiz_back'),
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    iconOnly: narrow,
                    onTap: n.minimize,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _Pill(
                      key: const ValueKey('quiz_listen'),
                      icon: Icons.volume_up_outlined,
                      label: 'Listen to explanation',
                      iconOnly: narrow,
                      onTap: () => onListen(listenText),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: _GreenButton(
                  key: const ValueKey('quiz_next'),
                  label: state.isLastQuestion ? 'Finish quiz' : 'Next question',
                  onTap: state.sendingChat ? null : n.nextQuestion,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    return _Shell(
      child: Column(
        key: ValueKey(essay ? 'quiz_review_essay' : 'quiz_review'),
        children: [
          _Header(
            onStop: onStop,
            chips: [
              _InfoChip(
                'Question ${state.questionIndex + 1} of ${state.totalQuestions} · ${essay ? 'Essay review' : 'Review'}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => c.maxWidth < 600
                  ? _NarrowTabs(
                      explanation: left,
                      coach: chat,
                    ) // portrait: one pane at a time
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: c.maxWidth >= 1000 ? 320 : 270,
                          child: chat,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Portrait (under 600 dp): Explanation and ELIOS AI coach as two tabs.
class _NarrowTabs extends StatefulWidget {
  const _NarrowTabs({required this.explanation, required this.coach});
  final Widget explanation, coach;

  @override
  State<_NarrowTabs> createState() => _NarrowTabsState();
}

class _NarrowTabsState extends State<_NarrowTabs> {
  bool _coach = false;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Flexible(
            child: _Pill(
              key: const ValueKey('tab_explanation'),
              icon: Icons.article_outlined,
              label: 'Explanation',
              small: true,
              onTap: () => setState(() => _coach = false),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: _Pill(
              key: const ValueKey('tab_coach'),
              icon: Icons.chat_bubble_outline_rounded,
              label: 'ELIOS AI coach',
              small: true,
              onTap: () => setState(() => _coach = true),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Expanded(child: _coach ? widget.coach : widget.explanation),
    ],
  );
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.state});
  final WasteQuizUiState state;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final q = state.question!;
    final ex = state.currentExplanation;
    final essay = q.type == QuizQuestionType.essay;
    // Pending grade (decision 0031): no score yet, or grading still running.
    final pending = essay && (ex == null || ex.essayScore == null);
    final right = !essay && state.selectedOption == q.correctIndex;
    final picked =
        !essay &&
            state.selectedOption != null &&
            state.selectedOption! < q.options.length
        ? q.options[state.selectedOption!]
        : '';
    final (
      String title,
      String sub,
      String art,
      String medal,
      int points,
      Color c,
      String key,
    ) = switch ((essay, pending, right)) {
      (true, true, _) => (
        'Waiting for grading',
        'ELIOS AI has not graded this answer yet. It is saved and graded later.',
        'assets/illustrations/home/bulb_buddy.svg',
        'assets/illustrations/home/medal_locked.svg',
        0,
        p.borderStrong,
        'banner_pending',
      ),
      (true, false, _) => (
        'Score ${ex!.essayScore} / 10',
        ex.essayFeedback ?? '',
        'assets/illustrations/home/bulb_buddy.svg',
        ex.essayScore! > 0
            ? 'assets/illustrations/home/medal_gold.svg'
            : 'assets/illustrations/home/medal_locked.svg',
        ex.essayScore!,
        ex.essayScore! >= 6 ? p.primary : ElioTokens.answerYellow,
        'banner_essay',
      ),
      (false, _, true) => (
        'Correct!',
        'You chose “$picked”.',
        'assets/illustrations/control/bottle_buddy_happy.svg',
        'assets/illustrations/home/medal_gold.svg',
        10,
        p.primary,
        'banner_good',
      ),
      _ => (
        'Not quite',
        'The right answer is “${q.options[q.correctIndex]}”.',
        'assets/illustrations/control/bottle_buddy_sad.svg',
        'assets/illustrations/home/medal_locked.svg',
        0,
        p.error,
        'banner_bad',
      ),
    };
    final gold = points > 0;
    return Container(
      key: ValueKey(key),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c),
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: SvgPicture.asset(art, height: 44)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: key == 'banner_bad' ? p.errorText : p.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            key: const ValueKey('banner_trophies'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: gold
                  ? ElioTokens.answerYellow.withValues(alpha: 0.14)
                  : p.surfaceRaised,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: gold ? ElioTokens.answerYellow : p.borderMedium,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(child: SvgPicture.asset(medal, height: 22)),
                const SizedBox(width: 4),
                Text(
                  '+$points',
                  style: TextStyle(
                    color: gold ? p.secondaryText : p.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrolling "Detailed explanation" (essay: "Answer review"), laid out like a PDF page.
class _Document extends StatefulWidget {
  const _Document({required this.state});
  final WasteQuizUiState state;

  @override
  State<_Document> createState() => _DocumentState();
}

class _DocumentState extends State<_Document> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final s = widget.state;
    final q = s.question!;
    final ex = s.currentExplanation;
    final essay = q.type == QuizQuestionType.essay;
    final right = !essay && s.selectedOption == q.correctIndex;
    final picked =
        !essay &&
            s.selectedOption != null &&
            s.selectedOption! < q.options.length
        ? q.options[s.selectedOption!]
        : null;
    final rightAnswer = essay ? null : q.options[q.correctIndex];

    TextStyle label() => TextStyle(
      color: p.textSecondary,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
    );
    Widget chip(bool good) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (good ? p.primary : p.error).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            good ? Icons.check_rounded : Icons.close_rounded,
            size: 12,
            color: good ? p.primaryText : p.errorText,
          ),
          const SizedBox(width: 3),
          Text(
            good ? 'Correct' : 'Wrong',
            style: TextStyle(
              color: good ? p.primaryText : p.errorText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    Widget checkRow(
      String l,
      String value, {
      TextStyle? style,
      Widget? trailing,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width < 520 ? 96 : 132,
            child: Text(l, style: label()),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  style ??
                  TextStyle(
                    color: p.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
    Widget heading(String t, Color c) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(
        t,
        style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
    Widget para(String t) => Text(
      t,
      textAlign: TextAlign.justify,
      style: TextStyle(color: p.textPrimary, fontSize: 13, height: 1.5),
    );
    Widget cell(
      String t, {
      bool head = false,
      Color? color,
      bool strong = false,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        t,
        style: head
            ? label()
            : TextStyle(
                color: color ?? p.textPrimary,
                fontSize: 12,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
              ),
      ),
    );
    Widget table(
      String caption,
      List<String> heads,
      List<(List<String>, Color?)> rows, {
      Map<int, TableColumnWidth>? widths,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          caption,
          style: TextStyle(
            color: p.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Table(
            key: const ValueKey('doc_table'),
            columnWidths: widths,
            border: TableBorder.all(color: p.borderSubtle),
            children: [
              TableRow(
                decoration: BoxDecoration(color: p.surfaceRaised),
                children: [for (final h in heads) cell(h, head: true)],
              ),
              for (final (cells, c) in rows)
                TableRow(
                  decoration: BoxDecoration(color: c?.withValues(alpha: 0.10)),
                  children: [
                    for (final t in cells)
                      cell(
                        t,
                        color: c == null
                            ? null
                            : (c == p.error ? p.errorText : p.primaryText),
                        strong: c != null,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );

    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              essay ? 'Answer review' : 'Detailed explanation',
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: Text(
              'QUESTION ${s.questionIndex + 1} OF ${s.totalQuestions} · ${essay ? 'ESSAY' : _level(s.difficulty).toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: label(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Container(height: 2, color: p.primary),
      const SizedBox(height: 8),
      Container(
        key: const ValueKey('doc_answer_check'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            checkRow('QUESTION', q.question),
            if (essay)
              checkRow('YOUR ANSWER', s.essayAnswer ?? '')
            else ...[
              checkRow(
                'YOUR ANSWER',
                picked ?? '-',
                style: right
                    ? TextStyle(
                        color: p.primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )
                    : TextStyle(
                        color: p.errorText,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: p.errorText,
                      ),
                trailing: chip(right),
              ),
              if (!right)
                checkRow(
                  'CORRECT ANSWER',
                  rightAnswer!,
                  style: TextStyle(
                    color: p.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  trailing: chip(true),
                ),
            ],
          ],
        ),
      ),
      if (ex == null) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: p.primary,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Loading the explanation…',
                style: TextStyle(color: p.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ] else ...[
        if (essay) ...[
          if (ex.essayScore == null) ...[
            const SizedBox(height: 10),
            para(
              'Your answer is saved. ELIOS AI grades it when it is ready; no trophies until then.',
            ),
          ] else if ((ex.essayFeedback ?? '').isNotEmpty) ...[
            heading('Feedback', p.primaryText),
            para(ex.essayFeedback!),
          ],
        ] else if (right) ...[
          const SizedBox(height: 10),
          para(ex.summary),
        ] else ...[
          // Only a reviewed reason; without one the heading is hidden (decision 0175).
          if (ex.selectedAnswerFeedback.isNotEmpty) ...[
            heading('Why your answer is not right', p.errorText),
            para(ex.selectedAnswerFeedback),
          ],
          heading('Why the correct answer is right', p.primaryText),
          para(
            ex.correctAnswerReason.isNotEmpty
                ? ex.correctAnswerReason
                : ex.summary,
          ),
        ],
        if (ex.quote != null) ...[
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('doc_quote'),
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: p.primary, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“${ex.quote}”',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 12,
                      color: p.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      [
                        'ELIOS module',
                        if (ex.sourceSection != null)
                          'section ${ex.sourceSection}',
                        if (ex.sourcePage != null) 'page ${ex.sourcePage}',
                      ].join(' · '),
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (essay && (ex.rubricRows?.isNotEmpty ?? false))
          table(
            'Table 1. Scoring breakdown',
            const ['CRITERIA', 'FEEDBACK', 'SCORE'],
            [
              for (final r in ex.rubricRows!)
                (
                  [r.criterion, r.comment, '${r.awardedScore} / ${r.maxScore}'],
                  r.awardedScore >= r.maxScore ? p.primary : null,
                ),
            ],
            widths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(4),
              2: IntrinsicColumnWidth(),
            },
          )
        else if (!essay && right && ex.comparisonRows.isNotEmpty)
          table(
            'Table 1. Where ${s.scan?.displayName ?? 'this item'} goes',
            const ['BIN', 'EXAMPLES', 'ACCEPTS'],
            [
              for (final r in ex.comparisonRows)
                (
                  [r.bin, r.material, r.accepted],
                  r.isCorrect ? p.primary : null,
                ),
            ],
            widths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(4),
            },
          )
        else if (!essay && !right)
          table(
            'Table 1. The answer options',
            const ['OPTION', 'STATUS'],
            [
              for (final r in QuizExplanationService.optionRows(
                q,
                s.selectedOption,
              ))
                (
                  [
                    r.option,
                    r.correct
                        ? 'Correct answer'
                        : (r.picked ? 'Your answer' : '—'),
                  ],
                  r.correct ? p.primary : (r.picked ? p.error : null),
                ),
            ],
            widths: const {0: FlexColumnWidth(5), 1: IntrinsicColumnWidth()},
          ),
        if (ex.learningTakeaway.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, size: 14, color: p.primaryText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ex.learningTakeaway,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _SourceChip(explanation: ex, essay: essay),
        ),
      ],
    ];
    return Container(
      key: const ValueKey('quiz_document'),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderSubtle),
      ),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(14, 12, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.explanation, required this.essay});
  final QuizExplanation explanation;
  final bool essay;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final bank = explanation.groundingStatus == GroundingStatus.bankGrounded;
    final (icon, text, sub) = essay
        ? (Icons.auto_awesome, 'AI graded · check with your teacher', null)
        : bank
        ? (
            Icons.verified_outlined,
            'Reviewed question bank',
            explanation.bankId,
          )
        : (Icons.auto_awesome, 'AI generated · not reviewed', null);
    return Row(
      key: const ValueKey('doc_source'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (bank && !essay ? p.primary : p.borderStrong).withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: bank && !essay ? p.primaryText : p.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: bank && !essay ? p.primaryText : p.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (sub != null) ...[
          const SizedBox(width: 8),
          Text(sub, style: TextStyle(color: p.textSecondary, fontSize: 11)),
        ],
      ],
    );
  }
}

// ── ELIOS AI coach (Phone/Chat message 413:6148, shadcn Message pattern) ────

class _Coach extends StatelessWidget {
  const _Coach({
    required this.state,
    required this.ask,
    required this.speaking,
    required this.onListen,
    required this.onSend,
  });
  final WasteQuizUiState state;
  final TextEditingController ask;
  final String? speaking;
  final ValueChanged<String> onListen, onSend;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final essay = state.question?.type == QuizQuestionType.essay;
    final suggestions = essay
        ? const ['Show a full-mark answer', 'Explain key terms']
        : const ['Give me a hint', 'Say it simpler'];
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    final initial = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()[0].toUpperCase()
        : 'Y';
    return Container(
      key: const ValueKey('quiz_coach'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const EliosAiBadge(size: 28),
              const SizedBox(width: 8),
              Text(
                'ELIOS AI coach',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            // Newest at the bottom; older messages scroll up.
            child: ListView(
              reverse: true,
              children: [
                if (state.sendingChat)
                  _ChatMessageTile(
                    text: '…',
                    fromAi: true,
                    initial: initial,
                    status: null,
                  ),
                for (final m in state.messages.reversed)
                  _ChatMessageTile(
                    text: m.text,
                    fromAi: !m.isUser,
                    initial: initial,
                    status: m.isUser
                        ? 'Sent'
                        : (speaking == m.text ? 'Playing' : null),
                    onListen: m.isUser ? null : () => onListen(m.text),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final t in suggestions)
                _Pill(
                  icon: Icons.add_rounded,
                  label: t,
                  small: true,
                  onTap: state.sendingChat ? null : () => onSend(t),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 38,
            padding: const EdgeInsets.only(left: 12, right: 3),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: p.borderMedium),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('quiz_ask'),
                    controller: ask,
                    style: TextStyle(color: p.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: essay
                          ? 'Ask ELIOS AI about your score…'
                          : 'Ask ELIOS AI…',
                      hintStyle: TextStyle(color: p.textTertiary, fontSize: 12),
                    ),
                    onSubmitted: onSend,
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Send',
                  excludeSemantics: true,
                  child: InkResponse(
                    key: const ValueKey('quiz_send'),
                    onTap: () => onSend(ask.text),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: p.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        size: 14,
                        color: p.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-anchored avatar, sender header, bubble, footer (Listen, Copy, status).
class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({
    required this.text,
    required this.fromAi,
    required this.initial,
    required this.status,
    this.onListen,
  });
  final String text;
  final bool fromAi;
  final String initial;
  final String? status;
  final VoidCallback? onListen;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final avatar = fromAi
        ? const EliosAiBadge(size: 22)
        : Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
            child: Text(
              initial,
              style: TextStyle(
                color: p.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
    Widget icon(IconData i, String tip, VoidCallback onTap) => Semantics(
      button: true,
      label: tip,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(i, size: 14, color: p.textSecondary),
        ),
      ),
    );
    final content = Column(
      crossAxisAlignment: fromAi
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        if (fromAi)
          Text(
            'ELIOS AI',
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: fromAi ? p.surface : p.primaryActive,
            borderRadius: BorderRadius.circular(12),
            border: fromAi ? Border.all(color: p.borderSubtle) : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: fromAi ? p.textPrimary : p.surface,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
        if (fromAi && onListen != null || status != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fromAi && onListen != null) ...[
                icon(Icons.volume_up_outlined, 'Listen', onListen!),
                icon(
                  Icons.copy_rounded,
                  'Copy',
                  () => Clipboard.setData(ClipboardData(text: text)),
                ),
              ],
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == 'Playing')
                        Icon(
                          Icons.graphic_eq_rounded,
                          size: 12,
                          color: p.primaryText,
                        ),
                      const SizedBox(width: 3),
                      Text(
                        status!,
                        style: TextStyle(
                          color: status == 'Playing'
                              ? p.primaryText
                              : p.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: fromAi
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: fromAi
            ? [avatar, const SizedBox(width: 6), Flexible(child: content)]
            : [Flexible(child: content), const SizedBox(width: 6), avatar],
      ),
    );
  }
}

/// "Not this?": pick the right object from the question bank (restyled, not in Figma).
Future<void> _pickCorrectItem(
  BuildContext context,
  WasteQuizNotifier notifier,
) async {
  final bank = await QuestionBank.load();
  if (!context.mounted) return;
  final picked = await showDialog<({String name, String? category})>(
    context: context,
    builder: (context) {
      final p = context.elio;
      return Dialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 380),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              key: const ValueKey('quiz_picker'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const EliosAiBadge(size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Which item is this?',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _Pill(
                      icon: Icons.close_rounded,
                      label: 'Cancel',
                      small: true,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in bank.pickerItems)
                          _Pill(
                            icon: Icons.label_outline_rounded,
                            label: item.name,
                            onTap: () => Navigator.pop(context, item),
                          ),
                      ],
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
  if (picked != null) {
    notifier.correctItem(picked.name, category: picked.category);
  }
}
