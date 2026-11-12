import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:elio/models/home_stats.dart' show questBonus;
import 'package:elio/Screens/scan_history_screen.dart';
import 'package:elio/services/scan_record_store.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/quiz_pdf_service.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:elio/widgets/quiz_explanation_overlay.dart';

class SeededQuiz extends WasteQuizNotifier {
  SeededQuiz(this.seed);
  final WasteQuizUiState seed;
  @override
  WasteQuizUiState build() => seed;
}

const question = GeneratedQuestion(
  type: QuizQuestionType.multipleChoice,
  question: 'Mengapa botol plastik PET harus dipilah sebelum didaur ulang?',
  options: ['Organik', 'Daur Ulang', 'B3', 'Residu'],
  correctIndex: 1,
  explanation: 'Pemilahan mencegah kontaminasi bahan daur ulang.',
);
const explanation = QuizExplanation(
  summary: 'Botol PET termasuk material anorganik yang dapat didaur ulang.',
  correctAnswerReason: 'Pemilahan mencegah kontaminasi.',
  groundingStatus: GroundingStatus.bankGrounded,
);

void main() {
  // H3 copy is asserted in Indonesian (decision 0185).
  setUpAll(() => debugSetL10n(const Locale('id')));
  tearDownAll(() => debugSetL10n(const Locale('en')));
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final size in [const Size(800, 600), const Size(844, 390)]) {
    testWidgets('explanation fits supported landscape window $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = WasteQuizUiState(
        phase: WasteQuizPhase.explaining,
        scan: ScannedWaste.fromLabel('botol plastik'),
        question: question,
        selectedOption: 1,
        voiceOn: false,
        currentExplanation: explanation,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [wasteQuizProvider.overrideWith(() => SeededQuiz(state))],
          child: const MaterialApp(
        locale: Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: QuizExplanationOverlay()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason:
            'Explanation and next action must fit the normal landscape app window',
      );
      expect(find.text('Soal Berikutnya →'), findsOneWidget);
    });
  }

  test('unavailable essay grading stays ungraded', () async {
    final container = ProviderContainer(
      overrides: [
        wasteQuizProvider.overrideWith(
          () => SeededQuiz(
            WasteQuizUiState(
              phase: WasteQuizPhase.active,
              scan: ScannedWaste.fromLabel('botol plastik'),
              voiceOn: false,
              question: const GeneratedQuestion(
                type: QuizQuestionType.essay,
                question: 'Jelaskan proses daur ulang plastik.',
                explanation: 'Pilah, cuci, cacah dan proses ulang.',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(wasteQuizProvider.notifier)
        .submitEssay('Plastik dipilah dan dicuci.');
    await pumpEventQueue();
    final state = container.read(wasteQuizProvider);
    expect(state.recordedQuestions.single.trophies, 0);
    expect(
      RecordQuestion.fromJson(
        state.recordedQuestions.single.toJson(),
      ).essayScore,
      isNull,
    );
    expect(state.currentExplanation?.essayScore, isNull);
    expect(
      state.recordedQuestions.single.essayScore,
      isNull,
      reason:
          'Decision 0031 requires pending evaluation when AI grading is unavailable',
    );
  });

  test('essay completion summary counts the essay question', () async {
    final dir = await Directory.systemTemp.createTemp('essay-summary-');
    final store = ScanRecordStore(customFile: File('${dir.path}/records.json'));
    ScanRecordStore.setInstanceForTesting(store);
    addTearDown(() async {
      ScanRecordStore.setInstanceForTesting(null);
      await dir.delete(recursive: true);
    });
    final container = ProviderContainer(overrides: [
      wasteQuizProvider.overrideWith(() => SeededQuiz(WasteQuizUiState(
        phase: WasteQuizPhase.active,
        scan: ScannedWaste.fromLabel('botol plastik'),
        difficulty: QuizDifficulty.easy,
        voiceOn: false,
        question: const GeneratedQuestion(
          type: QuizQuestionType.essay,
          question: 'Jelaskan daur ulang plastik.',
        ),
      ))),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(wasteQuizProvider.notifier);
    await notifier.submitEssay('Dipilah lalu didaur ulang.', score: 8);
    await pumpEventQueue();
    notifier.nextQuestion();
    await pumpEventQueue(times: 50);
    final state = container.read(wasteQuizProvider);
    expect(state.phase, WasteQuizPhase.finished);
    expect(state.messages.last.text, contains('Jawaban benar: 1 dari 1.'));
    expect(store.totalTrophies, 8 + questBonus(store.records));
    store.guideXp = 30; // Daily Guide XP counts too (0204)
    expect(store.totalTrophies, 38 + questBonus(store.records));
  });

  test('new explanation phase still stops TTS before next question', () async {
    var stops = 0;
    QuizTtsService.instance.mockStop = () async => stops++;
    addTearDown(() => QuizTtsService.instance.mockStop = null);
    final container = ProviderContainer(
      overrides: [
        wasteQuizProvider.overrideWith(
          () => SeededQuiz(
            WasteQuizUiState(
              phase: WasteQuizPhase.explaining,
              scan: ScannedWaste.fromLabel('botol plastik'),
              question: question,
              selectedOption: 1,
              voiceOn: false,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(wasteQuizProvider.notifier).nextQuestion();
    await pumpEventQueue();
    expect(stops, greaterThanOrEqualTo(1));
    expect(container.read(wasteQuizProvider).questionIndex, 1);
  });

  testWidgets('ungraded essay overlay shows pending rather than zero score', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = WasteQuizUiState(
      phase: WasteQuizPhase.explaining,
      scan: ScannedWaste.fromLabel('botol plastik'),
      voiceOn: false,
      question: const GeneratedQuestion(
        type: QuizQuestionType.essay,
        question: 'Jelaskan daur ulang plastik.',
      ),
      currentExplanation: const QuizExplanation(
        summary: 'Jawaban tersimpan, menunggu penilaian.',
        correctAnswerReason: '',
        groundingStatus: GroundingStatus.gemmaUngrounded,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [wasteQuizProvider.overrideWith(() => SeededQuiz(state))],
        child: const MaterialApp(
        locale: Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: QuizEssayExplanationOverlay()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Menunggu penilaian'), findsOneWidget);
    expect(find.textContaining('Score:'), findsNothing);
    expect(find.text('Table 1. Scoring breakdown'), findsNothing);
  });

  testWidgets('saved ungraded essay reopens as pending with no trophies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reopened = (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('pr49_pending_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/records.json');
    final store = ScanRecordStore(customFile: file);
    await store.addRecord(
      ScanRecord(
        id: 'pending',
        time: DateTime(2026, 10, 28),
        itemName: 'Botol Plastik',
        category: ScanCategory.recyclable,
        difficulty: QuizDifficulty.easy,
        questions: const [
          RecordQuestion(
            question: 'Jelaskan daur ulang.',
            yourAnswer: 'Pilah dan cuci.',
            rightAnswer: 'Pilah, cuci, cacah.',
            isCorrect: false,
            isEssay: true,
            trophies: 0,
          ),
        ],
      ),
    );
    final reopened = ScanRecordStore(customFile: file);
    await reopened.load();
    return reopened;
    }))!;
    expect(reopened.records.single.questions.single.gradingPending, isTrue);
    expect(reopened.totalTrophies, 0);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,home: ScanHistoryScreen(store: reopened)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsNothing);
    expect(find.text('Menunggu penilaian'), findsOneWidget);
    expect(find.text('Wrong'), findsNothing);
  });

  test(
    'long student essay exports without dropping content or throwing',
    () async {
      final text = List.filled(
        120,
        'Plastik dipilah, dicuci, dicacah dan diolah kembali.',
      ).join(' ');
      final record = ScanRecord(
        id: 'acceptance-long-essay',
        time: DateTime(2026, 10, 28),
        itemName: 'Botol Plastik',
        category: ScanCategory.recyclable,
        questions: [
          RecordQuestion(
            question: 'Jelaskan proses daur ulang plastik.',
            yourAnswer: text,
            rightAnswer: 'Pilah, cuci, cacah dan proses ulang.',
            isCorrect: true,
            isEssay: true,
            essayScore: 9,
            explanation: explanation,
          ),
        ],
      );
      final dir = await Directory.systemTemp.createTemp('pr49_long_pdf_');
      addTearDown(() => dir.delete(recursive: true));
      final path = await QuizPdfService.generateAndSave(record, targetDir: dir);
      expect(File(path).lengthSync(), greaterThan(1000));
    },
  );
}
