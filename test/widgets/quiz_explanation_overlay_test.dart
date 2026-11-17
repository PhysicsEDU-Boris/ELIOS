import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/widgets/quiz_explanation_overlay.dart';

class _FakeWasteQuizNotifier extends WasteQuizNotifier {
  _FakeWasteQuizNotifier(this.seed);
  final WasteQuizUiState seed;
  bool nextQuestionCalled = false;

  @override
  WasteQuizUiState build() => seed;

  @override
  void nextQuestion() {
    nextQuestionCalled = true;
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final testQuestion = GeneratedQuestion(
    type: QuizQuestionType.multipleChoice,
    question: 'Ke tempat mana botol plastik harus dibuang?',
    options: const ['Organik', 'Daur Ulang', 'B3', 'Residu'],
    correctIndex: 1,
    explanation: 'Plastik didaur ulang.',
  );

  final testExplanation = const QuizExplanation(
    summary: 'Botol plastik termasuk sampah anorganik yang dapat didaur ulang.',
    correctAnswerReason: 'Plastik dapat diproses kembali menjadi produk baru.',
    conceptExplanation: 'Daur ulang mengurangi ekstraksi minyak bumi untuk produksi polimer.',
    comparisonRows: [
      ComparisonRow(
        bin: 'Daur Ulang',
        material: 'Plastik',
        accepted: 'Botol bersih',
        isCorrect: true,
      ),
      ComparisonRow(
        bin: 'Residu',
        material: 'Plastik kotor',
        accepted: 'Tidak dapat diproses',
        isCorrect: false,
      ),
    ],
    learningTakeaway: 'Pisahkan plastik di tempat sampah daur ulang.',
    sourceTitle: 'Modul Daur Ulang',
    groundingStatus: GroundingStatus.bankGrounded,
  );

  Widget createSubject(WasteQuizUiState state, {WasteQuizNotifier Function()? notifierBuilder}) {
    return ProviderScope(
      overrides: [
        wasteQuizProvider.overrideWith(notifierBuilder ?? () => _FakeWasteQuizNotifier(state)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: QuizExplanationOverlay(),
        ),
      ),
    );
  }

  Widget createEssaySubject(WasteQuizUiState state, {WasteQuizNotifier Function()? notifierBuilder}) {
    return ProviderScope(
      overrides: [
        wasteQuizProvider.overrideWith(notifierBuilder ?? () => _FakeWasteQuizNotifier(state)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: QuizEssayExplanationOverlay(),
        ),
      ),
    );
  }

  group('QuizExplanationOverlay (MCQ)', () {
    testWidgets('shows success banner for correct answer', (tester) async {
      final state = WasteQuizUiState(
        phase: WasteQuizPhase.explaining,
        scan: ScannedWaste.fromLabel('botol-plastik'),
        difficulty: QuizDifficulty.medium,
        questionIndex: 0,
        question: testQuestion,
        selectedOption: 1, // correct
        currentExplanation: testExplanation,
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(state));
      await tester.pumpAndSettle();

      expect(find.text('Correct! +10 XP'), findsOneWidget);
      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.text('Next question →'), findsOneWidget);
      expect(find.text('AI Correction Assistant'), findsOneWidget);
      expect(find.text('Waste category comparison'), findsOneWidget);
      expect(find.text(testExplanation.summary), findsOneWidget);
      expect(find.text(testExplanation.learningTakeaway), findsOneWidget);
    });

    testWidgets('shows warning banner for incorrect answer with right answer', (tester) async {
      final state = WasteQuizUiState(
        phase: WasteQuizPhase.explaining,
        scan: ScannedWaste.fromLabel('botol-plastik'),
        difficulty: QuizDifficulty.medium,
        questionIndex: 0,
        question: testQuestion,
        selectedOption: 0, // incorrect ('Organik')
        currentExplanation: testExplanation,
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(state));
      await tester.pumpAndSettle();

      expect(find.text('Not quite right'), findsOneWidget);
      expect(find.text('Right answer: Daur Ulang'), findsOneWidget);
    });

    testWidgets('shows Selesai Quiz on the last question', (tester) async {
      final state = WasteQuizUiState(
        phase: WasteQuizPhase.explaining,
        scan: ScannedWaste.fromLabel('botol-plastik'),
        difficulty: QuizDifficulty.easy, // easy = 1 question
        questionIndex: 0,
        question: testQuestion,
        selectedOption: 1,
        currentExplanation: testExplanation,
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(state));
      await tester.pumpAndSettle();

      expect(find.text('Finish quiz ✓'), findsOneWidget);
    });

    testWidgets('tapping next button calls nextQuestion on notifier', (tester) async {
      final fakeNotifier = _FakeWasteQuizNotifier(WasteQuizUiState(
        phase: WasteQuizPhase.explaining,
        scan: ScannedWaste.fromLabel('botol-plastik'),
        difficulty: QuizDifficulty.medium,
        questionIndex: 0,
        question: testQuestion,
        selectedOption: 1,
        currentExplanation: testExplanation,
      ));

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(fakeNotifier.seed, notifierBuilder: () => fakeNotifier));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next question →'));
      await tester.pump();

      expect(fakeNotifier.nextQuestionCalled, isTrue);
    });
  });

  group('QuizEssayExplanationOverlay (Essay)', () {
    final essayQuestion = GeneratedQuestion(
      type: QuizQuestionType.essay,
      question: 'Jelaskan dampak lingkungan jika baterai dibuang sembarangan.',
      explanation: 'Baterai mengandung logam berat beracun.',
    );

    const essayExplanation = QuizExplanation(
      summary: 'Jawaban Anda telah dianalisis.',
      correctAnswerReason: 'Baterai mengandung timbal dan kadmium.',
      conceptExplanation: 'Pencemaran air tanah dapat merusak ekosistem akuatik.',
      rubricRows: [
        RubricRow(
          criterion: 'Analisis bahaya logam berat',
          maxScore: 6,
          awardedScore: 5,
          comment: 'Sangat baik',
        ),
        RubricRow(
          criterion: 'Rekomendasi pembuangan',
          maxScore: 4,
          awardedScore: 3,
          comment: 'Cukup jelas',
        ),
      ],
      learningTakeaway: 'Selalu buang baterai ke tempat khusus B3.',
      groundingStatus: GroundingStatus.gemmaUngrounded,
      essayScore: 8,
      essayFeedback: 'Uraian argumentatif dan sistematis.',
    );

    testWidgets('shows essay score banner and scoring breakdown table', (tester) async {
      final state = WasteQuizUiState(
        phase: WasteQuizPhase.explaining,
        scan: ScannedWaste.fromLabel('baterai'),
        difficulty: QuizDifficulty.easy,
        questionIndex: 0,
        question: essayQuestion,
        essaySubmitted: true,
        essayAnswer: 'Baterai mengandung logam berat yang mencemari air.',
        currentExplanation: essayExplanation,
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createEssaySubject(state));
      await tester.pumpAndSettle();

      // The shared essay review (0227) replaces the old banner and table.
      expect(find.text('8 / 10'), findsOneWidget);
      expect(find.text('Almost there!'), findsOneWidget);
      expect(find.text('Essay · max 150 words'), findsOneWidget);
    });
  });
}
