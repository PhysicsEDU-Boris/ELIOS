// Essay answer review (Figma "16 · Essay answer review", 869:29309; decision
// 0227): one body for the live quiz review and History's explanation page,
// built from the History explanation widgets.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../models/quiz_explanation.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_tokens.dart';
import '../auth/auth_widgets.dart' show authPalette;
import '../history_ui.dart';

class EssayReview extends StatelessWidget {
  const EssayReview({
    super.key,
    required this.question,
    required this.answer,
    required this.reference,
    required this.explanation,
    required this.score,
    required this.index,
    required this.total,
    required this.playing,
    required this.onListen,
    this.animate = true,
  });
  final String question, answer, reference;
  final QuizExplanation? explanation;

  /// 0..10; null while the answer is not graded (no score card then).
  final int? score;
  final int index, total;

  /// Id of the section being read aloud: question, feedback, correct, steps.
  final String? playing;
  final void Function(String id, String text) onListen;

  /// False shows everything at rest (an entrance already seen).
  final bool animate;

  /// A skipped or timed-out answer, in either app language.
  static bool isSkipped(String answer) => [
    for (final lang in const ['en', 'id']) ...[
      lookupAppLocalizations(Locale(lang)).quizSkippedAnswer,
      lookupAppLocalizations(Locale(lang)).quizTimeUpAnswer,
    ],
  ].contains(answer.trim());

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n, e = explanation;
    final s = score;
    final full = s == 10;
    final skipped = isSkipped(answer) || answer.trim().isEmpty;
    final feedback = e?.essayFeedback ?? '';
    final why = e?.correctAnswerReason ?? '';
    final idea = e?.keyIdea ?? '';
    final tips = e?.steps ?? const <String>[];
    var n = 0;
    // Hero first, then each card fades and slides up, 40 ms apart.
    Widget enter(String id, Widget child, {bool pop = false}) => ElioPopIn(
      key: ValueKey('essay-in-$id'),
      index: n++,
      rise: 10,
      scale: pop ? 0.9 : 0.96,
      curve: pop ? ElioMotion.pop : ElioMotion.emphasized,
      play: animate,
      child: child,
    );
    Widget art(HistoryTone tone, String mood) => historyArtTile(
      historyTint(p, tone).bg,
      SvgPicture.asset(
        'assets/illustrations/robot/robot_$mood.svg',
        width: 36,
        height: 41,
        excludeFromSemantics: true,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        enter(
          'hero',
          HistoryResultHero(
            correct: (s ?? 0) >= 5,
            essayScore: s,
            index: index,
            total: total,
            trophies: s ?? 0,
            animate: animate,
          ),
          pop: true,
        ),
        const SizedBox(height: 16),
        enter(
          'question',
          HistoryQuestionPanel(
            essay: true,
            question: question,
            listen: HistoryListenButton(
              active: playing == 'question',
              onPressed: () => onListen('question', question),
            ),
          ),
        ),
        if (s != null) ...[
          const SizedBox(height: 16),
          enter(
            'score',
            HistoryEssayScore(
              score: s,
              trophies: s,
              rows: e?.rubricRows ?? const [],
              animate: animate,
            ),
          ),
        ],
        const SizedBox(height: 16),
        enter(
          'answer',
          skipped
              ? HistoryAnswerTile(
                  t.h3YourAnswer,
                  t.essaySkipped,
                  tone: HistoryTone.error,
                )
              : HistoryAnswerTile(
                  s == null
                      ? t.h3YourAnswer
                      : t.essayYourAnswer(HistoryEssayScore.verdict(t, s)),
                  '“$answer”',
                  tone: s == null
                      ? HistoryTone.neutral
                      : (full ? HistoryTone.success : HistoryTone.error),
                ),
        ),
        if (!full && reference.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          enter(
            'reference',
            HistoryAnswerTile(t.essayRightAnswer, reference),
          ),
        ],
        if (feedback.isNotEmpty ||
            why.isNotEmpty ||
            idea.isNotEmpty ||
            tips.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              HistorySparkle(18, p.secondaryText),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    t.h3LearnWhy,
                    style: ElioTokens.subhead.copyWith(color: p.textPrimary),
                  ),
                ),
              ),
            ],
          ),
        ],
        // Personal feedback: nothing to correct on full marks.
        if (!full && feedback.isNotEmpty) ...[
          const SizedBox(height: 12),
          enter(
            'feedback',
            HistoryLearnCard(
              art: art(HistoryTone.warning, 'talking'),
              title: t.essayFeedbackTitle,
              body: feedback,
              active: playing == 'feedback',
              onListen: () => onListen('feedback', feedback),
            ),
          ),
        ],
        if (why.isNotEmpty) ...[
          const SizedBox(height: 12),
          enter(
            'correct',
            HistoryLearnCard(
              art: art(HistoryTone.warning, 'happy'),
              title: full ? t.essayWhyRightTitle : t.essayWhyTitle,
              body: why,
              active: playing == 'correct',
              onListen: () => onListen('correct', why),
            ),
          ),
        ],
        if (idea.isNotEmpty) ...[
          const SizedBox(height: 12),
          enter('idea', HistoryKeyIdea(text: idea), pop: true),
        ],
        if (!full && tips.isNotEmpty) ...[
          const SizedBox(height: 12),
          enter(
            'steps',
            HistoryMission(
              title: t.essayTipsTitle,
              subtitle: t.essayTipsSub(tips.length),
              done: t.essayTipsDone,
              steps: tips,
              active: playing == 'steps',
              onListen: () => onListen('steps', tips.join('\n')),
            ),
          ),
        ],
      ],
    );
  }
}
