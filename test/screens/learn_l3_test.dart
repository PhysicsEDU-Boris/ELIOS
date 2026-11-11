// Learn L3 (decision 0206): hub archive stack, Discover more synced with the
// Explore module, module / lesson / simulation / Kuis fisika pages, in light
// and dark, English and Indonesian. LEARN_RENDER=<dir> also writes PNGs.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:elio/Screens/tabs/elearning/learn_archive_stack.dart';
import 'package:elio/Screens/tabs/elearning/learn_content.dart';
import 'package:elio/Screens/tabs/elearning/learn_discover_more.dart';
import 'package:elio/Screens/tabs/elearning/learn_hub_v3.dart' show ExploreSection;
import 'package:elio/Screens/tabs/elearning/lesson_page.dart';
import 'package:elio/Screens/tabs/elearning/module_page.dart';
import 'package:elio/Screens/tabs/elearning/quiz/physics_quiz_page.dart';
import 'package:elio/Screens/tabs/elearning/simulations/density_simulation_page.dart';
import 'package:elio/Screens/tabs/elearning_tab.dart';
import 'package:elio/models/elearning_module.dart';
import 'package:elio/models/learning_progress.dart';
import 'package:elio/models/video_lesson.dart';
import 'package:elio/providers/elio_theme_mode_provider.dart';
import 'package:elio/providers/learning_progress_provider.dart';
import 'package:elio/providers/physics_progress_provider.dart';
import 'package:elio/services/elearning_content_service.dart';
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/services/progress_service.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/learn/learn_l3.dart';
import 'package:elio/Screens/tabs/elearning/daily_guides_page.dart' show GuidesHubSection;
import 'package:elio/widgets/learn/learn_ui.dart' show LearnHubSkeleton;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elio/Screens/tabs/elearning/guides/guide_widgets.dart'
    show guideImageCache;

import '../guides/g4_fixture.dart' as g4;
import '../guides/g4_test_app.dart';
import 'auth_test_support.dart' show loadElioFonts;

final _out = Platform.environment['LEARN_RENDER'];

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
      'description':
          'Learn how ${e.key} waste decomposes, then connect it to sorting.',
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
      'questionCount': 10,
      'iconType': '',
      'theme': '',
      'order': e.value.$2,
      'isPublished': true,
    });
    await db.collection('video_lessons').doc('v-${e.key}').set({
      'moduleId': e.key,
      'sectionTitle': 'Science',
      'title': 'Video about ${e.key}',
      'description': 'See how it works.',
      'durationLabel': '3:39',
      'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      'thumbnailUrl': '',
      'youtubeId': '',
      'level': 'Basics',
      'order': 1,
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
    'thumbnailUrl': '',
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
  return db;
}

class _Mode extends ElioThemeModeNotifier {
  _Mode(this.mode);
  final ElioThemeMode mode;
  @override
  ElioThemeMode build() => mode;
}

class _Progress extends LearningProgressNotifier {
  @override
  Future<LearningProgress> build() async => LearningProgress(
    userId: 'guest',
    completedGuideIds: const {'g1'},
    videoWatchProgress: const {'v1': 177},
    videoLastAccessed: {'v1': DateTime(2026, 11, 1)},
    quizScores: const {'organic': 80},
  );
}

const _organic = ElearningModule(
  id: 'organic',
  title: 'Organic waste management',
  description: 'Learn how food scraps and leaves decompose.',
  category: 'organic',
  level: 'Beginner friendly',
  durationMinutes: 16,
  lessonCount: 2,
  thumbnailUrl: '',
  guideUrl: '',
  order: 1,
  isPublished: true,
);

/// Today's guide plus three archive guides (air, water, heat).
String _feed() => g4.manifest([
  g4.entry('2026-11-08', theme: 'water', photo: false),
  g4.entry('2026-11-07', theme: 'air')
    ..['title'] = {
      'en': 'Why haze hangs over our cities',
      'id': 'Kenapa kabut asap',
    },
  g4.entry('2026-11-06', theme: 'water', photo: false)
    ..['title'] = {
      'en': 'Floods: a metre of rain',
      'id': 'Banjir: semeter hujan',
    },
  g4.entry('2026-11-05', theme: 'heat', photo: false)
    ..['title'] = {'en': 'Hot city rooftops', 'id': 'Atap kota yang panas'},
]);

Future<void> _pump(
  WidgetTester t,
  Widget page, {
  bool dark = false,
  String lang = 'en',
  Size size = const Size(390, 844),
  bool reduceMotion = false,
}) async {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final db = await _seed();
  await t.pumpWidget(
    G4TestApp(
      locale: ValueNotifier(Locale(lang)),
      dark: dark,
      reduceMotion: reduceMotion,
      overrides: [
        ...g4.guideOverrides(
          server: g4.FakeGuidesServer(),
          service: g4.fakeService(source: _feed()),
        ),
        elearningContentServiceProvider.overrideWithValue(
          ElearningContentService(firestore: db),
        ),
        learningProgressProvider.overrideWith(_Progress.new),
        elioThemeModeProvider.overrideWith(
          () => _Mode(dark ? ElioThemeMode.dark : ElioThemeMode.light),
        ),
        physicsProgressProvider.overrideWith(
          (ref) => PhysicsProgressNotifier(
            ProgressService(firestore: FakeFirebaseFirestore()),
            null,
            false,
          ),
        ),
      ],
      home: RepaintBoundary(
        key: const Key('capture'),
        child: ElioTheme.wrap(Scaffold(body: page)),
      ),
    ),
  );
  await _settle(t);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  if (_out == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    image.dispose();
    Directory(_out!).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(data.buffer.asUint8List());
  });
}

