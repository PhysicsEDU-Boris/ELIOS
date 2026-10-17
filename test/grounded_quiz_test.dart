// Module-grounded quiz (decision 0016): retriever, grounded validator, and
// the provider path (chunk rotation, fallbacks, essay grading context).
import 'dart:io';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/module_retriever.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeededPrefs extends AppPreferencesNotifier {
  _SeededPrefs(this.seed);
  final AppPreferences seed;
  @override
  AppPreferences build() => seed;
}

ModuleRetriever _retriever({Map<String, String>? excluded}) => ModuleRetriever.fromJson(
    File('assets/module/module_chunks.json').readAsStringSync(),
    File('assets/module/label_to_chunks.json').readAsStringSync(),
    excluded: excluded);

final _fixtures = [
  ScannedWaste.fromLabel('ponsel', material: 'plastik, logam, dan kaca', categoryHint: 'B3'),
  ScannedWaste.fromLabel('laptop', material: 'plastik dan logam', categoryHint: 'B3'),
  ScannedWaste.fromLabel('baterai', material: 'logam dan bahan kimia', categoryHint: 'B3'),
  ScannedWaste.fromLabel('botol plastik', material: 'plastik PET', categoryHint: 'anorganik'),
  ScannedWaste.fromLabel('gelas plastik', material: 'plastik', categoryHint: 'anorganik'),
  ScannedWaste.fromLabel('toples kaca', material: 'kaca', categoryHint: 'anorganik'),
  ScannedWaste.fromLabel('kaleng aluminium', material: 'aluminium', categoryHint: 'anorganik'),
  ScannedWaste.fromLabel('kardus', material: 'kertas karton', categoryHint: 'anorganik'),
  ScannedWaste.fromLabel('kulit pisang', material: 'bahan organik', categoryHint: 'organik'),
  ScannedWaste.fromLabel('kotak susu', material: 'karton berlapis plastik dan aluminium', categoryHint: 'anorganik'),
  ScannedWaste.fromLabel('kompos sisa sayur', material: 'bahan organik', categoryHint: 'organik'),
];

String _flat(String s) => s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');

