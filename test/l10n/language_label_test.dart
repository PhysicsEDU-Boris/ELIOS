// The language label follows the text (decision 0218): the model sometimes
// writes the "id" side of a bilingual reply in English, which saved English
// records labelled Indonesian that were never translated.
import 'dart:typed_data';

import 'package:elio/models/scan_record.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/history_translation_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/l10n/l10n.dart';

import '../history/h3_fixture.dart';

const _enQ = 'Why should plastic bottles be kept away from fire?';
const _idQ = 'Mengapa botol plastik harus dijauhkan dari api?';
String _side(String q, String correct) =>
    '{"question": "$q", "correct": "$correct", '
    '"wrong": ["B one", "C two", "D three"], "explanation": "e"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    AiQuizService.instance.mockSendExecute = null;
    debugSetL10n(const Locale('en'));
  });

  test('detectLang tells English from Indonesian, null when unclear', () {
    expect(AiQuizService.detectLang(_enQ), 'en');
    expect(AiQuizService.detectLang(_idQ), 'id');
    expect(AiQuizService.detectLang('Laptop'), isNull);
    expect(AiQuizService.detectLang(''), isNull);
  });

  group('a question reply', () {
    final ai = AiQuizService.instance;
    test('with English on both sides is labelled English, no false twin', () {
      final q = ai.parseQuestion(
        '{"id": ${_side(_enQ, 'It can melt and burn in the heat')}, '
        '"en": ${_side(_enQ, 'It can melt and burn in the heat')}}',
        QuizQuestionType.multipleChoice,
        lang: 'id',
      )!;
      expect(q.lang, 'en');
      expect(q.alt, isNull);
      expect(q.question, _enQ);
    });

    test('with swapped sides is put back', () {
      final q = ai.parseQuestion(
        '{"id": ${_side(_enQ, 'It can melt and burn in the heat')}, '
        '"en": ${_side(_idQ, 'Karena bisa meleleh dan terbakar')}}',
        QuizQuestionType.multipleChoice,
        lang: 'id',
      )!;
      expect(q.lang, 'id');
      expect(q.question, _idQ);
      expect(q.alt?.lang, 'en');
      expect(q.alt?.question, _enQ);
    });

    test('with correct sides is unchanged', () {
      final q = ai.parseQuestion(
        '{"id": ${_side(_idQ, 'Karena bisa meleleh dan terbakar')}, '
        '"en": ${_side(_enQ, 'It can melt and burn in the heat')}}',
        QuizQuestionType.multipleChoice,
        lang: 'id',
      )!;
      expect(q.lang, 'id');
      expect(q.question, _idQ);
      expect(q.alt?.question, _enQ);
    });
  });

  group('a record saved with the wrong label', () {
    // As found on the phone: English questions, lang "id", an "en" twin.
    Map<String, dynamic> json() => {
      'schemaVersion': 5,
      'id': 'scan-1',
      'time': '2026-11-16T22:57:29',
      'itemName': 'Plastic bottle',
      'category': 'recyclable',
      'lang': 'id',
      'questions': [
        {
          'question': _enQ,
          'options': ['It can melt and burn', 'Fire sorts it'],
          'yourAnswer': 'It can melt and burn',
          'rightAnswer': 'It can melt and burn',
          'isCorrect': true,
        },
      ],
      'translations': {
        'en': {
          'itemName': 'Plastic bottle',
          'questions': [
            {
              'question': _enQ,
              'options': ['It can melt and burn', 'Fire sorts it'],
              'yourAnswer': 'It can melt and burn',
              'rightAnswer': 'It can melt and burn',
            },
          ],
        },
      },
    };

    test('is relabelled on load and asks for the missing language', () {
      final r = ScanRecord.fromJson(json());
      expect(r.lang, 'en');
      expect(r.translations.containsKey('en'), isFalse);
      expect(r.needsTranslation('id'), isTrue);
      expect(r.needsTranslation('en'), isFalse);
    });

    test('a correctly labelled record is left alone', () {
      final r = ScanRecord.fromJson(h3Record().toJson());
      expect(r.lang, 'id');
      expect(r.needsTranslation('id'), isFalse);
    });

    test('History prefetch asks for it; it stops at the first failure', () async {
      var calls = 0;
      AiQuizService.instance.mockSendExecute =
          (String prompt, {Uint8List? imageBytes, bool isUser = false}) async {
            calls++;
            return null; // offline
          };
      final a = ScanRecord.fromJson(json());
      final b = ScanRecord.fromJson({...json(), 'id': 'scan-2'});
      final store = HistoryTestStore([a, b]);
      await HistoryTranslationService.prefetch(store, 'id');
      expect(calls, 1, reason: 'no retry storm while offline');
      calls = 0;
      await HistoryTranslationService.prefetch(store, 'en');
      expect(calls, 0, reason: 'already in English: nothing to fetch');
    });
  });
}
