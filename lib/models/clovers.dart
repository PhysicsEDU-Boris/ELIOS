// Clovers = finished learning (decision 0205). Every item has a fixed number to
// collect, so "12 of 40" means something. Derived from stored completions; nothing extra is saved.

/// Daily Guide issue state needed for clovers.
typedef IssueClovers = ({bool read, bool quizPassed, bool labApproved});

class CloverTally {
  const CloverTally(this.earned, this.possible);

  /// Counts only items in the current catalogue, so earned never exceeds possible.
  /// - video watched to the end, module guide read to the end, simulation opened: 1 each
  /// - module quiz: 1 at >= 70 %, +1 at 100 %
  /// - Daily Guide issue: story + physics read, quiz passed, lab approved: 1 each
  factory CloverTally.from({
    required Iterable<String> videoIds,
    required Set<String> completedVideoIds,
    required Iterable<String> guideIds,
    required Set<String> completedGuideIds,
    required Iterable<String> quizModuleIds,
    required Map<String, int> quizBestPercent,
    required Iterable<String> simulationIds,
    required Set<String> viewedSimulationIds,
    required Iterable<IssueClovers> issues,
  }) {
    var earned = 0, possible = 0;
    void one(bool done) {
      possible++;
      if (done) earned++;
    }

    for (final id in videoIds) {
      one(completedVideoIds.contains(id));
    }
    for (final id in guideIds) {
      one(completedGuideIds.contains(id));
    }
    for (final id in simulationIds) {
      one(viewedSimulationIds.contains(id));
    }
    for (final id in quizModuleIds) {
      final best = quizBestPercent[id] ?? 0;
      one(best >= 70);
      one(best >= 100);
    }
    for (final i in issues) {
      one(i.read);
      one(i.quizPassed);
      one(i.labApproved);
    }
    return CloverTally(earned, possible);
  }

  final int earned, possible;

  /// 0..1; 0 when nothing can be earned yet.
  double get fraction => possible == 0 ? 0 : earned / possible;
}
