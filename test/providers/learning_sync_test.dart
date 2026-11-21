import 'package:elio/models/clovers.dart';
import 'package:elio/models/learning_progress.dart';
import 'package:elio/providers/clover_provider.dart';
import 'package:elio/providers/learning_progress_provider.dart';
import 'package:elio/services/guide_progress.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Progress extends LearningProgressNotifier {
  @override
  Future<LearningProgress> build() async => LearningProgress(
    userId: 'u1',
    completedVideoIds: const {'v2'},
    videoWatchProgress: const {'v2': 300, 'v1': 40},
  );
}

void main() {
  test('sends one learning snapshot after a change settles, and skips 0/0', () {
    fakeAsync((async) {
      final sent = <Map<String, dynamic>>[];
      final tally = StateProvider((_) => const CloverTally(0, 0));
      final c = ProviderContainer(
        overrides: [
          learningProgressProvider.overrideWith(_Progress.new),
          cloverTallyProvider.overrideWith((ref) => ref.watch(tally)),
          guidesCallProvider.overrideWithValue((body) async {
            sent.add(body);
            return {'ok': true};
          }),
        ],
      );
      addTearDown(c.dispose);
      c.listen(learningSyncProvider, (_, _) {});
      async.elapse(const Duration(seconds: 10));
      expect(sent, isEmpty, reason: 'catalogue not loaded yet');

      c.read(tally.notifier).state = const CloverTally(3, 12);
      c.read(tally.notifier).state = const CloverTally(4, 12);
      async.elapse(const Duration(seconds: 10));
      expect(sent, [
        {
          'op': 'learning',
          'started_video_ids': ['v1', 'v2'],
          'watched_video_ids': ['v2'],
          'clovers_earned': 4,
          'clovers_possible': 12,
        },
      ]);

      c.read(tally.notifier).state = const CloverTally(4, 12);
      async.elapse(const Duration(seconds: 10));
      expect(sent, hasLength(1), reason: 'nothing changed');
    });
  });
}
