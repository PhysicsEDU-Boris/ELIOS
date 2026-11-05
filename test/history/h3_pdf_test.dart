import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/quiz_pdf_service.dart';
import 'h3_fixture.dart';

String streams(List<int> bytes) =>
    RegExp(
      r'stream\n(.*?)\nendstream',
      dotAll: true,
    ).allMatches(latin1.decode(bytes)).map((m) {
      try {
        return latin1.decode(zlib.decode(latin1.encode(m[1]!)));
      } catch (_) {
        return '';
      }
    }).join();
void main() {
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
}
