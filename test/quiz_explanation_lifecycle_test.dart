import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';

class _SeededQuiz extends WasteQuizNotifier {
  _SeededQuiz(this.seed);
  final WasteQuizUiState seed;
  @override
  WasteQuizUiState build() => seed;
}

const _testQuestion = GeneratedQuestion(
  type: QuizQuestionType.multipleChoice,
  question: 'Ke tempat sampah mana botol kaca harus dibuang?',
  options: ['Organik', 'Daur Ulang', 'B3', 'Residu'],
  correctIndex: 1,
  bankId: 'reviewed-glass',
  explanation: 'Kaca adalah material anorganik yang dapat didaur ulang.',
);

const _testEssayQuestion = GeneratedQuestion(
  type: QuizQuestionType.essay,
  question: 'Jelaskan mengapa pemilahan sampah organik penting di tingkat rumah tangga.',
  explanation: 'Mencegah pembusukan anaerobik yang menghasilkan gas metana di TPA.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AiQuizService.instance.mockSendExecute = (_, {imageBytes, isUser = false}) async => null);
  tearDown(() => AiQuizService.instance.mockSendExecute = null);

  group('Quiz Explanation Lifecycle', () {
    test('selectOption records answer and transitions phase to explaining', () async {
      final container = ProviderContainer(
        overrides: [
          wasteQuizProvider.overrideWith(
            () => _SeededQuiz(WasteQuizUiState(
              phase: WasteQuizPhase.active,
              scan: ScannedWaste.fromLabel('botol-kaca'),
              difficulty: QuizDifficulty.medium,
              questionIndex: 0,
              question: _testQuestion,
              voiceOn: false,
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(wasteQuizProvider.notifier);

      // Submit answer (index 1 = correct)
      notifier.selectOption(1);

      final state = container.read(wasteQuizProvider);
      expect(state.phase, WasteQuizPhase.explaining);
      expect(state.selectedOption, 1);
      expect(state.correctCount, 1);
      expect(state.recordedQuestions.length, 1);
      expect(state.recordedQuestions.first.isCorrect, isTrue);
      expect(state.recordedQuestions.first.trophies, 10);
    });

    test('nextQuestion does nothing if not in explaining phase', () async {
      final container = ProviderContainer(
        overrides: [
          wasteQuizProvider.overrideWith(
            () => _SeededQuiz(WasteQuizUiState(
              phase: WasteQuizPhase.active,
              scan: ScannedWaste.fromLabel('botol-kaca'),
              difficulty: QuizDifficulty.medium,
              questionIndex: 0,
              question: _testQuestion,
              voiceOn: false,
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(wasteQuizProvider.notifier);

      // Attempt nextQuestion before answering
      notifier.nextQuestion();

      // Phase should remain active at question 0
      final state = container.read(wasteQuizProvider);
      expect(state.phase, WasteQuizPhase.active);
      expect(state.questionIndex, 0);
    });

    test('loadExplanation populates currentExplanation and updates recordedQuestions', () async {
      final container = ProviderContainer(
        overrides: [
          wasteQuizProvider.overrideWith(
            () => _SeededQuiz(WasteQuizUiState(
              phase: WasteQuizPhase.explaining,
              scan: ScannedWaste.fromLabel('botol-kaca'),
              difficulty: QuizDifficulty.medium,
              questionIndex: 0,
              question: _testQuestion,
              selectedOption: 1,
              voiceOn: false,
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(wasteQuizProvider.notifier);

      await notifier.loadExplanation();

      final state = container.read(wasteQuizProvider);
      expect(state.currentExplanation, isNotNull);
      expect(state.explanationLoading, isFalse);
      expect(state.currentExplanation!.correctAnswerReason, isNotEmpty);
      expect(state.currentExplanation!.comparisonRows, isEmpty);
      expect(state.currentExplanation!.learningTakeaway, isEmpty);
    });

    test('submitEssay records essay and transitions phase to explaining with score', () async {
      final container = ProviderContainer(
        overrides: [
          wasteQuizProvider.overrideWith(
            () => _SeededQuiz(WasteQuizUiState(
              phase: WasteQuizPhase.active,
              scan: ScannedWaste.fromLabel('sisa-sayur'),
              difficulty: QuizDifficulty.easy,
              questionIndex: 0,
              question: _testEssayQuestion,
              voiceOn: false,
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(wasteQuizProvider.notifier);

      await notifier.submitEssay(
        'Sampah organik dapat dikomposkan untuk mengurangi gas metana.',
        score: 9,
      );

      final state = container.read(wasteQuizProvider);
      expect(state.phase, WasteQuizPhase.explaining);
      expect(state.essaySubmitted, isTrue);
      expect(state.recordedQuestions.length, 1);
      final recorded = state.recordedQuestions.first;
      expect(recorded.isEssay, isTrue);
      expect(recorded.essayScore, 9);
      expect(recorded.trophies, 9);
    });
  });
  test('draft bank explanation is not announced as a saved answer explanation', () async {
    final container = ProviderContainer(overrides: [wasteQuizProvider.overrideWith(() => _SeededQuiz(
      WasteQuizUiState(phase: WasteQuizPhase.active, scan: ScannedWaste.fromLabel('botol'), voiceOn: false,
        question: const GeneratedQuestion(type: QuizQuestionType.multipleChoice, question: 'Soal',
          options: ['Benar', 'Salah'], correctIndex: 0, bankId: 'draft', bankReviewed: false,
          explanation: 'DRAFT_TEXT_MUST_NOT_ANNOUNCE'))))]);
    addTearDown(container.dispose);
    container.read(wasteQuizProvider.notifier).selectOption(1);
    await pumpEventQueue();
    expect(container.read(wasteQuizProvider).messages.last.text, isNot(contains('DRAFT_TEXT_MUST_NOT_ANNOUNCE')));
    expect(container.read(wasteQuizProvider).currentExplanation!.correctAnswerReason, isEmpty);
  });

}
