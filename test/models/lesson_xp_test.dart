import 'package:elio/models/learning_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'lesson XP: 15 per video, 10 per guide, 10 per best correct answer (0212)',
    () {
      final p = LearningProgress(
        userId: 'u',
        completedVideoIds: const {'v1', 'v2'},
        completedGuideIds: const {'g1'},
        categories: const {
          'organic': CategoryProgress(
            categoryId: 'organic',
            quizBestScore: 7,
            totalQuestions: 10,
          ),
          'b3': CategoryProgress(
            categoryId: 'b3',
            quizBestScore: 3,
            totalQuestions: 5,
          ),
        },
      );
      expect(p.lessonXp, 2 * 15 + 10 + (7 + 3) * 10);
    },
  );

  test('a retake only adds its improvement: XP follows the best score', () {
    LearningProgress withBest(int best) => LearningProgress(
      userId: 'u',
      categories: {
        'organic': CategoryProgress(
          categoryId: 'organic',
          quizBestScore: best,
          quizAttempts: 3,
          totalQuestions: 10,
        ),
      },
    );
    expect(withBest(6).lessonXp, 60);
    expect(withBest(8).lessonXp, 80); // +20, not +80 for the whole retake
  });

  test('nothing done: 0 XP', () {
    expect(LearningProgress.empty('u').lessonXp, 0);
  });
}
