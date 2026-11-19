import 'package:elio/Screens/tabs/elearning/learn_content.dart';
import 'package:elio/models/guide_lesson.dart';
import 'package:elio/models/learning_progress.dart';
import 'package:elio/models/video_lesson.dart';
import 'package:flutter_test/flutter_test.dart';

VideoLesson _video(String id, String module) => VideoLesson(
  id: id,
  moduleId: module,
  sectionTitle: '',
  title: id,
  description: '',
  durationMinutes: 5,
  durationSeconds: 300,
  durationLabel: '',
  videoUrl: '',
  thumbnailUrl: '',
  youtubeId: '',
  level: '',
  moduleLabel: '',
  status: 'ready',
  isFeatured: false,
  order: 1,
  isPublished: true,
);

GuideLesson _guide(String id, String module) => GuideLesson(
  id: id,
  moduleId: module,
  moduleTitle: '',
  title: id,
  description: '',
  pdfUrl: '',
  coverUrl: '',
  pageCount: 4,
  order: 2,
  isPublished: true,
);

void main() {
  final lessons = mergeLessons(
    [_guide('g1', 'organic'), _guide('g2', 'hazardous')],
    [_video('v1', 'organic'), _video('v2', 'organic')],
  );

  test('module % = its clovers earned / possible (0214)', () {
    // organic: v1, v2, g1 + quiz (70 %, 100 %) = 5 possible.
    final p = LearningProgress(
      userId: 'u',
      completedVideoIds: const {'v1'},
      completedGuideIds: const {'g1', 'g2'},
      quizScores: const {'organic': 80},
      videoWatchProgress: const {'v2': 150},
    );
    // v1 + g1 + quiz >= 70 = 3; half-watched v2 earns nothing yet.
    expect(moduleProgress('organic', lessons, p), closeTo(3 / 5, 1e-9));
  });

  test('a perfect quiz earns its second clover; empty progress is 0', () {
    final p = LearningProgress(
      userId: 'u',
      quizScores: const {'hazardous': 100},
    );
    // hazardous: g2 + quiz x2 = 3 possible.
    expect(moduleProgress('hazardous', lessons, p), closeTo(2 / 3, 1e-9));
    expect(moduleProgress('organic', lessons, null), 0);
  });
}
