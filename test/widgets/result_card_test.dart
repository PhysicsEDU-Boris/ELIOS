import 'dart:io';
import 'package:elio/models/home_stats.dart' show questBonus;
import 'package:elio/models/scan_record.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/robot_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/detection_stabilizer.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/robot/r1_constants.dart';
import 'package:elio/services/robot/r1_orchestrator.dart';
import 'package:elio/services/robot/robot_controller.dart';
import 'package:elio/services/robot/simulated_robot.dart';
import 'package:elio/services/scan_record_store.dart';
import 'package:elio/widgets/control_layout.dart';
import 'package:elio/widgets/control/r2_controls.dart';
import 'package:elio/widgets/waste_quiz_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _SeededQuizNotifier extends WasteQuizNotifier {
  _SeededQuizNotifier(this.seed);
  final WasteQuizUiState seed;
  @override
  WasteQuizUiState build() => seed;
}

final _mcFinishedState = WasteQuizUiState(
  phase: WasteQuizPhase.finished,
  scan: ScannedWaste.fromLabel('botol-plastik'),
  difficulty: QuizDifficulty.easy,
  correctCount: 1,
  mcAnswered: 1,
  recordedQuestions: const [
    RecordQuestion(
      question: 'Pertanyaan MC 1',
      yourAnswer: 'Jawaban A',
      rightAnswer: 'Jawaban A',
      isCorrect: true,
      trophies: 10,
    ),
  ],
);

final _essayFinishedState = WasteQuizUiState(
  phase: WasteQuizPhase.finished,
  scan: ScannedWaste.fromLabel('botol-plastik'),
  difficulty: QuizDifficulty.easy,
  correctCount: 1,
  recordedQuestions: const [
    RecordQuestion(
      question: 'Pertanyaan Essay',
      yourAnswer: 'Jawaban essay mahasiswa',
      rightAnswer: 'Poin kunci materi',
      isCorrect: true,
      trophies: 8,
      isEssay: true,
      essayScore: 8,
    ),
  ],
);

const _sizes = {
  '1366x768': Size(1366, 768),
  '1024x768': Size(1024, 768),
  '800x632': Size(800, 632),
  '770x553': Size(770, 553),
  '390x844': Size(390, 844),
};

