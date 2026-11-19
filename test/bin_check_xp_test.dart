// Robot bin check (decision 0224): the right bin is worth 20 XP, once, and
// the XP is saved in the scan record; the fallback quiz skips its bin question.
import 'package:elio/models/scan_record.dart';
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:elio/services/scan_record_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store extends ScanRecordStore {
  final saved = <ScanRecord>[];
  @override
  bool get active => true;
  @override
  Future<void> addRecord(ScanRecord record) async => saved.add(record);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;

  setUp(() async {
    await AiQuizService.instance.cancel();
    AiQuizService.instance.mockSendExecute =
        (prompt, {imageBytes, isUser = false}) async => null;
    QuizTtsService.instance.mockSpeak = (_) async {};
    QuizTtsService.instance.mockStop = () async {};
    WasteQuizNotifier.sourceOverride = QuestionSource.bank;
    WasteQuizNotifier.essayQuestions = false;
    store = _Store();
    ScanRecordStore.setInstanceForTesting(store);
  });
  tearDown(() {
    AiQuizService.instance.mockSendExecute = null;
    QuizTtsService.instance.mockSpeak = null;
    QuizTtsService.instance.mockStop = null;
    WasteQuizNotifier.sourceOverride = null;
    WasteQuizNotifier.essayQuestions = essayQuestionsEnabled;
    ScanRecordStore.setInstanceForTesting(null);
  });

  /// Starts a plastic-bottle session, answers the bin check with [pick] and
  /// every question; returns the saved record.
  Future<ScanRecord> run(ScanCategory pick) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final quiz = c.read(wasteQuizProvider.notifier);
    quiz.startForLabel('botol plastik');
    for (var i = 0; i < 100 && c.read(wasteQuizProvider).question == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(c.read(wasteQuizProvider).binAnswer, ScanCategory.recyclable);
    quiz.answerBinCheck(pick);
    quiz.answerBinCheck(ScanCategory.recyclable); // a second pick is ignored
    quiz.ackBinCheck();
    for (var i = 0; i < 10 && store.saved.isEmpty; i++) {
      final s = c.read(wasteQuizProvider);
      if (s.phase == WasteQuizPhase.active) {
        quiz.selectOption(s.question!.correctIndex);
      }
      await pumpEventQueue();
      quiz.nextQuestion();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(store.saved, hasLength(1));
    return store.saved.single;
  }

  test('right bin: the record holds the questions\' XP plus 20', () async {
    final r = await run(ScanCategory.recyclable);
    final questions = r.questions.fold<int>(0, (sum, q) => sum + q.trophies);
    expect(questions, greaterThan(0));
    expect(r.trophies, questions + 20);
  });

  test('wrong bin: no extra XP', () async {
    final r = await run(ScanCategory.organic);
    expect(r.trophies, r.questions.fold<int>(0, (sum, q) => sum + q.trophies));
  });

  test('state: XP only for the right bin, none for a skip', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final quiz = c.read(wasteQuizProvider.notifier);
    quiz.skipBinCheck();
    expect(c.read(wasteQuizProvider).binCheckXp, 0);
    expect(c.read(wasteQuizProvider).binAcked, isTrue);
  });
}
