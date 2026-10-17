// Real-model A/B test of module-grounded questions (decision 0016).
// A = current ungrounded prompt (random angle, 1024 context); B = grounded
// (retrieved module passages, 2048 context). 10 objects x 3 questions each.
// Run on a dev machine:
//   flutter test integration_test/grounded_quiz_test.dart -d macos
//
// Every question prints one `[grounded-test] {json}` line; the end prints a
// summary per arm. docs/test-results/m3-grounded-quiz.md and
// docs/quiz-review/grounded_sample_review.md are built from those lines.
import 'dart:convert';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/waste_quiz_provider.dart' show questionTypeFor;
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/module_retriever.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

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
];
const _levels = [QuizDifficulty.easy, QuizDifficulty.medium, QuizDifficulty.hard];

final _closedLine = RegExp(r'\[GemmaQuizService\] generated (\d+) chars \(first token: (\d+)ms, total: (\d+)ms\)');
final _tokenLine = RegExp(r'tokens?\D{0,20}(\d{2,5})', caseSensitive: false);

Set<String> _words(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').split(' ').where((w) => w.isNotEmpty).toSet();
double _overlap(String a, String b) {
  final x = _words(a), y = _words(b);
  return x.isEmpty || y.isEmpty ? 0 : x.intersection(y).length / x.union(y).length;
}

int _percentile(List<int> values, double p) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  return sorted[((sorted.length - 1) * p).round()];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]));

  testWidgets('M3.4: ungrounded (A) vs grounded (B) questions for 10 objects', (tester) async {
    final service = GemmaQuizService.instance;
    final closed = <(int, int)>[]; // (first token ms, total ms) per finished stream
    final tokenNotes = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      final m = message == null ? null : _closedLine.firstMatch(message);
      if (m != null) closed.add((int.parse(m[2]!), int.parse(m[3]!)));
      if (message != null && message.contains('InferenceChat') && _tokenLine.hasMatch(message)) tokenNotes.add(message);
      original(message, wrapWidth: wrapWidth);
    };
    final summary = <String>[];
    try {
      // --dart-define=ARMS=B re-runs one arm (default both).
      for (final arm in const String.fromEnvironment('ARMS', defaultValue: 'A,B').split(',')) {
        service.grounded = arm == 'B';
        // --dart-define=PASSAGE_WORDS=300 measures a smaller passage budget.
        const budget = int.fromEnvironment('PASSAGE_WORDS', defaultValue: 450);
        if (arm == 'B') service.retriever = await ModuleRetriever.load(maxWords: budget);
        await service.dispose(); // the context size is set when the model loads
        expect(await service.ensureReady(vision: true), isTrue, reason: '${service.progress.value.error}');
        final rows = <Map<String, Object?>>[];
        var duplicates = 0;
        for (final waste in _fixtures) {
          final asked = <String>[];
          final usedChunks = <String>[];
          for (var i = 0; i < 3; i++) {
            final type = questionTypeFor(i);
            var promptWords = 0;
            var chunks = <String>[];
            service.onQuestionPrompt = (prompt, ids) {
              promptWords = prompt.split(RegExp(r'\s+')).length;
              chunks = ids;
            };
            final c0 = closed.length;
            final t0 = tokenNotes.length;
            debugPrint('[grounded-test] start $arm ${waste.displayName} q${i + 1}');
            final clock = Stopwatch()..start();
            final q = await service.generateQuestion(
                waste: waste, type: type, difficulty: _levels[i], avoid: List.of(asked),
                questionIndex: i, usedChunkIds: List.of(usedChunks));
            final totalMs = clock.elapsedMilliseconds;
            await Future<void>.delayed(const Duration(milliseconds: 50)); // let the stream-closed line land
            final g = q?.grounding;
            if (q != null) asked.add(q.question);
            if (g != null) usedChunks.add(g.chunkId);
            final attempts = closed.sublist(c0);
            final row = <String, Object?>{
              'arm': arm, 'item': waste.displayName, 'q': i + 1, 'type': type.name, 'level': _levels[i].name,
              'chunksSent': chunks, 'promptWords': promptWords,
              'firstTokenMs': attempts.isEmpty ? null : attempts.first.$1, 'totalMs': totalMs,
              'attempts': attempts.length, 'parsed': q != null,
              'quoteVerbatim': g != null, // the grounded validator only accepts verbatim quotes
              'mentionsObject': q != null && GemmaQuizService.mentionsObject(q.question, waste),
              'fallback': q == null, if (q == null) 'failure': service.lastQuestionFailure,
              if (tokenNotes.length > t0) 'tokenLog': tokenNotes.sublist(t0).take(3).toList(),
              if (q != null) 'question': q.question,
              if (q != null && q.options.isNotEmpty) 'correct': q.options[q.correctIndex],
              if (q != null && q.options.isNotEmpty) 'options': q.options,
              if (g != null) 'chunk': g.chunkId,
              if (g != null) 'quote': g.quote,
              if (g != null) 'page': g.pdfPage,
              if (g != null && g.rubric.isNotEmpty) 'rubric': g.rubric,
            };
            rows.add(row);
            debugPrint('[grounded-test] ${jsonEncode(row)}');
          }
          for (var a = 0; a < asked.length; a++) {
            for (var b = a + 1; b < asked.length; b++) {
              if (_overlap(asked[a], asked[b]) >= 0.6) duplicates++;
            }
          }
        }
        final n = rows.length;
        int count(String key) => rows.where((r) => r[key] == true).length;
        final total = [for (final r in rows) r['totalMs'] as int];
        final q1 = [for (final r in rows) if (r['q'] == 1) r['totalMs'] as int];
        final first = [for (final r in rows) if (r['firstTokenMs'] != null) r['firstTokenMs'] as int];
        summary.add('[grounded-test] summary $arm${arm == 'B' ? ' (${budget}w)' : ''}: parsed ${count('parsed')}/$n, '
            'verbatim ${count('quoteVerbatim')}/$n, mentionsObject ${count('mentionsObject')}/$n, '
            'fallback ${count('fallback')}/$n, total p50 ${_percentile(total, .5)} p95 ${_percentile(total, .95)} ms, '
            'q1 p50 ${_percentile(q1, .5)} ms, first token p50 ${_percentile(first, .5)} ms, '
            'duplicates within item $duplicates');
      }
    } finally {
      debugPrint = original;
      service
        ..onQuestionPrompt = null
        ..grounded = groundedQuizEnabled;
      await service.dispose();
    }
    summary.forEach(debugPrint);
  }, timeout: const Timeout(Duration(minutes: 45)));
}
