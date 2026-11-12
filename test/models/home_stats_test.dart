import 'package:elio/models/home_stats.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/models/trophy_rules.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _right = RecordQuestion(
  question: 'q',
  yourAnswer: 'a',
  rightAnswer: 'a',
  isCorrect: true,
);
const _wrong = RecordQuestion(
  question: 'q',
  yourAnswer: 'b',
  rightAnswer: 'a',
  isCorrect: false,
);

var _n = 0;
ScanRecord rec(
  DateTime time, {
  ScanCategory cat = ScanCategory.recyclable,
  List<RecordQuestion> qs = const [],
  QuizDifficulty diff = QuizDifficulty.easy,
  int? trophies,
}) => ScanRecord(
  id: 'r${_n++}',
  time: time,
  itemName: 'Item',
  category: cat,
  difficulty: diff,
  questions: qs,
  trophies: trophies,
);

void main() {
  // Wednesday 4 Nov 2026, 10:00 local.
  final now = DateTime(2026, 11, 4, 10);
  DateTime daysAgo(int d, [int hour = 9]) => DateTime(2026, 11, 4 - d, hour);

  group('streak', () {
    test('counts back from today', () {
      final s = HomeStats.from([
        rec(daysAgo(0)),
        rec(daysAgo(1)),
        rec(daysAgo(2)),
      ], now);
      expect(s.currentStreak, 3);
    });

    test('yesterday counts when there is no scan today yet', () {
      final s = HomeStats.from([rec(daysAgo(1)), rec(daysAgo(2))], now);
      expect(s.currentStreak, 2);
    });

    test('a gap ends it; longest is kept', () {
      final s = HomeStats.from([
        rec(daysAgo(0)),
        // gap on day 1
        rec(daysAgo(2)), rec(daysAgo(3)), rec(daysAgo(4)), rec(daysAgo(5)),
      ], now);
      expect(s.currentStreak, 1);
      expect(s.longestStreak, 4);
    });

    test('nothing today or yesterday is 0', () {
      expect(HomeStats.from([rec(daysAgo(2))], now).currentStreak, 0);
      expect(HomeStats.from([], now).currentStreak, 0);
    });
  });

  test('per-day counts split at local midnight', () {
    final s = HomeStats.from([
      rec(DateTime(2026, 11, 3, 23, 59)),
      rec(DateTime(2026, 11, 4, 0, 0)),
      rec(DateTime(2026, 11, 4, 0, 1)),
    ], now);
    expect(s.scansOn(DateTime(2026, 11, 3)), 1);
    expect(s.scansOn(DateTime(2026, 11, 4)), 2);
    expect(s.todayScans, 2);
  });

  test('UTC record times are counted on their local day', () {
    final local = DateTime(2026, 11, 4, 0, 30);
    final s = HomeStats.from([rec(local.toUtc())], now);
    expect(s.scansOn(DateTime(2026, 11, 4)), 1);
  });

  test('bins: residu goes to Anorganik, top bin, tie has no top', () {
    final s = HomeStats.from([
      rec(now, cat: ScanCategory.organic),
      rec(now, cat: ScanCategory.recyclable),
      rec(now, cat: ScanCategory.residu),
      rec(now, cat: ScanCategory.residu),
      rec(now, cat: ScanCategory.b3),
    ], now);
    expect(s.binCounts, {
      HomeBin.organik: 1,
      HomeBin.anorganik: 3,
      HomeBin.b3: 1,
    });
    expect(s.residuCount, 2);
    expect(s.topBin, HomeBin.anorganik);

    final tie = HomeStats.from([
      rec(now, cat: ScanCategory.organic),
      rec(now, cat: ScanCategory.b3),
    ], now);
    expect(tie.topBin, isNull);
    expect(HomeStats.from([], now).topBin, isNull);
  });

  group('quiz accuracy', () {
    test('null without questions', () {
      final s = HomeStats.from([rec(now)], now);
      expect(s.quizAccuracy, isNull);
      expect(s.quizDelta, isNull);
    });

    test('only the last 10 scans with questions count', () {
      final records = [
        // 5 old all-wrong scans fall out of the window.
        for (var i = 0; i < 5; i++) rec(daysAgo(30 + i), qs: const [_wrong]),
        // A scan without questions is skipped.
        rec(daysAgo(0)),
        for (var i = 0; i < 10; i++)
          rec(
            daysAgo(10 - i),
            qs: i < 2 ? const [_right, _wrong] : const [_right],
          ),
      ];
      final s = HomeStats.from(records, now);
      // 10 correct of 12 answered.
      expect(s.quizAccuracy, 83);
      expect(s.quizPercents.length, 10);
      expect(s.quizPercents.first, 50);
      expect(s.quizDelta, 50);
    });

    test('essays waiting for a grade are not counted as answered', () {
      const pending = RecordQuestion(
        question: 'e',
        yourAnswer: 'x',
        rightAnswer: '',
        isCorrect: false,
        isEssay: true,
      );
      final s = HomeStats.from([
        rec(now, qs: const [_right, pending]),
      ], now);
      expect(s.quizAccuracy, 100);
    });
  });

  test('week bars: Monday-first current week, split by bin', () {
    final s = HomeStats.from([
      rec(DateTime(2026, 11, 2, 8), cat: ScanCategory.organic), // Mon
      rec(DateTime(2026, 11, 2, 9), cat: ScanCategory.residu), // Mon
      rec(DateTime(2026, 11, 4, 9), cat: ScanCategory.b3), // Wed
      rec(DateTime(2026, 11, 1, 9)), // Sunday before: last week
    ], now);
    final w = s.weekBins;
    expect(w[0], {HomeBin.organik: 1, HomeBin.anorganik: 1, HomeBin.b3: 0});
    expect(w[2][HomeBin.b3], 1);
    expect(w[6].values.every((v) => v == 0), isTrue);
    expect(s.weekTotal, 3);
  });

  group('quests', () {
    test('progress from today', () {
      final s = HomeStats.from([
        rec(now, qs: const [_right]),
        rec(now, cat: ScanCategory.b3),
      ], now);
      final q = s.quests;
      expect(q[0].progress, closeTo(2 / 3, 1e-9));
      expect(q[1].done, isTrue);
      expect(q[2].done, isTrue);
      expect([q[0].reward, q[1].reward, q[2].reward], [10, 10, 20]);
    });

    test('a partly answered quiz is not finished', () {
      final s = HomeStats.from([
        rec(now, qs: const [_right], diff: QuizDifficulty.hard),
      ], now);
      expect(s.quests[1].done, isFalse);
    });

    test('reset at local midnight', () {
      final records = [
        rec(
          DateTime(2026, 11, 4, 23, 59),
          cat: ScanCategory.b3,
          qs: const [_right],
        ),
      ];
      expect(
        HomeStats.from(
          records,
          DateTime(2026, 11, 4, 23, 59, 30),
        ).quests.where((q) => q.done).length,
        2,
      );
      final next = HomeStats.from(records, DateTime(2026, 11, 5, 0, 0, 1));
      expect(next.quests.every((q) => q.progress == 0), isTrue);
    });

    test('done quests add their rewards to trophies and level', () {
      // Wed 4 Nov: B3 + finished quiz = +20 +10; 3 scans not reached.
      final s = HomeStats.from([
        rec(now, cat: ScanCategory.b3, qs: const [_right], trophies: 10),
        rec(now, trophies: 50),
      ], now);
      expect(s.totalTrophies, 60 + 30);
      expect(questBonus(s.records), 30);

      // A full day: all three quests, +40.
      final full = HomeStats.from([
        rec(now, cat: ScanCategory.b3, qs: const [_right], trophies: 0),
        rec(now, trophies: 0),
        rec(now, trophies: 0),
      ], now);
      expect(full.totalTrophies, 40);
    });

    test('each day counts once; days before quests existed count nothing', () {
      final records = [
        rec(DateTime(2026, 11, 3, 9), cat: ScanCategory.b3, trophies: 0),
        rec(DateTime(2026, 11, 3, 10), cat: ScanCategory.b3, trophies: 0),
        rec(DateTime(2026, 11, 2, 9), cat: ScanCategory.b3, trophies: 0),
        rec(DateTime(2026, 11, 1, 23, 59), cat: ScanCategory.b3, trophies: 0),
      ];
      // 3 Nov: B3 once (+20) even with two B3 scans; 2 Nov: +20; 1 Nov: before start.
      expect(questBonus(records), 40);
      expect(HomeStats.from(records, now).totalTrophies, 40);
    });

    test('bonus can move the level', () {
      final s = HomeStats.from([
        rec(now, cat: ScanCategory.b3, qs: const [_right], trophies: 120),
      ], now);
      expect(s.totalTrophies, 150);
      expect(s.level, StudentLevel.wasteSpotter);
    });
  });

  test('level progress from summed trophies', () {
    final s = HomeStats.from([
      rec(now, trophies: 300),
      rec(now, trophies: 210),
    ], now);
    expect(s.totalTrophies, 510);
    expect(s.level, StudentLevel.binExpert);
    expect(s.trophiesToNext, 240);
    expect(s.levelProgress, closeTo(135 / 375, 1e-9));

    final top = HomeStats.from([rec(now, trophies: 1600)], now);
    expect(top.trophiesToNext, isNull);
    expect(top.levelProgress, 1.0);
  });

  test('learning XP counts toward the level (0204, 0206)', () {
    final records = [rec(now, trophies: 100)];
    expect(HomeStats.from(records, now).level, StudentLevel.ecoStarter);
    final s = HomeStats.from(records, now, learnXp: 60);
    expect(s.totalTrophies, 160);
    expect(s.level, StudentLevel.wasteSpotter);
  });

  test('year grid starts on a Sunday 16 weeks before this week', () {
    final s = HomeStats.from([rec(daysAgo(0)), rec(daysAgo(200))], now);
    expect(s.gridStart.weekday, DateTime.sunday);
    expect(s.gridStart, DateTime(2026, 7, 12));
    expect(s.scansInGrid, 1);
  });
}
