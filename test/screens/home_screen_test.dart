import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:elio/Screens/home/home_activity.dart';
import 'package:elio/Screens/home_screen.dart';
import 'package:elio/models/guide_lesson.dart';
import 'package:elio/models/home_stats.dart';
import 'package:elio/models/learning_progress.dart';
import 'package:elio/models/quiz_set.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/models/video_lesson.dart';
import 'package:elio/providers/auth_provider.dart';
import 'package:elio/providers/learning_progress_provider.dart';
import 'package:elio/providers/navigation_provider.dart';
import 'package:elio/providers/robot_provider.dart';
import 'package:elio/services/elearning_content_service.dart';
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/widgets/history_ui.dart' show HistoryScanCard;
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/scan_record_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_support.dart';

/// H1 v4 gamified Home (decision 0144). Firestore is a fake content service;
/// the scan store is in memory; "now" is fixed to Saturday 31 Oct 2026 15:00.
class _FakeContent implements ElearningContentService {
  @override
  Stream<List<VideoLesson>> watchVideoLessons({String? moduleId}) =>
      Stream.value(const [
        VideoLesson(
          id: 'v1',
          moduleId: 'inorganic',
          sectionTitle: 'Basics',
          title: 'Plastic waste management',
          description: '',
          durationMinutes: 6,
          durationLabel: '6:38',
          videoUrl: '',
          thumbnailUrl: '',
          youtubeId: '',
          level: 'beginner',
          moduleLabel: 'Module 2',
          status: 'published',
          isFeatured: false,
          order: 1,
          isPublished: true,
        ),
      ]);
  @override
  Stream<List<GuideLesson>> watchGuideLessons({String? moduleId}) =>
      Stream.value(const [
        GuideLesson(
          id: 'g1',
          moduleId: 'organic',
          moduleTitle: 'Module 1',
          title: 'Sorting guide',
          description: '',
          pdfUrl: '',
          coverUrl: '',
          order: 1,
          isPublished: true,
        ),
      ]);
  @override
  Stream<List<QuizSet>> watchQuizSets({String? moduleId}) =>
      Stream.value(const [
        QuizSet(
          id: 'q1',
          moduleId: 'inorganic',
          title: 'Plastic waste quiz',
          description: '',
          level: 'easy',
          questionCount: 10,
          iconType: '',
          theme: '',
          order: 1,
          isPublished: true,
        ),
      ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStore extends ScanRecordStore {
  _FakeStore(this._records, {this.loaded = true});
  final List<ScanRecord> _records;
  final bool loaded;
  @override
  List<ScanRecord> get records => _records;
  @override
  bool get isLoaded => loaded;
  @override
  int get totalTrophies =>
      _records.fold(0, (s, r) => s + r.trophies) + questBonus(_records);
  @override
  Future<List<ScanRecord>> load({bool force = false}) async => _records;
}

class _Progress extends LearningProgressNotifier {
  @override
  Future<LearningProgress> build() async => LearningProgress(
    userId: 'u',
    completedVideoIds: {'v1'},
    completedGuideIds: {'g1'},
    completedQuizModules: {'inorganic'},
  );
}

final _now = DateTime(2026, 10, 31, 15);
const _right = RecordQuestion(
  question: 'q',
  yourAnswer: 'a',
  rightAnswer: 'a',
  isCorrect: true,
);
const _wrong = RecordQuestion(
  question: 'q',
  yourAnswer: 'b',
  rightAnswer: 'a',
  isCorrect: false,
);

List<ScanRecord> _sample() {
  var n = 0;
  ScanRecord r(
    int daysAgo,
    String name,
    ScanCategory c,
    List<RecordQuestion> qs, {
    int hour = 10,
  }) => ScanRecord(
    id: 's${n++}',
    time: DateTime(2026, 10, 31 - daysAgo, hour),
    itemName: name,
    category: c,
    difficulty: QuizDifficulty.easy,
    questions: qs,
    trophies: qs.where((q) => q.isCorrect).length * 10,
  );
  return [
    r(1, 'Botol plastik', ScanCategory.recyclable, const [_right], hour: 9),
    r(1, 'Kulit pisang', ScanCategory.organic, const [_right]),
    r(0, 'Baterai bekas', ScanCategory.b3, const [_right]),
    r(2, 'Gelas plastik', ScanCategory.residu, const [_wrong]),
    r(3, 'Kaleng', ScanCategory.recyclable, const [_right]),
    for (var i = 0; i < 20; i++)
      r(
        5 + i * 3,
        'Daun ${i + 1}',
        ScanCategory.organic,
        i.isEven ? const [_right] : const [_wrong],
      ),
  ];
}

enum _Data { sample, empty, loading }

Future<void> _pump(
  WidgetTester t, {
  _Data data = _Data.sample,
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  double textScale = 1,
  User? user,
  bool disableAnimations = false,
  bool shot = false,
  bool settle = true,
}) async {
  homeContentServiceForTest = _FakeContent();
  homeClock = () => _now;
  addTearDown(() {
    homeContentServiceForTest = null;
    homeClock = DateTime.now;
  });
  final store = _FakeStore(
    data == _Data.sample ? _sample() : const [],
    loaded: data != _Data.loading,
  );
  final screen = HomeScreen(
    auth: MockFirebaseAuth(),
    onOpenLearning: () {},
    store: store,
  );
  await pumpAt(
    t,
    shot ? RepaintBoundary(key: const Key('shot'), child: screen) : screen,
    size: size,
    brightness: brightness,
    textScale: textScale,
    disableAnimations: disableAnimations,
    overrides: [
      currentUserProvider.overrideWithValue(user),
      learningProgressProvider.overrideWith(_Progress.new),
    ],
  );
  await t.pump(const Duration(milliseconds: 50));
  // Let the entrance finish (it never does while the skeleton shimmers).
  for (var i = 0; settle && data != _Data.loading && i < 30; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

final _signedIn = MockUser(isAnonymous: false, uid: 'u1', displayName: 'Sam');

/// PNG renders for docs/test-results/h1v4/widget (run with H1_RENDER=1).
final _render = Platform.environment['H1_RENDER'] == '1';

Future<void> _png(WidgetTester t, String name) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    File('docs/test-results/h1v4/widget/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _scrollToEnd(WidgetTester t) async {
  await t.drag(find.byType(ListView), const Offset(0, -6000));
  await t.pump();
}

void main() {
  setUpAll(loadElioFonts);

  for (final b in Brightness.values) {
    testWidgets('${b.name}: home shows real numbers', (t) async {
      await _pump(
        t,
        brightness: b,
        user: _signedIn,
        size: const Size(390, 3200),
      );
      // Numbers count up on first show (ELIOS 3 motion, 0202).
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(find.text('25'), findsWidgets); // total scans
      expect(find.text('Waste Spotter'), findsOneWidget); // 140 trophies
      expect(find.text('140 trophies'), findsOneWidget);
      expect(
        find.text(
          '110 trophies to Level 3 · your tree grows with every trophy',
        ),
        findsOneWidget,
      );
      expect(find.text('Lv 2'), findsOneWidget);
      expect(find.text('Lv 3'), findsOneWidget);
      expect(
        find.text('ELIOS robot'.toUpperCase()),
        findsNothing,
        reason: 'no robot connected',
      );
      expect(find.text('Scan activity'), findsOneWidget);
      expect(find.text('Bin buddies'), findsOneWidget);
      expect(
        find.textContaining('Anorganik includes 1 residu scan'),
        findsOneWidget,
      );
      expect(find.text('Medals'), findsOneWidget);
      expect(find.text('DID YOU KNOW?'), findsNothing);
      expect(find.text('Open History'), findsOneWidget);
      expect(find.textContaining('Guest progress'), findsNothing);
      expect(find.textContaining('Drag to rotate'), findsNothing);
      expect(find.text('Quick Actions'), findsNothing);
    });

    testWidgets('${b.name}: 360 dp at text scale 1.3 has no overflow', (
      t,
    ) async {
      await _pump(
        t,
        brightness: b,
        size: const Size(360, 740),
        textScale: 1.3,
        user: _signedIn,
      );
      expect(t.takeException(), isNull);
      await _scrollToEnd(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('${b.name}: guest with no scans', (t) async {
      await _pump(
        t,
        brightness: b,
        data: _Data.empty,
        size: const Size(390, 3000),
      );
      expect(t.takeException(), isNull);
      expect(
        find.textContaining('Guest progress is stored on this device'),
        findsOneWidget,
      );
      expect(find.text('Eco Starter'), findsOneWidget);
      expect(
        find.text('Plant your first trophy: scan an item.'),
        findsOneWidget,
      );
      expect(find.text('No scans in the last 17 weeks'), findsOneWidget);
      expect(find.text('Your first scan lights up today'), findsOneWidget);
      expect(find.text('Your bins are hungry: scan an item'), findsOneWidget);
      expect(
        find.textContaining('Residu scans count toward Anorganik'),
        findsOneWidget,
      );
      expect(find.text('—'), findsWidgets);
      expect(find.text('0 of 3 done · resets at midnight'), findsOneWidget);
    });
  }

  testWidgets(
    'signed-in user with no scans: empty state without guest banner',
    (t) async {
      await _pump(
        t,
        data: _Data.empty,
        user: _signedIn,
        size: const Size(390, 3000),
      );
      expect(find.textContaining('Guest progress'), findsNothing);
      expect(find.text('Eco Starter'), findsOneWidget);
      final container = ProviderScope.containerOf(
        t.element(find.byType(HomeScreen)),
      );
      await t.tap(find.text('Scan an item'));
      expect(container.read(navigationIndexProvider), 2, reason: 'Scan hub');
    },
  );

  testWidgets('loading shows the skeleton; static under reduced motion', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await _pump(t, data: _Data.loading, disableAnimations: true);
    expect(find.text('Growing your tree…'), findsOneWidget);
    expect(find.bySemanticsLabel('Loading your progress'), findsOneWidget);
    expect(t.binding.hasScheduledFrame, isFalse);
    handle.dispose();
  });

  testWidgets('loading pulses with motion on', (t) async {
    await _pump(t, data: _Data.loading);
    expect(find.text('Growing your tree…'), findsOneWidget);
    expect(t.binding.hasScheduledFrame, isTrue);
  });

  testWidgets(
    'search: debounced results across scopes, bold match, open a scan',
    (t) async {
      await _pump(t, user: _signedIn, size: const Size(390, 1600));
      await t.enterText(find.byType(TextField), 'plas');
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Bin buddies'), findsOneWidget); // still debouncing
      await t.pump(const Duration(milliseconds: 200));
      // 1 video + 1 quiz + 2 scans; no simulation mentions "plas".
      expect(find.text('4 results'), findsOneWidget);
      expect(find.text('All 4'), findsOneWidget);
      expect(find.text('Simulations 0'), findsOneWidget);
      expect(find.text('Lessons 1'), findsOneWidget);
      expect(find.text('Scans 2'), findsOneWidget);
      expect(find.text('YOUR SCANS'), findsOneWidget);
      expect(find.text('Bin buddies'), findsNothing);
      expect(t.takeException(), isNull);

      await t.ensureVisible(find.text('Scans 2'));
      await t.tap(find.text('Scans 2'));
      await t.pump();
      expect(find.text('LESSONS'), findsNothing);

      final container = ProviderScope.containerOf(
        t.element(find.byType(HomeScreen)),
      );
      await t.tap(find.bySemanticsLabel(RegExp('^Botol plastik')));
      expect(container.read(navigationIndexProvider), 4);

      await t.tap(find.byTooltip('Clear search'));
      await t.pump();
      expect(find.text('Bin buddies'), findsOneWidget);
    },
  );

  testWidgets('search with no results', (t) async {
    await _pump(t, user: _signedIn);
    await t.enterText(find.byType(TextField), 'zzzz');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('0 results'), findsOneWidget);
    expect(find.text('No results for “zzzz”.'), findsOneWidget);
  });

  testWidgets('year grid: tap today opens the month view with that day', (
    t,
  ) async {
    await _pump(t, user: _signedIn, size: const Size(390, 3000));
    // Today (Saturday) is the bottom cell of the last column.
    final grid = t.getRect(find.byType(YearGrid));
    await t.tapAt(grid.bottomRight - const Offset(4, 4));
    await t.pump();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Saturday, 31 October · 1 scan'), findsOneWidget);
    expect(find.text('Baterai bekas'), findsWidgets); // day list + fan
  });

  testWidgets('month view: select a day, list its scans, open History', (
    t,
  ) async {
    await _pump(t, user: _signedIn, size: const Size(390, 3000));
    await t.tap(find.text('Month'));
    await t.pump();
    expect(find.text('14 scans in October'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('30 October, 2 scans'));
    await t.pump();
    expect(find.text('Friday, 30 October · 2 scans'), findsOneWidget);
    expect(find.text('Botol plastik'), findsWidgets);
    expect(find.text('Kulit pisang'), findsWidgets);
    expect(t.takeException(), isNull);
    final container = ProviderScope.containerOf(
      t.element(find.byType(HomeScreen)),
    );
    await t.tap(find.text('Open in History'));
    expect(container.read(navigationIndexProvider), 4);
  });

  testWidgets('charts and medals have TalkBack labels', (t) async {
    final handle = t.ensureSemantics();
    await _pump(t, user: _signedIn, size: const Size(390, 3200));
    expect(
      find.bySemanticsLabel(RegExp(r'^\d+ scans in the last 17 weeks$')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Organik 21 scans, 84%')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Anorganik 3 scans')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^\d+ scans this week\.')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Quiz accuracy \d+ percent')),
      findsOneWidget,
    );
    // 3 learning items completed in _Progress.
    expect(
      find.bySemanticsLabel(RegExp('^Environmental Explorer, unlocked')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('^Robotics Beginner, locked')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets(
    'header actions: only the 48 dp bell (trophies are on the hero)',
    (t) async {
      await pumpAt(
        t,
        Scaffold(
          body: Center(child: HomeHeaderActions(onOpenLearning: () {})),
        ),
        overrides: [currentUserProvider.overrideWithValue(null)],
      );
      expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
      final bell = t.getSize(find.byTooltip('Open notifications'));
      expect(bell.width, greaterThanOrEqualTo(48));
      await t.tap(find.byTooltip('Open notifications'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Notifications'), findsOneWidget);
    },
  );

  testWidgets('entrance replays on every open; still under reduced motion', (
    t,
  ) async {
    final sounds = <ElioSfx>[];
    ElioSound.instance
      ..sink = ((sfx, _) => sounds.add(sfx))
      ..isSilent = (() async => false)
      ..clock = (() => t.binding.clock.now());
    addTearDown(() => ElioSound.instance.sink = null);
    // "25" on the first screen is the scans pebble.
    int count() => find.text('25').evaluate().length;
    for (var visit = 0; visit < 2; visit++) {
      sounds.clear();
      await _pump(t, user: _signedIn, settle: false);
      expect(count(), 0, reason: 'visit $visit starts counting from 0');
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(count(), 1, reason: 'counted up to 25');
      expect(sounds, [
        ElioSfx.pop,
        ElioSfx.chime,
        ElioSfx.sparkleShort,
      ], reason: 'tree, dial and sticker beats');
      await t.pumpWidget(const SizedBox());
    }
    sounds.clear();
    await _pump(
      t,
      user: _signedIn,
      size: const Size(390, 3200),
      disableAnimations: true,
    );
    expect(count(), greaterThanOrEqualTo(2), reason: 'at rest at once');
    expect(t.binding.hasScheduledFrame, isFalse);
    expect(sounds, isEmpty);
  });

  testWidgets('lower sections play when scrolled into view', (t) async {
    await _pump(t, user: _signedIn);
    await t.pump(const Duration(seconds: 3));
    double opacity() => t
        .widget<Opacity>(
          find
              .ancestor(of: find.text('Medals'), matching: find.byType(Opacity))
              .first,
        )
        .opacity;
    expect(opacity(), 0, reason: 'below the fold: waiting');
    await _scrollToEnd(t);
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 2));
    expect(opacity(), 1);
  });

  testWidgets('Recent scans: the three latest, Open History opens History', (
    t,
  ) async {
    await _pump(
      t,
      user: _signedIn,
      size: const Size(390, 3200),
      disableAnimations: true,
    );
    expect(find.byType(HistoryScanCard), findsNWidgets(3));
    expect(find.textContaining('Latest: Baterai bekas'), findsOneWidget);
    final container = ProviderScope.containerOf(
      t.element(find.byType(HomeScreen)),
    );
    await t.tap(find.text('Open History'));
    expect(container.read(navigationIndexProvider), 4);
  });

  testWidgets('resume control shows only while a robot is connected', (
    t,
  ) async {
    final status = StreamController<String>.broadcast();
    addTearDown(status.close);
    await pumpAt(
      t,
      const Scaffold(body: Center(child: HomeResumeControl())),
      overrides: [robotStatusProvider.overrideWith((ref) => status.stream)],
    );
    expect(find.text('Still connected'), findsNothing);
    status.add('Connected');
    await t.pump();
    expect(find.text('Still connected'), findsOneWidget);
    final container = ProviderScope.containerOf(
      t.element(find.byType(HomeResumeControl)),
    );
    await t.tap(find.text('Continue'));
    expect(container.read(navigationIndexProvider), 3, reason: 'opens Control');
    status.add('Disconnected');
    await t.pump();
    expect(find.text('Still connected'), findsNothing);
  });

  const shots = [
    ('home-light', _Data.sample, Brightness.light, true),
    ('home-dark', _Data.sample, Brightness.dark, true),
    ('guest-light', _Data.empty, Brightness.light, false),
    ('guest-dark', _Data.empty, Brightness.dark, false),
    ('loading-light', _Data.loading, Brightness.light, true),
    ('loading-dark', _Data.loading, Brightness.dark, true),
  ];
  for (final (name, data, b, signedIn) in shots) {
    testWidgets('render $name', (t) async {
      await _pump(
        t,
        data: data,
        brightness: b,
        user: signedIn ? _signedIn : null,
        size: Size(390, data == _Data.loading ? 844 : 2300),
        disableAnimations: true,
        shot: true,
      );
      await _png(t, name);
    }, skip: !_render);
  }
  for (final b in Brightness.values) {
    testWidgets('render search-${b.name}', (t) async {
      await _pump(
        t,
        brightness: b,
        user: _signedIn,
        size: const Size(390, 900),
        shot: true,
      );
      await t.enterText(find.byType(TextField), 'plas');
      await t.pump(const Duration(milliseconds: 300));
      await _png(t, 'search-${b.name}');
    }, skip: !_render);
    testWidgets('render month-${b.name}', (t) async {
      await _pump(
        t,
        brightness: b,
        user: _signedIn,
        size: const Size(390, 2300),
        shot: true,
      );
      await t.tap(find.text('Month'));
      await t.pump();
      await t.tap(find.bySemanticsLabel('30 October, 2 scans'));
      await t.pump();
      await _png(t, 'month-${b.name}');
    }, skip: !_render);
  }
}
