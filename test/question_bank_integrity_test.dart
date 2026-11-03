import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:elio/models/scanned_waste.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/question_bank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final objects =
      jsonDecode(File('assets/quiz/object_bank_draft.json').readAsStringSync())
          as Map<String, dynamic>;
  final pools =
      jsonDecode(
            File('assets/quiz/question_bank_draft.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  test(
    'bank checker and its break checks run with the Flutter suite',
    () async {
      for (final args in [
        ['tools/quiz/check_bank'],
        ['-m', 'unittest', 'discover', '-s', 'tools/quiz'],
        ['scripts/test_validate_bank.py'],
      ]) {
        final result = await Process.run('python3', args);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
      }
    },
  );

  test(
    'every current item is accepted and every shuffled MC key is in range',
    () {
      final bank = QuestionBank.fromJson(
        jsonEncode(objects),
        jsonEncode(pools),
      );
      final items = [
        ...pools['items'] as List,
        for (final object in objects['objects'] as List)
          ...object['items'] as List,
      ];
      expect(items.every((i) => i['status'] == 'accepted'), isTrue);
      final seen = <String>{};
      final scans = [
        for (final object in objects['objects'] as List)
          ScannedWaste.fromLabel((object['synonyms'] as List).first as String),
        for (final labels in (pools['pools'] as Map).values)
          ScannedWaste.fromLabel((labels as List).first as String),
      ];
      for (final scan in scans) {
        for (final type in QuizQuestionType.values) {
          for (final q in bank.questionsFor(
            scan,
            type,
            random: Random(7),
            includeDrafts: false,
          )) {
            seen.add(q.bankId!);
            expect(q.explanation.trim(), isNotEmpty);
            if (type == QuizQuestionType.multipleChoice) {
              expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
              expect(
                q.options[q.correctIndex],
                items.firstWhere((i) => i['id'] == q.bankId)['correct'],
              );
            }
          }
        }
      }
      expect(seen, items.map((i) => i['id']).toSet());
    },
  );

  test(
    'release path excludes draft, rejected and missing statuses in both banks and types',
    () {
      final fixtureObjects =
          jsonDecode(jsonEncode(objects)) as Map<String, dynamic>;
      final fixturePools =
          jsonDecode(jsonEncode(pools)) as Map<String, dynamic>;
      final object = (fixtureObjects['objects'] as List).first;
      final objectItems = object['items'] as List;
      final poolItems = (fixturePools['items'] as List)
          .where((i) => i['pool'] == object['pool'])
          .toList();
      final excluded = <String>{};
      for (final items in [objectItems, poolItems]) {
        for (final type in ['mc', 'essay']) {
          final original = items.firstWhere((i) => i['type'] == type);
          for (final status in ['draft', 'rejected', null]) {
            final item = Map<String, dynamic>.from(original as Map)
              ..['id'] = '${original['id']}-$status'
              ..['status'] = status;
            items.add(item);
            if (identical(items, poolItems))
              (fixturePools['items'] as List).add(item);
            excluded.add(item['id'] as String);
          }
        }
      }
      final bank = QuestionBank.fromJson(
        jsonEncode(fixtureObjects),
        jsonEncode(fixturePools),
      );
      final scan = ScannedWaste.fromLabel('ponsel');
      for (final type in QuizQuestionType.values) {
        final release = bank.questionsFor(scan, type, includeDrafts: false);
        expect(release, isNotEmpty);
        expect(
          release.map((q) => q.bankId).toSet().intersection(excluded),
          isEmpty,
        );
        final debug = bank.questionsFor(scan, type);
        expect(debug.where((q) => q.bankId!.endsWith('-draft')), hasLength(2));
        expect(
          debug.any(
            (q) =>
                q.bankId!.endsWith('-rejected') || q.bankId!.endsWith('-null'),
          ),
          isFalse,
        );
      }
    },
  );
}
