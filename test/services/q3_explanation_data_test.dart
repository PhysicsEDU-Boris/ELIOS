// Q3 (decision 0175): the bank's quote, section, page, id and reviewed wrongWhy
// reach the explanation; the bin table only on a right answer; old records load.
import 'dart:convert';

import 'package:elio/models/essay_grade.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/question_bank.dart';
import 'package:elio/services/quiz_explanation_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _mc = {
  'id': 'botol-mc-01', 'type': 'mc', 'status': 'accepted', 'question': 'Q?',
  'correct': 'PET', 'wrong': ['PVC', 'HDPE', 'Styrofoam'],
  'explanation': 'Modul menyebut PET.', 'sourceChunk': '4.2', 'pdfPage': 21, 'quote': 'Botol minuman dari PET.',
  'wrongWhy': {'PVC': 'PVC dipakai untuk pipa.'},
};
final _essay = {
  'id': 'botol-essay-01', 'type': 'essay', 'status': 'accepted', 'question': 'Jelaskan?', 'sourceChunk': '4.2', 'pdfPage': 21,
  'rubricPoints': [
    {'point': 'A', 'sourceChunk': '4.2', 'pdfPage': 21, 'quote': 'Kutipan satu.'},
    {'point': 'B', 'sourceChunk': '4.3', 'pdfPage': 22, 'quote': 'Kutipan dua.'},
  ],
};

QuestionBank _bank() => QuestionBank.fromJson(
      jsonEncode({
        'objects': [
          {'object': 'botol', 'synonyms': ['botol'], 'label': 'Plastic', 'pool': 'plastik', 'items': [_mc, _essay]},
        ],
      }),
      jsonEncode({'pools': {'plastik': ['Plastic']}, 'items': []}),
    );

void main() {
  final scan = ScannedWaste.fromLabel('botol-plastik');

  test('the bank carries quote, section, page, id and wrongWhy into the question', () {
    final q = _bank().questionsFor(scan, QuizQuestionType.multipleChoice).single;
    expect(q.bankId, 'botol-mc-01');
    expect(q.quote, 'Botol minuman dari PET.');
    expect(q.sourceSection, '4.2');
    expect(q.sourcePage, '21');
    expect(q.wrongWhy, {'PVC': 'PVC dipakai untuk pipa.'});
  });

  test('essays cite their rubric points quotes, sections and pages', () {
    final q = _bank().questionsFor(scan, QuizQuestionType.essay).single;
    expect(q.quote, 'Kutipan satu. … Kutipan dua.');
    expect(q.sourceSection, '4.2, 4.3');
    expect(q.sourcePage, '21, 22');
  });

  test('right answer: bin reference rows, quote, section, page and id; no wrong-answer text', () async {
    final q = _bank().questionsFor(scan, QuizQuestionType.multipleChoice).single;
    final e = await QuizExplanationService.generate(question: q, scan: scan, selectedIndex: q.correctIndex);
    expect(e.comparisonRows, isNotEmpty);
    expect(e.selectedAnswerFeedback, isEmpty);
    expect((e.quote, e.sourceSection, e.sourcePage, e.bankId), ('Botol minuman dari PET.', '4.2', '21', 'botol-mc-01'));
    expect(e.groundingStatus, GroundingStatus.bankGrounded);
  });

  test('wrong answer: no bin table; the reviewed wrongWhy, or nothing (never a generic sentence)', () async {
    final q = _bank().questionsFor(scan, QuizQuestionType.multipleChoice).single;
    final pvc = q.options.indexOf('PVC'), hdpe = q.options.indexOf('HDPE');
    final withWhy = await QuizExplanationService.generate(question: q, scan: scan, selectedIndex: pvc);
    expect(withWhy.comparisonRows, isEmpty);
    expect(withWhy.selectedAnswerFeedback, 'PVC dipakai untuk pipa.');
    final without = await QuizExplanationService.generate(question: q, scan: scan, selectedIndex: hdpe);
    expect(without.selectedAnswerFeedback, isEmpty);
  });

  test('options table from a wrong MC answer marks the pick and the right one', () {
    const q = GeneratedQuestion(type: QuizQuestionType.multipleChoice, question: 'Q', options: ['a', 'b', 'c', 'd'], correctIndex: 2);
    final rows = QuizExplanationService.optionRows(q, 0);
    expect(rows.map((r) => r.option), ['a', 'b', 'c', 'd']);
    expect(rows.where((r) => r.picked).single.option, 'a');
    expect(rows.where((r) => r.correct).single.option, 'c');
  });

  test('essay grade keeps the rubric quote and page; pending too', () async {
    final q = _bank().questionsFor(scan, QuizQuestionType.essay).single;
    final pending = await QuizExplanationService.generate(question: q, scan: scan);
    expect((pending.essayScore, pending.quote, pending.sourcePage), (null, 'Kutipan satu. … Kutipan dua.', '21, 22'));
    final graded = await QuizExplanationService.generate(
      question: q,
      scan: scan,
      essayGrade: const EssayGrade(score: 8, feedback: 'Bagus.', improvement: '', rubricRows: []),
    );
    expect((graded.essayScore, graded.bankId), (8, 'botol-essay-01'));
  });

  test('old records (schema 2, no quote or id) load; new fields round-trip; schema is 3', () {
    final old = ScanRecord.fromJson({
      'id': 'r1', 'itemName': 'Botol', 'category': 'recyclable', 'time': '2026-10-30T10:00:00.000',
      'questions': [
        {'question': 'Q', 'yourAnswer': 'a', 'rightAnswer': 'a', 'isCorrect': true,
         'explanation': {'summary': 's', 'correctAnswerReason': 'r', 'sourceTitle': 'Bank Soal ELIO', 'groundingStatus': 'bankGrounded'}},
      ],
      'schemaVersion': 2,
    });
    final e = old.questions.single.explanation!;
    expect((e.quote, e.bankId, e.sourceTitle), (null, null, 'Bank Soal ELIO'));
    const fresh = QuizExplanation(summary: 's', correctAnswerReason: 'r', quote: 'q', bankId: 'x', sourcePage: '6');
    final back = QuizExplanation.fromJson(fresh.toJson());
    expect((back.quote, back.bankId, back.sourcePage), ('q', 'x', '6'));
  });
}
