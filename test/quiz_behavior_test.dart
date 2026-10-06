import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeededQuiz extends WasteQuizNotifier {
  _SeededQuiz(this.seed);
  final WasteQuizUiState seed;
  @override
  WasteQuizUiState build() => seed;
}

class _SeededPrefs extends AppPreferencesNotifier {
  _SeededPrefs(this.seed);
  final AppPreferences seed;
  @override
  AppPreferences build() => seed;
}

const _mc = GeneratedQuestion(
  type: QuizQuestionType.multipleChoice,
  question: 'Apa bahaya utama dari membuang botol plastik ke lingkungan?',
  options: ['Penyumbatan drainase', 'Pelepasan zat kimia', 'Polusi laut', 'Suhu udara'],
  correctIndex: 2,
);

ProviderContainer _container({required bool skipAllowed, int questionIndex = 0}) {
  final c = ProviderContainer(overrides: [
    appPreferencesProvider.overrideWith(() => _SeededPrefs(AppPreferences(skipAllowed: skipAllowed))),
    wasteQuizProvider.overrideWith(() => _SeededQuiz(WasteQuizUiState(
          phase: WasteQuizPhase.active,
          scan: ScannedWaste.fromLabel('botol plastik'),
          difficulty: QuizDifficulty.easy,
          questionIndex: questionIndex,
          question: _mc,
          voiceOn: false,
        ))),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chat replies that come back as JSON are shown as plain text', () {
    const leaked = '{"hint": "Pikirkan tentang tempat penampungan sampah yang benar berdasarkan jenisnya.", '
        '"explanation": "Tempat pembuangan akhir yang tepat sangat penting."}';
    final text = GemmaQuizService.toPlainText(leaked);
    expect(text, contains('Pikirkan tentang tempat penampungan'));
    expect(text, isNot(contains('{')));
    expect(text, isNot(contains('"hint"')));
    expect(GemmaQuizService.toPlainText('```json\n{"a": "Halo"}\n```'), 'Halo');
    expect(GemmaQuizService.toPlainText('**Benar.** Kardus didaur ulang.'), 'Benar. Kardus didaur ulang.');
  });

  test('Indonesian replies are spoken with the Indonesian voice', () {
    expect(QuizTtsService.detectLanguage('Benar! Plastik dapat mencemari laut dan merusak ekosistem perairan.'), 'id-ID');
    expect(QuizTtsService.detectLanguage('Benar!'), 'id-ID');
    expect(QuizTtsService.detectLanguage('This is the correct answer because the plastic is recyclable.'), 'en-US');
    expect(QuizTtsService.speakableText('Benar! 🎉 **Plastik**'), 'Benar! Plastik');
  });

  test('difficulty setting maps to 1 / 3 / 5 questions', () {
    expect(QuizDifficulty.fromSetting('Easy').questionCount, 1);
    expect(QuizDifficulty.fromSetting('Medium').questionCount, 3);
    expect(QuizDifficulty.fromSetting('Hard').questionCount, 5);
    expect(QuizDifficulty.fromSetting('unknown'), QuizDifficulty.medium);
  });

  test('phones are e-waste (B3) even if the model says "anorganik"', () {
    expect(ScannedWaste.fromLabel('ponsel', categoryHint: 'anorganik').category?.id, 'hazardous');
    expect(ScannedWaste.fromLabel('kardus', categoryHint: 'anorganik').category?.id, 'inorganic');
    expect(ScannedWaste.fromLabel('kulit pisang', categoryHint: 'organik').category?.id, 'organic');
  });

  test('chat before answering asks the student to answer first', () async {
    final c = _container(skipAllowed: false);
    await c.read(wasteQuizProvider.notifier).sendChatMessage('lalu dibuang kemana?');
    final last = c.read(wasteQuizProvider).messages.last;
    expect(last.isUser, isFalse);
    expect(last.text, startsWith('Jawab soalnya dulu'));
  });

  test('skip works only when "Skip Allowed" is on', () {
    final off = _container(skipAllowed: false);
    off.read(wasteQuizProvider.notifier).skipQuestion();
    expect(off.read(wasteQuizProvider).phase, WasteQuizPhase.active);

    // Easy = 1 question, so skipping the only question finishes the session.
    final on = _container(skipAllowed: true);
    on.read(wasteQuizProvider.notifier).skipQuestion();
    expect(on.read(wasteQuizProvider).phase, WasteQuizPhase.finished);
    expect(on.read(wasteQuizProvider).skippedCount, 1);
  });
}
