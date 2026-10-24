// Question source switch (decision 0018): bank vs Gemma, chosen per session.
import 'dart:async';

import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/widgets/waste_quiz_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _isQuestionRequest(String prompt) => prompt.contains('Buat SATU soal');

String _mcReply(String question) =>
    '{"question": "$question", "correct": "B3", "wrong": ["Organik", "Kertas", "Kaca"], "explanation": "e"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults and release builds resolve to the bank', () {
    expect(defaultQuestionSource, QuestionSource.bank, reason: 'no GEMMA_QUESTIONS define in tests');
    expect(const AppPreferences().questionSource, QuestionSource.bank);
    expect(effectiveQuestionSource(QuestionSource.gemma, debug: true), QuestionSource.gemma);
    expect(effectiveQuestionSource(QuestionSource.gemma, debug: false), QuestionSource.bank,
        reason: 'release always uses the bank, whatever the switch says');
    expect(AppPreferences.fromMap({'questionSource': 'gemma'}).questionSource, QuestionSource.bank,
        reason: 'a value saved by an older build is ignored');
    expect(const AppPreferences(questionSource: QuestionSource.gemma).toMap(), isNot(contains('questionSource')),
        reason: 'the switch is never saved');
  });

  test('a launch after a debug session left the switch on Gemma starts on the bank (24 Oct)', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.app_preferences_v1': '{"quizDifficulty": "Hard", "questionSource": "gemma"}',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appPreferencesProvider);
    for (var i = 0; i < 10 && container.read(appPreferencesProvider).quizDifficulty != 'Hard'; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(container.read(appPreferencesProvider).quizDifficulty, 'Hard', reason: 'the saved preferences loaded');
    expect(container.read(appPreferencesProvider).questionSource, QuestionSource.bank);
  });

  test('the header names the source of the shown question', () {
    const gemmaQ = GeneratedQuestion(type: QuizQuestionType.multipleChoice, question: 'q', options: ['a', 'b', 'c', 'd']);
    const bankQ = GeneratedQuestion(type: QuizQuestionType.multipleChoice, question: 'q', bankId: 'ponsel-mc-01');
    expect(questionSourceHeader(const WasteQuizUiState(question: bankQ)), 'SOAL DARI MODUL · BANK SOAL');
    expect(questionSourceHeader(const WasteQuizUiState(question: gemmaQ, questionSource: QuestionSource.gemma)),
        'SOAL GEMMA');
    expect(questionSourceHeader(const WasteQuizUiState(question: gemmaQ, isFallback: true)),
        'SOAL UMUM (BENDA BELUM ADA DI BANK SOAL)');
    expect(questionSourceHeader(const WasteQuizUiState(question: gemmaQ, isFallback: true, questionSource: QuestionSource.gemma)),
        'SOAL CADANGAN (AI ON-DEVICE BELUM SIAP)');
  });

  group('sessions follow the switch', () {
    late List<String> questionPrompts;
    late Future<String?> Function(String prompt) reply;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await GemmaQuizService.instance.cancel();
      questionPrompts = [];
      reply = (prompt) async => _mcReply('Soal Gemma ${questionPrompts.length}?');
      GemmaQuizService.instance.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) {
        if (_isQuestionRequest(prompt)) questionPrompts.add(prompt);
        return reply(prompt);
      };
      WasteQuizNotifier.sourceOverride = null; // the real switch decides
      WasteQuizNotifier.essayQuestions = false;
      await pumpEventQueue();
    });
    tearDown(() async {
      GemmaQuizService.instance.mockSendExecute = null;
      WasteQuizNotifier.essayQuestions = essayQuestionsEnabled;
      await GemmaQuizService.instance.cancel();
    });

    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(appPreferencesProvider.notifier).update((p) => p.copyWith(quizDifficulty: 'Medium', skipAllowed: true));
      return c;
    }

    void choose(ProviderContainer c, QuestionSource s) =>
        c.read(appPreferencesProvider.notifier).update((p) => p.copyWith(questionSource: s));

    Future<void> settle(ProviderContainer c) async {
      for (var i = 0; i < 200 && c.read(wasteQuizProvider).phase == WasteQuizPhase.loadingQuestion; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('gemma: the question prompt reaches Gemma and its question shows as "SOAL GEMMA"', () async {
      final c = container();
      choose(c, QuestionSource.gemma);
      c.read(wasteQuizProvider.notifier).startForLabel('botol plastik');
      await settle(c);
      final s = c.read(wasteQuizProvider);
      expect(questionPrompts, isNotEmpty);
      expect(s.question?.question, 'Soal Gemma 1?');
      expect(s.question?.bankId, isNull);
      expect(questionSourceHeader(s), 'SOAL GEMMA');
    });

    test('gemma: a failed or timed-out reply gives the fixed fallback, never the bank', () async {
      reply = (prompt) async => _isQuestionRequest(prompt) ? null : 'ok'; // null = failed / timed out
      final c = container();
      choose(c, QuestionSource.gemma);
      c.read(wasteQuizProvider.notifier).startForLabel('botol plastik');
      await settle(c);
      final s = c.read(wasteQuizProvider);
      expect(questionPrompts, isNotEmpty);
      expect(s.isFallback, isTrue);
      expect(s.question?.bankId, isNull, reason: 'not silently swapped for a bank question');
      final fixed = WasteQuizNotifier.fallbackQuestions(s.scan!, QuizQuestionType.multipleChoice).map((q) => q.question);
      expect(fixed, contains(s.question?.question));
      expect(questionSourceHeader(s), 'SOAL CADANGAN (AI ON-DEVICE BELUM SIAP)');
    });

    test('bank -> gemma -> bank across scans, and a stale prefetch is never shown', () async {
      final c = container();
      final quiz = c.read(wasteQuizProvider.notifier);

      // 1. bank: no question request to Gemma.
      quiz.startForLabel('botol plastik');
      await settle(c);
      expect(c.read(wasteQuizProvider).question?.bankId, 'botol_plastik-mc-01');
      expect(questionPrompts, isEmpty);
      quiz.dismiss();

      // 2. gemma: question 1 from Gemma; question 2's prefetch hangs.
      final stale = Completer<String?>();
      reply = (prompt) async => !_isQuestionRequest(prompt)
          ? 'ok'
          : questionPrompts.length == 1
              ? _mcReply('Soal Gemma pertama?')
              : stale.future;
      choose(c, QuestionSource.gemma);
      quiz.startForLabel('botol plastik');
      await settle(c);
      expect(c.read(wasteQuizProvider).question?.question, 'Soal Gemma pertama?');
      expect(questionPrompts.length, greaterThanOrEqualTo(2), reason: 'prefetch for question 2 started');
      quiz.dismiss();

      // 3. back to bank: the stale Gemma prefetch finishes but never shows.
      choose(c, QuestionSource.bank);
      final promptsBefore = questionPrompts.length;
      quiz.startForLabel('botol plastik');
      await settle(c);
      stale.complete(_mcReply('Soal Gemma basi?'));
      await pumpEventQueue();
      final shown = <String?>[c.read(wasteQuizProvider).question?.bankId];
      quiz.skipQuestion();
      await settle(c);
      shown.add(c.read(wasteQuizProvider).question?.bankId);
      expect(shown, ['botol_plastik-mc-01', 'botol_plastik-mc-02']);
      expect(c.read(wasteQuizProvider).question?.question, isNot('Soal Gemma basi?'));
      expect(questionPrompts.length, promptsBefore, reason: 'no Gemma question work in a bank session');
    });

    test('switching mid-session changes the next scan only', () async {
      final c = container();
      final quiz = c.read(wasteQuizProvider.notifier);
      quiz.startForLabel('kardus');
      await settle(c);
      choose(c, QuestionSource.gemma); // during a bank session
      quiz.skipQuestion();
      await settle(c);
      expect(c.read(wasteQuizProvider).question?.bankId, 'kardus-mc-02');
      expect(questionPrompts, isEmpty, reason: 'switching must not start Gemma work in a bank session');
    });
  });
}
