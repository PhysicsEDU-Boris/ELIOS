import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/trophy_rules.dart';

void main() {
  group('QuizGrade boundary tests', () {
    test('100% -> Sempurna', () {
      expect(QuizGrade.forPercent(100), QuizGrade.sempurna);
      expect(QuizGrade.forPercent(100), QuizGrade.sempurna);
    });

    test('99% -> Hebat', () {
      expect(QuizGrade.forPercent(99), QuizGrade.hebat);
      expect(QuizGrade.forPercent(99), QuizGrade.hebat);
    });

    test('80% -> Hebat', () {
      expect(QuizGrade.forPercent(80), QuizGrade.hebat);
      expect(QuizGrade.forPercent(80), QuizGrade.hebat);
    });

    test('79% -> Bagus', () {
      expect(QuizGrade.forPercent(79), QuizGrade.bagus);
      expect(QuizGrade.forPercent(79), QuizGrade.bagus);
    });

    test('60% -> Bagus', () {
      expect(QuizGrade.forPercent(60), QuizGrade.bagus);
      expect(QuizGrade.forPercent(60), QuizGrade.bagus);
    });

    test('59% -> Belajar Lagi', () {
      expect(QuizGrade.forPercent(59), QuizGrade.belajarLagi);
      expect(QuizGrade.forPercent(59), QuizGrade.belajarLagi);
    });

    test('40% -> Belajar Lagi', () {
      expect(QuizGrade.forPercent(40), QuizGrade.belajarLagi);
      expect(QuizGrade.forPercent(40), QuizGrade.belajarLagi);
    });

    test('39% -> Coba Lagi', () {
      expect(QuizGrade.forPercent(39), QuizGrade.cobaLagi);
      expect(QuizGrade.forPercent(39), QuizGrade.cobaLagi);
    });

    test('0% -> Coba Lagi', () {
      expect(QuizGrade.forPercent(0), QuizGrade.cobaLagi);
      expect(QuizGrade.forPercent(0), QuizGrade.cobaLagi);
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

  group('StudentLevel boundary tests (decision 0204 thresholds)', () {
    test('149 -> Lv1 Eco Starter', () {
      final level = StudentLevel.forTotal(149);
      expect(level, StudentLevel.ecoStarter);
      expect(level.levelNumber, 1);
      expect(level.title, 'Eco Starter');
      expect(level.shortName, 'Lv1 Eco Starter');
      expect(level.levelAndTitle, 'Level 1 · Eco Starter');
      expect(level.progress(149), closeTo(149 / 150, 0.001));
      expect(StudentLevel.forTotal(0), StudentLevel.ecoStarter);
    });

    test('150 -> Lv2 Waste Spotter, 374 stays Lv2', () {
      final level = StudentLevel.forTotal(150);
      expect(level, StudentLevel.wasteSpotter);
      expect(level.levelAndTitle, 'Level 2 · Waste Spotter');
      expect(level.progress(150), 0.0);
      expect(StudentLevel.forTotal(374), StudentLevel.wasteSpotter);
      expect(level.progress(374), closeTo(224 / 225, 0.001));
    });

    test('375 -> Lv3 Bin Expert, 749 stays Lv3', () {
      final level = StudentLevel.forTotal(375);
      expect(level, StudentLevel.binExpert);
      expect(level.levelAndTitle, 'Level 3 · Bin Expert');
      expect(level.progress(375), 0.0);
      expect(StudentLevel.forTotal(749), StudentLevel.binExpert);
      // (510 - 375) / (750 - 375) = 135 / 375 = 0.36
      expect(level.progress(510), closeTo(0.36, 0.001));
    });

    test('750 -> Lv4 Eco Sorter, 1499 stays Lv4', () {
      final level = StudentLevel.forTotal(750);
      expect(level, StudentLevel.ecoSorter);
      expect(level.levelAndTitle, 'Level 4 · Eco Sorter');
      expect(level.progress(750), 0.0);
      expect(StudentLevel.forTotal(1499), StudentLevel.ecoSorter);
    });

    test('1500 -> Lv5 Planet Guardian', () {
      final level = StudentLevel.forTotal(1500);
      expect(level, StudentLevel.planetGuardian);
      expect(level.levelAndTitle, 'Level 5 · Planet Guardian');
      expect(level.progress(1500), 1.0);
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
