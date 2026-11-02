// The phone quiz popups (Figma 398:3042 question, 398:3300 explanation, Q2
// 390:4561 wrong answer, Q2 389:3489 essay review). Same provider and
// notifier calls as the older popup: only the look and the English text are
// new. Phases the Figma does not draw (identifying, hazard and mismatch
// questions, essay input, the final result) stay on [WasteQuizPopup].
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/home_stats.dart' show HomeBin;
import '../../../models/quiz_explanation.dart';
import '../../../providers/waste_quiz_provider.dart';
import '../../../services/gemma_quiz_service.dart'
    show QuizDifficulty, QuizQuestionType;
import '../../../theme/elio_tokens.dart';
import '../../learn/learn_ui.dart' show LearnTheme;
import '../../waste_quiz_popup.dart';
import 'phone_control.dart' show EliosAiBadge;

class PhoneQuizPopup extends ConsumerWidget {
  const PhoneQuizPopup({super.key, required this.onStop, this.onRescan});
  final VoidCallback onStop;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wasteQuizProvider);
    if (state.phase == WasteQuizPhase.idle || state.minimized) {
      return const SizedBox.shrink();
    }
    final q = state.question;
    final mc = q?.type == QuizQuestionType.multipleChoice;
    final explaining = state.phase == WasteQuizPhase.explaining && q != null;
    final asking =
        state.phase == WasteQuizPhase.active &&
        q != null &&
        mc &&
        !state.answered;
    if (!explaining && !asking) {
      return WasteQuizPopup(
        onStop: onStop,
        showLauncher: false,
        onRescan: onRescan,
      );
    }
    final p = context.elio;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: p.isDark ? 0.55 : 0.35),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Material(
              key: const ValueKey('phone_quiz_popup'),
              color: p.surface,
              elevation: 8,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    _Header(state: state, onStop: onStop),
                    const SizedBox(height: 8),
                    Expanded(
                      child: asking
                          ? _Question(state: state)
                          : _Explanation(state: state),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.state, required this.onStop});
  final WasteQuizUiState state;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final n = ref.read(wasteQuizProvider.notifier);
    final essay = state.question?.type == QuizQuestionType.essay;
    final progress =
        'Question ${state.questionIndex + 1} of ${state.totalQuestions}';
    final label = state.phase == WasteQuizPhase.explaining
        ? '$progress · ${essay ? 'Essay review' : 'Review'}'
        : progress;
    Widget chip(String t) => Flexible(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
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
    return SizedBox(
      height: 36,
      child: Row(
        children: [
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
          chip(label),
          const SizedBox(width: 8),
          chip('Scanned: ${state.scan?.displayName ?? '-'}'),
          const Spacer(),
          GestureDetector(
            key: const ValueKey('quiz_voice'),
            onTap: n.toggleVoice,
            child: Semantics(
              toggled: state.voiceOn,
              label: 'Voice',
              excludeSemantics: true,
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
                      Container(
                        width: 34,
                        height: 20,
                        padding: const EdgeInsets.all(2),
                        alignment: state.voiceOn
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: state.voiceOn ? p.primary : p.borderMedium,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: p.surface,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // The small STOP: the same emergency stop, always in reach while a quiz is open.
          Semantics(
            button: true,
            label: 'Berhenti darurat',
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('quiz_stop'),
              onTap: onStop,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.error,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
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
          ),
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
      ),
    );
  }
}

// ── Question ────────────────────────────────────────────────────────────────

class _Question extends ConsumerWidget {
  const _Question({required this.state});
  final WasteQuizUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final q = state.question!;
    final n = ref.read(wasteQuizProvider.notifier);
    final level = switch (state.difficulty) {
      QuizDifficulty.easy => 'EASY',
      QuizDifficulty.medium => 'MEDIUM',
      _ => 'HARD',
    };
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
                  color: Color.lerp(fills[i], Colors.black, 0.25)!,
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
    final count = q.options.length.clamp(0, 4);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(
              'assets/illustrations/control/bottle_buddy.svg',
              height: 52,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MULTIPLE CHOICE · $level',
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
                  children: [for (var i = 0; i < 2 && i < count; i++) tile(i)],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [for (var i = 2; i < 4 && i < count; i++) tile(i)],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < state.totalQuestions; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Container(
                width: i == state.questionIndex ? 22 : 10,
                height: 8,
                decoration: BoxDecoration(
                  color: i <= state.questionIndex ? p.primary : p.borderMedium,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
            const SizedBox(width: 12),
            _TrophyChip(
              text: '+10 trophies for a right answer',
              outlined: true,
            ),
            const Spacer(),
            _Pill(
              key: const ValueKey('quiz_read'),
              icon: Icons.volume_up_outlined,
              label: 'Read it to me',
              onTap: () => n.listen(
                '${q.question} ${[for (var i = 0; i < q.options.length; i++) '${'ABCD'[i % 4]}. ${q.options[i]}'].join('. ')}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Explanation (multiple choice and essay) ─────────────────────────────────

class _Explanation extends ConsumerStatefulWidget {
  const _Explanation({required this.state});
  final WasteQuizUiState state;

  @override
  ConsumerState<_Explanation> createState() => _ExplanationState();
}

class _ExplanationState extends ConsumerState<_Explanation> {
  final _ask = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ask.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    ref.read(wasteQuizProvider.notifier).sendChatMessage(t);
    _ask.clear();
  }

  static HomeBin? _binOf(String id) => switch (id) {
    'organic' => HomeBin.organik,
    'inorganic' => HomeBin.anorganik,
    'hazardous' => HomeBin.b3,
    _ => null,
  };

  /// The bin an answer names, if it names one ("Anorganik" before "Organik").
  static HomeBin? _binNamed(String text) {
    final t = text.toLowerCase();
    if (t.contains('anorganik') || t.contains('inorganic')) {
      return HomeBin.anorganik;
    }
    if (t.contains('organik') || t.contains('organic')) return HomeBin.organik;
    if (t.contains('b3') || t.contains('hazard')) return HomeBin.b3;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final p = context.elio;
    final n = ref.read(wasteQuizProvider.notifier);
    final q = state.question!;
    final ex = state.currentExplanation;
    final essay = q.type == QuizQuestionType.essay;
    final correct = !essay && state.selectedOption == q.correctIndex;
    final rightBin =
        _binOf(state.scan?.category?.id ?? '') ??
        _binNamed(
          q.options.isEmpty
              ? ''
              : q.options[q.correctIndex.clamp(0, q.options.length - 1)],
        );
    final picked =
        !essay &&
            state.selectedOption != null &&
            state.selectedOption! < q.options.length
        ? _binNamed(q.options[state.selectedOption!])
        : null;
    final pickedText =
        !essay &&
            state.selectedOption != null &&
            state.selectedOption! < q.options.length
        ? q.options[state.selectedOption!]
        : '';
    final listenText = essay
        ? (ex?.essayFeedback ?? ex?.summary ?? '')
        : (ex?.summary.isNotEmpty ?? false ? ex!.summary : q.explanation);
    final left = essay
        ? _essayLeft(p, state, ex)
        : _mcLeft(
            p,
            state,
            ex,
            correct,
            rightBin,
            picked,
            pickedText,
            q.explanation,
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(child: SingleChildScrollView(child: left)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Pill(
                    key: const ValueKey('quiz_back'),
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    onTap: n
                        .minimize, // returns to the robot; the Quiz button reopens it
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    key: const ValueKey('quiz_listen'),
                    icon: Icons.volume_up_outlined,
                    label: 'Listen',
                    onTap: () => n.listen(listenText),
                  ),
                  const Spacer(),
                  _NextButton(
                    key: const ValueKey('quiz_next'),
                    label: state.isLastQuestion ? 'Finish' : 'Next question',
                    onTap: n.nextQuestion,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 270, child: _coach(p, state, n, essay)),
      ],
    );
  }

  Widget _banner(
    ElioPalette p, {
    required bool good,
    bool neutral = false,
    required String small,
    required String title,
    required String sub,
    required String trophies,
    Widget? art,
  }) {
    final c = neutral ? p.borderStrong : (good ? p.primary : p.error);
    return Container(
      key: ValueKey(
        neutral ? 'banner_wait' : (good ? 'banner_good' : 'banner_bad'),
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c),
      ),
      child: Row(
        children: [
          art ??
              SvgPicture.asset(
                'assets/illustrations/control/bottle_buddy.svg',
                height: 44,
              ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  small,
                  style: TextStyle(
                    color: good ? p.primaryText : p.errorText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
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
          _TrophyChip(text: trophies, outlined: true, big: true),
        ],
      ),
    );
  }

  Widget _mcLeft(
    ElioPalette p,
    WasteQuizUiState s,
    QuizExplanation? ex,
    bool correct,
    HomeBin? right,
    HomeBin? picked,
    String pickedText,
    String fallback,
  ) {
    final why = (ex?.summary.isNotEmpty ?? false) ? ex!.summary : fallback;
    const bins = [
      (
        HomeBin.anorganik,
        'Anorganik',
        'Plastic, glass, metal',
        'bin_anorganik',
      ),
      (HomeBin.organik, 'Organik', 'Food, leaves', 'bin_organik'),
      (HomeBin.b3, 'B3', 'Batteries, e-waste', 'bin_b3'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _banner(
          p,
          good: correct,
          small: correct ? 'NICE SORTING!' : 'NOT QUITE',
          title: correct
              ? 'Correct! ${_name(right)} bin'
              : 'The right bin is ${_name(right)}',
          sub: pickedText.isEmpty ? '' : 'You chose "$pickedText".',
          trophies: correct ? '+10' : '+0',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 12,
              color: p.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'WHY IT GOES THERE',
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          why,
          style: TextStyle(color: p.textPrimary, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final b in bins) ...[
                if (b.$1 != bins.first.$1) const SizedBox(width: 8),
                Expanded(
                  child: _BinCard(
                    bin: b.$1,
                    name: b.$2,
                    sub: b.$3,
                    art: b.$4,
                    isRight: b.$1 == right,
                    isPicked: !correct && b.$1 == picked,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _name(HomeBin? b) => switch (b) {
    HomeBin.organik => 'Organik',
    HomeBin.b3 => 'B3',
    HomeBin.anorganik => 'Anorganik',
    _ => 'right',
  };

  Widget _essayLeft(ElioPalette p, WasteQuizUiState s, QuizExplanation? ex) {
    final score = ex?.essayScore ?? 0;
    final rows = ex?.rubricRows ?? const <RubricRow>[];
    final max = rows.isEmpty ? 10 : rows.fold<int>(0, (a, r) => a + r.maxScore);
    final good = max > 0 && score / max >= 0.5;
    final grading = ex?.essayScore == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _banner(
          p,
          good: good && !grading,
          neutral: grading,
          small: grading ? 'GRADING' : (good ? 'GOOD ANSWER' : 'KEEP GOING'),
          title: grading ? 'Checking your answer...' : 'Score $score / $max',
          sub: grading
              ? 'The score appears here when ELIOS AI has read it.'
              : (ex?.essayFeedback ?? ''),
          trophies: '+$score',
          art: SvgPicture.asset(
            'assets/illustrations/home/bulb_buddy.svg',
            height: 44,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 12,
              color: p.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'YOUR ANSWER, REVIEWED',
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: p.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '"${s.essayAnswer ?? ''}"',
            style: TextStyle(color: p.textPrimary, fontSize: 13, height: 1.4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Scoring breakdown',
          style: TextStyle(
            color: p.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          key: const ValueKey('essay_rows'),
          decoration: BoxDecoration(
            border: Border.all(color: p.borderSubtle),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        r.awardedScore >= r.maxScore
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        size: 18,
                        color: r.awardedScore >= r.maxScore
                            ? p.primaryText
                            : ElioTokens.answerYellow,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.criterion,
                              style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (r.comment.isNotEmpty)
                              Text(
                                r.comment,
                                style: TextStyle(
                                  color: p.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${r.awardedScore} / ${r.maxScore}',
                        style: TextStyle(
                          color: r.awardedScore >= r.maxScore
                              ? p.primaryText
                              : p.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// ELIOS AI coach: the existing chat and Gemma path (sendChatMessage), Listen chips, suggestions.
  Widget _coach(
    ElioPalette p,
    WasteQuizUiState s,
    WasteQuizNotifier n,
    bool essay,
  ) {
    final greeting = essay
        ? 'Your review is on the left. Ask me about any part of the feedback.'
        : 'Nice work! Tap Listen and I will read the answer.';
    final msgs = s.messages;
    final suggestions = essay
        ? const ['Show a full-mark answer', 'Explain key terms']
        : const ['Give me a hint', 'Say it simpler'];
    Widget bubble(String t, {required bool user, bool listen = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: user
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 230),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: user ? p.primaryActive : p.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  t,
                  style: TextStyle(
                    color: user ? Colors.white : p.textPrimary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              if (listen) ...[
                const SizedBox(height: 3),
                _Pill(
                  icon: Icons.volume_up_outlined,
                  label: 'Listen',
                  small: true,
                  onTap: () => n.listen(t),
                ),
              ],
            ],
          ),
        );
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
              Container(
                width: 28,
                height: 28,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.primary,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/illustrations/control/elio_robot.svg',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ELIOS AI coach',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              controller: _scroll,
              reverse: true, // the newest message stays in view
              children: [
                if (s.sendingChat) bubble('…', user: false),
                for (final m in msgs.reversed)
                  bubble(m.text, user: m.isUser, listen: !m.isUser),
                if (msgs.isEmpty) bubble(greeting, user: false, listen: true),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final t in suggestions)
                _Pill(
                  icon: Icons.auto_awesome,
                  label: t,
                  small: true,
                  onTap: () => _send(t),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 36,
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
                    controller: _ask,
                    style: TextStyle(color: p.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: essay
                          ? 'Ask ELIOS AI about your score...'
                          : 'Ask ELIOS AI...',
                      hintStyle: TextStyle(color: p.textTertiary, fontSize: 12),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                InkResponse(
                  key: const ValueKey('quiz_send'),
                  onTap: () => _send(_ask.text),
                  child: Container(
                    width: 30,
                    height: 30,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BinCard extends StatelessWidget {
  const _BinCard({
    required this.bin,
    required this.name,
    required this.sub,
    required this.art,
    required this.isRight,
    required this.isPicked,
  });
  final HomeBin bin;
  final String name, sub, art;
  final bool isRight, isPicked;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final c = isRight
        ? p.primaryText
        : (isPicked ? p.errorText : p.textSecondary);
    final border = isRight
        ? p.primary
        : (isPicked ? p.error : Colors.transparent);
    return Container(
      key: ValueKey('bin_${name.toLowerCase()}'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isRight
            ? p.primary.withValues(alpha: 0.08)
            : (isPicked ? p.error.withValues(alpha: 0.08) : p.surfaceRaised),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/illustrations/home/$art.svg',
                height: 22,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: p.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                isRight ? Icons.check_rounded : Icons.close_rounded,
                size: 12,
                color: c,
              ),
              const SizedBox(width: 3),
              Text(
                isRight ? 'Yes' : (isPicked ? 'Your pick' : 'No'),
                style: TextStyle(
                  color: c,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrophyChip extends StatelessWidget {
  const _TrophyChip({
    required this.text,
    this.outlined = false,
    this.big = false,
  });
  final String text;
  final bool outlined, big;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: big ? 12 : 10,
        vertical: big ? 8 : 3,
      ),
      decoration: BoxDecoration(
        color: big ? ElioTokens.answerYellow.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: ElioTokens.answerYellow, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (big) ...[
            Icon(
              Icons.workspace_premium_rounded,
              size: 20,
              color: ElioTokens.answerYellow,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: p.secondaryText,
              fontSize: big ? 16 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.small = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: p.borderSubtle),
          boxShadow: small
              ? null
              : [BoxShadow(color: p.borderMedium, offset: const Offset(0, 2))],
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
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: small ? 11 : 13,
                    fontWeight: FontWeight.w700,
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

class _NextButton extends StatelessWidget {
  const _NextButton({super.key, required this.label, required this.onTap});
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: p.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 16, color: p.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
