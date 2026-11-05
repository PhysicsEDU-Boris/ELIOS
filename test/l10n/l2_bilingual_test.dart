// L2 (decision 0185): bilingual AI replies, the History translation cache,
// the English bank, prompts, TTS on a language switch and the ELIOS rename.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:elio/l10n/l10n.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/quiz_question.dart';
import 'package:elio/models/quiz_set.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/providers/app_locale_provider.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/history_translation_service.dart';
import 'package:elio/services/question_bank.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:elio/services/scan_record_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ScanRecord _record() => ScanRecord(
  id: 'r1',
  time: DateTime(2026, 11, 3, 23, 29),
  itemName: 'Botol plastik',
  category: ScanCategory.recyclable,
  questions: const [
    RecordQuestion(
      question: 'Mengapa botol PET tenggelam di air?',
      options: ['Massa jenisnya lebih besar', 'Massa jenisnya lebih kecil'],
      yourAnswer: 'Massa jenisnya lebih kecil',
      rightAnswer: 'Massa jenisnya lebih besar',
      isCorrect: false,
    ),
  ],
);

String _reply({
  required String rightEn,
  String yourEn = 'Its density is lower',
}) => jsonEncode({
  'en': {
    'item': 'Plastic bottle',
    'questions': [
      {
        'question': 'Why does a PET bottle sink in water?',
        'options': ['Its density is higher', 'Its density is lower'],
        'yourAnswer': yourEn,
        'rightAnswer': rightEn,
      },
    ],
  },
  'id': {'item': 'Botol plastik', 'questions': []},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    AiQuizService.instance.mockSendExecute = null;
    QuizTtsService.instance.mockStop = null;
    debugSetL10n(const Locale('en'));
  });

  group('bilingual replies', () {
    test(
      'a question keeps one shuffle and one correct index in both languages',
      () {
        final raw = jsonEncode({
          'id': {
            'question': 'Mengapa?',
            'correct': 'Benar',
            'wrong': ['A', 'B', 'C'],
            'explanation': 'Karena.',
          },
          'en': {
            'question': 'Why?',
            'correct': 'Right',
            'wrong': ['X', 'Y', 'Z'],
            'explanation': 'Because.',
          },
        });
        for (var i = 0; i < 20; i++) {
          final q = AiQuizService.instance.parseQuestion(
            raw,
            QuizQuestionType.multipleChoice,
            lang: 'id',
          )!;
          expect(q.lang, 'id');
          expect(q.options[q.correctIndex], 'Benar');
          expect(q.alt!.lang, 'en');
          expect(q.alt!.options[q.correctIndex], 'Right');
          // Same permutation: each Indonesian option sits where its English twin sits.
          const pairs = {'Benar': 'Right', 'A': 'X', 'B': 'Y', 'C': 'Z'};
          for (var k = 0; k < 4; k++) {
            expect(q.alt!.options[k], pairs[q.options[k]]);
          }
        }
      },
    );

    test(
      'a twin with a different option count is dropped, the question kept',
      () {
        final raw = jsonEncode({
          'id': {
            'question': 'Mengapa?',
            'correct': 'Benar',
            'wrong': ['A', 'B', 'C'],
          },
          'en': {
            'question': 'Why?',
            'correct': 'Right',
            'wrong': ['X'],
          },
        });
        final q = AiQuizService.instance.parseQuestion(
          raw,
          QuizQuestionType.multipleChoice,
          lang: 'id',
        )!;
        expect(q.alt, isNull);
        expect(q.options, hasLength(4));
      },
    );

    test(
      'an explanation keeps its twin; a changed correct option is rejected',
      () {
        Map<String, Object> side(String correct, int steps) => {
          'correct_option': correct,
          'why_correct': 'w',
          'why_wrong': 'x',
          'key_idea': 'k',
          'steps': [for (var i = 0; i < steps; i++) 's$i'],
        };
        final ok = AiQuizService.parseAnswerExplanation(
          jsonEncode({'id': side('Benar', 2), 'en': side('Right', 2)}),
          correctOption: 'Benar',
          studentAnswer: 'Salah',
          lang: 'id',
        )!;
        expect(ok.lang, 'id');
        expect(ok.alt!.lang, 'en');
        expect(ok.alt!.steps, hasLength(2));
        final badTwin = AiQuizService.parseAnswerExplanation(
          jsonEncode({'id': side('Benar', 2), 'en': side('Right', 3)}),
          correctOption: 'Benar',
          studentAnswer: 'Salah',
          lang: 'id',
        )!;
        expect(badTwin.alt, isNull, reason: 'step counts must match');
        expect(
          AiQuizService.parseAnswerExplanation(
            jsonEncode({'id': side('Salah', 2), 'en': side('Wrong', 2)}),
            correctOption: 'Benar',
            studentAnswer: 'Salah',
            lang: 'id',
          ),
          isNull,
        );
      },
    );

    test('the system prompt is the owner text and asks for "id" and "en"', () {
      final prompt = AiQuizService.questionPrompt(
        waste: ScannedWaste.fromLabel('botol plastik'),
        type: QuizQuestionType.multipleChoice,
        difficulty: QuizDifficulty.easy,
        angleText: 'massa jenis',
      );
      expect(prompt, contains('{"id": {...}, "en": {...}}'));
      expect(prompt, isNot(contains('Bahasa Indonesia')));
    });
  });

  group('History translation cache', () {
    late Directory dir;
    late ScanRecordStore store;
    setUp(() async {
      dir = Directory.systemTemp.createTempSync('l2-cache-');
      store = ScanRecordStore(customFile: File('${dir.path}/records.json'));
      await store.load();
      await store.addRecord(_record());
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test(
      'one AI call per record and language, none on reopen; text in English',
      () async {
        var calls = 0;
        String? prompt;
        AiQuizService.instance.mockSendExecute =
            (p, {imageBytes, isUser = false}) async {
              calls++;
              prompt = p;
              return _reply(rightEn: 'Its density is higher');
            };
        expect(
          await HistoryTranslationService.ensure(
            store,
            store.records.first,
            'en',
          ),
          isTrue,
        );
        expect(
          await HistoryTranslationService.ensure(
            store,
            store.records.first,
            'en',
          ),
          isTrue,
        );
        expect(calls, 1);
        expect(prompt, contains('English'));
        final shown = store.records.first.localized('en');
        expect(shown.itemName, 'Plastic bottle');
        expect(shown.questions.first.rightAnswer, 'Its density is higher');
        expect(shown.questions.first.isCorrect, isFalse);
        // Saved: a reloaded store still has it, and Indonesian stays the original.
        final reloaded = ScanRecordStore(
          customFile: File('${dir.path}/records.json'),
        );
        await reloaded.load();
        expect(
          reloaded.records.first.translations['en']!.itemName,
          'Plastic bottle',
        );
        expect(
          reloaded.records.first.localized('id').itemName,
          'Botol plastik',
        );
      },
    );

    test('a slightly reworded answer still maps to its option (index, not wording)', () async {
      AiQuizService.instance.mockSendExecute = (p, {imageBytes, isUser = false}) async =>
          _reply(rightEn: 'The density is higher.', yourEn: 'its density is lower');
      expect(await HistoryTranslationService.ensure(store, store.records.first, 'en'), isTrue);
      final q = store.records.first.localized('en').questions.first;
      expect(q.rightAnswer, 'Its density is higher');
      expect(q.yourAnswer, 'Its density is lower');
    });

    test('records saved without options (before H3) translate their answers as text', () async {
      final old = _record();
      final noOptions = old.copyWith(questions: [
        RecordQuestion(question: old.questions.first.question, yourAnswer: old.questions.first.yourAnswer,
            rightAnswer: old.questions.first.rightAnswer, isCorrect: false),
      ]);
      await store.clearRecords();
      await store.addRecord(noOptions);
      Map<String, dynamic>? sent;
      AiQuizService.instance.mockSendExecute = (p, {imageBytes, isUser = false}) async {
        sent = jsonDecode(p.substring(p.indexOf('Data: ') + 6)) as Map<String, dynamic>;
        return jsonEncode({'en': {'item': 'Plastic bottle', 'questions': [
          {'question': 'Why?', 'yourAnswer': 'Lower density', 'rightAnswer': 'Higher density'},
        ]}});
      };
      expect(await HistoryTranslationService.ensure(store, store.records.first, 'en'), isTrue);
      expect((sent!['questions'] as List).first.containsKey('options'), isFalse);
      expect(store.records.first.localized('en').questions.first.rightAnswer, 'Higher density');
    });

    test(
      'a reply that changes the correct answer is rejected and nothing is saved',
      () async {
        AiQuizService.instance.mockSendExecute =
            (p, {imageBytes, isUser = false}) async => _reply(
              rightEn: 'It weighs more',
            ); // not the translated correct option
        expect(
          await HistoryTranslationService.ensure(
            store,
            store.records.first,
            'en',
          ),
          isFalse,
        );
        AiQuizService.instance.mockSendExecute =
            (p, {imageBytes, isUser = false}) async => _reply(
              rightEn: 'Its density is lower',
              yourEn: 'Its density is higher',
            ); // answers swapped
        expect(
          await HistoryTranslationService.ensure(
            store,
            store.records.first,
            'en',
          ),
          isFalse,
        );
        expect(store.records.first.translations, isEmpty);
      },
    );

    test(
      'offline: false, nothing saved, the original stays (no local text)',
      () async {
        AiQuizService.instance.mockSendExecute =
            (p, {imageBytes, isUser = false}) async => null;
        expect(
          await HistoryTranslationService.ensure(
            store,
            store.records.first,
            'en',
          ),
          isFalse,
        );
        expect(store.records.first.localized('en').itemName, 'Botol plastik');
      },
    );

    test('an explanation twin from creation needs no translation call', () {
      final r = _record().copyWith(
        questions: [
          _record().questions.first.copyWith(
            explanation: const QuizExplanation(
              summary: 's',
              correctAnswerReason: 'r',
              keyIdea: 'k',
              groundingStatus: GroundingStatus.gemmaUngrounded,
              lang: 'id',
              alt: QuizExplanation(
                summary: 'S',
                correctAnswerReason: 'R',
                keyIdea: 'K',
                groundingStatus: GroundingStatus.gemmaUngrounded,
                lang: 'en',
              ),
            ),
          ),
        ],
      );
      expect(r.explanationIn(0, 'en')!.correctAnswerReason, 'R');
      expect(
        HistoryTranslationService.payloadFor(
          r,
          'en',
        )['questions'].first.containsKey('explanation'),
        isFalse,
      );
    });
  });

  test(
    'old records migrate to schema 5 as Indonesian with no translations',
    () {
      final old = ScanRecord.fromJson({
        ..._record().toJson()..remove('lang'),
        'schemaVersion': 4,
      });
      expect(old.schemaVersion, 5);
      expect(old.lang, 'id');
      expect(old.translations, isEmpty);
      expect(old.needsTranslation('en'), isTrue);
      expect(old.needsTranslation('id'), isFalse);
    },
  );

  group('English bank files', () {
    Map<String, Map<String, dynamic>> items(String obj, String pool) => {
      for (final o
          in (jsonDecode(File(obj).readAsStringSync())['objects'] as List))
        for (final i in o['items'] as List)
          i['id'] as String: Map<String, dynamic>.from(i),
      for (final i
          in jsonDecode(File(pool).readAsStringSync())['items'] as List)
        i['id'] as String: Map<String, dynamic>.from(i),
    };
    final id = items(
      'assets/quiz/object_bank_draft.json',
      'assets/quiz/question_bank_draft.json',
    );
    final en = items(
      'assets/quiz/object_bank_draft.en.json',
      'assets/quiz/question_bank_draft.en.json',
    );

    test(
      'same ids, option counts, rubric counts and status; marked for review',
      () {
        expect(en.keys.toSet(), id.keys.toSet());
        for (final k in id.keys) {
          expect(en[k]!['type'], id[k]!['type'], reason: k);
          expect(en[k]!['status'], id[k]!['status'], reason: k);
          expect(
            (en[k]!['wrong'] as List?)?.length,
            (id[k]!['wrong'] as List?)?.length,
            reason: k,
          );
          expect(
            (en[k]!['rubricPoints'] as List?)?.length,
            (id[k]!['rubricPoints'] as List?)?.length,
            reason: k,
          );
        }
        for (final f in [
          'object_bank_draft.en.json',
          'question_bank_draft.en.json',
        ]) {
          expect(
            jsonDecode(
              File('assets/quiz/$f').readAsStringSync(),
            )['translation'],
            contains('needs owner review'),
          );
        }
      },
    );

    test('a bank question has the same correct index in both languages', () {
      final bank =
          QuestionBank.fromJson(
            File('assets/quiz/object_bank_draft.json').readAsStringSync(),
            File('assets/quiz/question_bank_draft.json').readAsStringSync(),
          )..addEnglish(
            File('assets/quiz/object_bank_draft.en.json').readAsStringSync(),
            File('assets/quiz/question_bank_draft.en.json').readAsStringSync(),
          );
      for (final lang in ['en', 'id']) {
        debugSetL10n(Locale(lang));
        final qs = bank.questionsFor(
          ScannedWaste.fromLabel('botol plastik'),
          QuizQuestionType.multipleChoice,
          random: Random(1),
          includeDrafts: true,
        );
        expect(qs, isNotEmpty);
        for (final q in qs) {
          expect(q.lang, lang);
          final idText = lang == 'id'
              ? q.options[q.correctIndex]
              : q.alt!.options[q.correctIndex];
          expect(id[q.bankId]!['correct'], idText, reason: q.bankId);
        }
      }
      // An English item name finds the same object.
      expect(
        bank.matchObject(ScannedWaste.fromLabel('plastic bottle')),
        'botol_plastik',
      );
    });
  });

  test('Learn content picks i18n in the app language, else the original field', () {
    final set = QuizSet.fromMap({
      'title': 'Kuis Sampah', 'description': 'Asli',
      'i18n': {'en': {'title': 'Waste Quiz'}},
    }, 's1');
    final q = QuizQuestion.fromMap({
      'question': 'Apa?', 'options': ['a', 'b'], 'correctIndex': 1,
      'i18n': {'en': {'question': 'What?', 'options': ['A']}},
    }, 'q1');
    debugSetL10n(const Locale('en'));
    expect(set.title, 'Waste Quiz');
    expect(set.description, 'Asli', reason: 'missing field falls back');
    expect(q.question, 'What?');
    expect(q.options, ['a', 'b'], reason: 'a list of another length is not used');
    expect(set.toMap()['title'], 'Kuis Sampah', reason: 'toMap keeps the original');
    debugSetL10n(const Locale('id'));
    expect(set.title, 'Kuis Sampah');
  });

  test('switching the language stops speech', () async {
    SharedPreferences.setMockInitialValues({});
    var stops = 0;
    QuizTtsService.instance.mockStop = () async => stops++;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(appLocaleProvider.notifier).setLocale(const Locale('en'));
    final before = stops;
    c.read(appLocaleProvider.notifier).setLocale(const Locale('id'));
    expect(stops, greaterThan(before));
  });

  test('no user-visible ELIO left in the ARB files', () {
    for (final f in ['lib/l10n/app_en.arb', 'lib/l10n/app_id.arb']) {
      final arb =
          jsonDecode(File(f).readAsStringSync()) as Map<String, dynamic>;
      for (final e in arb.entries.where((e) => !e.key.startsWith('@'))) {
        expect(
          RegExp(r'\bELIO\b').hasMatch('${e.value}'),
          isFalse,
          reason: '${e.key} in $f',
        );
      }
    }
  });

  test('the hard-coded string audit is 0', () {
    final r = Process.runSync('python3', [
      'tools/l10n/audit_strings.py',
      '--count',
    ]);
    expect('${r.stdout}'.trim(), '0', reason: '${r.stderr}');
  });
}
