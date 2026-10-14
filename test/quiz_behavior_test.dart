import 'dart:async';
import 'dart:typed_data';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:fake_async/fake_async.dart';
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

  group('GemmaQuizService single flight slot logic', () {
    late GemmaQuizService service;
    
    setUp(() {
      service = GemmaQuizService.instance;
      service.cancel();
    });

    test('scan request rejected while busy', () async {
      final completer1 = Completer<String?>();
      service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) => completer1.future;

      final f1 = service.identifyItem(Uint8List(0));
      
      final res2 = await service.identifyItem(Uint8List(0));
      expect(res2.failure, 'busy');
      
      completer1.complete('{"item": "botol", "material": "plastik", "category": "anorganik"}');
      final res1 = await f1;
      expect(res1.item, 'botol');
    });

    test('user request cancels a running scan request', () async {
      final completer1 = Completer<String?>();
      final completer2 = Completer<String?>();
      var call = 0;
      service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) {
        call++;
        return call == 1 ? completer1.future : completer2.future;
      };

      final f1 = service.identifyItem(Uint8List(0));
      final f2 = service.discuss(quizContext: 'ctx', history: [], message: 'hi');
      
      final res1 = await f1;
      expect(res1.item, isNull);
      
      completer2.complete('reply');
      final res2 = await f2;
      expect(res2, 'reply');
    });

    test('stale result discarded after dismiss', () async {
      final completer = Completer<String?>();
      service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) => completer.future;

      final f1 = service.identifyItem(Uint8List(0));
      service.cancel();
      
      completer.complete('{"item": "botol"}');
      
      final res1 = await f1;
      expect(res1.item, isNull);
    });
    
    test('slot released after cancel/timeout/exception', () async {
      final completer1 = Completer<String?>();
      service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) => completer1.future;
      final f1 = service.identifyItem(Uint8List(0));
      service.cancel();
      await f1;
      
      final completer2 = Completer<String?>();
      service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) => completer2.future;
      final f2 = service.identifyItem(Uint8List(0));
      completer2.complete('{"item": "kertas", "material": "kertas", "category": "organik"}');
      final res2 = await f2;
      expect(res2.item, 'kertas');
    });

    test('cancel() awaits stopGeneration, and a throwing one does not escape', () async {
      final stopCompleter = Completer<void>();
      var stopCalled = 0;
      service.mockStopGeneration = () {
        stopCalled++;
        return stopCompleter.future;
      };
      service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) => Completer<String?>().future;
      final f1 = service.identifyItem(Uint8List(0));

      var cancelDone = false;
      final cancelFuture = service.cancel().then((_) => cancelDone = true);
      await Future<void>.delayed(Duration.zero); // let the mock get called
      expect(stopCalled, 1);
      expect(cancelDone, isFalse, reason: 'cancel() should still be awaiting stopGeneration');

      stopCompleter.completeError(StateError('native stop failed')); // the throwing case
      await cancelFuture; // must not throw despite the error
      expect(cancelDone, isTrue);

      final res1 = await f1;
      expect(res1.item, isNull);
      service.mockStopGeneration = null;
    });

    test('cancel() releases the active caller well before a slow native stop settles, '
        'and _stopGeneration itself is capped at 2 s', () {
      fakeAsync((async) {
        final genCompleter = Completer<String?>();
        service.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) => genCompleter.future;
        var stopCalled = 0;
        service.mockStopGeneration = () {
          stopCalled++;
          return Future<void>.delayed(const Duration(seconds: 5)); // "native" never returns quickly
        };

        PhotoIdentification? result;
        service.identifyItem(Uint8List(0)).then((r) => result = r);
        async.flushMicrotasks();
        expect(result, isNull, reason: 'still generating');

        var cancelSettled = false;
        service.cancel().then((_) => cancelSettled = true);

        async.elapse(const Duration(milliseconds: 50)); // well under 100 ms, on the fake clock
        expect(stopCalled, 1);
        expect(result, isNotNull, reason: 'the active caller must not be held up by the 5 s stop');
        expect(result!.item, isNull);
        expect(cancelSettled, isFalse, reason: 'cancel() itself is still awaiting the capped stop');

        async.elapse(const Duration(seconds: 2)); // the cap in _stopGeneration
        expect(cancelSettled, isTrue, reason: '_stopGeneration must give up at 2 s, not wait the full 5 s');

        service.mockStopGeneration = null;
      });
    });

  });

  group('TTS: one slot, no repeat for the same text, closing stops it', () {
    setUp(() {
      QuizTtsService.instance.mockSpeak = null;
      QuizTtsService.instance.mockStop = null;
    });
    tearDown(() {
      QuizTtsService.instance.mockSpeak = null;
      QuizTtsService.instance.mockStop = null;
    });

    test('a new utterance stops the old one first (not queued)', () async {
      final spoken = <String>[];
      final stopCalls = <int>[];
      QuizTtsService.instance.mockStop = () async => stopCalls.add(spoken.length);
      QuizTtsService.instance.mockSpeak = (text) async => spoken.add(text);

      final before = QuizTtsService.instance.startedCount;
      await QuizTtsService.instance.speak('pertama');
      await QuizTtsService.instance.speak('kedua');

      expect(spoken, ['pertama', 'kedua']); // both went through, not queued behind each other
      expect(stopCalls.length, 2); // stop() ran before each speak
      expect(QuizTtsService.instance.startedCount, before + 2);
    });

    test('the same auto-spoken text is not repeated within a quiz (rebuild-safe)', () async {
      final spoken = <String>[];
      QuizTtsService.instance.mockSpeak = (text) async => spoken.add(text);

      final container = _container(skipAllowed: false);
      final notifier = container.read(wasteQuizProvider.notifier);
      // Need voiceOn: true to exercise auto-speak; _container seeds it off.
      container.read(wasteQuizProvider.notifier).toggleVoice();

      // Before the question is answered, every chat message gets the exact
      // same "answer first" reply — the scenario the popup rebuilding (or
      // minimizing/restoring) could otherwise cause to speak twice.
      await notifier.sendChatMessage('apa ini?');
      await pumpEventQueue(); // _appendAiReply's speak() is unawaited
      await notifier.sendChatMessage('tolong jelaskan');
      await pumpEventQueue();

      expect(spoken, hasLength(1), reason: 'identical text spoken only once per quiz');
      expect(spoken.single, startsWith('Jawab soalnya dulu'));
    });

    test('a genuinely different reply is still spoken', () async {
      final spoken = <String>[];
      QuizTtsService.instance.mockSpeak = (text) async => spoken.add(text);
      final container = _container(skipAllowed: true, questionIndex: 0);
      container.read(wasteQuizProvider.notifier).toggleVoice();
      container.read(wasteQuizProvider.notifier).skipQuestion(); // finishes (Easy = 1 question): a different message
      await pumpEventQueue(); // _appendAiReply's speak() is unawaited

      expect(spoken, hasLength(1));
      expect(spoken.single, contains('Sesi selesai'));
    });

    test('closing the quiz stops speech', () async {
      var stopCalled = 0;
      QuizTtsService.instance.mockStop = () async => stopCalled++;
      final container = _container(skipAllowed: false);
      container.read(wasteQuizProvider.notifier).dismiss();
      expect(stopCalled, 1);
    });
  });
}
