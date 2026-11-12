// Home H1 v4 numbers (decision 0144). Pure maths over the local scan records so
// it can be tested with a fixed clock. Days are local calendar days.
import 'scan_record.dart';
import 'trophy_rules.dart';
import 'package:elio/l10n/l10n.dart';

/// The robot's three physical bins. Residu is sorted into Anorganik.
enum HomeBin {
  organik('Organik'),
  anorganik('Anorganik'),
  b3('B3');

  const HomeBin(this.label);
  final String label;

  static HomeBin of(ScanCategory c) => switch (c) {
    ScanCategory.organic => HomeBin.organik,
    ScanCategory.b3 => HomeBin.b3,
    ScanCategory.recyclable || ScanCategory.residu => HomeBin.anorganik,
  };
}

DateTime localDay(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Calendar arithmetic, safe across daylight-saving changes.
DateTime addDays(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day + n);

class DailyQuest {
  const DailyQuest(this.title, this.reward, this.progress);
  final String title;

  /// Added to the trophy total when done (owner, 2 Nov; decision 0144).
  final int reward;

  /// 0..1
  final double progress;
  bool get done => progress >= 1;
}

/// Quest rewards count from the day the quests first appeared; earlier days get
/// none, so old records do not suddenly add trophies.
final questRewardsStart = DateTime(2026, 11, 2);

/// The three daily quests for one local day's scans.
List<DailyQuest> dailyQuests(List<ScanRecord> dayRecords) {
  final quizDone = dayRecords.any(
    (r) =>
        r.questions.isNotEmpty &&
        r.questions.length >= r.difficulty.questionCount &&
        !r.questions.any((q) => q.gradingPending),
  );
  return [
    DailyQuest(l10n.questScan3, 10, (dayRecords.length / 3).clamp(0, 1)),
    DailyQuest(l10n.questFinishQuiz, 10, quizDone ? 1 : 0),
    DailyQuest(
      l10n.questSortB3,
      20,
      dayRecords.any((r) => r.category == ScanCategory.b3) ? 1 : 0,
    ),
  ];
}

/// Rewards of every quest done on each local day since [questRewardsStart].
/// Derived from the records, so nothing extra is stored.
int questBonus(Iterable<ScanRecord> records) {
  final byDay = <DateTime, List<ScanRecord>>{};
  for (final r in records) {
    final d = localDay(r.time);
    if (!d.isBefore(questRewardsStart)) byDay.putIfAbsent(d, () => []).add(r);
  }
  return byDay.values.fold(
    0,
    (sum, day) =>
        sum +
        dailyQuests(day).where((q) => q.done).fold(0, (a, q) => a + q.reward),
  );
}

class HomeStats {
  HomeStats._({
    required this.today,
    required this.records,
    required this.perDay,
    required this.totalTrophies,
    required this.quizSeries,
    required this.currentStreak,
    required this.longestStreak,
    required this.binCounts,
    required this.residuCount,
  });

  /// [guideXp]: Daily Guide XP, counted in the level total (decision 0204).
  factory HomeStats.from(
    List<ScanRecord> records,
    DateTime now, {
    int guideXp = 0,
  }) {
    final perDay = <DateTime, int>{};
    final bins = {for (final b in HomeBin.values) b: 0};
    var residu = 0, trophies = 0;
    for (final r in records) {
      final d = localDay(r.time);
      perDay[d] = (perDay[d] ?? 0) + 1;
      bins[HomeBin.of(r.category)] = bins[HomeBin.of(r.category)]! + 1;
      if (r.category == ScanCategory.residu) residu++;
      trophies += r.trophies;
    }

    final today = localDay(now);
    // Current streak: today, or yesterday when nothing is scanned yet today.
    var day = perDay.containsKey(today) ? today : addDays(today, -1);
    var current = 0;
    while (perDay.containsKey(day)) {
      current++;
      day = addDays(day, -1);
    }
    var longest = 0, run = 0;
    DateTime? prev;
    for (final d in perDay.keys.toList()..sort()) {
      run = prev != null && addDays(prev, 1) == d ? run + 1 : 1;
      if (run > longest) longest = run;
      prev = d;
    }

    // Last 10 scans that have answered questions, oldest first.
    final withQuiz = records.where((r) => _answered(r) > 0).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final last = withQuiz.length > 10
        ? withQuiz.sublist(withQuiz.length - 10)
        : withQuiz;

    return HomeStats._(
      today: today,
      records: records,
      perDay: perDay,
      totalTrophies: trophies + questBonus(records) + guideXp,
      quizSeries: last,
      currentStreak: current,
      longestStreak: longest,
      binCounts: bins,
      residuCount: residu,
    );
  }

  final DateTime today;
  final List<ScanRecord> records;
  final Map<DateTime, int> perDay;
  final int totalTrophies;
  final List<ScanRecord> quizSeries;
  final int currentStreak, longestStreak;
  final Map<HomeBin, int> binCounts;
  final int residuCount;

  int get totalScans => records.length;
  bool get isEmpty => records.isEmpty;

  StudentLevel get level => StudentLevel.forTotal(totalTrophies);
  double get levelProgress => level.progress(totalTrophies);
  int? get trophiesToNext => level.nextLevelThreshold == null
      ? null
      : level.nextLevelThreshold! - totalTrophies;

  static int _answered(ScanRecord r) =>
      r.questions.where((q) => !q.gradingPending).length;

  /// Correct / answered over the last 10 scans with questions; null when none.
  int? get quizAccuracy {
    var correct = 0, answered = 0;
    for (final r in quizSeries) {
      correct += r.questions.where((q) => q.isCorrect).length;
      answered += _answered(r);
    }
    return answered == 0 ? null : (correct * 100 / answered).round();
  }

  /// Per-scan quiz % for the sparkline, oldest first.
  List<int> get quizPercents => [
    for (final r in quizSeries)
      (r.questions.where((q) => q.isCorrect).length * 100 / _answered(r))
          .round(),
  ];

  /// Last minus first of [quizPercents]; null with fewer than 2 points.
  int? get quizDelta {
    final p = quizPercents;
    return p.length < 2 ? null : p.last - p.first;
  }

  int scansOn(DateTime day) => perDay[localDay(day)] ?? 0;

  List<ScanRecord> recordsOn(DateTime day) {
    final d = localDay(day);
    return records.where((r) => localDay(r.time) == d).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
  }

  /// First (Sunday) of the 17-week year grid; the last column holds today.
  DateTime get gridStart => addDays(today, -(today.weekday % 7) - 16 * 7);

  int get scansInGrid => perDay.entries
      .where((e) => !e.key.isBefore(gridStart) && !e.key.isAfter(today))
      .fold(0, (s, e) => s + e.value);

  int scansInMonth(int year, int month) => perDay.entries
      .where((e) => e.key.year == year && e.key.month == month)
      .fold(0, (s, e) => s + e.value);

  int get todayScans => scansOn(today);

  /// Monday-first days of the current week, each split by bin.
  List<Map<HomeBin, int>> get weekBins {
    final monday = addDays(today, 1 - today.weekday);
    final days = [for (var i = 0; i < 7; i++) addDays(monday, i)];
    final week = [
      for (var i = 0; i < 7; i++) {for (final b in HomeBin.values) b: 0},
    ];
    for (final r in records) {
      final i = days.indexOf(localDay(r.time));
      if (i < 0) continue;
      final bin = HomeBin.of(r.category);
      week[i][bin] = week[i][bin]! + 1;
    }
    return week;
  }

  int get weekTotal =>
      weekBins.fold(0, (s, d) => s + d.values.fold(0, (a, b) => a + b));

  /// The bin with the most scans; null when empty or tied for first.
  HomeBin? get topBin {
    final sorted = binCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.first.value == 0 || sorted.first.value == sorted[1].value) {
      return null;
    }
    return sorted.first.key;
  }

  List<DailyQuest> get quests => dailyQuests(recordsOn(today));
}
