import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/quiz_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('elio_pdf_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('QuizPdfService', () {
    test('generates valid PDF bytes for MCQ record with explanations', () async {
      final record = ScanRecord(
        id: 'test-mcq-1',
        time: DateTime(2026, 10, 28, 14, 0),
        itemName: 'Botol Plastik PET',
        category: ScanCategory.recyclable,
        difficulty: QuizDifficulty.medium,
        questions: const [
          RecordQuestion(
            question: 'Ke tempat sampah mana botol plastik PET harus dibuang?',
            yourAnswer: 'Daur Ulang (Anorganik)',
            rightAnswer: 'Daur Ulang (Anorganik)',
            isCorrect: true,
            trophies: 10,
            explanation: QuizExplanation(
              summary: 'Botol plastik terbuat dari PET yang bernilai daur ulang tinggi.',
              correctAnswerReason: 'Plastik PET dapat dilelehkan kembali menjadi serat atau botol baru.',
              conceptExplanation: 'Pemilahan di sumber mencegah kontaminasi residu organik.',
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
                  accepted: 'Sampah tak dapat didaur ulang',
                  isCorrect: false,
                ),
              ],
              learningTakeaway: 'Bilas botol sebelum dimasukkan ke tempat sampah daur ulang.',
              sourceTitle: 'Modul Daur Ulang ELIO',
              sourceSection: 'Bab 2',
              groundingStatus: GroundingStatus.bankGrounded,
            ),
          ),
          RecordQuestion(
            question: 'Apakah tutup botol plastik jenisnya sama dengan badannya?',
            yourAnswer: 'Sama',
            rightAnswer: 'Berbeda (HDPE/PP)',
            isCorrect: false,
            trophies: 0,
            explanation: QuizExplanation(
              summary: 'Tutup botol biasanya terbuat dari HDPE atau PP.',
              correctAnswerReason: 'Titik leleh HDPE dan PET berbeda sehingga proses daur ulang dipisahkan.',
              selectedAnswerFeedback: 'Jawaban salah: badan botol adalah PET, tutup botol HDPE.',
              learningTakeaway: 'Pisahkan tutup botol jika fasilitas daur ulang mensyaratkannya.',
              groundingStatus: GroundingStatus.bankGrounded,
            ),
          ),
        ],
        trophies: 10,
      );

      // Verify generateAndSave produces a real file on disk
      final filePath = await QuizPdfService.generateAndSave(record, targetDir: tempDir);
      final file = File(filePath);

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));

      // Read PDF header magic bytes %PDF-
      final bytes = file.readAsBytesSync();
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      expect(header, '%PDF-');

      // Cleanup
      file.deleteSync();
    });

    test('generates valid PDF for essay question with rubric breakdown', () async {
      final record = ScanRecord(
        id: 'test-essay-1',
        time: DateTime(2026, 10, 28, 14, 30),
        itemName: 'Baterai Litium Ponsel',
        category: ScanCategory.b3,
        difficulty: QuizDifficulty.hard,
        questions: const [
          RecordQuestion(
            question: 'Jelaskan bahaya pembuangan baterai litium ke TPA sembarangan dan prinsip penanganannya.',
            yourAnswer: 'Baterai litium mengandung logam berat dan bahan kimia reaktif yang bisa menyebabkan kebakaran serta mencemari air tanah.',
            rightAnswer: 'Mengandung kobalt, nikel, dan litium yang reaktif; harus diserahkan ke drop-off limbah B3.',
            isCorrect: true,
            isEssay: true,
            essayScore: 9,
            trophies: 9,
            explanation: QuizExplanation(
              summary: 'Jawaban Anda sangat komprehensif dan tepat.',
              correctAnswerReason: 'Baterai litium rentan mengalami thermal runaway dan kebocoran elektrolit.',
              conceptExplanation: 'Pengelolaan limbah B3 memerlukan rantai pasok terpisah dari sampah rumah tangga biasa.',
              rubricRows: [
                RubricRow(
                  criterion: 'Identifikasi bahaya kebakaran & pencemaran',
                  maxScore: 6,
                  awardedScore: 6,
                  comment: 'Lengkap dan tepat',
                ),
                RubricRow(
                  criterion: 'Solusi pembuangan & daur ulang',
                  maxScore: 4,
                  awardedScore: 3,
                  comment: 'Sudah baik, bisa ditambahkan fasilitas drop-off',
                ),
              ],
              learningTakeaway: 'Jangan membuang baterai bekas ke tempat sampah umum.',
              sourceTitle: 'Pedoman Pengelolaan Limbah B3',
              groundingStatus: GroundingStatus.gemmaUngrounded,
              essayScore: 9,
              essayFeedback: 'Analisis sebab-akibat sangat baik.',
            ),
          ),
        ],
        trophies: 9,
      );

      final filePath = await QuizPdfService.generateAndSave(record, targetDir: tempDir);
      final file = File(filePath);

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
      file.deleteSync();
    });

    test('generates valid PDF when cropPhotoPath and explanation are null (legacy record)', () async {
      final legacyRecord = ScanRecord(
        id: 'legacy-record-1',
        time: DateTime(2026, 10, 20, 9, 0),
        itemName: 'Daun Kering',
        category: ScanCategory.organic,
        cropPhotoPath: null,
        difficulty: QuizDifficulty.easy,
        questions: const [
          RecordQuestion(
            question: 'Ke mana daun kering harus dimasukkan?',
            yourAnswer: 'Sampah Organik',
            rightAnswer: 'Sampah Organik',
            isCorrect: true,
            trophies: 10,
            explanation: null,
          ),
        ],
        trophies: 10,
      );

      final filePath = await QuizPdfService.generateAndSave(legacyRecord, targetDir: tempDir);
      final file = File(filePath);

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(500));
      file.deleteSync();
    });

    test('safe filename does not contain illegal characters or spaces', () async {
      final record = ScanRecord(
        id: 'scan-weird-#1!',
        time: DateTime(2026, 10, 28, 12, 0),
        itemName: 'Sampah Elektronik (E-Waste) / PCB!',
        category: ScanCategory.b3,
        questions: const [],
        trophies: 0,
      );

      final filePath = await QuizPdfService.generateAndSave(record, targetDir: tempDir);
      final filename = filePath.split(Platform.pathSeparator).last;

      expect(filename.contains(' '), isFalse);
      expect(filename.contains('#'), isFalse);
      expect(filename.contains('!'), isFalse);
      expect(filename.endsWith('.pdf'), isTrue);

      File(filePath).deleteSync();
    });
  });
}
