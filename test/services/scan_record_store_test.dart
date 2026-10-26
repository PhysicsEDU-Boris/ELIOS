import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/models/trophy_rules.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/scan_record_store.dart';

void main() {
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
      expect(store1.totalTrophies, 40); // 10 + 30
      expect(store1.userLevel, StudentLevel.ecoStarter);
      expect(store1.levelProgress, closeTo(0.40, 0.001));

      // Reload into a fresh store instance from same file
      final store2 = ScanRecordStore(customFile: testFile);
      await store2.load();

      expect(store2.records.length, 2);
      expect(store2.records[0].id, 'rec-2');
      expect(store2.records[1].id, 'rec-1');
      expect(store2.totalTrophies, 40);
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

      expect(store.totalTrophies, 340);
      expect(store.userLevel, StudentLevel.binExpert);
      expect(store.userLevel.levelNumber, 3);
      expect(store.userLevel.levelAndTitle, 'Level 3 · Bin Expert');
      // Progress from 250 to 500: (340 - 250) / 250 = 90 / 250 = 0.36
      expect(store.levelProgress, closeTo(0.36, 0.001));
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

      expect(store.totalTrophies, 50); // 20 + 20 + 10 + 0
    });
  });
}
