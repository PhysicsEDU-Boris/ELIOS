// Multiple-choice parse path, decision 0013: one `correct` answer plus
// `wrong` distractors, so the answer key comes from the structure.
import 'package:elio/services/ai_quiz_service.dart';
import 'package:flutter_test/flutter_test.dart';

GeneratedQuestion? _mc(String raw) =>
    AiQuizService.instance.parseQuestion(raw, QuizQuestionType.multipleChoice);

void main() {
  test('correct + 3 wrong gives 4 options with the key on the correct text', () {
    for (var i = 0; i < 20; i++) {
      final q = _mc('{"question": "Bahan utama kardus?", "correct": "Selulosa", '
          '"wrong": ["PET", "Aluminium", "Kaca"], "explanation": "Kardus dari serat kayu."}')!;
      expect(q.options, hasLength(4));
      expect(q.options.toSet(), {'Selulosa', 'PET', 'Aluminium', 'Kaca'});
      expect(q.options[q.correctIndex], 'Selulosa');
    }
  });

  test('a 4th distractor (the old 5-option failure) is dropped and the key stays right', () {
    final q = _mc('{"question": "Q?", "correct": "Benar", '
        '"wrong": ["Salah 1", "Salah 2", "Salah 3", "Salah 4"], "explanation": "e"}')!;
    expect(q.options, hasLength(4));
    expect(q.options, isNot(contains('Salah 4')));
    expect(q.options[q.correctIndex], 'Benar');
  });

  test('empty or repeated distractors are skipped, fewer than 3 left is rejected', () {
    final q = _mc('{"question": "Q?", "correct": "Benar", '
        '"wrong": ["Salah 1", "", "salah 1.", "Salah 2", "Salah 3"], "explanation": "e"}')!;
    expect(q.options.toSet(), {'Benar', 'Salah 1', 'Salah 2', 'Salah 3'});
    expect(_mc('{"question": "Q?", "correct": "Benar", "wrong": ["Salah 1", "Salah 1", "Salah 2"]}'), isNull);
  });

  test('a distractor equal to the answer is rejected (two correct options)', () {
    expect(_mc('{"question": "Q?", "correct": "Daur ulang", '
        '"wrong": ["Dibakar", "daur ulang!", "Ditimbun", "Dibuang"]}'), isNull);
  });

  test('no single correct answer is rejected', () {
    expect(_mc('{"question": "Q?", "correct": "", "wrong": ["A", "B", "C"]}'), isNull);
    expect(_mc('{"question": "Q?", "correct": ["A", "B"], "wrong": ["C", "D", "E"]}'), isNull);
    expect(_mc('{"question": "Q?", "wrong": ["A", "B", "C"]}'), isNull);
  });

  test('the old options/correctIndex shape and invalid JSON are rejected', () {
    expect(_mc('{"question": "Q?", "options": ["A","B","C","D"], "correctIndex": 0}'), isNull);
    expect(_mc('{"question": "Q?", "correct": "A", "wrong": ["B", "C", "D",], }'), isNull);
  });

  test('essay still parses without options', () {
    final q = AiQuizService.instance
        .parseQuestion('{"question": "Jelaskan?", "explanation": "poin"}', QuizQuestionType.essay)!;
    expect(q.options, isEmpty);
  });
}
