import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/models/scanned_waste.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/history_explanation_service.dart';
import 'package:elio/services/quiz_explanation_service.dart';
import 'package:elio/services/quiz_pdf_service.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:elio/services/scan_record_store.dart';

final valid = {
  'correct_option': 'Pilah',
  'why_correct': 'Pemilahan menjaga bahan tetap bersih.',
  'why_wrong': 'Mencampur mengotori bahan.',
  'key_idea': 'Pisahkan bahan sebelum didaur ulang.',
  'steps': ['Pisahkan bahan.', 'Serahkan ke tempat daur ulang.'],
};
const question = GeneratedQuestion(
  type: QuizQuestionType.multipleChoice,
  question: 'Apa yang harus dilakukan?',
  options: ['Pilah', 'Campur'],
  correctIndex: 0,
);
ScanRecord sample({String answer = 'Campur'}) => ScanRecord(
  id: 'test',
  time: DateTime(2026),
  itemName: 'Botol',
  category: ScanCategory.recyclable,
  questions: [
    RecordQuestion(
      question: question.question,
      options: question.options,
      yourAnswer: answer,
      rightAnswer: 'Pilah',
      isCorrect: answer == 'Pilah',
    ),
  ],
);

void main() {
  // H3 copy is asserted in Indonesian (decision 0185).
  setUpAll(() => debugSetL10n(const Locale('id')));
  tearDownAll(() => debugSetL10n(const Locale('en')));
  TestWidgetsFlutterBinding.ensureInitialized();
  final ai = AiQuizService.instance;
  tearDown(() async {
    ai.mockSendExecute = null;
    await ai.cancel();
  });
  test(
    'offline explanation never invents a category reason or takeaway',
    () async {
      ai.mockSendExecute = (_, {imageBytes, isUser = false}) async => null;
      final result = await QuizExplanationService.generate(
        question: question,
        scan: ScannedWaste.fromLabel('botol'),
        selectedIndex: 1,
      );
      expect(result.isUnavailable, isTrue);
      expect(result.correctAnswerReason, isEmpty);
      expect(result.learningTakeaway, isEmpty);
    },
  );
  for (final bad in [
    'not json',
    '[]',
    jsonEncode({...valid, 'why_correct': ''}),
    jsonEncode({...valid, 'key_idea': ' '}),
    jsonEncode({...valid, 'correct_option': 'Campur'}),
    jsonEncode({...valid, 'why_wrong': 2}),
    jsonEncode({...valid, 'steps': List.filled(6, 'Langkah')}),
    jsonEncode({...valid, 'key_idea': 'x' * 601}),
    jsonEncode({
      ...valid,
      'steps': ['x' * 241],
    }),
  ]) {
    test(
      'reject invalid explanation ${bad.substring(0, bad.length.clamp(0, 35))}',
      () {
        expect(
          AiQuizService.parseAnswerExplanation(
            bad,
            correctOption: 'Pilah',
            studentAnswer: 'Campur',
          ),
          isNull,
        );
      },
    );
  }
  test(
    'reviewed wrongWhy wins and right answer always has empty why_wrong',
    () {
      final e = AiQuizService.parseAnswerExplanation(
        jsonEncode(valid),
        correctOption: 'Pilah',
        studentAnswer: 'Campur',
        bankId: 'reviewed',
        wrongWhy: {'Campur': 'Alasan yang ditinjau.'},
      )!;
      expect(e.selectedAnswerFeedback, 'Alasan yang ditinjau.');
      expect(e.source, 'aiWithBank');
      expect(e.generatedAt, isNotNull);
      expect(
        AiQuizService.parseAnswerExplanation(
          jsonEncode(valid),
          correctOption: 'Pilah',
          studentAnswer: 'Pilah',
        )!.selectedAnswerFeedback,
        isEmpty,
      );
    },
  );
  test(
    'one retry, user slot and exact saved answer in structured input',
    () async {
      var calls = 0;
      ai.mockSendExecute = (prompt, {imageBytes, isUser = false}) async {
        expect(isUser, isTrue);
        expect(prompt, contains('"student_answer":"  Campur  "'));
        calls++;
        return calls == 1 ? '{}' : jsonEncode(valid);
      };
      final e = await ai.explainAnswer(
        itemName: 'Botol',
        category: 'recyclable',
        question: question.question,
        options: question.options,
        correctOption: 'Pilah',
        studentAnswer: '  Campur  ',
        difficulty: 'easy',
      );
      expect(calls, 2);
      expect(e!.isComplete, isTrue);
    },
  );
  test('one retry then unavailable, preserving reviewed bank text', () async {
    var calls = 0;
    ai.mockSendExecute = (_, {imageBytes, isUser = false}) async {
      calls++;
      return '{}';
    };
    final e = await QuizExplanationService.generate(
      question: const GeneratedQuestion(
        type: QuizQuestionType.multipleChoice,
        question: 'Q',
        options: ['Pilah', 'Campur'],
        correctIndex: 0,
        bankId: 'reviewed',
        explanation: 'Teks bank ditinjau.',
        wrongWhy: {'Campur': 'Alasan ditinjau.'},
      ),
      scan: ScannedWaste.fromLabel('botol'),
      selectedIndex: 1,
    );
    expect(calls, 2);
    expect(e.correctAnswerReason, 'Teks bank ditinjau.');
    expect(e.selectedAnswerFeedback, 'Alasan ditinjau.');
    expect(e.isComplete, isFalse);
  });
  test(
    'two opens share request; reopening, disk reload and PDF never call AI again',
    () async {
      final dir = Directory.systemTemp.createTempSync('h3-cache-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = ScanRecordStore(
        customFile: File('${dir.path}/records.json'),
      );
      final record = sample();
      await store.addRecord(record);
      var calls = 0;
      final reply = Completer<String?>();
      ai.mockSendExecute = (_, {imageBytes, isUser = false}) {
        calls++;
        return reply.future;
      };
      final first = HistoryExplanationService.load(store, record, 0);
      final simultaneous = HistoryExplanationService.load(store, record, 0);
      reply.complete(jsonEncode(valid));
      await Future.wait([first, simultaneous]);
      await HistoryExplanationService.load(store, record, 0);
      final reload = ScanRecordStore(
        customFile: File('${dir.path}/records.json'),
      );
      await reload.load();
      final result = await HistoryExplanationService.load(
        reload,
        reload.records.single,
        0,
      );
      expect(result.steps, valid['steps']);
      expect(result.source, 'ai');
      expect(
        await QuizPdfService.generateQuestionPdfBytes(reload.records.single, 0),
        isNotEmpty,
      );
      expect(calls, 1);
      expect(reload.records.single.questions.single.yourAnswer, 'Campur');
    },
  );
  test(
    'old schema migrates, removing local templates but retaining bank and source fields',
    () {
      final raw = sample().toJson()..['schemaVersion'] = 3;
      final questions = raw['questions'] as List;
      (questions.single as Map)['explanation'] = {
        'summary': 'Invented',
        'correctAnswerReason': 'Berdasarkan klasifikasi',
        'learningTakeaway': 'Ingat: botol masuk',
        'groundingStatus': 'gemmaUngrounded',
        'sourceSection': '1.3',
      };
      final old = ScanRecord.fromJson(raw);
      expect(old.schemaVersion, 5);
      expect(old.questions.single.explanation!.correctAnswerReason, isEmpty);
      expect(old.questions.single.explanation!.sourceSection, '1.3');
      (questions.single as Map)['explanation'] = {
        'summary': 'Reviewed',
        'correctAnswerReason': 'Reviewed',
        'learningTakeaway': 'Ingat: botol masuk',
        'groundingStatus': 'bankGrounded',
        'bankId': 'reviewed',
      };
      final bank = ScanRecord.fromJson(raw).questions.single;
      expect(bank.explanation!.correctAnswerReason, 'Reviewed');
      expect(bank.explanation!.learningTakeaway, isEmpty);
      expect(bank.bankExplanation, 'Reviewed');
    },
  );
  test(
    'offline result is saved; only explicit retry can request it again',
    () async {
      final dir = Directory.systemTemp.createTempSync('h3-offline-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = ScanRecordStore(
        customFile: File('${dir.path}/records.json'),
      );
      final record = sample();
      await store.addRecord(record);
      var calls = 0;
      ai.mockSendExecute = (_, {imageBytes, isUser = false}) async {
        calls++;
        return null;
      };
      expect(
        (await HistoryExplanationService.load(store, record, 0)).isUnavailable,
        isTrue,
      );
      expect(calls, 2);
      await HistoryExplanationService.load(store, record, 0);
      expect(calls, 2);
      ai.mockSendExecute = (_, {imageBytes, isUser = false}) async {
        calls++;
        return jsonEncode(valid);
      };
      expect(
        (await HistoryExplanationService.load(
          store,
          record,
          0,
          retry: true,
        )).isComplete,
        isTrue,
      );
      expect(calls, 3);
    },
  );
  test(
    'quiz explanation yields to a busy slot and aliases share one History request',
    () async {
      var calls = 0;
      final reply = Completer<String?>();
      ai.mockSendExecute = (_, {imageBytes, isUser = false}) {
        calls++;
        return reply.future;
      };
      Future<dynamic> request(String category) => ai.explainAnswer(
        itemName: 'Botol',
        category: category,
        question: question.question,
        options: question.options,
        correctOption: 'Pilah',
        studentAnswer: 'Campur',
        difficulty: 'easy',
      );
      final first = request('inorganic'), second = request('recyclable');
      expect(ai.isBusy, isTrue);
      final deferred = await QuizExplanationService.generate(
        question: question,
        scan: ScannedWaste.fromLabel('botol'),
        onlyWhenIdle: true,
      );
      expect(deferred.isUnavailable, isTrue);
      expect(deferred.generatedAt, isNull);
      expect(calls, 1);
      reply.complete(jsonEncode(valid));
      expect((await first).isComplete, isTrue);
      expect((await second).isComplete, isTrue);
      expect(calls, 1);
    },
  );
  test(
    'failed cache write preserves previous record and reports the failure',
    () async {
      final dir = Directory.systemTemp.createTempSync('h3-write-failure-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/records.json'),
          store = ScanRecordStore(customFile: File('${dir.path}/records.json'));
      final record = sample();
      await store.addRecord(record);
      file.deleteSync();
      Directory(file.path).createSync();
      final explanation = AiQuizService.parseAnswerExplanation(
        jsonEncode(valid),
        correctOption: 'Pilah',
        studentAnswer: 'Campur',
      )!;
      await expectLater(
        store.saveExplanation(record.id, 0, explanation),
        throwsA(isA<FileSystemException>()),
      );
      expect(store.records.single.questions.single.explanation, isNull);
      expect(store.records.single.questions.single.yourAnswer, 'Campur');
    },
  );
  test(
    'late TTS setup cannot speak over a newer request or after stop',
    () async {
      final tts = QuizTtsService.instance,
          stops = <Completer<void>>[],
          spoken = <String>[];
      tts.mockStop = () {
        final done = Completer<void>();
        stops.add(done);
        return done.future;
      };
      tts.mockSpeak = (text) async {
        spoken.add(text);
      };
      addTearDown(() {
        tts.mockSpeak = null;
        tts.mockStop = null;
      });
      final first = tts.speak('Pertama'), second = tts.speak('Kedua');
      stops[1].complete();
      await second;
      stops[0].complete();
      await first;
      expect(spoken, ['Kedua']);
      final third = tts.speak('Ketiga'), stopped = tts.stop();
      stops[3].complete();
      await stopped;
      stops[2].complete();
      await third;
      expect(spoken, ['Kedua']);
    },
  );
  for (final input in [
    ('', <String>['Pilah']),
    ('Soal', <String>['Pilihan lain']),
  ]) {
    test(
      'invalid saved inputs do not spend an AI request: ${input.$1}',
      () async {
        var calls = 0;
        ai.mockSendExecute = (_, {imageBytes, isUser = false}) async {
          calls++;
          return jsonEncode(valid);
        };
        final result = await ai.explainAnswer(
          itemName: 'Botol',
          category: 'recyclable',
          question: input.$1,
          options: input.$2,
          correctOption: 'Pilah',
          studentAnswer: 'Campur',
          difficulty: 'easy',
        );
        expect(result, isNull);
        expect(calls, 0);
      },
    );
  }
  test(
    'empty bank explanation retains source grounding without inventing text',
    () {
      final result = QuizExplanationService.bankExplanation(
        const GeneratedQuestion(
          type: QuizQuestionType.multipleChoice,
          question: 'Soal',
          bankId: 'reviewed',
          quote: 'Kutipan disimpan',
          sourcePage: '6',
        ),
      );
      expect(result.bankId, 'reviewed');
      expect(result.quote, 'Kutipan disimpan');
      expect(result.sourcePage, '6');
      expect(result.isUnavailable, isTrue);
      expect(result.correctAnswerReason, isEmpty);
    },
  );
}
