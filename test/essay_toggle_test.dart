// Profile → Essay questions (decision 0219): off = no essay question on any
// path (ELIOS AI and the question bank); on = the alternating MC / essay order.
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeededPrefs extends AppPreferencesNotifier {
  _SeededPrefs(this.seed);
  final AppPreferences seed;
  @override
  AppPreferences build() => seed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await AiQuizService.instance.cancel();
    WasteQuizNotifier.essayQuestions = null; // follow the setting
    await pumpEventQueue();
  });
  tearDown(() {
    AiQuizService.instance.mockSendExecute = null;
    WasteQuizNotifier.sourceOverride = null;
  });

  ProviderContainer container(bool essays) {
    final c = ProviderContainer(
      overrides: [
        appPreferencesProvider.overrideWith(
          () => _SeededPrefs(AppPreferences(essayQuestions: essays)),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the setting survives a save and load', () {
    const on = AppPreferences(essayQuestions: true);
    expect(AppPreferences.fromMap(on.toMap()).essayQuestions, isTrue);
    expect(
      AppPreferences.fromMap(on.copyWith(essayQuestions: false).toMap())
          .essayQuestions,
      isFalse,
    );
    expect(
      AppPreferences.fromMap(const {}).essayQuestions,
      essayQuestionsEnabled,
      reason: 'an older save keeps the build default',
    );
  });

  for (final essays in [false, true]) {
    test('ELIOS AI quiz, essays ${essays ? 'on' : 'off'}', () async {
      WasteQuizNotifier.sourceOverride = QuestionSource.ai;
      final prompts = <String>[];
      AiQuizService.instance.mockSendExecute =
          (prompt, {imageBytes, isUser = false}) async {
            if (prompt.contains('why_correct')) return null;
            prompts.add(prompt);
            return prompt.contains('pilihan ganda')
                ? '{"question": "Soal ${prompts.length}?", "correct": "A", "wrong": ["B","C","D"], "explanation": "e"}'
                : '{"question": "Soal ${prompts.length}?", "explanation": "e"}';
          };
      container(essays).read(wasteQuizProvider.notifier)
          .startForLabel('botol plastik');
      await pumpEventQueue();
      expect(prompts.length, 3, reason: 'question 1 + two prefetched');
      final essayPrompts = prompts.where((p) => p.contains('soal essay'));
      expect(essayPrompts.length, essays ? 1 : 0);
    });

    test('question bank quiz, essays ${essays ? 'on' : 'off'}', () async {
      WasteQuizNotifier.sourceOverride = QuestionSource.bank;
      AiQuizService.instance.mockSendExecute =
          (prompt, {imageBytes, isUser = false}) async => null;
      final c = container(essays);
      final quiz = c.read(wasteQuizProvider.notifier);
      quiz.startForLabel('botol plastik');
      // The bank loads from assets the first time.
      for (var i = 0; i < 50 && c.read(wasteQuizProvider).question == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final types = <QuizQuestionType?>[];
      for (var i = 0; i < 3; i++) {
        final q = c.read(wasteQuizProvider).question;
        types.add(q?.type);
        if (q?.type == QuizQuestionType.essay) {
          await quiz.submitEssay('Plastik didaur ulang agar tidak mencemari.');
        } else {
          quiz.selectOption(0);
        }
        await pumpEventQueue();
        quiz.nextQuestion();
        await pumpEventQueue();
      }
      expect(types, isNot(contains(null)));
      expect(
        types.where((t) => t == QuizQuestionType.essay).length,
        essays ? 1 : 0,
      );
    });
  }
}
