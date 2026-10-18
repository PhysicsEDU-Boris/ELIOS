// Object bank (decision 0017): name matching, serving order, essay flag,
// no repeats, and no question request ever reaching Gemma by default.
import 'dart:io';
import 'dart:typed_data';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/question_bank.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeededPrefs extends AppPreferencesNotifier {
  _SeededPrefs(this.seed);
  final AppPreferences seed;
  @override
  AppPreferences build() => seed;
}

final _bank = QuestionBank.fromJson(File('assets/quiz/object_bank_draft.json').readAsStringSync(),
    File('assets/quiz/question_bank_draft.json').readAsStringSync());

ScannedWaste _scan(String item, {String? material, String? category}) =>
    ScannedWaste.fromLabel(item, material: material, categoryHint: category);

/// Question prompts are the only Gemma calls that ask for a "soal".
bool _isQuestionRequest(String prompt) => prompt.contains('Buat SATU soal');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('name matching', () {
    test('names seen in the logs and fixtures map to their object', () {
      final cases = {
        _scan('ponsel', material: 'logam, kaca, plastik', category: 'anorganik'): 'ponsel',
        _scan('Telepon genggam'): 'ponsel',
        _scan('laptop', material: 'logam, plastik, kaca'): 'laptop',
        _scan('perangkat elektronik/scanner', material: 'plastik dan logam'): 'perangkat_elektronik',
        _scan('baterai', material: 'logam'): 'baterai',
        _scan('lampu neon'): 'lampu_tl_cfl',
        _scan('botol-plastik'): 'botol_plastik',
        _scan('Plastic Bottle'): 'botol_plastik',
        _scan('botol', material: 'plastik'): 'botol_plastik',
        _scan('toples kaca', material: 'kaca'): 'toples_kaca',
        _scan('kaleng aluminium'): 'kaleng_aluminium',
        _scan('kardus', material: 'kertas', category: 'organik'): 'kardus',
        _scan('kertas', material: 'cellulose', category: 'residu'): 'kertas',
        _scan('kulit_pisang'): 'kulit_pisang',
        _scan('kotak susu', material: 'karton berlapis plastik dan aluminium'): 'kotak_susu',
        ScannedWaste.fromLabel('Cardboard'): 'kardus',
        ScannedWaste.fromLabel('Tetra_Pak'): 'kotak_susu',
      };
      cases.forEach((scan, object) => expect(_bank.matchObject(scan), object, reason: scan.displayName));
    });

    test('vetoes, ambiguity and the hazard rule', () {
      expect(_bank.matchObject(_scan('kaleng aerosol')), isNot('kaleng_aluminium'));
      expect(_bank.matchObject(_scan('botol', material: 'plastik/kaca')), isNull, reason: 'plastic or glass: ambiguous');
      expect(_bank.matchObject(_scan('limbah cair', material: 'air/cairan', category: 'residu')), isNull);
      // A non-B3 object never serves a B3 scan: its questions would contradict the hazard card.
      final b3Peel = _scan('kulit pisang', category: 'B3');
      expect(_bank.matchObject(b3Peel), isNull);
      expect(_bank.poolFor(b3Peel), 'e_waste_b3');
      expect(_bank.poolFor(ScannedWaste.fromLabel('Metal')), 'metal');
    });

    test('serving order: the object\'s own questions in order, then its pool', () {
      final mc = _bank.questionsFor(_scan('ponsel'), QuizQuestionType.multipleChoice);
      expect(mc.take(4).map((q) => q.bankId), ['ponsel-mc-01', 'ponsel-mc-02', 'ponsel-mc-03', 'ponsel-mc-04']);
      expect(mc.skip(4).first.bankId, startsWith('e_waste_b3-mc-'));
      for (final q in mc) {
        expect(q.options, hasLength(4));
        expect(q.correctIndex, inInclusiveRange(0, 3));
      }
      expect(_bank.questionsFor(_scan('ponsel'), QuizQuestionType.essay).first.bankId, 'ponsel-essay-01');
    });
  });

  group('quiz session (bank default, Gemma never asked for a question)', () {
    late List<String> prompts;
    setUp(() async {
      await GemmaQuizService.instance.cancel();
      prompts = [];
      GemmaQuizService.instance.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) async {
        prompts.add(prompt);
        if (_isQuestionRequest(prompt)) fail('question request reached Gemma: $prompt');
        if (imageBytes != null) return '{"item":"ponsel","material":"logam, kaca, plastik","category":"B3"}';
        return 'Benar, sesuai modul.';
      };
      WasteQuizNotifier.sourceOverride = QuestionSource.bank;
      WasteQuizNotifier.essayQuestions = false;
      await pumpEventQueue();
    });
    tearDown(() {
      GemmaQuizService.instance.mockSendExecute = null;
      WasteQuizNotifier.sourceOverride = null;
      WasteQuizNotifier.essayQuestions = essayQuestionsEnabled;
    });

    ProviderContainer container(String difficulty) {
      final c = ProviderContainer(overrides: [
        appPreferencesProvider.overrideWith(() => _SeededPrefs(AppPreferences(quizDifficulty: difficulty, skipAllowed: true))),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    Future<void> untilSettled(ProviderContainer c) async {
      // The bank's first load reads two assets; later sessions reuse it.
      for (var i = 0; i < 200 && c.read(wasteQuizProvider).phase == WasteQuizPhase.loadingQuestion; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    Future<List<GeneratedQuestion>> playAll(ProviderContainer c) async {
      await untilSettled(c);
      final shown = <GeneratedQuestion>[];
      final notifier = c.read(wasteQuizProvider.notifier);
      for (var i = 0; i < 6 && c.read(wasteQuizProvider).phase == WasteQuizPhase.active; i++) {
        shown.add(c.read(wasteQuizProvider).question!);
        notifier.skipQuestion();
        await pumpEventQueue();
        await untilSettled(c);
      }
      return shown;
    }

    test('defaults: build flags are off', () {
      expect(gemmaQuestionsEnabled, isFalse);
      expect(essayQuestionsEnabled, isFalse);
    });

    test('a Hard session is 5 multiple-choice bank questions, object first, no repeats, no Gemma', () async {
      final c = container('Hard');
      c.read(wasteQuizProvider.notifier).startForLabel('botol plastik');
      await pumpEventQueue();
      final shown = await playAll(c);
      expect(shown, hasLength(5));
      expect(shown.every((q) => q.type == QuizQuestionType.multipleChoice), isTrue, reason: 'essays are off');
      expect(shown.map((q) => q.bankId).take(4), ['botol_plastik-mc-01', 'botol_plastik-mc-02', 'botol_plastik-mc-03',
        'botol_plastik-mc-04']);
      expect(shown.last.bankId, startsWith('plastic-mc-'));
      expect(shown.map((q) => q.question).toSet(), hasLength(5));
      expect(prompts, isEmpty, reason: 'no request of any kind for a label scan');
    });

    test('ESSAY_QUESTIONS on: question 2 is the object\'s essay, still from the bank', () async {
      WasteQuizNotifier.essayQuestions = true;
      final c = container('Medium');
      c.read(wasteQuizProvider.notifier).startForLabel('kardus');
      await pumpEventQueue();
      final shown = await playAll(c);
      expect(shown.map((q) => q.bankId), ['kardus-mc-01', 'kardus-essay-01', 'kardus-mc-02']);
      expect(prompts.where(_isQuestionRequest), isEmpty);
    });

    test('an unknown object uses distinct fixed fallbacks and ends early rather than repeat', () async {
      final c = container('Hard');
      c.read(wasteQuizProvider.notifier).startForLabel('benda aneh');
      await untilSettled(c);
      expect(c.read(wasteQuizProvider).isFallback, isTrue);
      final shown = await playAll(c);
      expect(shown.map((q) => q.question).toSet(), hasLength(shown.length), reason: 'never a repeat');
      expect(shown, hasLength(3), reason: 'three MC fallbacks, then the session ends');
      expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.finished);
    });

    test('photo path: Gemma identifies, the bank asks', () async {
      final c = container('Medium');
      final notifier = c.read(wasteQuizProvider.notifier)..toggleVoice();
      notifier.onPhotoCaptured(Uint8List(4));
      for (var i = 0; i < 50 && c.read(wasteQuizProvider).phase != WasteQuizPhase.confirmingHazard; i++) {
        await pumpEventQueue();
      }
      expect(c.read(wasteQuizProvider).phase, WasteQuizPhase.confirmingHazard, reason: 'hazard rule unchanged');
      notifier.confirmHazard();
      await untilSettled(c);
      expect(c.read(wasteQuizProvider).question?.bankId, 'ponsel-mc-01');
      expect(prompts, hasLength(1), reason: 'only the identify request');
      expect(prompts.where(_isQuestionRequest), isEmpty);
    });
  });
}
