import 'dart:async';

import 'package:elio/Screens/home_screen.dart';
import 'package:elio/models/guide_lesson.dart';
import 'package:elio/models/learning_progress.dart';
import 'package:elio/models/video_lesson.dart';
import 'package:elio/providers/auth_provider.dart';
import 'package:elio/providers/learning_progress_provider.dart';
import 'package:elio/providers/navigation_provider.dart';
import 'package:elio/services/elearning_content_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_support.dart';

/// H1 home screen (decision 0140). The 3D viewer and Firestore are replaced by
/// the static robot stage and a fake content service.
class _FakeContent implements ElearningContentService {
  @override
  Stream<List<VideoLesson>> watchVideoLessons({String? moduleId}) =>
      Stream.value(_videos);
  @override
  Stream<List<GuideLesson>> watchGuideLessons({String? moduleId}) =>
      Stream.value(_guides);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _videos = [
  VideoLesson(
    id: 'v1',
    moduleId: 'organic',
    sectionTitle: 'Basics',
    title: 'Waste sorting basics',
    description: '',
    durationMinutes: 10,
    durationLabel: '10 min',
    videoUrl: '',
    thumbnailUrl: '',
    youtubeId: '',
    level: 'beginner',
    moduleLabel: 'Module 1',
    status: 'published',
    isFeatured: false,
    order: 1,
    isPublished: true,
  ),
];
const _guides = [
  GuideLesson(
    id: 'g1',
    moduleId: 'organic',
    moduleTitle: 'Organic',
    title: 'Sorting guide',
    description: '',
    pdfUrl: '',
    coverUrl: '',
    order: 1,
    isPublished: true,
  ),
];

class _Progress extends LearningProgressNotifier {
  _Progress(this.value);
  final FutureOr<LearningProgress> Function() value;
  @override
  Future<LearningProgress> build() async => value();
}

LearningProgress _withActivity() {
  final now = DateTime.now();
  return LearningProgress(
    userId: 'guest',
    completedVideoIds: {'v1'},
    completedGuideIds: {'g1'},
    videoWatchProgress: {'v1': 42},
    videoLastAccessed: {'v1': now},
    guideLastAccessed: {'g1': now},
    quizScores: {'organic': 85},
    quizLastAccessed: {'organic': now.subtract(const Duration(days: 1))},
    completedQuizModules: {'organic'},
    categories: {
      'organic': CategoryProgress(
        categoryId: 'organic',
        lessonViewed: true,
        quizBestScore: 8,
        quizAttempts: 2,
        totalQuestions: 10,
        lastAccessed: now,
      ),
    },
  );
}

enum _State { empty, activity, loading }

class _Calls {
  int drawer = 0, learning = 0;
}

Future<_Calls> _pump(
  WidgetTester t, {
  required _State state,
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  homeContentServiceForTest = _FakeContent();
  homeStaticRobotForTest = true;
  addTearDown(() {
    homeContentServiceForTest = null;
    homeStaticRobotForTest = false;
  });
  final calls = _Calls();
  await pumpAt(
    t,
    HomeScreen(
      auth: MockFirebaseAuth(),
      onOpenDrawer: () => calls.drawer++,
      onOpenLearning: () => calls.learning++,
    ),
    size: size,
    brightness: brightness,
    textScale: textScale,
    overrides: [
      currentUserProvider.overrideWithValue(null),
      progressSyncWarningProvider.overrideWithValue(false),
      learningProgressProvider.overrideWith(
        () => _Progress(switch (state) {
          _State.empty => () => LearningProgress(userId: 'guest'),
          _State.activity => _withActivity,
          _State.loading => () => Completer<LearningProgress>().future,
        }),
      ),
    ],
  );
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(milliseconds: 50));
  return calls;
}

void main() {
  setUpAll(loadElioFonts);

  const phone = Size(390, 844);
  const tall = Size(390, 2600);

  for (final b in Brightness.values) {
    for (final s in _State.values) {
      testWidgets('${b.name} ${s.name} renders without overflow', (t) async {
        await _pump(t, state: s, brightness: b);
        expect(t.takeException(), isNull);
        expect(find.text('Hello, Guest'), findsOneWidget);
        expect(find.text('Your Progress'), findsOneWidget);
        expect(find.text('Quick Actions'), findsOneWidget);
        expect(
          find.text(
            'Guest progress is stored on this device. Sign in to sync it across devices.',
          ),
          findsOneWidget,
        );
        if (s == _State.activity) {
          expect(
            find.text('Completed video: Waste sorting basics'),
            findsOneWidget,
          );
          expect(find.textContaining('Your lessons, videos'), findsNothing);
        } else {
          expect(find.textContaining('Your lessons, videos'), findsOneWidget);
        }
        if (s == _State.loading) {
          expect(find.bySemanticsLabel('Loading progress'), findsOneWidget);
        }
      });
    }

    for (final (name, size, scale) in [
      ('narrow 360', const Size(360, 740), 1.0),
      ('text scale 1.3', phone, 1.3),
      ('narrow 360 scale 1.3', const Size(360, 740), 1.3),
      ('tablet 768', const Size(768, 1024), 1.0),
      ('desktop 1280', const Size(1280, 800), 1.0),
      ('desktop 1280 scale 1.3', const Size(1280, 800), 1.3),
    ]) {
      testWidgets('${b.name} $name has no overflow', (t) async {
        await _pump(
          t,
          state: _State.activity,
          brightness: b,
          size: size,
          textScale: scale,
        );
        expect(t.takeException(), isNull);
        // Scroll to the end: lazy content must lay out too.
        await t.drag(find.byType(CustomScrollView), const Offset(0, -4000));
        await t.pump();
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('tap targets are at least 48 dp', (t) async {
    await _pump(t, state: _State.activity, size: tall);
    final targets = [
      find.byTooltip('Open navigation menu'),
      find.byTooltip('Open notifications'),
      find.widgetWithText(TextButton, 'View learning'),
      find.widgetWithText(FilledButton, 'Continue Module'),
      find.text('Learn'),
      find.text('Config'),
      find.text('Control'),
      find.text('Camera'),
      find.textContaining('learning items completed'),
    ];
    for (final f in targets) {
      expect(f, findsWidgets);
    }
    for (final f in [
      find.byTooltip('Open navigation menu'),
      find.byTooltip('Open notifications'),
      find.widgetWithText(TextButton, 'View learning'),
      find.widgetWithText(FilledButton, 'Continue Module'),
    ]) {
      final size = t.getSize(f.first);
      expect(size.width, greaterThanOrEqualTo(48), reason: '$f');
      expect(size.height, greaterThanOrEqualTo(48), reason: '$f');
    }
    for (final title in ['Learn', 'Config', 'Control', 'Camera']) {
      final card = find.ancestor(
        of: find.text(title),
        matching: find.byType(InkWell),
      );
      final size = t.getSize(card.first);
      expect(size.height, greaterThanOrEqualTo(48), reason: title);
    }
  });

  testWidgets('every action still reaches its target', (t) async {
    final calls = await _pump(t, state: _State.empty, size: tall);
    final container = ProviderScope.containerOf(
      t.element(find.byType(HomeScreen)),
    );

    await t.tap(find.byTooltip('Open navigation menu'));
    expect(calls.drawer, 1);

    await t.tap(find.text('View learning'));
    expect(calls.learning, 1);

    await t.tap(find.widgetWithText(FilledButton, 'Start Module 1'));
    expect(calls.learning, 2);

    await t.tap(find.text('Learn'));
    expect(calls.learning, 3);

    await t.tap(find.text('Config'));
    expect(container.read(navigationIndexProvider), 2);
    await t.tap(find.text('Control'));
    expect(container.read(navigationIndexProvider), 3);
    container.read(navigationIndexProvider.notifier).state = 0;
    await t.tap(find.text('Camera'));
    expect(container.read(navigationIndexProvider), 3);

    // Notifications and progress cards open their sheets.
    await t.tap(find.byTooltip('Open notifications'));
    await t.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Dismiss notifications'),
      findsNothing,
    ); // barrier label only
    expect(t.takeException(), isNull);
  });

  testWidgets('progress cards open their detail sheets', (t) async {
    await _pump(t, state: _State.activity, size: tall);
    await t.tap(find.text('Quiz Avg').last);
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Quiz History'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('semantics labels exist for the main controls', (t) async {
    final handle = t.ensureSemantics();
    await _pump(t, state: _State.activity, size: tall);
    for (final tip in ['Open navigation menu', 'Open notifications']) {
      final node = t.getSemantics(find.byTooltip(tip));
      expect('${node.label}|${node.tooltip}', contains(tip));
    }
    expect(find.bySemanticsLabel(RegExp('^Learning, ')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Quiz Avg, ')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Environmental Explorer, ')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('^Learn, ')), findsOneWidget);
    expect(
      find.bySemanticsLabel('ELIO robot 3D viewer. Drag to rotate.'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
