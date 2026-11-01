import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/home_stats.dart' show questBonus;
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/models/trophy_rules.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/scan_record_store.dart';

void main() {
  test('debug samples preserve existing unloaded history and are idempotent', () async {
    final dir = await Directory.systemTemp.createTemp('seed-preserve-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/records.json');
    final original = ScanRecord(
      id: 'owner-record', time: DateTime(2026), itemName: 'Original item',
      category: ScanCategory.recyclable, difficulty: QuizDifficulty.easy,
      questions: const [], trophies: 10,
    );
    await ScanRecordStore(customFile: file).addRecord(original);
    final store = ScanRecordStore(customFile: file);
    await store.seedFigmaSampleRecords();
    await store.seedFigmaSampleRecords();
    final saved = await ScanRecordStore(customFile: file).load();
    expect(saved, hasLength(5));
    expect(saved.singleWhere((r) => r.id == original.id).toJson(), original.toJson());
  });

  group('ScanRecord JSON serialization', () {
    test('serializes and deserializes cleanly', () {
      final now = DateTime(2026, 10, 26, 14, 30);
      final record = ScanRecord(
        id: 'test-1',
        time: now,
        itemName: 'Cardboard Box',
        category: ScanCategory.recyclable,
        cropPhotoPath: '/path/to/box.jpg',
        difficulty: QuizDifficulty.medium,
        questions: const [
          RecordQuestion(
            question: 'Where does cardboard go?',
            yourAnswer: 'Recyclable',
            rightAnswer: 'Recyclable',
            isCorrect: true,
            trophies: 10,
          ),
          RecordQuestion(
            question: 'Should you flatten cardboard?',
            yourAnswer: 'No',
            rightAnswer: 'Yes',
            isCorrect: false,
            trophies: 0,
          ),
        ],
        trophies: 10,
      );

      final json = record.toJson();
      final revived = ScanRecord.fromJson(json);

      expect(revived.id, 'test-1');
      expect(revived.time, now);
      expect(revived.itemName, 'Cardboard Box');
      expect(revived.category, ScanCategory.recyclable);
      expect(revived.cropPhotoPath, '/path/to/box.jpg');
      expect(revived.difficulty, QuizDifficulty.medium);
      expect(revived.trophies, 10);
      expect(revived.questions.length, 2);
      expect(revived.questions[0].isCorrect, true);
      expect(revived.questions[1].isCorrect, false);
      expect(revived.correctCount, 1);
      expect(revived.totalQuestions, 2);
    });
  });

  group('ScanRecordStore persistence and totals', () {
    late Directory tempDir;
    late File testFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('scan_record_store_test_');
      testFile = File('${tempDir.path}/records.json');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('starts empty when file does not exist', () async {
      final store = ScanRecordStore(customFile: testFile);
      final records = await store.load();

      expect(records, isEmpty);
      expect(store.totalTrophies, 0);
      expect(store.userLevel, StudentLevel.ecoStarter);
      expect(store.levelProgress, 0.0);
    });

    test('saves and reloads records, maintaining totals and levels', () async {
      final store1 = ScanRecordStore(customFile: testFile);
      await store1.load();

      final record1 = ScanRecord(
        id: 'rec-1',
        time: DateTime.now(),
        itemName: 'Plastic Cup',
        category: ScanCategory.recyclable,
        difficulty: QuizDifficulty.easy,
        questions: const [
          RecordQuestion(
            question: 'Is plastic recyclable?',
            yourAnswer: 'Yes',
            rightAnswer: 'Yes',
            isCorrect: true,
            trophies: 10,
          ),
        ],
        trophies: 10,
      );

      final record2 = ScanRecord(
        id: 'rec-2',
        time: DateTime.now(),
        itemName: 'Laptop Battery',
        category: ScanCategory.b3,
        difficulty: QuizDifficulty.hard,
        questions: const [
          RecordQuestion(
            question: 'Q1',
            yourAnswer: 'A',
            rightAnswer: 'A',
            isCorrect: true,
            trophies: 10,
          ),
          RecordQuestion(
            question: 'Q2',
            yourAnswer: 'B',
            rightAnswer: 'B',
            isCorrect: true,
            trophies: 10,
          ),
          RecordQuestion(
            question: 'Q3',
            yourAnswer: 'C',
            rightAnswer: 'C',
            isCorrect: true,
            trophies: 10,
          ),
        ],
        trophies: 30,
      );

      await store1.addRecord(record1);
      await store1.addRecord(record2);

      expect(store1.records.length, 2);
      expect(store1.records.first.id, 'rec-2'); // newest first
      expect(store1.totalTrophies, 40 + questBonus(store1.records)); // 10 + 30 + quests
      expect(store1.userLevel, StudentLevel.ecoStarter);
      expect(store1.levelProgress, StudentLevel.ecoStarter.progress(store1.totalTrophies));

      // Reload into a fresh store instance from same file
      final store2 = ScanRecordStore(customFile: testFile);
      await store2.load();

      expect(store2.records.length, 2);
      expect(store2.records[0].id, 'rec-2');
      expect(store2.records[1].id, 'rec-1');
      expect(store2.totalTrophies, 40 + questBonus(store2.records));
    });

    test('level updates to Lv3 Bin Expert at 340 trophies', () async {
      final store = ScanRecordStore(customFile: testFile);
      await store.load();

      // Add a high-score record to reach 340 trophies
      final record = ScanRecord(
        id: 'big-score',
        time: DateTime.now(),
        itemName: 'Electronic Device Collection',
        category: ScanCategory.b3,
        difficulty: QuizDifficulty.hard,
        questions: const [],
        trophies: 340,
      );

      await store.addRecord(record);

      expect(store.totalTrophies, 340 + questBonus(store.records));
      expect(store.userLevel, StudentLevel.binExpert);
      expect(store.userLevel.levelNumber, 3);
      expect(store.userLevel.levelAndTitle, 'Level 3 · Bin Expert');
      // Progress from 250 to 500: (340 - 250) / 250 = 90 / 250 = 0.36
      expect(StudentLevel.binExpert.progress(340), closeTo(0.36, 0.001));
      expect(store.levelProgress, StudentLevel.binExpert.progress(store.totalTrophies));
    });

    test('seedFigmaSampleRecords populates Figma 100:170 sample data', () async {
      final store = ScanRecordStore(customFile: testFile);
      await store.seedFigmaSampleRecords();

      expect(store.records.length, 4);
      expect(store.records[0].itemName, 'Phone');
      expect(store.records[0].category, ScanCategory.b3);
      expect(store.records[0].trophies, 20);

      expect(store.records[1].itemName, 'Plastic Bottle');
      expect(store.records[1].category, ScanCategory.recyclable);
      expect(store.records[1].trophies, 20);

      expect(store.records[2].itemName, 'Battery');
      expect(store.records[2].category, ScanCategory.b3);
      expect(store.records[2].trophies, 10);

      expect(store.records[3].itemName, 'Banana Peel');
      expect(store.records[3].category, ScanCategory.organic);
      expect(store.records[3].trophies, 0);

      expect(store.totalTrophies, 50 + questBonus(store.records)); // 20 + 20 + 10 + 0 + quests
    });

    test('saves and reloads records with structured explanations and tables', () async {
      final store1 = ScanRecordStore(customFile: testFile);
      await store1.load();

      const exp = QuizExplanation(
        summary: 'Ringkasan edukasi botol PET',
        correctAnswerReason: 'Daur ulang mekanik PET efisien',
        conceptExplanation: 'Termoplastik dapat dilelehkan berulang kali',
        comparisonRows: [
          ComparisonRow(
            bin: 'Daur Ulang',
            material: 'PET',
            accepted: 'Botol bersih',
            isCorrect: true,
          ),
        ],
        learningTakeaway: 'Ingat bilas sebelum buang',
        sourceTitle: 'Fisika Lingkungan',
        groundingStatus: GroundingStatus.bankGrounded,
      );

      final record = ScanRecord(
        id: 'rec-exp',
        time: DateTime(2026, 10, 28, 11, 0),
        itemName: 'Botol Plastik',
        category: ScanCategory.recyclable,
        difficulty: QuizDifficulty.easy,
        questions: const [
          RecordQuestion(
            question: 'Termasuk apakah plastik PET?',
            yourAnswer: 'Termoplastik',
            rightAnswer: 'Termoplastik',
            isCorrect: true,
            trophies: 10,
            explanation: exp,
          ),
        ],
        trophies: 10,
      );

      await store1.addRecord(record);

      // Reload in a fresh store instance from the same file
      final store2 = ScanRecordStore(customFile: testFile);
      await store2.load();

      expect(store2.records.length, 1);
      final revived = store2.records.first;
      expect(revived.id, 'rec-exp');
      expect(revived.schemaVersion, 2);
      expect(revived.questions.first.explanation, isNotNull);
      final revivedExp = revived.questions.first.explanation!;
      expect(revivedExp.summary, 'Ringkasan edukasi botol PET');
      expect(revivedExp.correctAnswerReason, 'Daur ulang mekanik PET efisien');
      expect(revivedExp.comparisonRows.length, 1);
      expect(revivedExp.comparisonRows.first.isCorrect, isTrue);
      expect(revivedExp.groundingStatus, GroundingStatus.bankGrounded);
    });
    test('restarting store preserves existing records and addRecord without load retains history', () async {
      // 1. Initial store saves a real record
      final store1 = ScanRecordStore(customFile: testFile);
      final record1 = ScanRecord(
        id: 'initial-scan',
        time: DateTime.now(),
        itemName: 'Kardus',
        category: ScanCategory.recyclable,
        difficulty: QuizDifficulty.easy,
        questions: const [
          RecordQuestion(
            question: 'Dimana kardus dibuang?',
            yourAnswer: 'Daur ulang',
            rightAnswer: 'Daur ulang',
            isCorrect: true,
            trophies: 10,
          ),
        ],
        trophies: 10,
      );
      await store1.addRecord(record1);
      expect(store1.records.length, 1);
      expect(store1.totalTrophies, 10 + questBonus(store1.records));

      // 2. Restart store (new instance, simulating app rebuild / restart)
      final store2 = ScanRecordStore(customFile: testFile);

      // Verify that adding a second record without an explicit load() does NOT
      // overwrite or wipe existing records, but preserves record1.
      final record2 = ScanRecord(
        id: 'second-scan',
        time: DateTime.now(),
        itemName: 'Baterai Jam',
        category: ScanCategory.b3,
        difficulty: QuizDifficulty.medium,
        questions: const [
          RecordQuestion(
            question: 'Kategori baterai?',
            yourAnswer: 'B3',
            rightAnswer: 'B3',
            isCorrect: true,
            trophies: 10,
          ),
        ],
        trophies: 10,
      );
      await store2.addRecord(record2);

      expect(store2.records.length, 2);
      expect(store2.records[0].id, 'second-scan');
      expect(store2.records[1].id, 'initial-scan');
      expect(store2.totalTrophies, 20 + questBonus(store2.records));

      // 3. Restart store once more and load explicitly: records still there
      final store3 = ScanRecordStore(customFile: testFile);
      final reloaded = await store3.load();
      expect(reloaded.length, 2);
      expect(store3.records[0].id, 'second-scan');
      expect(store3.records[1].id, 'initial-scan');
      expect(store3.totalTrophies, 20 + questBonus(store3.records));
    });

    test('rapid overlapping addRecord calls do not lose records', () async {
      final store = ScanRecordStore(customFile: testFile);
      const count = 10;
      final futures = <Future<void>>[];
      for (var i = 0; i < count; i++) {
        futures.add(store.addRecord(
          ScanRecord(
            id: 'concurrent-$i',
            time: DateTime.now(),
            itemName: 'Item $i',
            category: ScanCategory.recyclable,
            difficulty: QuizDifficulty.easy,
            questions: const [],
            trophies: 10,
          ),
        ));
      }
      await Future.wait(futures);

      expect(store.records.length, count);
      expect(store.totalTrophies, count * 10 + questBonus(store.records));

      // Reload into fresh instance to verify disk persistence
      final storeReloaded = ScanRecordStore(customFile: testFile);
      final diskRecords = await storeReloaded.load();
      expect(diskRecords.length, count);
      expect(storeReloaded.totalTrophies, count * 10 + questBonus(storeReloaded.records));
    });
  });
}
