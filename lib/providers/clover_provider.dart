import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clovers.dart';
import '../models/physics_module.dart';
import '../services/guide_progress.dart';
import 'daily_guide_provider.dart';
import 'learn_shortcut_provider.dart';
import 'learning_progress_provider.dart';
import 'physics_progress_provider.dart';

/// Clovers earned / possible across all learning content (decision 0211).
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

/// Sends the learning snapshot (videos started/watched, clovers) to the guides backend for the
/// ELIOS Insights dashboard, a few seconds after it changes. Best effort: a failed send is
/// retried on the next change or app start. Kept alive by the Learn tab.
final learningSyncProvider = Provider<void>((ref) {
  Timer? timer;
  String? sent;
  ref.onDispose(() => timer?.cancel());
  void schedule() {
    final call = ref.read(guidesCallProvider);
    final progress = ref.read(learningProgressProvider).valueOrNull;
    final tally = ref.read(cloverTallyProvider);
    // possible == 0 means the catalogue has not loaded yet; never overwrite real numbers with 0/0.
    if (call == null || progress == null || tally.possible == 0) return;
    final body = <String, dynamic>{
      'op': 'learning',
      'started_video_ids': progress.videoWatchProgress.keys.toList()..sort(),
      'watched_video_ids': progress.completedVideoIds.toList()..sort(),
      'clovers_earned': tally.earned,
      'clovers_possible': tally.possible,
    };
    final key = jsonEncode(body);
    if (key == sent) return;
    timer?.cancel();
    timer = Timer(const Duration(seconds: 5), () async {
      try {
        await call(body);
        sent = key;
      } catch (_) {
        // Offline or backend down: the next change sends it again.
      }
    });
  }

  ref.listen(guidesCallProvider, (_, _) {
    sent = null; // another account: its row needs its own snapshot
    schedule();
  });
  ref.listen(cloverTallyProvider, (_, _) => schedule());
  ref.listen(learningProgressProvider, (_, _) => schedule(), fireImmediately: true);
});