Future<void> _expectTappable(WidgetTester tester, Finder finder, String what, {bool scroll = true}) async {
  expect(finder, findsOneWidget, reason: what);
  if (scroll) {
    await tester.ensureVisible(finder);
    await tester.pump();
  }
  final target = tester.renderObject(finder);
  final hits = tester.hitTestOnBinding(tester.getCenter(finder)).path.map((e) => e.target).whereType<RenderObject>();
  expect(hits, contains(target), reason: '$what is covered or offscreen');
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    WasteQuizPopup.r1EnabledOverride = false;
  });

  group('Result card numbers and trophy display', () {
    testWidgets('multiple-choice results show correct counts, trophies, grade and level', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wasteQuizProvider.overrideWith(() => _SeededQuizNotifier(_mcFinishedState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WasteQuizPopup(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check item name & correct counts
      expect(find.text('Botol plastik'), findsWidgets);
      expect(find.text('1 dari 1 benar'), findsOneWidget);

      // Check trophies (+10 Piala)
      expect(find.text('+10 trophies'), findsOneWidget);

      // Check grade Sempurna
      expect(find.text('Perfect'), findsOneWidget);

      // Check action buttons
      expect(find.text('Scan again'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('essay score out of 10 awarded directly as trophies', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wasteQuizProvider.overrideWith(() => _SeededQuizNotifier(_essayFinishedState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WasteQuizPopup(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check correct count & trophies (+8 Piala)
      expect(find.text('1 dari 1 benar'), findsOneWidget);
      expect(find.text('+8 trophies'), findsOneWidget);

      // Check grade Hebat
      expect(find.text('Great'), findsOneWidget);
    });
  });

  group('ScanRecord persistence from finished session', () {
    late Directory tempDir;
    late File testFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('scan_record_test_');
      testFile = File('${tempDir.path}/test_records.json');
      ScanRecordStore.setInstanceForTesting(ScanRecordStore(customFile: testFile));
    });

    tearDown(() async {
      ScanRecordStore.setInstanceForTesting(null);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('finishing a quiz session saves record into ScanRecordStore and reloads cleanly', () async {
      final store = ScanRecordStore.instance;
      await store.load();
      expect(store.records, isEmpty);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(wasteQuizProvider.notifier);
      final scan = ScannedWaste.fromLabel('botol-plastik');

      // Set initial active state with a question
      final q = const GeneratedQuestion(
        type: QuizQuestionType.multipleChoice,
        question: 'Bagaimana memilah botol plastik?',
        options: ['Daur ulang', 'Bakar', 'Timbun'],
        correctIndex: 0,
        explanation: 'Botol plastik masuk daur ulang.',
      );

      notifier.state = WasteQuizUiState(
        phase: WasteQuizPhase.active,
        scan: scan,
        difficulty: QuizDifficulty.easy,
        question: q,
      );

      // Student selects the correct option (index 0)
      notifier.selectOption(0);

      // Last question finished -> _advance() -> _finish()
      notifier.nextQuestion();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.phase, WasteQuizPhase.finished);
      expect(store.records.length, 1);

      final saved = store.records.first;
      expect(saved.itemName, 'Botol plastik');
      expect(saved.trophies, 10);
      expect(saved.correctCount, 1);
      expect(saved.totalQuestions, 1);
      expect(saved.questions.first.question, 'Bagaimana memilah botol plastik?');
      expect(saved.questions.first.isCorrect, true);

      // Reload into a separate store instance from disk
      final reloadedStore = ScanRecordStore(customFile: testFile);
      await reloadedStore.load();
      expect(reloadedStore.records.length, 1);
      expect(reloadedStore.totalTrophies, 10 + questBonus(reloadedStore.records));
      expect(reloadedStore.records.first.itemName, 'Botol plastik');
    });
  });

  group('R1 drop gate', () {
    testWidgets('shows drop notice and disables Scan lagi while R1 drop is pending', (tester) async {
      WasteQuizPopup.r1EnabledOverride = true;
      var rescanCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wasteQuizProvider.overrideWith(() => _SeededQuizNotifier(_mcFinishedState)),
            r1DropPendingProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WasteQuizPopup(
                onRescan: () => rescanCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Drop notice shown
      expect(find.text('The robot is dropping it in the bin...'), findsOneWidget);

      // Scan lagi is disabled
      final scanLagiButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Scan again'),
      );
      expect(scanLagiButton.onPressed, isNull);

      // Tap should do nothing
      await tester.tap(find.widgetWithText(FilledButton, 'Scan again'));
      await tester.pump();
      expect(rescanCalled, isFalse);
    });

    testWidgets('enables Scan lagi once R1 drop finishes', (tester) async {
      WasteQuizPopup.r1EnabledOverride = true;
      var rescanCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wasteQuizProvider.overrideWith(() => _SeededQuizNotifier(_mcFinishedState)),
            r1DropPendingProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: WasteQuizPopup(
                onRescan: () => rescanCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drop notice is not shown
      expect(find.text('The robot is dropping it in the bin...'), findsNothing);

      // Scan lagi is enabled and tappable
      final scanLagiButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Scan again'),
      );
      expect(scanLagiButton.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Scan again'));
      await tester.pump();
      expect(rescanCalled, isTrue);
    });

    test('SimulatedRobot drop state transition resolves pending drop', () {
      var now = 0;
      DateTime clock() => DateTime(2026, 1, 1).add(Duration(milliseconds: now));

      final robot = SimulatedRobot(clock);
      final r1 = R1Orchestrator(robot, clock: clock);

      void run(int ms) {
        for (final end = now + ms; now < end;) {
          now += 100;
          robot.tick();
          r1.onFrame(robot.frame());
        }
      }

      r1.linkUp();
      run(300);
      expect(r1.robotConnected, isTrue);

      // Lock -> identified -> position -> ready -> sorting
      const lockBox = TrackedDetection(label: 'Plastic', x: 320, y: 300, w: 120, h: 160, score: 0.9);
      expect(r1.onLock(lockBox), isTrue);
      run(300);
      r1.onIdentified(Bin.anorganik);
      r1.onStudentBin(Bin.anorganik);
      run(revealDuration.inMilliseconds + 200);

      expect(r1.state, R1State.ready);
      r1.onAmbil();

      // In sorting / dropping
      final isDropping = r1.state == R1State.sorting || r1.state == R1State.waitBoth;
      expect(isDropping, isTrue);

      // Complete questions and run out all motions (PICK, MOVE_TO_BIN, DROP)
      for (var i = 0; i < objectQuestionCount; i++) {
        r1.onQuestionShown();
        run(500);
        r1.onQuestionAnswered();
      }
      run(15000);

      // Dropping finished: returned to searching
      expect(r1.state, R1State.searching);
      expect(r1.state == R1State.sorting || r1.state == R1State.waitBoth, isFalse);
    });
  });

  group('Layout tests across 5 viewports', () {
    for (final entry in _sizes.entries) {
      testWidgets('finished result card at ${entry.key}: no overflow, buttons and STOP reachable', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = entry.value;
        addTearDown(tester.view.reset);

        var stoppedTapped = false;
        var rescanTapped = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              wasteQuizProvider.overrideWith(() => _SeededQuizNotifier(_mcFinishedState)),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: Colors.white,
                body: ControlLayout(
                  stoppedBanner: null,
                  exitButton: ControlPill(icon: Icons.arrow_back_rounded, label: 'Exit', onTap: () {}),
                  debugScanButton: ControlPill(icon: Icons.bug_report_outlined, label: 'Debug Scan', onTap: () {}),
                  debugBuild: true,
                  historyButton: const HistoryPill(),
                  driveStatus: const SizedBox(),
                  joystick: DriveJoystick(enabled: true, onDirection: (_) {}, onRelease: () {}),
                  speed: const SizedBox(height: 40),
                  camera: const ColoredBox(key: ValueKey('control_camera'), color: Color(0xFFD9D9D9)),
                  actions: const SizedBox(),
                  armStatus: const SizedBox(),
                  armHeight: ControlFader(vertical: true, value: 0.2, onChanged: (_) {}),
                  armReach: ControlFader(vertical: true, value: 0.3, onChanged: (_) {}),
                  power: const SizedBox(height: 52),
                  stopButton: EmergencyStopButton(onStop: () => stoppedTapped = true),
                  bottomCards: const [SizedBox(), SizedBox(), SizedBox(), SizedBox()],
                  compactStrip: const SizedBox(),
                  quiz: WasteQuizPopup(
                    onStop: () => stoppedTapped = true,
                    onRescan: () => rescanTapped = true,
                    showLauncher: false,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Zero RenderFlex overflow
        expect(tester.takeException(), isNull);

        // 2. Scan lagi is reachable and on top
        await _expectTappable(tester, find.widgetWithText(FilledButton, 'Scan again'), 'Scan lagi button');

        // 3. Tutup is reachable and on top
        await _expectTappable(tester, find.widgetWithText(OutlinedButton, 'Close'), 'Tutup button');

        // 4. STOP button in quiz header is reachable and on top (decision 0026)
        final quizStop = find.descendant(of: find.byType(WasteQuizPopup), matching: find.text('STOP'));
        await _expectTappable(tester, quizStop, 'Quiz header STOP button');
        await tester.tap(quizStop);
        await tester.pump();
        expect(stoppedTapped, isTrue);

        // 5. Buttons invoke callbacks
        await tester.tap(find.widgetWithText(FilledButton, 'Scan again'));
        await tester.pump();
        expect(rescanTapped, isTrue);
      });
    }
  });
}
