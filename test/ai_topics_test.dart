// AI question topics (decision 0019): physics angles chosen in code,
// never repeated in a session, fitting the bin; LCA / circular-economy
// replies rejected and retried with another angle.
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _isQuestionRequest(String prompt) => prompt.contains('Buat SATU soal');

/// The angle id whose text appears in [prompt].
String _angleOf(String prompt) =>
    AiQuizService.questionAngles.firstWhere((a) => prompt.contains('tentang ${a.text} untuk')).id;

String _mc(String question, {String extra = ''}) =>
    '{"question": "$question", "correct": "Benar", "wrong": ["Salah satu", "Salah dua", "Salah tiga"], '
    '"explanation": "Penjelasan.$extra"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final peel = ScannedWaste.fromLabel('kulit pisang', material: 'bahan organik', categoryHint: 'organik');
  final bottle = ScannedWaste.fromLabel('botol plastik', material: 'plastik', categoryHint: 'anorganik');
  final battery = ScannedWaste.fromLabel('baterai', material: 'logam', categoryHint: 'B3');

  test('no prompt carries a banned topic, for any angle, object, type or level', () {
    for (final waste in [peel, bottle, battery]) {
      for (final angle in AiQuizService.questionAngles) {
        for (final type in QuizQuestionType.values) {
          for (final level in QuizDifficulty.values) {
            final prompt = AiQuizService.questionPrompt(
                waste: waste, type: type, difficulty: level, angleText: angle.text);
            expect(AiQuizService.bannedTopicIn(prompt), isNull, reason: prompt);
            expect(prompt, contains('tentang ${angle.text} untuk "${waste.displayName}"'));
          }
        }
      }
    }
    expect(AiQuizService.bannedTopicIn('Analisis LCA kardus'), 'lca');
    expect(AiQuizService.bannedTopicIn('dalam ekonomi sirkular'), 'ekonomi sirkular');
    expect(AiQuizService.bannedTopicIn('kalcium dan balcony'), isNull, reason: 'whole words only');
  });

  test('angles fit the bin: no batteries or recycling energy for a banana peel', () {
    final peelAngles = AiQuizService.anglesFor(peel).map((a) => a.id);
    expect(peelAngles, isNot(contains('electricity')));
    expect(peelAngles, isNot(contains('recycling_energy')));
    expect(AiQuizService.anglesFor(battery).map((a) => a.id), contains('electricity'));
    for (final waste in [peel, bottle, battery]) {
      expect(AiQuizService.anglesFor(waste).length, greaterThanOrEqualTo(5),
          reason: '${waste.displayName}: enough angles for a 5-question session');
    }
  });

  group('sessions in AI mode', () {
    late List<String> prompts;
    late String Function(String prompt, int n) reply;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AiQuizService.instance.cancel();
      prompts = [];
      reply = (prompt, n) => _mc('Soal fisika $n?');
      AiQuizService.instance.mockSendExecute = (prompt, {imageBytes, isUser = false}) async {
        if (!_isQuestionRequest(prompt)) return 'ok';
        prompts.add(prompt);
        return reply(prompt, prompts.length);
      };
      WasteQuizNotifier.sourceOverride = QuestionSource.ai;
      WasteQuizNotifier.essayQuestions = false;
      await pumpEventQueue();
    });
    tearDown(() async {
      AiQuizService.instance.mockSendExecute = null;
      WasteQuizNotifier.sourceOverride = null;
      WasteQuizNotifier.essayQuestions = essayQuestionsEnabled;
      await AiQuizService.instance.cancel();
    });

    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(appPreferencesProvider.notifier).update((p) => p.copyWith(quizDifficulty: 'Hard', skipAllowed: true));
      return c;
    }

    Future<void> settle(ProviderContainer c) async {
      for (var i = 0; i < 300 && c.read(wasteQuizProvider).phase == WasteQuizPhase.loadingQuestion; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    Future<List<GeneratedQuestion>> playAll(ProviderContainer c, String label, {bool hazard = false}) async {
      final quiz = c.read(wasteQuizProvider.notifier)..startForLabel(label);
      if (hazard) {
        await pumpEventQueue();
        quiz.confirmHazard();
      }
      await settle(c);
      final shown = <GeneratedQuestion>[];
      for (var i = 0; i < 5 && c.read(wasteQuizProvider).phase == WasteQuizPhase.active; i++) {
        shown.add(c.read(wasteQuizProvider).question!);
        quiz.skipQuestion();
        await settle(c);
      }
      return shown;
    }

    for (final (label, waste, hazard) in [('kulit pisang', peel, false), ('botol plastik', bottle, false), ('baterai', battery, true)]) {
      test('$label: 5 questions, 5 different angles, all fitting its bin', () async {
        final shown = await playAll(container(), label, hazard: hazard);
        expect(shown, hasLength(5));
        final angles = [for (final p in prompts) _angleOf(p)];
        expect(angles.toSet(), hasLength(angles.length), reason: 'no angle repeats in a session: $angles');
        final fitting = AiQuizService.anglesFor(waste).map((a) => a.id);
        expect(fitting, containsAll(angles));
        expect(shown.map((q) => q.angle).toSet(), hasLength(5));
      });
    }

    test('an "LCA" reply is rejected and retried with another angle', () async {
      reply = (prompt, n) => n == 1 ? _mc('Analisis LCA untuk botol plastik?') : _mc('Mengapa botol plastik mengapung?');
      final c = container();
      c.read(wasteQuizProvider.notifier).startForLabel('botol plastik');
      await settle(c);
      final s = c.read(wasteQuizProvider);
      expect(s.isFallback, isFalse);
      expect(s.question?.question, 'Mengapa botol plastik mengapung?');
      expect(_angleOf(prompts[1]), isNot(_angleOf(prompts[0])), reason: 'the retry uses a different angle');
    });

    test('two banned replies give a bank question, like any AI failure (decision 0179)', () async {
      reply = (prompt, n) => n <= 2 ? _mc('Soal fisika $n?', extra: ' Ini mendukung ekonomi sirkular.') : _mc('Soal fisika $n?');
      final c = container();
      c.read(wasteQuizProvider.notifier).startForLabel('botol plastik');
      await settle(c);
      final s = c.read(wasteQuizProvider);
      expect(s.question?.bankId, isNotNull);
      expect(s.questionSource, QuestionSource.bank);
    });

    test('bank mode still sends no question prompt to the AI', () async {
      WasteQuizNotifier.sourceOverride = QuestionSource.bank;
      final shown = await playAll(container(), 'botol plastik');
      expect(shown, hasLength(5));
      expect(prompts, isEmpty);
    });
  });
}
