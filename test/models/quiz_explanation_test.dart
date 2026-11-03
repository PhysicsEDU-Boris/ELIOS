import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/services/gemma_quiz_service.dart';

void main() {
  group('QuizExplanation model', () {
    test('serializes and deserializes ComparisonRow cleanly', () {
      const row = ComparisonRow(
        bin: 'Sampah Organik',
        material: 'Sisa makanan',
        accepted: 'Dapat terurai secara alami',
        isCorrect: true,
      );
      final json = row.toJson();
      final revived = ComparisonRow.fromJson(json);

      expect(revived.bin, 'Sampah Organik');
      expect(revived.material, 'Sisa makanan');
      expect(revived.accepted, 'Dapat terurai secara alami');
      expect(revived.isCorrect, true);
    });

    test('serializes and deserializes RubricRow cleanly', () {
      const rubric = RubricRow(
        criterion: 'Ketepatan konsep',
        maxScore: 6,
        awardedScore: 5,
        comment: 'Sangat baik',
      );
      final json = rubric.toJson();
      final revived = RubricRow.fromJson(json);

      expect(revived.criterion, 'Ketepatan konsep');
      expect(revived.maxScore, 6);
      expect(revived.awardedScore, 5);
      expect(revived.comment, 'Sangat baik');
    });

    test('serializes and deserializes QuizExplanation cleanly with all fields', () {
      const exp = QuizExplanation(
        summary: 'Botol plastik adalah bahan daur ulang yang berharga.',
        correctAnswerReason: 'Daur ulang plastik menghemat energi dan mengurangi timbunan sampah.',
        selectedAnswerFeedback: 'Pilihan Anda kurang tepat karena residu akan dibakar/ditimbun.',
        conceptExplanation: 'PET (Polyethylene Terephthalate) dapat didaur ulang menjadi serat tekstil.',
        comparisonRows: [
          ComparisonRow(
            bin: 'Daur Ulang',
            material: 'Plastik PET',
            accepted: 'Botol bersih tanpa cairan',
            isCorrect: true,
          ),
          ComparisonRow(
            bin: 'Residu',
            material: 'Bahan tercemar',
            accepted: 'Sampah yang tidak bisa didaur ulang',
            isCorrect: false,
          ),
        ],
        learningTakeaway: 'Bilas botol sebelum dimasukkan ke tempat daur ulang.',
        sourceTitle: 'Modul Fisika Lingkungan',
        sourceSection: 'Bab 4: Termodinamika Daur Ulang',
        sourcePage: '42',
        groundingStatus: GroundingStatus.bankGrounded,
        essayScore: 8,
        essayFeedback: 'Analisis sebab-akibat sangat lengkap.',
        rubricRows: [
          RubricRow(
            criterion: 'Penguasaan materi',
            maxScore: 6,
            awardedScore: 5,
            comment: 'Poin utama disebutkan dengan baik',
          ),
          RubricRow(
            criterion: 'Struktur argumen',
            maxScore: 4,
            awardedScore: 3,
            comment: 'Sistematika penulisan jelas',
          ),
        ],
        referenceAnswer: 'Botol plastik dibersihkan, dicacah, lalu dilelehkan kembali.',
      );

      final json = exp.toJson();
      final revived = QuizExplanation.fromJson(json);

      expect(revived.summary, exp.summary);
      expect(revived.correctAnswerReason, exp.correctAnswerReason);
      expect(revived.selectedAnswerFeedback, exp.selectedAnswerFeedback);
      expect(revived.conceptExplanation, exp.conceptExplanation);
      expect(revived.comparisonRows.length, 2);
      expect(revived.comparisonRows.first.bin, 'Daur Ulang');
      expect(revived.comparisonRows.first.isCorrect, true);
      expect(revived.learningTakeaway, exp.learningTakeaway);
      expect(revived.sourceTitle, exp.sourceTitle);
      expect(revived.sourceSection, exp.sourceSection);
      expect(revived.sourcePage, exp.sourcePage);
      expect(revived.groundingStatus, GroundingStatus.bankGrounded);
      expect(revived.essayScore, 8);
      expect(revived.essayFeedback, exp.essayFeedback);
      expect(revived.rubricRows?.length, 2);
      expect(revived.referenceAnswer, exp.referenceAnswer);
      expect(revived.isUnavailable, false);
    });

    test('QuizExplanation.unavailable sentinel behaves as expected', () {
      expect(QuizExplanation.unavailable.isUnavailable, true);
      expect(QuizExplanation.unavailable.groundingStatus, GroundingStatus.unavailable);
    });
  });

  group('RecordQuestion with QuizExplanation backward compatibility', () {
    test('RecordQuestion serializes and deserializes explanation cleanly', () {
      const explanation = QuizExplanation(
        summary: 'Penjelasan uji',
        correctAnswerReason: 'Alasan benar',
        groundingStatus: GroundingStatus.bankGrounded,
      );

      const q = RecordQuestion(
        question: 'Ke mana botol plastik dibuang?',
        yourAnswer: 'Daur ulang',
        rightAnswer: 'Daur ulang',
        isCorrect: true,
        trophies: 10,
        explanation: explanation,
      );

      final json = q.toJson();
      final revived = RecordQuestion.fromJson(json);

      expect(revived.explanation, isNotNull);
      expect(revived.explanation!.summary, 'Penjelasan uji');
      expect(revived.explanation!.correctAnswerReason, 'Alasan benar');
    });

    test('Legacy RecordQuestion JSON without explanation loads without error', () {
      final legacyJson = {
        'question': 'Soal lama tanpa penjelasan',
        'yourAnswer': 'A',
        'rightAnswer': 'A',
        'isCorrect': true,
        'trophies': 10,
        'isEssay': false,
      };

      final revived = RecordQuestion.fromJson(legacyJson);
      expect(revived.question, 'Soal lama tanpa penjelasan');
      expect(revived.explanation, isNull);
    });

    test('ScanRecord schemaVersion forward and backward compatibility', () {
      // Default new record has schemaVersion 3
      final newRecord = ScanRecord(
        id: 'new-1',
        time: DateTime.now(),
        itemName: 'Koran',
        category: ScanCategory.recyclable,
        difficulty: QuizDifficulty.easy,
        questions: const [
          RecordQuestion(
            question: 'Jenis sampah?',
            yourAnswer: 'Kertas',
            rightAnswer: 'Kertas',
            isCorrect: true,
          ),
        ],
      );
      expect(newRecord.schemaVersion, 3);
      expect(newRecord.toJson()['schemaVersion'], 3);

      // Legacy record JSON without schemaVersion defaults to 1
      final legacyRecordJson = {
        'id': 'old-1',
        'time': '2026-10-25T10:00:00.000',
        'itemName': 'Baterai Bekas',
        'category': 'b3',
        'difficulty': 'easy',
        'questions': [
          {
            'question': 'Bahaya limbah B3?',
            'yourAnswer': 'Beracun',
            'rightAnswer': 'Beracun',
            'isCorrect': true,
            'trophies': 10,
          }
        ],
        'trophies': 10,
      };

      final legacyRecord = ScanRecord.fromJson(legacyRecordJson);
      expect(legacyRecord.schemaVersion, 1);
      expect(legacyRecord.questions.first.explanation, isNull);
    });
  });
}
