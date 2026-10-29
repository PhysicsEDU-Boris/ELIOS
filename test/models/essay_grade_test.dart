import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/essay_grade.dart';

const _good = '''
{"accuracy":4,"keyTerms":2,"completeness":2,"clarity":1,"total":9,
"feedback":"Penjelasan akurat dan jelas.","improvement":"Sebutkan istilah metana."}
''';

void main() {
  group('EssayGrade.parse', () {
    test('accepts a complete, consistent rubric', () {
      final grade = EssayGrade.parse(_good)!;
      expect(grade.score, 9);
      expect(grade.rubricRows.map((row) => row.criterion), [
        'Accuracy',
        'Key terms',
        'Completeness',
        'Clarity',
      ]);
      expect(grade.rubricRows.map((row) => row.maxScore), [4, 3, 2, 1]);
      expect(grade.rubricRows.map((row) => row.awardedScore), [4, 2, 2, 1]);
      expect(grade.feedback, 'Penjelasan akurat dan jelas.');
      expect(grade.improvement, 'Sebutkan istilah metana.');
    });

    test('accepts a partial score without inventing rubric rows', () {
      final grade = EssayGrade.parse('''
        {"accuracy":2,"keyTerms":1,"completeness":1,"clarity":0,"total":4,
        "feedback":"Beberapa poin tepat.","improvement":"Jelaskan dampaknya."}
      ''')!;
      expect(grade.score, 4);
      expect(grade.rubricRows, hasLength(4));
    });

    test('keeps a valid total score-only when rubric fields are malformed', () {
      final grade = EssayGrade.parse(
        '{"accuracy":"4","total":7,"feedback":"Cukup.","improvement":"Perjelas."}',
      )!;
      expect(grade.score, 7);
      expect(grade.rubricRows, isEmpty);
      final wordList = EssayGrade.parse(
        '{"accuracy":4,"keyTerms":["pilah","cuci"],"completeness":1,"clarity":1,"total":8}',
      )!;
      expect(wordList.score, 8);
      expect(wordList.rubricRows, isEmpty);
    });

    test('rejects malformed replies and out-of-range totals or criteria', () {
      expect(EssayGrade.parse('not JSON'), isNull);
      expect(EssayGrade.parse('{"total":11}'), isNull);
      final outOfRange = EssayGrade.parse('{"total":5,"accuracy":5}')!;
      expect(outOfRange.score, 5);
      expect(outOfRange.rubricRows, isEmpty);
      expect(EssayGrade.parse('{"total":"5"}'), isNull);
    });

    test('rejects a total that does not equal the rubric sum', () {
      expect(
        EssayGrade.parse(_good.replaceFirst('"total":9', '"total":8')),
        isNull,
      );
    });
  });
}
