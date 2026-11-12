import 'package:elio/models/clovers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CloverTally tally({
    Set<String> videos = const {},
    Set<String> guides = const {},
    Map<String, int> quiz = const {},
    Set<String> sims = const {},
    List<IssueClovers> issues = const [],
  }) => CloverTally.from(
    videoIds: const ['v1', 'v2'],
    completedVideoIds: videos,
    guideIds: const ['g1'],
    completedGuideIds: guides,
    quizModuleIds: const ['organic', 'b3'],
    quizBestPercent: quiz,
    simulationIds: const ['torque'],
    viewedSimulationIds: sims,
    issues: issues,
  );

  test('nothing done: 0 of every clover the catalogue offers', () {
    final t = tally(
      issues: const [(read: false, quizPassed: false, labApproved: false)],
    );
    // 2 videos + 1 guide + 1 sim + 2 quizzes x 2 + 1 issue x 3
    expect(t.possible, 11);
    expect(t.earned, 0);
    expect(t.fraction, 0);
  });

  test('each finished item earns its clovers', () {
    final t = tally(
      videos: {'v1'},
      guides: {'g1'},
      sims: {'torque'},
      quiz: {'organic': 100, 'b3': 70},
      issues: const [(read: true, quizPassed: true, labApproved: false)],
    );
    // 1 video + 1 guide + 1 sim + (2 + 1) quiz + 2 issue
    expect(t.earned, 8);
    expect(t.fraction, closeTo(8 / 11, 1e-9));
  });

  test('a quiz under 70 % earns nothing; removed content is not counted', () {
    final t = tally(videos: {'gone'}, quiz: {'organic': 69, 'gone': 100});
    expect(t.earned, 0);
  });

  test('empty catalogue: fraction is 0, not NaN', () {
    final t = CloverTally.from(
      videoIds: const [],
      completedVideoIds: const {},
      guideIds: const [],
      completedGuideIds: const {},
      quizModuleIds: const [],
      quizBestPercent: const {},
      simulationIds: const [],
      viewedSimulationIds: const {},
      issues: const [],
    );
    expect(t.fraction, 0);
  });
}
