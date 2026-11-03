import 'package:flutter/foundation.dart';

import '../models/essay_grade.dart';
import '../models/quiz_explanation.dart';
import '../models/scanned_waste.dart';
import '../services/gemma_quiz_service.dart';

/// Generates structured [QuizExplanation] objects for answered questions.
///
/// Design (decision 0031):
/// - Bank-grounded questions use in-process logic to build a deterministic
///   explanation table; no Gemma call needed.
/// - Gemma-generated questions attempt a short `discuss()` call; if the
///   service is unavailable the unavailable sentinel is returned.
/// - The call is non-blocking: the caller sets `explanationLoading = true`
///   and awaits this future while showing a spinner.
class QuizExplanationService {
  const QuizExplanationService._();

  /// Generate an explanation for a just-answered question.
  ///
  /// [question] — the [GeneratedQuestion] that was shown.
  /// [selectedIndex] — the option index chosen (null for essay / skipped).
  /// [scan] — the [ScannedWaste] that triggered the quiz session.
  /// [essayGrade] — validated Gemma grade; null when grading is unavailable.
  static Future<QuizExplanation> generate({
    required GeneratedQuestion question,
    required ScannedWaste scan,
    int? selectedIndex,
    EssayGrade? essayGrade,
  }) async {
    try {
      if (question.type == QuizQuestionType.essay) {
        return _buildEssayExplanation(
          question: question,
          essayGrade: essayGrade,
        );
      }
      return _buildMcqExplanation(
        question: question,
        scan: scan,
        selectedIndex: selectedIndex ?? -1,
      );
    } catch (e) {
      debugPrint('[QuizExplanationService] generate failed: $e');
      return QuizExplanation.unavailable;
    }
  }

  // ---------------------------------------------------------------------------
  // MCQ explanation
  // ---------------------------------------------------------------------------

  static QuizExplanation _buildMcqExplanation({
    required GeneratedQuestion question,
    required ScannedWaste scan,
    required int selectedIndex,
  }) {
    final isCorrect = selectedIndex == question.correctIndex;
    final correctAnswer = question.options.isNotEmpty ? question.options[question.correctIndex] : '';
    final selectedAnswer = selectedIndex >= 0 && selectedIndex < question.options.length
        ? question.options[selectedIndex]
        : '';

    final explanation = question.explanation;
    final itemName = scan.displayName;
    final categoryId = scan.category?.id ?? '';

    final summary = explanation.isNotEmpty
        ? explanation
        : isCorrect
            ? 'Kamu memilih jawaban yang benar: "$correctAnswer".'
            : 'Jawaban yang benar adalah "$correctAnswer", bukan "$selectedAnswer".';

    final correctReason = explanation.isNotEmpty
        ? explanation
        : 'Berdasarkan klasifikasi sampah, $itemName termasuk dalam kategori '
            '${_categoryLabel(categoryId)}.';

    final bank = question.bankId != null;
    return QuizExplanation(
      summary: summary,
      correctAnswerReason: correctReason,
      // Only a reviewed reason; empty hides "Why your answer is not right" (decision 0175).
      selectedAnswerFeedback: isCorrect ? '' : (question.wrongWhy[selectedAnswer] ?? ''),
      // The bin reference belongs to the right-answer path only; a wrong answer gets the options table.
      comparisonRows: isCorrect ? _buildComparisonRows(categoryId, itemName) : const [],
      learningTakeaway: 'Ingat: $itemName masuk ke ${_categoryLabel(categoryId)}.',
      sourceTitle: bank ? 'Bank Soal ELIO' : null,
      sourceSection: bank ? question.sourceSection : null,
      sourcePage: bank ? question.sourcePage : null,
      quote: bank ? question.quote : null,
      bankId: question.bankId,
      groundingStatus: bank ? GroundingStatus.bankGrounded : GroundingStatus.gemmaUngrounded,
    );
  }

  /// Table 1 for a wrong answer: every option, the pick and the right one marked.
  static List<({String option, bool picked, bool correct})> optionRows(GeneratedQuestion question, int? selectedIndex) => [
        for (var i = 0; i < question.options.length; i++)
          (option: question.options[i], picked: i == selectedIndex, correct: i == question.correctIndex),
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
        summary: 'Jawaban tersimpan. Menunggu penilaian karena AI belum tersedia.',
        correctAnswerReason: '',
        essayFeedback: 'Menunggu penilaian',
        sourceSection: question.sourceSection,
        sourcePage: question.sourcePage,
        quote: question.quote,
        bankId: question.bankId,
        groundingStatus: GroundingStatus.gemmaUngrounded,
      );
    }
    final expectedPoints = question.explanation;
    final feedback = essayGrade.feedback.isNotEmpty
        ? essayGrade.feedback
        : 'Skor: ${essayGrade.score}/10.';
    return QuizExplanation(
      summary: feedback,
      correctAnswerReason: '',
      learningTakeaway: essayGrade.improvement.isEmpty
          ? ''
          : 'Untuk nilai penuh: ${essayGrade.improvement}',
      groundingStatus: GroundingStatus.gemmaUngrounded,
      essayScore: essayGrade.score,
      essayFeedback: feedback,
      sourceSection: question.sourceSection,
      sourcePage: question.sourcePage,
      quote: question.quote,
      bankId: question.bankId,
      rubricRows: essayGrade.rubricRows.isEmpty ? null : essayGrade.rubricRows,
      referenceAnswer: expectedPoints.isNotEmpty ? expectedPoints : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static List<ComparisonRow> _buildComparisonRows(String categoryId, String itemName) {
    return [
      ComparisonRow(
        bin: 'Sampah Organik',
        material: 'Sisa makanan, daun',
        accepted: 'Bahan yang terurai secara alami',
        isCorrect: categoryId == 'organic',
      ),
      ComparisonRow(
        bin: 'Daur Ulang (Anorganik)',
        material: 'Plastik, kertas, logam',
        accepted: 'Bahan yang dapat diproses ulang secara industri',
        isCorrect: categoryId == 'recyclable' || categoryId == 'inorganic',
      ),
      ComparisonRow(
        bin: 'Limbah B3',
        material: 'Baterai, HP, bahan kimia',
        accepted: 'Bahan berbahaya yang perlu penanganan khusus',
        isCorrect: categoryId == 'b3' || categoryId == 'hazardous',
      ),
      ComparisonRow(
        bin: 'Sampah Residu',
        material: 'Styrofoam, pembalut, dll.',
        accepted: 'Sampah yang tidak dapat didaur ulang atau didaur biologis',
        isCorrect: categoryId == 'residu' || categoryId == 'residual',
      ),
    ];
  }

  static String _categoryLabel(String categoryId) => switch (categoryId) {
        'organic' || 'organik' => 'Sampah Organik',
        'recyclable' || 'inorganic' => 'Daur Ulang (Anorganik)',
        'b3' || 'hazardous' => 'Limbah B3',
        _ => 'Sampah Residu',
      };
}
