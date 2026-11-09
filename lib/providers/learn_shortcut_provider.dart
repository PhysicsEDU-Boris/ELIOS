import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/elearning_module.dart';
import '../models/guide_lesson.dart';
import '../models/quiz_set.dart';
import '../models/video_lesson.dart';
import '../services/elearning_content_service.dart';

/// Explore tabs on the Learn hub (L2 v3, decision 0195).
enum LearnExploreTab { modules, videos, simulations, guides }

/// A Learn-shortcuts sidebar row. The sidebar sets it; the Learn hub acts on
/// it (opens the page, or selects the Explore tab and scrolls to it) and clears it.
enum LearnShortcut {
  today,
  resume,
  modules,
  videos,
  simulations,
  guides,
  quiz,
  miniLab,
  progress,
  archive,
}

final learnShortcutProvider = StateProvider<LearnShortcut?>((ref) => null);

/// Continue dropdown in the Learn shortcuts sidebar stays as the learner left it.
final learnContinueOpenProvider = StateProvider<bool>((ref) => true);

final learnExploreTabProvider = StateProvider<LearnExploreTab>(
  (ref) => LearnExploreTab.modules,
);

/// Content counts for the sidebar (Firestore streams with offline cache).
final learnModulesProvider = StreamProvider<List<ElearningModule>>(
  (ref) => ref.watch(elearningContentServiceProvider).watchModules(),
);
final learnVideosProvider = StreamProvider<List<VideoLesson>>(
  (ref) => ref.watch(elearningContentServiceProvider).watchVideoLessons(),
);
final learnGuidesProvider = StreamProvider<List<GuideLesson>>(
  (ref) => ref.watch(elearningContentServiceProvider).watchGuideLessons(),
);
final learnQuizSetsProvider = StreamProvider<List<QuizSet>>(
  (ref) => ref.watch(elearningContentServiceProvider).watchQuizSets(),
);
