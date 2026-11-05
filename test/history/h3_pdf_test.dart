import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/services/quiz_pdf_service.dart';
import 'h3_fixture.dart';

List<String> contentStreams(List<int> bytes) =>
    RegExp(
      r'stream\n(.*?)\nendstream',
      dotAll: true,
    ).allMatches(latin1.decode(bytes)).map((m) {
      try {
        return latin1.decode(zlib.decode(latin1.encode(m[1]!)));
      } catch (_) {
        return '';
      }
    }).toList();
String streams(List<int> bytes) => contentStreams(bytes).join();
String lastPageContent(List<int> bytes) {
  final pdf = latin1.decode(bytes);
  final pages = RegExp(
    r'/Type\s*/Page(?=[/\s>])(?:(?!endobj).)*?/Contents\s*(\d+)\s+0\s+R',
    dotAll: true,
  ).allMatches(pdf);
  final id = pages.last[1]!;
  final object = RegExp(
    '(?:^|\\n)$id 0 obj\\s*(.*?)\\s*endobj',
    dotAll: true,
  ).firstMatch(pdf)![1]!;
  final stream = RegExp(
    r'stream\n(.*?)\nendstream',
    dotAll: true,
  ).firstMatch(object)![1]!;
  return latin1.decode(zlib.decode(latin1.encode(stream)));
}

void main() {
  // H3 copy is asserted in Indonesian (decision 0185).
  setUpAll(() => debugSetL10n(const Locale('id')));
  tearDownAll(() => debugSetL10n(const Locale('en')));
  TestWidgetsFlutterBinding.ensureInitialized();
  for (var mask = 0; mask < 16; mask++) {
    test(
      'question PDF honours include flags $mask and omits every source field',
      () async {
        final dir = Directory.systemTemp.createTempSync('h3-pdf-');
        addTearDown(() => dir.deleteSync(recursive: true));
        final photo = File('${dir.path}/scan.jpg')
          ..writeAsBytesSync(img.encodeJpg(img.Image(width: 90, height: 240)));
        final record = h3Record(photo: photo.path);
        var calls = 0;
        AiQuizService.instance.mockSendExecute =
            (_, {imageBytes, isUser = false}) async {
              calls++;
              return null;
            };
        addTearDown(() => AiQuizService.instance.mockSendExecute = null);
        final flags = QuestionPdfOptions(
          answers: mask & 1 != 0,
          explanation: mask & 2 != 0,
          photo: mask & 4 != 0,
          notes: mask & 8 != 0,
        );
        final bytes = await QuizPdfService.generateQuestionPdfBytes(
          record,
          0,
          options: flags,
        );
        final pdf = latin1.decode(bytes);
        final content = RegExp(
          r'\(([^()]*)\)',
        ).allMatches(streams(bytes)).map((m) => m[1]).join(' ');
        expect(pdf, startsWith('%PDF-'));
        expect(
          pdf,
          matches(RegExp(r'/MediaBox\s*\[0 0 595\.27559 841\.88976\]')),
        );
        expect(content.contains('Campur'), flags.answers);
        expect(content.contains('Baterai dapat'), flags.explanation);
        expect(content.contains('Cara melakukannya'), flags.explanation);
        expect(content.contains('Ruang catatan'), flags.notes);
        expect(RegExp(r'/Subtype\s*/Image').hasMatch(pdf), flags.photo);
        for (final forbidden in [
          'SOURCE_MUST_NOT_RENDER',
          'MODULE_MUST_NOT_RENDER',
          'QUOTE_MUST_NOT_RENDER',
          'Sumber:',
          'Learn more',
          'Physics',
          'Mengapa plastik harus bersih?',
        ]) {
          expect(content, isNot(contains(forbidden)));
        }
        expect(calls, 0);
        if (mask == 15) {
          final path = await QuizPdfService.saveQuestion(
            record,
            0,
            options: flags,
            targetDir: dir,
          );
          expect(File(path).existsSync(), isTrue);
          expect(path, endsWith('ELIOS_Wadah-earphone_Q1.pdf'));
          final artifacts = Directory('/tmp/elios-h3-artifacts')
            ..createSync(recursive: true);
          File('${artifacts.path}/question.pdf').writeAsBytesSync(bytes);
        }
      },
    );
  }
  test(
    'notes heading stays with the writing lines across page breaks',
    () async {
      for (var length = 40; length <= 180; length += 5) {
        final record = ScanRecord(
          id: 'notes-layout',
          time: DateTime(2026),
          itemName: 'Benda',
          category: ScanCategory.recyclable,
          questions: [
            RecordQuestion(
              question: 'Jelaskan jawabanmu.',
              yourAnswer: List.filled(
                length,
                'Penjelasan panjang tetap tersimpan lengkap.',
              ).join(' '),
              rightAnswer: 'Jawaban acuan.',
              isCorrect: false,
            ),
          ],
        );
        final bytes = await QuizPdfService.generateQuestionPdfBytes(
          record,
          0,
          options: const QuestionPdfOptions(explanation: false, notes: true),
        );
        final lastPage = lastPageContent(bytes);
        final text = RegExp(
          r'\(([^()]*)\)',
        ).allMatches(lastPage).map((m) => m[1]).join(' ');
        expect(
          text,
          contains('Ruang catatan'),
          reason: 'Notes need their heading, including at length $length',
        );
      }
    },
  );
  test(
    'Android Save PDF writes through Downloads without an AI request',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel('elio/pdf');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });
      var saves = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'saveToDownloads');
        final args = call.arguments as Map;
        expect(args['filename'], 'ELIOS_Wadah-earphone_Q1.pdf');
        expect(
          latin1.decode((args['bytes'] as List<int>).take(5).toList()),
          '%PDF-',
        );
        saves++;
        return 'Download/ELIOS/ELIOS_Wadah-earphone_Q1.pdf';
      });
      expect(
        await QuizPdfService.saveQuestion(h3Record(), 0),
        'Download/ELIOS/ELIOS_Wadah-earphone_Q1.pdf',
      );
      expect(saves, 1);
    },
  );
  test(
    'Android Save PDF reports native storage failure instead of success',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel('elio/pdf');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'pdf_save_failed');
      });
      await expectLater(
        QuizPdfService.saveQuestion(h3Record(), 0),
        throwsA(isA<PlatformException>()),
      );
    },
  );
}