/// A grounded reply citing the first passage of [prompt] with its first 8 words.
String _groundedReply(String prompt, {String item = 'botol plastik', bool essay = false}) {
  final m = RegExp(r'^\[(\S+)\] (.+)$', multiLine: true).firstMatch(prompt)!;
  final quote = m[2]!.split(' ').take(8).join(' ');
  return essay
      ? '{"question": "Jelaskan pengelolaan $item.", "rubric": ["poin dari kutipan"], '
          '"explanation": "e", "quote": "$quote", "chunk": "${m[1]}"}'
      : '{"question": "Bagaimana $item didaur ulang?", "correct": "A", "wrong": ["B", "C", "D"], '
          '"explanation": "e", "quote": "$quote", "chunk": "${m[1]}"}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final r = _retriever();

  group('retriever', () {
    test('ranks the object\'s own passage first and ends with its definition chunk', () {
      final tetra = r.retrieve(_fixtures[9]);
      expect(tetra.first.id, '4.6');
      expect(tetra.last.id, '1.3');
      expect(r.retrieve(_fixtures[3]).map((c) => c.id), containsAllInOrder(['4.2', '1.4']));
      expect(r.retrieve(_fixtures[0]).last.id, '2.1', reason: 'B3 definition (1.6 is a table chunk)');
      expect(r.retrieve(_fixtures[8]).last.id, '1.3');
    });

    test('never sends an excluded topic or a table, and honours a custom exclusion list', () {
      for (final f in _fixtures) {
        final used = <String>[];
        for (var i = 0; i < 3; i++) {
          final picked = r.retrieve(f, questionIndex: i, usedChunkIds: used);
          for (final c in picked) {
            expect(ModuleRetriever.defaultExcluded.keys, isNot(contains(c.id)), reason: '${f.displayName} q$i');
            expect(ModuleRetriever.pickableTypes, contains(c.type), reason: '${f.displayName} q$i ${c.id}');
            expect(c.id.startsWith('7.'), isFalse);
          }
          used.add(picked.first.id);
        }
      }
      expect(_retriever(excluded: {'4.6': 'test'}).retrieve(_fixtures[9]).map((c) => c.id), isNot(contains('4.6')));
    });

    test('question k skips chunks cited earlier, and reuses only when nothing else is left', () {
      final q1 = r.retrieve(_fixtures[3]);
      final q2 = r.retrieve(_fixtures[3], questionIndex: 1, usedChunkIds: [q1.first.id]);
      expect(q2.map((c) => c.id), isNot(contains(q1.first.id)));
      // Kotak susu has one eligible passage (4.6): reuse it rather than send no topic.
      expect(r.retrieve(_fixtures[9], questionIndex: 1, usedChunkIds: ['4.6']).first.id, '4.6');
    });

    test('2-3 passages within ~450 words; a cut definition is a verbatim prefix', () {
      for (final f in _fixtures) {
        final picked = r.retrieve(f);
        expect(picked.length, inInclusiveRange(2, 3), reason: f.displayName);
        expect(picked.fold<int>(0, (a, c) => a + c.words), lessThanOrEqualTo(r.maxWords + 5));
        expect(r.chunk(picked.last.id)!.text.startsWith(picked.last.text), isTrue);
      }
    });
  });

  group('grounded validator', () {
    final waste = _fixtures[3];
    final passages = r.retrieve(waste);
    final prompt = GemmaQuizService.groundedPrompt(
        waste: waste, type: QuizQuestionType.multipleChoice, difficulty: QuizDifficulty.easy, passages: passages);
    final svc = GemmaQuizService.instance;
    ({GeneratedQuestion? question, String? reason}) check(String raw, {QuizQuestionType type = QuizQuestionType.multipleChoice}) =>
        svc.parseGroundedQuestion(raw, type, passages, waste);

    test('accepts a verbatim quote from a sent chunk and keeps it in the debug field', () {
      final result = check(_groundedReply(prompt));
      expect(result.reason, isNull);
      final g = result.question!.grounding!;
      expect(g.chunkId, passages.first.id);
      expect(g.pdfPage, passages.first.pdfPage);
      expect(_flat(passages.first.text), contains(g.quote));
      expect(result.question!.options, hasLength(4));
    });

    test('rejects an altered quote, an unsent chunk, a question without the object, an essay without rubric', () {
      final ok = _groundedReply(prompt);
      final quote = RegExp(r'"quote": "([^"]+)"').firstMatch(ok)![1]!;
      expect(check(ok.replaceFirst(quote, '$quote tambahan kata')).reason, contains('quote'));
      expect(check(ok.replaceFirst('"chunk": "${passages.first.id}"', '"chunk": "9.qa"')).reason, contains('not sent'));
      expect(check(ok.replaceFirst('"chunk": "${passages.first.id}"', '"chunk": "Benda yang discan: botol plastik"')).reason,
          contains('not sent'), reason: 'the object line seen on the real model is not a chunk');
      expect(check(ok.replaceFirst('"chunk": "${passages.first.id}"', '"chunk": "[${passages.first.id}]"')).reason, isNull);
      expect(check(ok.replaceFirst('Bagaimana botol plastik didaur ulang?', 'Apa itu daur ulang?')).reason,
          contains('object'));
      final essay = _groundedReply(prompt, essay: true).replaceFirst('"rubric": ["poin dari kutipan"], ', '');
      expect(check(essay, type: QuizQuestionType.essay).reason, contains('rubric'));
      final placeholder = _groundedReply(prompt, essay: true).replaceFirst('["poin dari kutipan"]', '["1", "2"]');
      expect(check(placeholder, type: QuizQuestionType.essay).reason, contains('rubric'),
          reason: 'placeholder points seen on the real model');
    });

    test('a quote cited under the wrong sent id is credited to the chunk it comes from', () {
      final ok = _groundedReply(prompt);
      final wrongId = ok.replaceFirst('"chunk": "${passages.first.id}"', '"chunk": "${passages.last.id}"');
      final g = check(wrongId).question!.grounding!;
      expect(g.chunkId, passages.first.id);
      expect(g.pdfPage, passages.first.pdfPage);
    });

    test('the prompt carries the object, the chunk ids and the grounding rule', () {
      expect(prompt, contains('"Botol plastik"'));
      for (final p in passages) {
        expect(prompt, contains('[${p.id}] '));
      }
      expect(prompt, contains('jangan memakai pengetahuan di luar kutipan'));
      expect(prompt, contains('"quote"'));
    });
  });

  group('provider (grounded on)', () {
    setUp(() async {
      await GemmaQuizService.instance.cancel();
      GemmaQuizService.instance
        ..grounded = true
        ..retriever = r
        ..mockSendExecute = null;
      await pumpEventQueue();
    });
    tearDown(() => GemmaQuizService.instance
      ..grounded = false
      ..mockSendExecute = null);

    ProviderContainer container(String difficulty) {
      final c = ProviderContainer(overrides: [
        appPreferencesProvider.overrideWith(() => _SeededPrefs(AppPreferences(quizDifficulty: difficulty, skipAllowed: true))),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('ungroundable replies fall back, and no fallback repeats within a session', () async {
      GemmaQuizService.instance.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) async =>
          '{"question": "Bagaimana botol plastik didaur ulang?", "correct": "A", "wrong": ["B", "C", "D"], '
          '"explanation": "e", "quote": "kalimat yang tidak ada di modul sama sekali", "chunk": "4.2"}';
      final c = container('Hard');
      final notifier = c.read(wasteQuizProvider.notifier)..startForLabel('botol plastik');
      await pumpEventQueue();
      final shown = <String>[];
      for (var i = 0; i < 5; i++) {
        final s = c.read(wasteQuizProvider);
        expect(s.isFallback, isTrue, reason: 'question ${i + 1}');
        shown.add(s.question!.question);
        notifier.skipQuestion();
        await pumpEventQueue();
      }
      expect(shown.toSet(), hasLength(5), reason: 'three MC and two essay fallbacks, all different: $shown');
      expect(GemmaQuizService.instance.lastQuestionFailure, anyOf(contains('quote'), contains('not sent')));
    });

    test('prefetched questions get other passages, and essay grading gets the passage and rubric', () async {
      final prompts = <String>[];
      GemmaQuizService.instance.mockSendExecute = (prompt, {imageBytes, fresh = false, isUser = false, onToken}) async {
        prompts.add(prompt);
        if (prompt.startsWith('Soal essay')) return 'Benar, sesuai kutipan.';
        return _groundedReply(prompt, essay: prompt.contains('SATU soal essay'));
      };
      final c = container('Medium');
      final notifier = c.read(wasteQuizProvider.notifier)..startForLabel('botol plastik');
      await pumpEventQueue();
      expect(c.read(wasteQuizProvider).isFallback, isFalse);
      final cited = [for (final p in prompts.take(3)) RegExp(r'^\[(\S+)\]', multiLine: true).firstMatch(p)![1]];
      expect(cited.toSet(), hasLength(3), reason: 'each question leads with a passage not cited before: $cited');

      notifier.selectOption(0);
      notifier.nextQuestion(); // question 2 is the essay
      await pumpEventQueue();
      await notifier.submitEssay('Botol plastik dipilah lalu dicacah.');
      final review = prompts.last;
      expect(review, startsWith('Soal essay'));
      expect(review, contains('Kutipan modul kuliah'));
      expect(review, contains('poin dari kutipan'));
    });
  });
}
