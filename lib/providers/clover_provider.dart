import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clovers.dart';
import '../models/physics_module.dart';
import '../services/guide_progress.dart';
import 'daily_guide_provider.dart';
import 'learn_shortcut_provider.dart';
import 'learning_progress_provider.dart';
import 'physics_progress_provider.dart';

/// Clovers earned / possible across all learning content (decision 0205).
final cloverTallyProvider = Provider<CloverTally>((ref) {
  List<T> list<T>(AsyncValue<List<T>> v) => v.valueOrNull ?? const [];
  final progress = ref.watch(learningProgressProvider).valueOrNull;
  final guides = ref.watch(guideProgressProvider);
  final feed = ref.watch(dailyGuideFeedProvider).valueOrNull;
  return CloverTally.from(
    videoIds: list(ref.watch(learnVideosProvider)).map((v) => v.id),
    completedVideoIds: progress?.completedVideoIds ?? const {},
    guideIds: list(ref.watch(learnGuidesProvider)).map((g) => g.id),
    completedGuideIds: progress?.completedGuideIds ?? const {},
    quizModuleIds: list(
      ref.watch(learnQuizSetsProvider),
    ).map((q) => q.moduleId).toSet(),
    quizBestPercent: progress?.quizScores ?? const {},
    simulationIds: physicsModules
        .where((m) => m.isAvailable)
        .map((m) => m.id.name),
    viewedSimulationIds:
        ref
            .watch(physicsProgressProvider)
            .valueOrNull
            ?.viewedModuleIds
            .toSet() ??
        const {},
    issues: [
      for (final g in feed?.guides ?? const [])
        if (guides.of(g.date) case final p)
          (
            read: p.story && p.physics,
            quizPassed: p.quizPassed,
            labApproved: p.labApproved,
          ),
    ],
  );
});
