import 'dart:async';
import 'dart:typed_data';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/l10n/l10n.dart';

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
    final text = AiQuizService.toPlainText(leaked);
    expect(text, contains('Pikirkan tentang tempat penampungan'));
    expect(text, isNot(contains('{')));
    expect(text, isNot(contains('"hint"')));
    expect(AiQuizService.toPlainText('```json\n{"a": "Halo"}\n```'), 'Halo');
    expect(AiQuizService.toPlainText('**Benar.** Kardus didaur ulang.'), 'Benar. Kardus didaur ulang.');
  });

  test('the TTS voice follows the app language, or the text language when given', () {
    debugSetL10n(const Locale('id'));
    expect(QuizTtsService.voiceFor(), 'id-ID');
    debugSetL10n(const Locale('en'));
    expect(QuizTtsService.voiceFor(), 'en-US');
    expect(QuizTtsService.voiceFor('id'), 'id-ID');
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
    expect(last.text, startsWith('Answer the question first'));
  });

  test('skip works only when "Skip Allowed" is on', () async {
    final off = _container(skipAllowed: false);
    off.read(wasteQuizProvider.notifier).skipQuestion();
    expect(off.read(wasteQuizProvider).phase, WasteQuizPhase.active);

    // Easy = 1 question, so skipping the only question finishes the session.
    final on = _container(skipAllowed: true);
    on.read(wasteQuizProvider.notifier).skipQuestion();
    await pumpEventQueue();
    expect(on.read(wasteQuizProvider).phase, WasteQuizPhase.finished);
    expect(on.read(wasteQuizProvider).skippedCount, 1);
  });

  group('AiQuizService single flight slot logic', () {
    late AiQuizService service;
    
    setUp(() {
      service = AiQuizService.instance;
      service.cancel();
    });

    test('scan request rejected while busy', () async {
      final completer1 = Completer<String?>();
      service.mockSendExecute = (prompt, {imageBytes, isUser = false}) => completer1.future;

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
      service.mockSendExecute = (prompt, {imageBytes, isUser = false}) {
        call++;
        return call == 1 ? completer1.future : completer2.future;
      };

      final f1 = service.identifyItem(Uint8List(0));
      await pumpEventQueue(); // the scan is running (submitted) before the user asks
      expect(call, 1);
      final f2 = service.discuss(quizContext: 'ctx', history: [], message: 'hi');
      
      final res1 = await f1;
      expect(res1.item, isNull);
      completer1.complete(null); // the cancelled call's late reply is dropped

      completer2.complete('reply');
      final res2 = await f2;
      expect(res2, 'reply');
    });

    test('stale result discarded after dismiss', () async {
      final completer = Completer<String?>();
      service.mockSendExecute = (prompt, {imageBytes, isUser = false}) => completer.future;

      final f1 = service.identifyItem(Uint8List(0));
      service.cancel();
      
      completer.complete('{"item": "botol"}');
      
      final res1 = await f1;
      expect(res1.item, isNull);
    });
    
    test('slot released after cancel/timeout/exception', () async {
      final completer1 = Completer<String?>();
      service.mockSendExecute = (prompt, {imageBytes, isUser = false}) => completer1.future;
      final f1 = service.identifyItem(Uint8List(0));
      service.cancel();
      await f1;
      completer1.complete(null); // the cancelled call's late reply is dropped
      await pumpEventQueue();

      final completer2 = Completer<String?>();
      service.mockSendExecute = (prompt, {imageBytes, isUser = false}) => completer2.future;
      final f2 = service.identifyItem(Uint8List(0));
      completer2.complete('{"item": "kertas", "material": "kertas", "category": "organik"}');
      final res2 = await f2;
      expect(res2.item, 'kertas');
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
      expect(spoken.single, startsWith('Answer the question first'));
    });

    test('a genuinely different reply is still spoken', () async {
      final spoken = <String>[];
      QuizTtsService.instance.mockSpeak = (text) async => spoken.add(text);
      final container = _container(skipAllowed: true, questionIndex: 0);
      container.read(wasteQuizProvider.notifier).toggleVoice();
      container.read(wasteQuizProvider.notifier).skipQuestion(); // finishes (Easy = 1 question): a different message
      await pumpEventQueue(); // _appendAiReply's speak() is unawaited

      expect(spoken, hasLength(1));
      expect(spoken.single, contains('Session done'));
    });

    test('closing the quiz stops speech', () async {
      var stopCalled = 0;
      QuizTtsService.instance.mockStop = () async => stopCalled++;
      final container = _container(skipAllowed: false);
      container.read(wasteQuizProvider.notifier).dismiss();
      expect(stopCalled, 1);
    });

    test('"Soal berikutnya" stops speech immediately, before the new question shows', () async {
      var stopCalled = 0;
      QuizTtsService.instance.mockStop = () async => stopCalled++;
      final container = ProviderContainer(overrides: [
        appPreferencesProvider.overrideWith(() => _SeededPrefs(const AppPreferences(skipAllowed: false))),
        wasteQuizProvider.overrideWith(() => _SeededQuiz(WasteQuizUiState(
              phase: WasteQuizPhase.explaining,
              scan: ScannedWaste.fromLabel('botol plastik'),
              difficulty: QuizDifficulty.medium, // 3 questions: not the last one yet
              questionIndex: 0,
              question: _mc,
              selectedOption: _mc.correctIndex, // answered
              voiceOn: false,
            ))),
      ]);
      addTearDown(container.dispose);

      container.read(wasteQuizProvider.notifier).nextQuestion();
      await pumpEventQueue();

      expect(stopCalled, greaterThanOrEqualTo(1),
          reason: 'the previous question\'s voice must not keep playing over the new question');
      expect(container.read(wasteQuizProvider).questionIndex, 1, reason: 'the stop call must not block advancing');
    });

    test('skipping a question stops speech immediately', () async {
      var stopCalled = 0;
      QuizTtsService.instance.mockStop = () async => stopCalled++;
      final container = ProviderContainer(overrides: [
        appPreferencesProvider.overrideWith(() => _SeededPrefs(const AppPreferences(skipAllowed: true))),
        wasteQuizProvider.overrideWith(() => _SeededQuiz(WasteQuizUiState(
              phase: WasteQuizPhase.active,
              scan: ScannedWaste.fromLabel('botol plastik'),
              difficulty: QuizDifficulty.medium,
              questionIndex: 0,
              question: _mc,
              voiceOn: false,
            ))),
      ]);
      addTearDown(container.dispose);

      container.read(wasteQuizProvider.notifier).skipQuestion();
      await pumpEventQueue();

      expect(stopCalled, greaterThanOrEqualTo(1));
      expect(container.read(wasteQuizProvider).questionIndex, 1);
    });

    test('a stop call when nothing is speaking changes nothing else', () async {
      var stopCalled = 0;
      QuizTtsService.instance.mockStop = () async => stopCalled++;
      final container = _container(skipAllowed: false, questionIndex: 0);

      container.read(wasteQuizProvider.notifier).dismiss(); // nothing was ever spoken in this test
      await pumpEventQueue();

      expect(stopCalled, 1, reason: 'stop() is still called, but safely -- no speak() ever happened');
      expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.idle);
    });
  });

  group('M2b part 3: background quiz prefetch (decision 0011)', () {
    setUp(() async {
      // AiQuizService.instance is a process-wide singleton: flush any
      // leftover active/pending request from a previous test before this
      // one starts, so it never sees the slot as busy.
      await AiQuizService.instance.cancel();
      AiQuizService.instance.mockSendExecute = null;
      // Prefetch is the opt-in Gemma question path (decision 0017 keeps it, off by default).
      WasteQuizNotifier.sourceOverride = QuestionSource.ai;
      WasteQuizNotifier.essayQuestions = true;
      await pumpEventQueue();
    });
    tearDown(() {
      AiQuizService.instance.mockSendExecute = null;
      WasteQuizNotifier.sourceOverride = null;
      WasteQuizNotifier.essayQuestions = essayQuestionsEnabled;
    });

    const mcJson = '{"question": "Soal ke-1?", "correct": "A", "wrong": ["B","C","D"], '
        ' "explanation": "e"}';

    String fakeResponse(int n, String prompt) => prompt.contains('pilihan ganda')
        ? '{"question": "Soal ke-$n?", "correct": "A", "wrong": ["B","C","D"], "explanation": "e"}'
        : '{"question": "Soal ke-$n?", "explanation": "e"}';

    ProviderContainer mediumContainer() {
      final c = ProviderContainer(overrides: [
        appPreferencesProvider
            .overrideWith(() => _SeededPrefs(const AppPreferences(quizDifficulty: 'Medium'))),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('background prefetch fills questions 2 and 3 in order after question 1 shows', () async {
      var calls = 0;
      final prompts = <String>[];
      AiQuizService.instance.mockSendExecute = (prompt, {imageBytes, isUser = false}) async {
        if (prompt.contains('why_correct')) return '{"correct_option":"Daur ulang", "why_correct":"Alasan AI.", "why_wrong":"", "key_idea":"Ide AI.", "steps":[]}';
        calls++;
        prompts.add(prompt);
        return fakeResponse(calls, prompt);
      };

      final container = mediumContainer();
      container.read(wasteQuizProvider.notifier).startForLabel('botol plastik');
      await pumpEventQueue();

      expect(container.read(wasteQuizProvider).question?.question, 'Soal ke-1?');
      expect(calls, 3, reason: 'question 1 (foreground) + questions 2, 3 (background) all generated');
      expect(prompts[1], contains('Soal ke-1?'), reason: 'question 2 avoids question 1 (sequential, not parallel)');
      expect(prompts[2], contains('Soal ke-2?'), reason: 'question 3 avoids question 2 too');
    });

    test('"Soal berikutnya" takes an already-buffered question instantly, no new generation', () async {
      var calls = 0;
      AiQuizService.instance.mockSendExecute = (prompt, {imageBytes, isUser = false}) async {
        if (prompt.contains('why_correct')) return '{"correct_option":"Daur ulang", "why_correct":"Alasan AI.", "why_wrong":"", "key_idea":"Ide AI.", "steps":[]}';
        calls++;
        return fakeResponse(calls, prompt);
      };

      final container = mediumContainer();
      final notifier = container.read(wasteQuizProvider.notifier);
      notifier.startForLabel('botol plastik');
      await pumpEventQueue(); // question 1 shown, questions 2 and 3 prefetched

      final callsBeforeTap = calls;
      notifier.selectOption(0); // answers question 1 (multiple choice)
      notifier.nextQuestion();
      await pumpEventQueue();

      expect(container.read(wasteQuizProvider).questionIndex, 1);
      expect(container.read(wasteQuizProvider).question?.question, 'Soal ke-2?');
      expect(calls, callsBeforeTap, reason: 'served straight from the buffer, no new generation call');
      expect(notifier.lastNextWaitMs, lessThan(20), reason: 'instant from the buffer');
    });

    test('a tap before the buffer is ready waits, then shows the question (never a fallback)', () async {
      var calls = 0;
      final pending = Completer<String?>();
      AiQuizService.instance.mockSendExecute = (prompt, {imageBytes, isUser = false}) async {
        if (prompt.contains('why_correct')) return '{"correct_option":"Daur ulang", "why_correct":"Alasan AI.", "why_wrong":"", "key_idea":"Ide AI.", "steps":[]}';
        calls++;
        if (calls == 1) return mcJson; // question 1 resolves right away
        return pending.future; // question 2's background generation hangs
      };

      final container = mediumContainer();
      final notifier = container.read(wasteQuizProvider.notifier);
      notifier.startForLabel('botol plastik');
      await pumpEventQueue();
      expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.active);

      notifier.selectOption(0);
      notifier.nextQuestion();
      await pumpEventQueue();
      expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.loadingQuestion,
          reason: 'not ready yet: show the waiting state, not a fallback');
      expect(container.read(wasteQuizProvider).questionIndex, 1);

      pending.complete('{"question": "Soal ke-2?", "explanation": "e"}');
      await pumpEventQueue();

      expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.active);
      expect(container.read(wasteQuizProvider).question?.question, 'Soal ke-2?');
      expect(container.read(wasteQuizProvider).isFallback, isFalse);
    });

    test('a chat message pauses prefetch, which resumes after -- never a fallback', () {
      fakeAsync((async) {
        var calls = 0;
        final completers = <Completer<String?>>[];
        AiQuizService.instance.mockSendExecute = (prompt, {imageBytes, isUser = false}) {
          if (prompt.contains('why_correct')) return Future.value('{"correct_option":"Daur ulang", "why_correct":"Alasan AI.", "why_wrong":"", "key_idea":"Ide AI.", "steps":[]}');
          calls++;
          final c = Completer<String?>();
          completers.add(c);
          return c.future;
        };

        final container = mediumContainer();
        final notifier = container.read(wasteQuizProvider.notifier)..toggleVoice(); // no TTS

        notifier.startForLabel('botol plastik'); // call 1: question 1
        async.flushMicrotasks();
        expect(calls, 1);
        completers[0].complete(mcJson);
        async.flushMicrotasks();
        expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.active);
        expect(calls, 2, reason: 'prefetch for question 2 (essay) starts right away');

        notifier.selectOption(0); // answers question 1, synchronous
        notifier.sendChatMessage('apa ini?'); // call 3 (isUser) cancels call 2 (prefetch)
        async.flushMicrotasks();
        expect(calls, 3, reason: 'the chat runs at once: a cancelled cloud call holds nothing');
        completers[1].complete(null); // the cancelled prefetch reply arrives late and is dropped
        async.flushMicrotasks();

        completers[2].complete('balasan obrolan'); // the chat's own reply
        async.flushMicrotasks();
        expect(container.read(wasteQuizProvider).messages.last.text, 'balasan obrolan');

        async.elapse(const Duration(milliseconds: 300)); // the prefetch retry delay
        expect(calls, 4, reason: 'prefetch retried question 2 once the slot was free again');
        completers[3].complete('{"question": "Soal ke-2?", "explanation": "e"}');
        async.flushMicrotasks();

        notifier.nextQuestion();
        async.flushMicrotasks();
        expect(container.read(wasteQuizProvider).question?.question, 'Soal ke-2?');
        expect(container.read(wasteQuizProvider).isFallback, isFalse,
            reason: 'a chat message must never turn a question into a fallback');

        // Medium has a 3rd question: resolving question 2 just above kicks
        // off its own background prefetch (call 5, never scripted here).
        // Settle it so the singleton AiQuizService isn't left mid-request
        // for the next test.
        notifier.dismiss();
        for (final c in completers) {
          if (!c.isCompleted) c.complete(null); // end every call so the slot frees
        }
        async.flushMicrotasks();
      });
    });

    test('closing the quiz cancels prefetch and clears the buffer', () {
      fakeAsync((async) {
        var calls = 0;
        final completers = <Completer<String?>>[];
        AiQuizService.instance.mockSendExecute = (prompt, {imageBytes, isUser = false}) {
          if (prompt.contains('why_correct')) return Future.value('{"correct_option":"Daur ulang", "why_correct":"Alasan AI.", "why_wrong":"", "key_idea":"Ide AI.", "steps":[]}');
          calls++;
          final c = Completer<String?>();
          completers.add(c);
          return c.future;
        };

        final container = mediumContainer();
        final notifier = container.read(wasteQuizProvider.notifier);
        notifier.startForLabel('botol plastik');
        async.flushMicrotasks();
        completers[0].complete(mcJson);
        async.flushMicrotasks();
        expect(calls, 2, reason: 'prefetch for question 2 started');

        notifier.dismiss();
        completers[1].complete('{"question": "Soal ke-2?", "explanation": "e"}'); // the cancelled call resolves late
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.idle,
            reason: 'dismiss must stick even if the stale prefetch resolves late');
        expect(calls, 2, reason: 'no retry after close: the buffer is cancelled, not kept alive');
      });
    });

    test('a near-identical question is rejected and retried', () async {
      var calls = 0;
      AiQuizService.instance.mockSendExecute = (prompt, {imageBytes, isUser = false}) async {
        if (prompt.contains('why_correct')) return '{"correct_option":"Daur ulang", "why_correct":"Alasan AI.", "why_wrong":"", "key_idea":"Ide AI.", "steps":[]}';
        calls++;
        return calls == 1
            ? '{"question": "Apa dampak plastik?", "explanation": "e"}' // near-duplicate of avoid[0]
            : '{"question": "Bagaimana proses daur ulang logam?", "explanation": "e"}';
      };

      final result = await AiQuizService.instance.generateQuestionBackground(
        waste: ScannedWaste.fromLabel('botol plastik'),
        type: QuizQuestionType.essay,
        difficulty: QuizDifficulty.easy,
        avoid: const ['apa dampak plastik?'],
      );

      expect(calls, 2, reason: 'the near-duplicate on attempt 1 is rejected; attempt 2 is accepted');
      expect(result.retry, isFalse);
      expect(result.question?.question, 'Bagaimana proses daur ulang logam?');
    });

    test('an unparseable response is retried once in the background', () async {
      var calls = 0;
      AiQuizService.instance.mockSendExecute = (prompt, {imageBytes, isUser = false}) async {
        if (prompt.contains('why_correct')) return '{"correct_option":"Daur ulang", "why_correct":"Alasan AI.", "why_wrong":"", "key_idea":"Ide AI.", "steps":[]}';
        calls++;
        return calls == 1 ? 'not json at all' : '{"question": "Soal valid?", "explanation": "e"}';
      };

      final result = await AiQuizService.instance.generateQuestionBackground(
        waste: ScannedWaste.fromLabel('kardus'),
        type: QuizQuestionType.essay,
        difficulty: QuizDifficulty.easy,
      );

      expect(calls, 2);
      expect(result.retry, isFalse);
      expect(result.question?.question, 'Soal valid?');
    });
  });
}