Finder _svg(String asset) => find.byWidgetPredicate(
  (w) =>
      w is SvgPicture && (w.bytesLoader as SvgAssetLoader).assetName == asset,
);

Future<VideoLesson> _video() async {
  final db = await _seed();
  return VideoLesson.fromFirestore(
    await db.collection('video_lessons').doc('v1').get(),
  );
}

void main() {
  final sounds = <ElioSfx>[];
  // A fake clock, 1 s per call across all tests, so the 120 ms gap never drops a sound.
  var now = DateTime(2026);
  setUpAll(loadElioFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'daily-guide-notified': '2099-01-01',
    });
    guideImageCache = g4.PhotoCache(g4.testPhoto());
    sounds.clear();
    ElioSound.instance
      ..sink = ((s, _) => sounds.add(s))
      ..isSilent = (() async => false)
      ..clock = () => now = now.add(const Duration(seconds: 1));
  });

  testWidgets('archive stack: last 3 guides, swipe sends the top photo back', (
    t,
  ) async {
    await _pump(t, const ElearningTab(), size: const Size(390, 3400));
    expect(t.takeException(), isNull);
    expect(find.text('From the archive'), findsOneWidget);
    expect(find.text('Your last 3 guides · swipe the photos'), findsOneWidget);
    // Today's guide is not in the archive; the newest archive guide is on top.
    expect(find.text('Why haze hangs over our cities'), findsOneWidget);
    final top = find.bySemanticsLabel(RegExp('^Why haze hangs'));
    // A swipe to the right does not flick.
    await t.drag(top, const Offset(220, 0));
    await _settle(t);
    expect(find.text('Why haze hangs over our cities'), findsOneWidget);
    // Swiped left, the top photo goes to the back and the next comes up.
    await t.drag(top, const Offset(-220, 0));
    await _settle(t);
    expect(find.text('Floods: a metre of rain'), findsOneWidget);
    expect(sounds, contains(ElioSfx.tick));
    // A short drag springs back.
    final floods = find.bySemanticsLabel(RegExp('^Floods'));
    await t.drag(floods, const Offset(-30, 0));
    await _settle(t);
    expect(find.text('Floods: a metre of rain'), findsOneWidget);
    // Two more swipes bring the first photo back to the top.
    await t.drag(floods, const Offset(-220, 0));
    await _settle(t);
    await t.drag(find.bySemanticsLabel(RegExp('^Hot city')), const Offset(-220, 0));
    await _settle(t);
    expect(find.text('Why haze hangs over our cities'), findsOneWidget);
  });

  testWidgets('archive stack: tap pulls the photo out and shows Continue', (
    t,
  ) async {
    await _pump(t, const ElearningTab(), size: const Size(390, 3400));
    final cont = find.widgetWithText(L3Button, 'Continue');
    expect(cont, findsNothing);
    await t.tap(find.bySemanticsLabel(RegExp('^Why haze hangs')));
    await _settle(t);
    expect(find.text('Pick up where you left off'), findsOneWidget);
    expect(cont, findsOneWidget);
    expect(sounds, contains(ElioSfx.pop));
    // Tapping the photo again slides it back.
    await t.tap(find.bySemanticsLabel(RegExp('^Why haze hangs')));
    await _settle(t);
    expect(cont, findsNothing);
  });

  testWidgets('Discover more follows the Explore module snapped to the left', (
    t,
  ) async {
    await _pump(t, const ElearningTab(), size: const Size(390, 3400));
    expect(find.byType(DiscoverMore), findsOneWidget);
    // Organic first (recent activity): its video rail shows.
    expect(find.text('Watch and learn · 2 in Organik'), findsOneWidget);
    expect(find.text('Video about inorganic'), findsNothing);
    // No module chip or header: only the rails.
    expect(find.text('Discover more'), findsNothing);
    final carousel = find.descendant(
      of: find.byType(ExploreSection),
      matching: find.byType(SnapRail),
    );
    await t.fling(carousel, const Offset(-120, 0), 1000);
    await _settle(t);
    expect(find.text('Watch and learn · 1 in Anorganik'), findsOneWidget);
    expect(find.text('Video about inorganic'), findsOneWidget);
    expect(sounds, containsAllInOrder([ElioSfx.tick, ElioSfx.pop]));
    // The far-right card can snap to the left too (B3 was unreachable).
    await t.fling(carousel, const Offset(-120, 0), 1000);
    await _settle(t);
    expect(find.text('Watch and learn · 1 in B3'), findsOneWidget);
    expect(sounds.where((s) => s == ElioSfx.tick).length, 2);
  });

  testWidgets('module page: hero, ticket, tags, lesson grid, quiz ticket', (
    t,
  ) async {
    await _pump(
      t,
      const ModulePage(module: _organic),
      size: const Size(390, 2400),
    );
    expect(t.takeException(), isNull);
    expect(find.text('MODULE 1 · ORGANIK'), findsOneWidget);
    expect(find.text('Module progress · 1 of 3 done'), findsOneWidget);
    expect(find.text('Start lesson 2'), findsOneWidget);
    expect(find.text('What goes in the green bin'), findsOneWidget);
    expect(find.byType(ContentPopCard), findsNWidgets(4)); // 3 lessons + sim
    expect(_svg(RobotBuddy.asset(RobotMood.thinking)), findsOneWidget);
  });

  testWidgets('lesson page: polaroid player, stat bubbles, playlist', (
    t,
  ) async {
    await _pump(t, LessonPage(lesson: LearnLesson.video(await _video())));
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('Lesson 3 of 3'), findsOneWidget);
    expect(find.text('Continue video · 40%'), findsOneWidget);
    expect(find.text('40%'), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp('Composting fundamentals, 7:22')),
      findsOneWidget,
    );
  });

  testWidgets('density: right bin chimes, wrong bin knocks', (t) async {
    await _pump(t, const DensitySimulationPage(), size: const Size(390, 2000));
    expect(t.takeException(), isNull);
    expect(find.text('Done'), findsNothing); // not viewed yet in this fake
    await t.tap(find.bySemanticsLabel('Plastic').first);
    await t.pump();
    await t.tap(find.bySemanticsLabel('Glass').first);
    await t.pump();
    expect(sounds, [ElioSfx.knock, ElioSfx.chime]);
  });

  testWidgets('Kuis fisika: pick, check, then next; buddy reacts', (t) async {
    await _pump(t, const PhysicsQuizPage());
    expect(t.takeException(), isNull);
    expect(find.text('Pick an answer to continue.'), findsOneWidget);
    expect(_svg(RobotBuddy.asset(RobotMood.thinking)), findsOneWidget);
    await t.tap(find.bySemanticsLabel(RegExp('^Answer A')));
    await t.pump();
    expect(sounds, [ElioSfx.tick]);
    await t.tap(find.text('Check answer'));
    await _settle(t);
    expect(
      _svg(RobotBuddy.asset(RobotMood.excited)).evaluate().length +
          _svg(RobotBuddy.asset(RobotMood.sad)).evaluate().length,
      1,
    );
    expect(sounds.last, anyOf(ElioSfx.chime, ElioSfx.knock));
    expect(find.text('Next question'), findsOneWidget);
  });

  testWidgets('RiseWatcher fires on a rise only, never on first show', (
    t,
  ) async {
    final rises = <(int, int)>[];
    Widget at(int v) => Directionality(
      textDirection: TextDirection.ltr,
      child: RiseWatcher(
        value: v,
        onRise: (a, b) => rises.add((a, b)),
        builder: (_, bump) => Text('$bump'),
      ),
    );
    await t.pumpWidget(at(1));
    await t.pump();
    expect(rises, isEmpty);
    await t.pumpWidget(at(0));
    await t.pump();
    await t.pumpWidget(at(2));
    await t.pump();
    expect(rises, [(0, 2)]);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('returning to Learn shows the hub at once, no loading frame', (
    t,
  ) async {
    final show = ValueNotifier(true);
    await _pump(
      t,
      ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (_, on, _) => on ? const ElearningTab() : const SizedBox(),
      ),
      size: const Size(390, 3400),
    );
    expect(find.byType(ArchiveStack), findsOneWidget);
    show.value = false;
    await t.pump();
    show.value = true;
    await t.pump(); // the very first frame back on Learn
    expect(find.byType(LearnHubSkeleton), findsNothing);
    expect(find.byType(GuidesHubSection), findsNothing);
    expect(find.byType(ArchiveStack), findsOneWidget);
    expect(find.text('1 of 3 modules in progress'), findsOneWidget);
  });

  testWidgets('reduce motion still renders the hub', (t) async {
    await _pump(
      t,
      const ElearningTab(),
      size: const Size(390, 3400),
      reduceMotion: true,
    );
    expect(t.takeException(), isNull);
    expect(find.byType(ArchiveStack), findsOneWidget);
  });

  // Every redesigned screen in light/dark, EN/ID without exceptions.
  for (final dark in [false, true]) {
    for (final lang in ['en', 'id']) {
      final m = '${dark ? 'dark' : 'light'}-$lang';
      testWidgets('renders $m', (t) async {
        Future<void> one(String name, Widget page, Size size) async {
          await _pump(t, page, dark: dark, lang: lang, size: size);
          await _settle(t);
          expect(t.takeException(), isNull, reason: name);
          await _shot(t, '$m-$name');
        }

        await one('hub', const ElearningTab(), const Size(390, 3000));
        await one(
          'module',
          const ModulePage(module: _organic),
          const Size(390, 2200),
        );
        await one(
          'lesson',
          LessonPage(lesson: LearnLesson.video(await _video())),
          const Size(390, 1250),
        );
        await one(
          'density',
          const DensitySimulationPage(),
          const Size(390, 1250),
        );
        await one('kuis', const PhysicsQuizPage(), const Size(390, 870));
      });
    }
  }
}
