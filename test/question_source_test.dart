// Question source switch (decisions 0018, 0179): bank vs ELIOS AI, chosen per session.
import 'dart:async';

import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/widgets/waste_quiz_popup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _isQuestionRequest(String prompt) => prompt.contains('Buat SATU soal');

String _mcReply(String question) =>
    '{"question": "$question", "correct": "B3", "wrong": ["Organik", "Kertas", "Kaca"], "explanation": "e"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the default is ELIOS AI; a saved choice is kept (decisions 0145, 0179)', () {
    expect(const AppPreferences().questionSource, QuestionSource.ai);
    expect(AppPreferences.fromMap({'questionSource': 'bank'}).questionSource, QuestionSource.bank);
    // A choice saved before 0179 ("gemma") or a bad value becomes the default.
    expect(AppPreferences.fromMap({'questionSource': 'gemma'}).questionSource, QuestionSource.ai);
    expect(AppPreferences.fromMap({'questionSource': 'nonsense'}).questionSource, QuestionSource.ai);
    expect(const AppPreferences(questionSource: QuestionSource.ai).toMap()['questionSource'], 'ai');
  });

  test('the saved Config choice survives a restart (decision 0145)', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.app_preferences_v1': '{"quizDifficulty": "Hard", "questionSource": "bank"}',
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
    expect(questionSourceHeader(const WasteQuizUiState(question: gemmaQ, questionSource: QuestionSource.ai)),
        'SOAL ELIOS AI');
    expect(questionSourceHeader(const WasteQuizUiState(question: gemmaQ, isFallback: true)),
        'SOAL UMUM (BENDA BELUM ADA DI BANK SOAL)');
    expect(questionSourceHeader(const WasteQuizUiState(question: gemmaQ, isFallback: true, questionSource: QuestionSource.ai)),
        'SOAL CADANGAN (ELIOS AI TIDAK TERSAMBUNG)');
  });

  group('sessions follow the switch', () {
    late List<String> questionPrompts;
    late Future<String?> Function(String prompt) reply;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AiQuizService.instance.cancel();
      questionPrompts = [];
      reply = (prompt) async => _mcReply('Soal Gemma ${questionPrompts.length}?');
      AiQuizService.instance.mockSendExecute = (prompt, {imageBytes, isUser = false}) {
        if (_isQuestionRequest(prompt)) questionPrompts.add(prompt);
        return reply(prompt);
      };
      WasteQuizNotifier.sourceOverride = null; // the real switch decides
      WasteQuizNotifier.essayQuestions = false;
      await pumpEventQueue();
    });
    tearDown(() async {
      AiQuizService.instance.mockSendExecute = null;
      WasteQuizNotifier.essayQuestions = essayQuestionsEnabled;
      await AiQuizService.instance.cancel();
    });

    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(appPreferencesProvider.notifier).update((p) => p.copyWith(quizDifficulty: 'Medium', skipAllowed: true, questionSource: QuestionSource.bank));
      return c;
    }

    void choose(ProviderContainer c, QuestionSource s) =>
        c.read(appPreferencesProvider.notifier).update((p) => p.copyWith(questionSource: s));

    Future<void> settle(ProviderContainer c) async {
      for (var i = 0; i < 200 && c.read(wasteQuizProvider).phase == WasteQuizPhase.loadingQuestion; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('ai: the question prompt reaches the AI and its question shows as "SOAL ELIOS AI"', () async {
      final c = container();
      choose(c, QuestionSource.ai);
      c.read(wasteQuizProvider.notifier).startForLabel('botol plastik');
      await settle(c);
      final s = c.read(wasteQuizProvider);
      expect(questionPrompts, isNotEmpty);
      expect(s.question?.question, 'Soal Gemma 1?');
      expect(s.question?.bankId, isNull);
      expect(questionSourceHeader(s), 'SOAL ELIOS AI');
    });

    test('ai: no AI answer (offline, every model capped) gives a bank question, said out loud', () async {
      reply = (prompt) async => _isQuestionRequest(prompt) ? null : 'ok'; // null = the function failed
      final c = container();
      choose(c, QuestionSource.ai);
      c.read(wasteQuizProvider.notifier).startForLabel('botol plastik');
      await settle(c);
      final s = c.read(wasteQuizProvider);
      expect(questionPrompts, isNotEmpty);
      expect(s.isFallback, isFalse);
      expect(s.question?.bankId, 'botol_plastik-mc-01');
      expect(s.questionSource, QuestionSource.bank);
      expect(questionSourceHeader(s), 'SOAL DARI MODUL · BANK SOAL');
      expect(s.messages.first.text, contains('AI tidak tersambung'));
      expect(c.read(appPreferencesProvider).questionSource, QuestionSource.ai,
          reason: 'the saved choice is kept for the next scan');
    });

    test('ai: a prefetched question with no AI answer is taken from the bank', () async {
      reply = (prompt) async =>
          !_isQuestionRequest(prompt) ? 'ok' : questionPrompts.length == 1 ? _mcReply('Soal AI pertama?') : null;
      final c = container();
      choose(c, QuestionSource.ai);
      final quiz = c.read(wasteQuizProvider.notifier);
      quiz.startForLabel('botol plastik');
      await settle(c);
      expect(c.read(wasteQuizProvider).question?.question, 'Soal AI pertama?');
      quiz.skipQuestion();
      await settle(c);
      final s = c.read(wasteQuizProvider);
      expect(s.question?.bankId, isNotNull);
      expect(s.messages.last.text, contains('AI tidak tersambung'));
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
      choose(c, QuestionSource.ai);
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
      choose(c, QuestionSource.ai); // during a bank session
      quiz.skipQuestion();
      await settle(c);
      expect(c.read(wasteQuizProvider).question?.bankId, 'kardus-mc-02');
      expect(questionPrompts, isEmpty, reason: 'switching must not start Gemma work in a bank session');
    });
  });
}
