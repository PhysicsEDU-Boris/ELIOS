import 'package:elio/l10n/l10n.dart';

/// Grade given based on quiz percentage (trophies / (questions * 10) * 100).
/// Boundaries:
/// - 100 %     : Sempurna
/// - 80 - 99 % : Hebat
/// - 60 - 79 % : Bagus
/// - 40 - 59 % : Belajar Lagi
/// - < 40 %    : Coba Lagi
enum QuizGrade {
  sempurna(100, 100),
  hebat(80, 99),
  bagus(60, 79),
  belajarLagi(40, 59),
  cobaLagi(0, 39);

  const QuizGrade(this.minPercent, this.maxPercent);

  String get label => switch (this) {
    sempurna => l10n.gradePerfect,
    hebat => l10n.gradeGreat,
    bagus => l10n.gradeGood,
    belajarLagi => l10n.gradeKeepLearning,
    cobaLagi => l10n.gradeTryAgain,
  };
  final int minPercent;
  final int maxPercent;

  static QuizGrade forPercent(num percent) {
    if (percent >= 100) return QuizGrade.sempurna;
    if (percent >= 80) return QuizGrade.hebat;
    if (percent >= 60) return QuizGrade.bagus;
    if (percent >= 40) return QuizGrade.belajarLagi;
    return QuizGrade.cobaLagi;
  }
}

/// Student level derived from total cumulative trophies.
/// Boundaries:
/// - Lv1 Eco Starter     : 0 - 149
/// - Lv2 Waste Spotter   : 150 - 374
/// - Lv3 Bin Expert      : 375 - 749
/// - Lv4 Eco Sorter      : 750 - 1499
/// - Lv5 Planet Guardian : 1500+
/// Counts scan trophies + quest rewards + guide XP; ×1.5 of the old
/// scan-only thresholds so adding guide XP does not lift everyone (decision 0204).
enum StudentLevel {
  ecoStarter(1, 0, 149, 150),
  wasteSpotter(2, 150, 374, 375),
  binExpert(3, 375, 749, 750),
  ecoSorter(4, 750, 1499, 1500),
  planetGuardian(5, 1500, null, null);

  const StudentLevel(
    this.levelNumber,
    this.minTrophies,
    this.maxTrophies,
    this.nextLevelThreshold,
  );

  final int levelNumber;
  String get title => switch (this) {
    ecoStarter => l10n.levelEcoStarter,
    wasteSpotter => l10n.levelWasteSpotter,
    binExpert => l10n.levelBinExpert,
    ecoSorter => l10n.levelEcoSorter,
    planetGuardian => l10n.levelPlanetGuardian,
  };
  final int minTrophies;
  final int? maxTrophies;
  final int? nextLevelThreshold;

  String get shortName => 'Lv$levelNumber $title';
  String get levelAndTitle => 'Level $levelNumber · $title';

  static StudentLevel forTotal(int trophies) => values.lastWhere(
    (l) => trophies >= l.minTrophies,
    orElse: () => ecoStarter,
  );

  /// Linear progress fraction [0.0, 1.0] towards the next level threshold.
  double progress(int totalTrophies) {
    if (nextLevelThreshold == null) return 1.0;
    final clamped = totalTrophies.clamp(minTrophies, nextLevelThreshold!);
    final span = nextLevelThreshold! - minTrophies;
    if (span <= 0) return 1.0;
    return (clamped - minTrophies) / span;
  }
}

/// Calculates trophies earned for a quiz session.
/// Rule: each correct MC = 10 trophies; essay = score out of 10.
int trophiesFor(dynamic session, {int essayScore = 0}) {
  if (session is int) {
    return (session * 10) + essayScore;
  }
  if (session != null) {
    try {
      final dynamic s = session;
      if (s.questions != null && s.questions is Iterable) {
        var total = 0;
        for (final q in s.questions) {
          if (q.trophies != null) {
            total += (q.trophies as num).toInt();
          } else if (q.isCorrect == true) {
            total += 10;
          }
        }
        return total;
      }
      if (s.correctCount != null) {
        return ((s.correctCount as int) * 10) + essayScore;
      }
    } catch (_) {}
  }
  return 0;
}

/// Helper to compute trophies given explicit correct MC count and essay score.
int trophiesForScores({required int correctMcCount, int essayScore = 0}) {
  return (correctMcCount * 10) + essayScore.clamp(0, 10);
}

/// Computes the percentage of trophies earned out of max possible trophies (questions * 10).
double gradePercent({required int trophies, required int totalQuestions}) {
  if (totalQuestions <= 0) return 0.0;
  final maxTrophies = totalQuestions * 10;
  return (trophies / maxTrophies) * 100.0;
}

/// Returns the QuizGrade for given trophies and total question count.
QuizGrade gradeFor({required int trophies, required int totalQuestions}) {
  return QuizGrade.forPercent(
    gradePercent(trophies: trophies, totalQuestions: totalQuestions),
  );
}
