import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../l10n/l10n.dart';

import '../models/essay_grade.dart';
import '../models/quiz_explanation.dart';
import '../models/scanned_waste.dart';
import '../services/ai_quiz_service.dart';

/// Stored source title of bank explanations; shown as the localized bank name.
const bankSourceTitle = 'Bank Soal ELIOS';

/// ELIOS AI explanations with reviewed bank fallback (0184).
/// Legacy overlay fields are populated from the same saved text.
class QuizExplanationService {
  const QuizExplanationService._();

  /// Generate an explanation for a just-answered question.
  ///
  /// [question] — the [GeneratedQuestion] that was shown.
  /// [selectedIndex] — the option index chosen (null for essay / skipped).
  /// [scan] — the [ScannedWaste] that triggered the quiz session.
  /// [essayGrade] — validated AI grade; null when grading is unavailable.
  static Future<QuizExplanation> generate({
    required GeneratedQuestion question,
    required ScannedWaste scan,
    int? selectedIndex,
    EssayGrade? essayGrade,
    String difficulty = 'medium',
    bool onlyWhenIdle = false,
  }) async {
    try {
      if (question.type == QuizQuestionType.essay) {
        return _buildEssayExplanation(
          question: question,
          essayGrade: essayGrade,
        );
      }
      if (onlyWhenIdle && AiQuizService.instance.isBusy) {
        return bankExplanation(question, selectedIndex: selectedIndex ?? -1);
      }
      final picked =
          selectedIndex != null &&
              selectedIndex >= 0 &&
              selectedIndex < question.options.length
          ? question.options[selectedIndex]
          : '';
      final correct =
          question.correctIndex >= 0 &&
              question.correctIndex < question.options.length
          ? question.options[question.correctIndex]
          : '';
      final result =
          await AiQuizService.instance.explainAnswer(
            itemName: scan.displayName,
            category: scan.category?.id ?? '',
            question: question.question,
            options: question.options,
            correctOption: correct,
            studentAnswer: picked,
            difficulty: difficulty,
            bankExplanation: question.bankId == null || !question.bankReviewed
                ? ''
                : question.explanation,
            wrongWhy: question.bankReviewed ? question.wrongWhy : const {},
            quote: question.quote,
            bankId: question.bankId,
            dataLang: question.lang,
          ) ??
          bankExplanation(question, selectedIndex: selectedIndex ?? -1);
      return QuizExplanation.fromJson({
        ...result.toJson(),
        'lang': result.lang ?? question.lang,
        'generatedAt': DateTime.now().toIso8601String(),
        if (question.sourceSection != null)
          'sourceSection': question.sourceSection,
        if (question.sourcePage != null) 'sourcePage': question.sourcePage,
      });
    } catch (e) {
      debugPrint('[QuizExplanationService] generate failed: $e');
      return QuizExplanation.unavailable;
    }
  }

  // ---------------------------------------------------------------------------
  // MCQ explanation
  // ---------------------------------------------------------------------------

  /// Reviewed text is the only offline fallback; no locally invented explanation.
  static QuizExplanation bankExplanation(
    GeneratedQuestion question, {
    int selectedIndex = -1,
  }) {
    if (question.bankId == null) {
      return QuizExplanation.unavailable;
    }
    final picked = selectedIndex >= 0 && selectedIndex < question.options.length
        ? question.options[selectedIndex]
        : '';
    // The reviewed bank text in the other language, when the bank has it (0185).
    final alt = question.alt;
    final altExplanation =
        alt == null || !question.bankReviewed || alt.explanation.trim().isEmpty
        ? null
        : QuizExplanation(
            summary: alt.explanation,
            correctAnswerReason: alt.explanation,
            source: 'bank',
            bankId: question.bankId,
            quote: question.quote,
            sourceTitle: bankSourceTitle,
            sourceSection: question.sourceSection,
            sourcePage: question.sourcePage,
            groundingStatus: GroundingStatus.bankGrounded,
            lang: alt.lang,
          );
    return QuizExplanation(
      lang: question.lang,
      alt: altExplanation,
      summary: question.bankReviewed ? question.explanation : '',
      correctAnswerReason: question.bankReviewed ? question.explanation : '',
      selectedAnswerFeedback:
          !question.bankReviewed || selectedIndex == question.correctIndex
          ? ''
          : (question.wrongWhy[picked] ?? ''),
      source: 'bank',
      bankId: question.bankId,
      quote: question.quote,
      sourceTitle: bankSourceTitle,
      sourceSection: question.sourceSection,
      sourcePage: question.sourcePage,
      groundingStatus:
          !question.bankReviewed || question.explanation.trim().isEmpty
          ? GroundingStatus.unavailable
          : GroundingStatus.bankGrounded,
    );
  }

  /// Table 1 for a wrong answer: every option, the pick and the right one marked.
  static List<({String option, bool picked, bool correct})> optionRows(
    GeneratedQuestion question,
    int? selectedIndex,
  ) => [
    for (var i = 0; i < question.options.length; i++)
      (
        option: question.options[i],
        picked: i == selectedIndex,
        correct: i == question.correctIndex,
      ),
  ];

  // ---------------------------------------------------------------------------
  // Essay explanation
  // ---------------------------------------------------------------------------

  static QuizExplanation _buildEssayExplanation({
    required GeneratedQuestion question,
    required EssayGrade? essayGrade,
  }) {
    if (essayGrade == null) {
      return QuizExplanation(
        summary: l10n.essaySavedPending,
        correctAnswerReason: '',
        essayFeedback: l10n.h3AwaitingGrading,
        sourceSection: question.sourceSection,
        sourcePage: question.sourcePage,
        quote: question.quote,
        bankId: question.bankId,
        groundingStatus: GroundingStatus.gemmaUngrounded,
        lang: question.lang,
      );
    }
    QuizExplanation build(
      EssayGrade g,
      String lang,
      String reference,
      QuizExplanation? alt,
    ) {
      final t = lookupAppLocalizations(Locale(lang));
      final feedback = g.feedback.isNotEmpty
          ? g.feedback
          : t.essayScoreLine(g.score);
      return QuizExplanation(
        summary: feedback,
        source: question.bankId != null && question.bankReviewed
            ? 'aiWithBank'
            : 'ai',
        generatedAt: DateTime.now(),
        model: AiQuizService.instance.lastModel,
        correctAnswerReason: '',
        learningTakeaway: g.improvement.isEmpty
            ? ''
            : t.wqForFullMarks(g.improvement),
        groundingStatus: GroundingStatus.gemmaUngrounded,
        essayScore: g.score,
        essayFeedback: feedback,
        sourceSection: question.sourceSection,
        sourcePage: question.sourcePage,
        quote: question.quote,
        bankId: question.bankId,
        rubricRows: g.rubricRows.isEmpty ? null : g.rubricRows,
        referenceAnswer: reference.isNotEmpty ? reference : null,
        lang: lang,
        alt: alt,
      );
    }

    var alt = essayGrade.alt;
    final altLang = AiQuizService.otherLang(question.lang);
    // The grade's sides can arrive swapped (feedback in the other language).
    if (alt != null &&
        AiQuizService.detectLang(essayGrade.feedback) == altLang &&
        AiQuizService.detectLang(alt.feedback) != altLang) {
      (essayGrade, alt) = (alt, essayGrade);
    }
    return build(
      essayGrade,
      question.lang,
      question.explanation,
      alt == null
          ? null
          : build(alt, altLang, question.alt?.explanation ?? '', null),
    );
  }
}
