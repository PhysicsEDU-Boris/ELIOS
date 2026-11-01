import 'dart:async';

import 'package:elio/Screens/tabs/elearning/learn_content.dart';
import 'package:elio/Screens/tabs/elearning/lesson_page.dart';
import 'package:elio/Screens/tabs/elearning/module_page.dart';
import 'package:elio/Screens/tabs/elearning/progress_page.dart';
import 'package:elio/Screens/tabs/elearning/quiz/physics_quiz_page.dart';
import 'package:elio/Screens/tabs/elearning/quiz_page.dart';
import 'package:elio/Screens/tabs/elearning/simulations/deep_dive_simulation_page.dart';
import 'package:elio/Screens/tabs/elearning/simulations/density_simulation_page.dart';
import 'package:elio/Screens/tabs/elearning/simulations/heat_simulation_page.dart';
import 'package:elio/Screens/tabs/elearning/simulations/kinematics_simulation_page.dart';
import 'package:elio/Screens/tabs/elearning/simulations/power_budget_simulation_page.dart';
import 'package:elio/Screens/tabs/elearning/simulations/pwm_simulation_page.dart';
import 'package:elio/Screens/tabs/elearning/simulations/torque_simulation_page.dart';
import 'package:elio/Screens/tabs/elearning/simulations/widgets/calc_box.dart';
import 'package:elio/Screens/tabs/elearning/simulations/work_energy_simulation_page.dart';
import 'package:elio/Screens/tabs/elearning_tab.dart';
import 'package:elio/models/elearning_module.dart';
import 'package:elio/models/guide_lesson.dart';
import 'package:elio/models/learning_progress.dart';
import 'package:elio/models/quiz_set.dart';
import 'package:elio/models/video_lesson.dart';
import 'package:elio/physics/density/density_notifier.dart';
import 'package:elio/physics/heat/heat_notifier.dart';
import 'package:elio/physics/kinematics/kinematics_notifier.dart';
import 'package:elio/physics/power_budget/power_budget_notifier.dart';
import 'package:elio/physics/pwm/pwm_notifier.dart';
import 'package:elio/physics/torque/torque_notifier.dart';
import 'package:elio/physics/work_energy/work_energy_notifier.dart';
import 'package:elio/providers/auth_provider.dart';
import 'package:elio/providers/learning_progress_provider.dart';
import 'package:elio/providers/physics_progress_provider.dart';
import 'package:elio/services/elearning_content_service.dart';
import 'package:elio/services/progress_service.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/learn/learn_ui.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_support.dart';

/// L1 v2 Learn screens (decisions 0170-0172): every screen in light and
/// dark against fake_cloud_firestore, plus loading, error and empty states.

Future<FakeFirebaseFirestore> _seed() async {
  final db = FakeFirebaseFirestore();
  final modules = {
    'organic': ('Organic waste management', 1, 'Beginner friendly', 16),
    'inorganic': ('Inorganic / recyclable waste', 2, 'Basics', 5),
    'hazardous': ('Hazardous waste (B3)', 3, 'Advanced', 28),
  };
  for (final e in modules.entries) {
    await db.collection('elearning_modules').doc(e.key).set({
      'title': e.value.$1,
      'description': 'Learn how ${e.key} waste is sorted.',
      'category': e.key,
      'level': e.value.$3,
      'durationMinutes': e.value.$4,
      'lessonCount': 2,
      'thumbnailUrl': '',
      'guideUrl': '',
      'order': e.value.$2,
      'isPublished': true,
    });
    await db.collection('quiz_sets').doc('q-${e.key}').set({
      'moduleId': e.key,
      'title': '${e.value.$1} quiz',
      'description': 'Ten questions.',
      'level': 'Beginner',
      'questionCount': 2,
      'iconType': '',
      'theme': '',
      'order': e.value.$2,
      'isPublished': true,
    });
  }
  await db.collection('video_lessons').doc('v1').set({
    'moduleId': 'organic',
    'sectionTitle': 'Science',
    'title': 'Composting fundamentals',
    'description': 'See how a compost heap breaks down food scraps.',
    'durationLabel': '7:22',
    'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    // A URL that cannot load in tests: the Organik/Biogas art must show.
    'thumbnailUrl': 'https://res.cloudinary.com/demo/image/upload/missing.jpg',
    'youtubeId': '',
    'level': 'Science',
    'order': 2,
    'isPublished': true,
  });
  await db.collection('guide_lessons').doc('g1').set({
    'moduleId': 'organic',
    'moduleTitle': 'Organic',
    'title': 'Introduction & definitions of waste',
    'description': 'foundational principles',
    'pdfUrl': 'https://example.org/g1.pdf',
    'coverUrl': '',
    'pageCount': 10,
    'order': 1,
    'isPublished': true,
  });
  final questions = db.collection('quizzes').doc('organic').collection('questions');
  for (var i = 0; i < 2; i++) {
    await questions.doc('q$i').set({
      'question': 'Question $i: which bin takes banana peel?',
      'options': ['Organik', 'Anorganik', 'B3', 'Residu'],
      'correctIndex': 0,
      'explanation': 'Food scraps rot.',
      'difficulty': 'Easy',
      'order': i,
    });
  }
  return db;
}

