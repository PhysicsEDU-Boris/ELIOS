import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';

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
  explanation: 'Kaca adalah material anorganik yang dapat didaur ulang.',
);

const _testEssayQuestion = GeneratedQuestion(
  type: QuizQuestionType.essay,
  question: 'Jelaskan mengapa pemilahan sampah organik penting di tingkat rumah tangga.',
  explanation: 'Mencegah pembusukan anaerobik yang menghasilkan gas metana di TPA.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(state.currentExplanation!.comparisonRows, isNotEmpty);
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
}
