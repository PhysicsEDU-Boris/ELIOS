// Real-model multiple-choice parse test at several temperatures (decision 0013).
// Measurement only: it never changes the production temperature (0.9).
// Run on a dev machine:
//   flutter test integration_test/quiz_temperature_test.dart -d macos
//
// Every attempt prints one `[temp-test]` line (JSON) and the end prints a
// summary per temperature; docs/test-results/m3-quiz-parse.md is built from them.
import 'dart:convert';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _temperatures = [0.9, 0.4, 0.3];
// Same 5 prompts at every temperature: run i always uses angle i.
const _angles = [
  'komposisi material serta sifat kimia atau fisikanya',
  'proses daur ulang atau pengolahan industrinya',
  'dampak lingkungannya beserta mekanisme penyebabnya',
  'lama penguraian dan hal yang mempercepatnya',
  'risiko kesehatan dan keselamatannya',
];

String _norm(Object? s) => '$s'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// What the raw reply looks like, independent of the service's parser.
Map<String, Object?> _inspect(String raw) {
  Map<String, dynamic>? map;
  try {
    final decoded = jsonDecode(raw.substring(raw.indexOf('{'), raw.lastIndexOf('}') + 1));
    if (decoded is Map<String, dynamic>) map = decoded;
  } catch (_) {}
  if (map == null) return {'validJson': false};
  final wrong = map['wrong'] is List ? (map['wrong'] as List) : null;
  final correct = map['correct'];
  // The pre-0013 shape (options + correctIndex) is read too, for the baseline run.
  final options = map['options'] is List ? (map['options'] as List) : null;
  final index = map['correctIndex'];
  final all = options ?? [if (correct is String) correct, ...?wrong];
  final keys = all.map(_norm).where((k) => k.isNotEmpty).toList();
  return {
    'validJson': true,
    'shape': wrong != null ? 'correct+wrong' : (options != null ? 'options' : 'other'),
    'wrongCount': wrong?.length,
    'optionCount': all.length,
    'oneCorrect': options != null
        ? index is int && index >= 0 && index < options.length && _norm(options[index]).isNotEmpty
        : correct is String && _norm(correct).isNotEmpty,
    'emptyField': [map['question'], map['explanation'], ...all].any((v) => v == null || _norm(v).isEmpty),
    'duplicate': keys.length != keys.toSet().length,
  };
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]));

  testWidgets('M3.1: multiple-choice parse rate at temperature 0.9 / 0.4 / 0.3, 5 runs each', (tester) async {
    final service = GemmaQuizService.instance;
    final kardus = ScannedWaste.fromLabel('kardus', material: 'kertas karton');
    final summary = <String>[];
    try {
      for (final t in _temperatures) {
        service.temperature = t;
        await service.dispose(); // the temperature is set when the chat is created
        expect(await service.ensureReady(vision: true), isTrue, reason: '${service.progress.value.error}');
        var attempts = 0, parsedAttempts = 0, questions = 0, extraWrong = 0;
        for (var run = 0; run < _angles.length; run++) {
          service.angleOverride = _angles[run];
          final clock = Stopwatch()..start();
          var attempt = 0;
          service.onQuestionReply = (raw) {
            attempt++;
            attempts++;
            final parsed = service.parseQuestion(raw, QuizQuestionType.multipleChoice) != null;
            if (parsed) parsedAttempts++;
            final info = _inspect(raw);
            if ((info['wrongCount'] as int? ?? 0) > 3) extraWrong++;
            debugPrint('[temp-test] ${jsonEncode({
                  't': t, 'run': run + 1, 'attempt': attempt, 'ms': clock.elapsedMilliseconds,
                  'parsed': parsed, ...info,
                  if (!parsed) 'raw': raw,
                })}');
            clock.reset();
          };
          final q = await service.generateQuestion(
            waste: kardus,
            type: QuizQuestionType.multipleChoice,
            difficulty: QuizDifficulty.hard,
          );
          if (q != null) {
            questions++;
            expect(q.options, hasLength(4));
            expect(q.correctIndex, inInclusiveRange(0, 3));
          }
        }
        summary.add('[temp-test] summary t=$t: attempts parsed $parsedAttempts/$attempts, '
            'questions $questions/${_angles.length}, more than 3 wrong $extraWrong');
      }
    } finally {
      service.onQuestionReply = null;
      service.angleOverride = null;
      service.temperature = 0.9;
      await service.dispose();
    }
    summary.forEach(debugPrint);
  }, timeout: const Timeout(Duration(minutes: 30)));
}