class _Progress extends LearningProgressNotifier {
  _Progress(this.value);
  final FutureOr<LearningProgress> Function() value;
  @override
  Future<LearningProgress> build() async => value();
  @override
  Future<void> updateProgress(
    String categoryId,
    int score,
    int totalQuestions, {
    QuizReview? quizReview,
  }) async => saved.add((categoryId, score, totalQuestions));
  static final saved = <(String, int, int)>[];
}

LearningProgress _active() => LearningProgress(
  userId: 'guest',
  completedGuideIds: const {'g1'},
  videoWatchProgress: const {'v1': 177},
  videoLastAccessed: {'v1': DateTime(2026, 11, 1)},
);

/// Service whose module stream the test controls.
class _StreamService implements ElearningContentService {
  _StreamService(this.modules);
  final Stream<List<ElearningModule>> modules;
  @override
  Stream<List<ElearningModule>> watchModules() => modules;
  @override
  Stream<List<VideoLesson>> watchVideoLessons({String? moduleId}) => Stream.value(const []);
  @override
  Stream<List<GuideLesson>> watchGuideLessons({String? moduleId}) => Stream.value(const []);
  @override
  Stream<List<QuizSet>> watchQuizSets({String? moduleId}) => Stream.value(const []);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester t,
  Widget page, {
  required Brightness brightness,
  ElearningContentService? service,
  LearningProgress Function()? progress,
  double textScale = 1.0,
  Size size = const Size(390, 2400),
}) async {
  final db = service == null ? await _seed() : null;
  await pumpAt(
    t,
    ElioTheme.wrap(Scaffold(body: page)),
    size: size,
    brightness: brightness,
    textScale: textScale,
    overrides: [
      currentUserProvider.overrideWithValue(null),
      elearningContentServiceProvider.overrideWithValue(
        service ?? ElearningContentService(firestore: db),
      ),
      learningProgressProvider.overrideWith(
        () => _Progress(progress ?? _active),
      ),
      physicsProgressProvider.overrideWith(
        (ref) => PhysicsProgressNotifier(
          ProgressService(firestore: FakeFirebaseFirestore()),
          null,
          false,
        ),
      ),
    ],
  );
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Finder _svg(String asset) => find.byWidgetPredicate(
  (w) => w is SvgPicture && (w.bytesLoader as SvgAssetLoader).assetName == asset,
);

/// Cache that fails every download, like a dead Cloudinary link.
class _FailingCache implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(String url, {String? key, Map<String, String>? headers, bool withProgress = false}) =>
      Stream.error(const HttpExceptionWithStatus(404, 'missing'));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _organic = ElearningModule(
  id: 'organic',
  title: 'Organic waste management',
  description: 'Food scraps and leaves.',
  category: 'organic',
  level: 'Beginner friendly',
  durationMinutes: 16,
  lessonCount: 2,
  thumbnailUrl: '',
  guideUrl: '',
  order: 1,
  isPublished: true,
);

void main() {
  setUpAll(loadElioFonts);

  for (final b in Brightness.values) {
    group(b.name, () {
      testWidgets('hub shows all sections from Firestore', (t) async {
        await _pump(t, const ElearningTab(), brightness: b);
        expect(t.takeException(), isNull);
        expect(find.text('Knowledge challenge'), findsOneWidget);
        expect(find.text('Your learning progress'), findsOneWidget);
        for (final label in ['Organik', 'Anorganik', 'B3']) {
          expect(find.text(label), findsWidgets);
        }
        expect(find.text('Continue learning'), findsOneWidget);
        expect(find.text('Composting fundamentals'), findsWidgets);
        expect(find.text('1 videos'), findsOneWidget);
        expect(find.text('9 modules'), findsOneWidget);
        expect(find.text('Introduction & definitions of waste'), findsWidgets);
        // Failing Cloudinary URL falls back to the module illustration.
        expect(_svg(LearnArt.coverBiogas), findsWidgets);
      });

      testWidgets('hub first launch', (t) async {
        await _pump(
          t,
          const ElearningTab(),
          brightness: b,
          progress: () => LearningProgress(userId: 'guest'),
        );
        expect(t.takeException(), isNull);
        expect(find.text('Welcome to Learn'), findsOneWidget);
        expect(find.text('No modules started yet'), findsOneWidget);
        expect(find.textContaining('Nothing in progress yet'), findsOneWidget);
      });

      testWidgets('hub loading shows the skeleton', (t) async {
        await _pump(
          t,
          const ElearningTab(),
          brightness: b,
          service: _StreamService(const Stream.empty()),
        );
        expect(find.byType(LearnHubSkeleton), findsOneWidget);
        expect(find.text('Course modules'), findsNothing);
      });

      testWidgets('hub error offers retry and offline lessons', (t) async {
        await _pump(
          t,
          const ElearningTab(),
          brightness: b,
          service: _StreamService(Stream.error(Exception('offline'))),
        );
        expect(find.text('Learning modules could not be loaded.'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('Open offline lessons'), findsOneWidget);
      });

      testWidgets('hub with no modules', (t) async {
        await _pump(
          t,
          const ElearningTab(),
          brightness: b,
          service: _StreamService(Stream.value(const [])),
        );
        expect(find.text('No learning modules available yet.'), findsOneWidget);
      });

      testWidgets('module page lists lessons, simulation and quiz', (t) async {
        await _pump(t, const ModulePage(module: _organic), brightness: b);
        expect(t.takeException(), isNull);
        expect(find.text('Organic waste management'), findsOneWidget);
        expect(find.text('Read again'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Food scraps'), findsOneWidget);
        expect(find.text('Videos'), findsOneWidget);
        expect(find.text('1 video'), findsOneWidget);
        expect(find.text('Guides'), findsOneWidget);
        expect(find.text('1 guide'), findsOneWidget);
        expect(find.text('Simulation for this module'), findsOneWidget);
        expect(find.text('Organic waste management quiz'), findsOneWidget);
      });

      testWidgets('lesson page shows stats and the sticky button', (t) async {
        final db = await _seed();
        final video = VideoLesson.fromFirestore(
          await db.collection('video_lessons').doc('v1').get(),
        );
        await _pump(
          t,
          LessonPage(lesson: LearnLesson.video(video)),
          brightness: b,
          service: ElearningContentService(firestore: db),
        );
        expect(t.takeException(), isNull);
        expect(find.text('Composting fundamentals'), findsWidgets);
        expect(find.text('2 of 2'), findsOneWidget);
        expect(find.text('Continue video · 40%'), findsOneWidget);
        expect(find.text('About this lesson'), findsOneWidget);
      });

      testWidgets('my progress shows modules and quiz history', (t) async {
        await _pump(
          t,
          const ProgressPage(),
          brightness: b,
          progress: () => _active().copyWith(quizScores: {'organic': 80}),
        );
        expect(t.takeException(), isNull);
        expect(find.text('Progres simulasi'), findsOneWidget);
        expect(find.text('Organic waste management'), findsOneWidget);
        expect(find.text('Best 80% · 2 questions'), findsOneWidget);
        expect(find.text('Organic waste management quiz'), findsOneWidget);
        expect(find.text('Passed'), findsOneWidget);
      });

      testWidgets('my progress empty state', (t) async {
        await _pump(
          t,
          const ProgressPage(),
          brightness: b,
          progress: () => LearningProgress(userId: 'guest'),
        );
        expect(find.text('No progress yet.'), findsOneWidget);
      });

      testWidgets('quiz runs and saves the score', (t) async {
        _Progress.saved.clear();
        await _pump(t, const QuizPage(moduleId: 'organic'), brightness: b, progress: () => LearningProgress(userId: 'guest'));
        expect(find.text('Organic waste management quiz'), findsOneWidget);
        await t.tap(find.text('Start'));
        await t.pumpAndSettle();
        await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Start')));
        await t.pumpAndSettle();
        for (var i = 0; i < 2; i++) {
          expect(find.text('Question ${i + 1} / 2'), findsOneWidget);
          expect(find.text('A'), findsOneWidget);
          await t.tap(find.text('Organik'));
          await t.pump();
          await t.tap(find.byType(FilledButton).last);
          await t.pumpAndSettle();
        }
        expect(find.text('You scored 2 out of 2.'), findsOneWidget);
        expect(_Progress.saved, [('organic', 2, 2)]);
      });

      testWidgets('physics quiz uses the v2 question layout', (t) async {
        await _pump(t, const PhysicsQuizPage(), brightness: b);
        expect(t.takeException(), isNull);
        expect(find.textContaining('Pertanyaan 1 /'), findsOneWidget);
        expect(find.text('Fisika lanjutan'), findsOneWidget);
        expect(find.text('D'), findsOneWidget);
      });
    });
  }

  testWidgets('text scale 1.3 does not clip the hub or the module page', (t) async {
    await _pump(t, const ElearningTab(), brightness: Brightness.light, textScale: 1.3, size: const Size(360, 3200));
    expect(t.takeException(), isNull);
    await _pump(t, const ModulePage(module: _organic), brightness: Brightness.dark, textScale: 1.3, size: const Size(360, 3600));
    expect(t.takeException(), isNull);
  });

  for (final b in Brightness.values) {
    testWidgets('videos and guides list as a 3-column thumbnail grid (${b.name}, text 1.3)', (t) async {
      LearnLesson video(int i) => LearnLesson.video(VideoLesson.fromMap({
        'moduleId': 'organic',
        'title': 'A long video title number $i that wraps',
        'durationLabel': '3:1$i',
        'level': 'Basics',
        'thumbnailUrl': '',
        'order': i,
      }, 'v$i'));
      await _pump(
        t,
        LessonListPage(title: 'Videos', lessons: [for (var i = 0; i < 4; i++) video(i)]),
        brightness: b,
        textScale: 1.3,
        size: const Size(360, 1600),
      );
      expect(t.takeException(), isNull);
      expect(find.byType(LessonThumbTile), findsNWidgets(4));
      // First three share a row, the fourth starts the next one.
      final y = [for (var i = 0; i < 4; i++) t.getTopLeft(find.byType(LessonThumbTile).at(i)).dy];
      expect(y[0], y[1]);
      expect(y[1], y[2]);
      expect(y[3], greaterThan(y[0]));
      expect(_svg(LearnArt.coverOrganik), findsWidgets);
    });
  }

  group('simulations show the computed result in the v2 layout', () {
    String calcText(WidgetTester t) => t
        .widgetList<Text>(find.descendant(of: find.byType(CalcBox), matching: find.byType(Text)))
        .map((w) => w.data)
        .join(' ');
    T read<T>(WidgetTester t, ProviderListenable<T> p) =>
        ProviderScope.containerOf(t.element(find.byType(Scaffold).first)).read(p);

    for (final b in Brightness.values) {
      testWidgets('density ${b.name}', (t) async {
        await _pump(t, const DensitySimulationPage(), brightness: b);
        expect(t.takeException(), isNull);
        expect(find.text('Simulasi'), findsWidgets);
        expect(find.text('Materi'), findsOneWidget);
        expect(find.text('Rumus'), findsWidgets);
        final s = read(t, densityProvider);
        expect(calcText(t), contains(s.density.toStringAsFixed(2)));
        // Moving the mass slider changes the shown result.
        final before = calcText(t);
        await t.drag(find.byType(Slider).first, const Offset(-120, 0));
        await t.pump();
        expect(calcText(t), isNot(before));
        expect(calcText(t), contains(read(t, densityProvider).density.toStringAsFixed(2)));
      });
    }

    testWidgets('heat', (t) async {
      await _pump(t, const HeatSimulationPage(), brightness: Brightness.light);
      expect(calcText(t), contains(read(t, heatProvider).finalTemp.toStringAsFixed(1)));
    });
    testWidgets('torque', (t) async {
      await _pump(t, const TorqueSimulationPage(), brightness: Brightness.dark);
      expect(calcText(t), contains(read(t, torqueProvider).torque.toStringAsFixed(2)));
    });
    testWidgets('work and energy', (t) async {
      await _pump(t, const WorkEnergySimulationPage(), brightness: Brightness.light);
      expect(calcText(t), contains(read(t, workEnergyProvider).workJoules.toStringAsFixed(1)));
    });
    testWidgets('kinematics', (t) async {
      await _pump(t, const KinematicsSimulationPage(), brightness: Brightness.dark);
      expect(calcText(t), contains(read(t, kinematicsProvider).predictedTimeS.toStringAsFixed(1)));
    });
    testWidgets('pwm', (t) async {
      await _pump(t, const PwmSimulationPage(), brightness: Brightness.light);
      expect(calcText(t), contains(read(t, pwmProvider).averageVoltage.toStringAsFixed(1)));
    });
    testWidgets('power budget', (t) async {
      await _pump(t, const PowerBudgetSimulationPage(), brightness: Brightness.dark);
      expect(calcText(t), contains(read(t, powerBudgetProvider).totalPowerW.toStringAsFixed(0)));
    });
    testWidgets('deep dive renders its tabs', (t) async {
      await _pump(t, const DeepDiveSimulationPage(), brightness: Brightness.dark);
      expect(t.takeException(), isNull);
      expect(find.text('Simulasi'), findsWidgets);
    });
  });

  group('content rules', () {
    test('youtubeId comes from videoUrl when the field is empty', () {
      for (final url in [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://youtu.be/dQw4w9WgXcQ?t=3',
        'https://www.youtube.com/embed/dQw4w9WgXcQ',
        'https://youtube.com/shorts/dQw4w9WgXcQ',
        'https://m.youtube.com/watch?feature=share&v=dQw4w9WgXcQ',
      ]) {
        expect(VideoLesson.parseYoutubeId(url), 'dQw4w9WgXcQ', reason: url);
      }
      expect(VideoLesson.parseYoutubeId('https://res.cloudinary.com/x.mp4'), isNull);
      final lesson = VideoLesson.fromMap({
        'videoUrl': 'https://youtu.be/dQw4w9WgXcQ',
        'youtubeId': '',
      }, 'v');
      expect(lesson.resolvedYoutubeId, 'dQw4w9WgXcQ');
      expect(
        VideoLesson.fromMap({'videoUrl': 'https://youtu.be/dQw4w9WgXcQ', 'youtubeId': 'abcdefghijk'}, 'v').resolvedYoutubeId,
        'abcdefghijk',
      );
    });

    test('fallback covers follow the module mapping', () {
      expect(LearnArt.cover('organic'), LearnArt.coverOrganik);
      expect(LearnArt.cover('organic', alt: true), LearnArt.coverBiogas);
      expect(LearnArt.cover('inorganic'), LearnArt.coverAnorganik);
      expect(LearnArt.cover('inorganic', alt: true), LearnArt.coverReuse);
      expect(LearnArt.cover('hazardous'), LearnArt.coverB3);
      expect(LearnArt.cover('hazardous', alt: true), LearnArt.coverSafeHandling);
      final foundation = VideoLesson.fromMap({'moduleId': 'organic', 'sectionTitle': 'Foundation module', 'order': 2}, 'v');
      expect(LearnLesson.video(foundation).fallbackArt, LearnArt.coverIntro);
    });

    testWidgets('thumbnail falls back to the illustration when the URL fails', (t) async {
      await pumpAt(
        t,
        Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: LearnThumbnail(
              url: 'https://res.cloudinary.com/demo/missing.jpg',
              fallbackAsset: LearnArt.coverB3,
              cacheManager: _FailingCache(),
            ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(_svg(LearnArt.coverB3), findsOneWidget);
      await pumpAt(
        t,
        const Scaffold(body: LearnThumbnail(url: '', fallbackAsset: LearnArt.coverIntro)),
      );
      expect(_svg(LearnArt.coverIntro), findsOneWidget);
    });

    test('lesson state and in-progress order', () {
      final p = _active();
      const a = LearnLesson.guide(GuideLesson(id: 'g1', moduleId: 'organic', moduleTitle: '', title: 'G', description: '', pdfUrl: '', coverUrl: '', order: 1, isPublished: true));
      final v = LearnLesson.video(VideoLesson.fromMap({'moduleId': 'organic', 'durationLabel': '7:22'}, 'v1'));
      expect(a.state(p), LessonState.done);
      expect(a.actionLabel(p), 'Read again');
      expect(v.state(p), LessonState.inProgress);
      expect((v.progress(p) * 100).round(), 40);
      expect(inProgressLessons([a, v], p).map((l) => l.id), ['v1']);
    });
  });
}
