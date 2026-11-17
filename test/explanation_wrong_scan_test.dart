// A new scan's explanations must not be saved into the previous scan's
// History record (decision 0225; found in the owner's data, 16 Nov).
import 'dart:typed_data';

import 'package:elio/models/quiz_explanation.dart';
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
  final explained = <String>[];
  @override
  bool get active => true;
  @override
  Future<void> addRecord(ScanRecord record) async => saved.add(record);
  @override
  Future<void> saveExplanation(
    String recordId,
    int questionIndex,
    QuizExplanation explanation,
  ) async => explained.add(recordId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;

  setUp(() async {
    await AiQuizService.instance.cancel();
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

  test('a photo scan after a finished scan leaves the old record alone', () async {
    AiQuizService.instance.mockSendExecute =
        (String prompt, {Uint8List? imageBytes, bool isUser = false}) async {
          if (imageBytes != null) {
            return '{"item":"ponsel","material":"logam, kaca","category":"B3"}';
          }
          if (prompt.contains('why_correct')) {
            return '{"correct_option":"x", "why_correct":"Alasan.", '
                '"why_wrong":"", "key_idea":"Ide.", "steps":[]}';
          }
          return null;
        };
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final quiz = c.read(wasteQuizProvider.notifier);
    WasteQuizUiState s() => c.read(wasteQuizProvider);
    Future<void> until(bool Function() ok) async {
      for (var i = 0; i < 150 && !ok(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    // Scan A, played to the end: its record is saved.
    quiz.startForLabel('botol plastik');
    await until(() => s().question != null);
    for (var i = 0; i < 10 && store.saved.isEmpty; i++) {
      if (s().phase == WasteQuizPhase.active) {
        quiz.selectOption(s().question!.correctIndex);
      }
      await pumpEventQueue();
      quiz.nextQuestion();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(store.saved, hasLength(1));
    final first = store.saved.single.id;
    quiz.dismiss();
    await pumpEventQueue();
    store.explained.clear();

    // Scan B from a photo: answer its first question and let it explain.
    quiz.onPhotoCaptured(Uint8List.fromList([1, 2, 3]));
    await until(() => s().phase == WasteQuizPhase.confirmingHazard);
    quiz.confirmHazard();
    await until(() => s().phase == WasteQuizPhase.active);
    expect(s().phase, WasteQuizPhase.active, reason: 'scan B reached a question');
    quiz.selectOption(0);
    await until(() => !s().explanationLoading);
    await pumpEventQueue();

    expect(
      store.explained,
      isNot(contains(first)),
      reason: 'scan B explained into scan A\'s record',
    );
  });
}
