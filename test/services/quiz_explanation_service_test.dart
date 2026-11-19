import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/essay_grade.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/quiz_explanation_service.dart';
import 'package:elio/services/quiz_pdf_service.dart';

const _question = GeneratedQuestion(
  type: QuizQuestionType.essay,
  question: 'Jelaskan pemilahan sampah organik.',
  explanation: 'Pemilahan mengurangi metana dari TPA.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('validated rubric survives saved review and PDF generation', () async {
    const raw =
        '{"accuracy":4,"keyTerms":3,"completeness":1,"clarity":1,'
        '"total":9,"feedback":"Penjelasan tepat.",'
        '"improvement":"Tambahkan contoh konkret."}';
    final grade = EssayGrade.parse(raw)!;
    final explanation = await QuizExplanationService.generate(
      question: _question,
      scan: ScannedWaste.fromLabel('sisa sayur'),
      essayGrade: grade,
    );
    expect(explanation.essayScore, 9);
    expect(explanation.rubricRows?.map((row) => row.awardedScore), [
      4,
      3,
      1,
      1,
    ]);
    expect(explanation.summary, 'Penjelasan tepat.');
    expect(explanation.source, 'ai');
    expect(explanation.generatedAt, isNotNull);
    expect(
      explanation.learningTakeaway,
      'Untuk nilai penuh: Tambahkan contoh konkret.',
    );
    expect(explanation.sourceTitle, isNull);

    final saved = RecordQuestion.fromJson(
      RecordQuestion(
        question: _question.question,
        yourAnswer: 'Saya memilah sisa sayur.',
        rightAnswer: _question.explanation,
        isCorrect: true,
        isEssay: true,
        essayScore: grade.score,
        trophies: grade.score,
        explanation: explanation,
      ).toJson(),
    );
    final record = ScanRecord(
      id: 'essay-review',
      time: DateTime(2026),
      itemName: 'Sisa sayur',
      category: ScanCategory.organic,
      difficulty: QuizDifficulty.easy,
      questions: [saved],
    );
    expect(saved.explanation?.rubricRows?.map((row) => row.maxScore), [
      4,
      3,
      2,
      1,
    ]);
    expect(await QuizPdfService.generatePdfBytes(record), isNotEmpty);
  });

  test('score-only result has no rubric rows or invented source', () async {
    final explanation = await QuizExplanationService.generate(
      question: _question,
      scan: ScannedWaste.fromLabel('sisa sayur'),
      essayGrade: EssayGrade.parse('{"total":5,"accuracy":"bad"}'),
    );
    expect(explanation.essayScore, 5);
    expect(explanation.rubricRows, isNull);
    expect(explanation.sourceTitle, isNull);
    expect(explanation.summary, 'Skor: 5/10.');
  });
}
