import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/trophy_rules.dart';

void main() {
  group('QuizGrade boundary tests', () {
    test('100% -> Sempurna', () {
      expect(QuizGrade.forPercent(100), QuizGrade.sempurna);
      expect(QuizGrade.forPercent(100).label, 'Sempurna');
    });

    test('99% -> Hebat', () {
      expect(QuizGrade.forPercent(99), QuizGrade.hebat);
      expect(QuizGrade.forPercent(99).label, 'Hebat');
    });

    test('80% -> Hebat', () {
      expect(QuizGrade.forPercent(80), QuizGrade.hebat);
      expect(QuizGrade.forPercent(80).label, 'Hebat');
    });

    test('79% -> Bagus', () {
      expect(QuizGrade.forPercent(79), QuizGrade.bagus);
      expect(QuizGrade.forPercent(79).label, 'Bagus');
    });

    test('60% -> Bagus', () {
      expect(QuizGrade.forPercent(60), QuizGrade.bagus);
      expect(QuizGrade.forPercent(60).label, 'Bagus');
    });

    test('59% -> Belajar Lagi', () {
      expect(QuizGrade.forPercent(59), QuizGrade.belajarLagi);
      expect(QuizGrade.forPercent(59).label, 'Belajar Lagi');
    });

    test('40% -> Belajar Lagi', () {
      expect(QuizGrade.forPercent(40), QuizGrade.belajarLagi);
      expect(QuizGrade.forPercent(40).label, 'Belajar Lagi');
    });

    test('39% -> Coba Lagi', () {
      expect(QuizGrade.forPercent(39), QuizGrade.cobaLagi);
      expect(QuizGrade.forPercent(39).label, 'Coba Lagi');
    });

    test('0% -> Coba Lagi', () {
      expect(QuizGrade.forPercent(0), QuizGrade.cobaLagi);
      expect(QuizGrade.forPercent(0).label, 'Coba Lagi');
    });

    test('gradeFor calculates percent from trophies and question count', () {
      // 3 of 3 correct = 30 trophies out of 30 = 100%
      expect(gradeFor(trophies: 30, totalQuestions: 3), QuizGrade.sempurna);
      // 2 of 3 correct = 20 trophies out of 30 = 66.67% -> Bagus
      expect(gradeFor(trophies: 20, totalQuestions: 3), QuizGrade.bagus);
      // 1 of 3 correct = 10 trophies out of 30 = 33.33% -> Coba Lagi
      expect(gradeFor(trophies: 10, totalQuestions: 3), QuizGrade.cobaLagi);
    });
  });

  group('StudentLevel boundary tests', () {
    test('99 trophies -> Lv1 Eco Starter', () {
      final level = StudentLevel.forTotal(99);
      expect(level, StudentLevel.ecoStarter);
      expect(level.levelNumber, 1);
      expect(level.title, 'Eco Starter');
      expect(level.shortName, 'Lv1 Eco Starter');
      expect(level.levelAndTitle, 'Level 1 · Eco Starter');
      // Progress: 99 / 100 = 0.99
      expect(level.progress(99), closeTo(0.99, 0.001));
    });

    test('100 trophies -> Lv2 Waste Spotter', () {
      final level = StudentLevel.forTotal(100);
      expect(level, StudentLevel.wasteSpotter);
      expect(level.levelNumber, 2);
      expect(level.title, 'Waste Spotter');
      expect(level.levelAndTitle, 'Level 2 · Waste Spotter');
      // Progress at start of level 2 (min 100, next 250): 0.0
      expect(level.progress(100), 0.0);
    });

    test('249 trophies -> Lv2 Waste Spotter', () {
      final level = StudentLevel.forTotal(249);
      expect(level, StudentLevel.wasteSpotter);
      expect(level.levelNumber, 2);
      // Progress: (249 - 100) / (250 - 100) = 149 / 150 = 0.9933
      expect(level.progress(249), closeTo(149 / 150, 0.001));
    });

    test('250 trophies -> Lv3 Bin Expert', () {
      final level = StudentLevel.forTotal(250);
      expect(level, StudentLevel.binExpert);
      expect(level.levelNumber, 3);
      expect(level.title, 'Bin Expert');
      expect(level.levelAndTitle, 'Level 3 · Bin Expert');
      expect(level.progress(250), 0.0);
    });

    test('340 trophies -> Lv3 Bin Expert (Figma shows 340 · Level 4, but rule is Lv3)', () {
      final level = StudentLevel.forTotal(340);
      expect(level, StudentLevel.binExpert);
      expect(level.levelNumber, 3);
      expect(level.title, 'Bin Expert');
      expect(level.levelAndTitle, 'Level 3 · Bin Expert');
      // Progress: (340 - 250) / (500 - 250) = 90 / 250 = 0.36
      expect(level.progress(340), closeTo(0.36, 0.001));
    });

    test('499 trophies -> Lv3 Bin Expert', () {
      final level = StudentLevel.forTotal(499);
      expect(level, StudentLevel.binExpert);
      expect(level.levelNumber, 3);
      // Progress: (499 - 250) / 250 = 249 / 250 = 0.996
      expect(level.progress(499), closeTo(249 / 250, 0.001));
    });

    test('500 trophies -> Lv4 Eco Sorter', () {
      final level = StudentLevel.forTotal(500);
      expect(level, StudentLevel.ecoSorter);
      expect(level.levelNumber, 4);
      expect(level.title, 'Eco Sorter');
      expect(level.levelAndTitle, 'Level 4 · Eco Sorter');
      expect(level.progress(500), 0.0);
    });

    test('999 trophies -> Lv4 Eco Sorter', () {
      final level = StudentLevel.forTotal(999);
      expect(level, StudentLevel.ecoSorter);
      expect(level.levelNumber, 4);
      // Progress: (999 - 500) / (1000 - 500) = 499 / 500 = 0.998
      expect(level.progress(999), closeTo(499 / 500, 0.001));
    });

    test('1000 trophies -> Lv5 Planet Guardian', () {
      final level = StudentLevel.forTotal(1000);
      expect(level, StudentLevel.planetGuardian);
      expect(level.levelNumber, 5);
      expect(level.title, 'Planet Guardian');
      expect(level.levelAndTitle, 'Level 5 · Planet Guardian');
      expect(level.progress(1000), 1.0);
    });
  });

  group('trophiesFor calculation', () {
    test('correct x 10 for MC', () {
      expect(trophiesFor(0), 0);
      expect(trophiesFor(1), 10);
      expect(trophiesFor(2), 20);
      expect(trophiesFor(3), 30);
    });

    test('essay score out of 10 added as trophies', () {
      expect(trophiesFor(2, essayScore: 8), 28);
      expect(trophiesForScores(correctMcCount: 1, essayScore: 7), 17);
    });
  });
}
