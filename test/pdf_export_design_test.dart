// Quiz PDF export redesign (decision 0228, Figma "17 · Quiz PDF export · A4"):
// the full report and the single-question export, in EN and ID, light and
// dark, plus the three old export bugs and the theme setting.
// PDF_RENDER=<dir> writes every PDF there (rendered to PNG for the PR by
// tools/pdf/render_pdf_pages.swift).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:elio/Screens/question_explanation_screen.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/services/ai_quiz_service.dart' show QuizDifficulty;
import 'package:elio/services/quiz_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _out = String.fromEnvironment('PDF_RENDER');

const _why =
    'Secara fisik, ketika sisa makanan dipotong kecil, kita menciptakan lebih '
    'banyak permukaan yang terbuka bagi mikroba dan jamur.';
const _idea =
    'Luas permukaan yang lebih besar memudahkan mikroba pengurai menjangkau '
    'seluruh bagian limbah.';

/// A bank explanation: its summary and its reason are the same text.
const _mcExplanation = QuizExplanation(
  summary: _why,
  correctAnswerReason: _why,
  selectedAnswerFeedback:
      'Potongan kecil tidak menyimpan panas lebih banyak; justru lebih mudah '
      'melepaskan panas ke udara.',
  keyIdea: _idea,
  steps: [
    'Potong sisa makanan menjadi bagian kecil.',
    'Luas permukaan yang terpapar udara naik.',
    'Mikroba punya lebih banyak tempat untuk menempel.',
    'Penguraian terjadi serentak di banyak titik.',
    'Bahan organik berubah jadi kompos lebih cepat.',
  ],
  source: 'bank',
  groundingStatus: GroundingStatus.bankGrounded,
);

const _essayExplanation = QuizExplanation(
  summary: 'Tambahkan akibatnya pada saringan.',
  correctAnswerReason: 'Kadar air berpindah ke kertas sehingga menggumpal.',
  keyIdea: 'Bahan basah membuat campuran menggumpal.',
  essayScore: 6,
  essayFeedback: 'Tambahkan akibatnya pada saringan.',
  rubricRows: [
    RubricRow(
      criterion: 'Accuracy',
      maxScore: 4,
      awardedScore: 3,
      comment: 'Sebabnya sudah benar.',
    ),
    RubricRow(criterion: 'Key terms', maxScore: 3, awardedScore: 1),
    RubricRow(criterion: 'Completeness', maxScore: 2, awardedScore: 1),
    RubricRow(criterion: 'Clarity', maxScore: 1, awardedScore: 1),
  ],
  groundingStatus: GroundingStatus.gemmaUngrounded,
);

const _q1 = RecordQuestion(
  question:
      'Mengapa sisa makanan yang dipotong kecil terurai lebih cepat daripada '
      'potongan besar secara fisik?',
  yourAnswer: 'Potongan kecil menyimpan panas lebih banyak',
  rightAnswer: 'Luas permukaan lebih besar mempercepat kontak mikroba',
  isCorrect: false,
  explanation: _mcExplanation,
);

/// A skipped essay with nothing saved.
const _q2 = RecordQuestion(
  question:
      'Jika sisa makanan yang basah dicampur dengan sampah kertas kering, '
      'bagaimana pengaruhnya pada pemilahan dengan saringan?',
  yourAnswer: '(dilewati)',
  rightAnswer: 'Kadar air berpindah ke kertas sehingga menggumpal.',
  isCorrect: false,
  isEssay: true,
  essayScore: 0,
);

const _q3 = RecordQuestion(
  question: 'Mengapa mengeringkan sisa makanan membantu suhu kompos stabil?',
  yourAnswer: 'Mengurangi air yang menyerap kalor',
  rightAnswer: 'Mengurangi air yang menyerap kalor',
  isCorrect: true,
  explanation: _mcExplanation,
);

ScanRecord _record({
  List<RecordQuestion> questions = const [_q1, _q2, _q3],
  String item = 'Sisa makanan',
  String? photo,
}) => ScanRecord(
  id: 'scan-1794884899453-7c1e8f47',
  time: DateTime(2026, 11, 17, 9, 10),
  itemName: item,
  category: ScanCategory.organic,
  cropPhotoPath: photo,
  difficulty: QuizDifficulty.medium,
  questions: questions,
  trophies: questions.fold<int>(0, (sum, q) => sum + q.trophies),
);

/// Page count, read from the page tree root (/Type /Pages … /Count n).
int _pages(List<int> bytes) {
  final pdf = latin1.decode(bytes);
  final root = RegExp(
    r'<<(?:(?!>>).)*?/Type\s*/Pages\b(?:(?!>>).)*?>>',
    dotAll: true,
  ).firstMatch(pdf)![0]!;
  return int.parse(RegExp(r'/Count\s+(\d+)').firstMatch(root)![1]!);
}

List<String> get _texts => QuizPdfService.debugTexts!;
int _count(String text) => _texts.where((t) => t == text).length;

void _save(String name, List<int> bytes) {
  if (_out.isEmpty) return;
  File('$_out/$name.pdf')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}

/// WCAG relative luminance contrast of two opaque colours.
double _contrast(PdfColor a, PdfColor b) {
  double lum(PdfColor c) {
    double ch(double v) =>
        v <= .03928 ? v / 12.92 : pow((v + .055) / 1.055, 2.4).toDouble();
    return .2126 * ch(c.red) + .7152 * ch(c.green) + .0722 * ch(c.blue);
  }

  final la = lum(a), lb = lum(b);
  return (max(la, lb) + .05) / (min(la, lb) + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late String photo;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('pdf-design-');
    // A busy 1600 x 1200 photo, like a phone scan.
    final image = img.Image(width: 1600, height: 1200);
    final r = Random(7);
    for (final p in image) {
      p
        ..r = r.nextInt(256)
        ..g = (p.x * 255 ~/ 1600)
        ..b = (p.y * 255 ~/ 1200);
    }
    photo = (File(
      '${dir.path}/scan.jpg',
    )..writeAsBytesSync(img.encodeJpg(image, quality: 95))).path;
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    QuizPdfService.darkTheme.value = false;
    QuizPdfService.debugTexts = [];
    debugSetL10n(const Locale('id'));
  });
  tearDown(() {
    QuizPdfService.debugTexts = null;
    debugSetL10n(const Locale('en'));
  });

  group('full report', () {
    for (final lang in ['id', 'en']) {
      for (final dark in [false, true]) {
        final mode = '$lang ${dark ? 'dark' : 'light'}';
        test('renders: cover and one page per question, $mode', () async {
          debugSetL10n(Locale(lang));
          final bytes = await QuizPdfService.generatePdfBytes(
            _record(photo: photo),
            dark: dark,
          );
          _save('report_${lang}_${dark ? 'dark' : 'light'}', bytes);
          expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
          expect(_pages(bytes), 4);
          expect(
            latin1.decode(bytes),
            matches(RegExp(r'/MediaBox\s*\[0 0 595\.27559 841\.88976\]')),
          );
          // Target: under 1 MB for a 3-question report with a photo.
          expect(bytes.length, lessThan(1024 * 1024));
          // Google Sans Flex is embedded.
          expect(latin1.decode(bytes), contains('GoogleSansFlex'));
          expect(_texts, contains('Sisa makanan'));
          expect(_texts, contains(lang == 'id' ? 'Peta soal' : 'Question map'));
          // The map names each question's page.
          for (final page in [2, 3, 4]) {
            expect(
              _texts.where((t) => t.endsWith(' $page')),
              isNotEmpty,
              reason: 'map row for page $page',
            );
          }
        });
      }
    }

    test(
      '0 correct, partial and all correct have their own headline',
      () async {
        await QuizPdfService.generatePdfBytes(
          _record(questions: const [_q1, _q2]),
        );
        expect(_texts, contains('Coba lagi, kamu pasti bisa!'));
        expect(_texts, contains('NILAI: COBA LAGI'));

        await QuizPdfService.generatePdfBytes(_record());
        expect(_texts, contains('Awal yang bagus, lanjutkan!'));
        expect(_texts, contains('1/3'));

        final all = await QuizPdfService.generatePdfBytes(
          _record(questions: const [_q3, _q3]),
        );
        _save('report_all_correct', all);
        expect(_texts, contains('Sempurna, semua benar!'));
        expect(_texts, contains('NILAI: SEMPURNA'));
        expect(_texts, contains('Semua benar'));
      },
    );

    test('the tip is built from this quiz\'s key ideas', () async {
      await QuizPdfService.generatePdfBytes(_record());
      expect(_texts.where((t) => t.contains('(1) $_idea')), hasLength(1));
      // No key idea saved: a general tip, never an empty bubble.
      await QuizPdfService.generatePdfBytes(_record(questions: const [_q2]));
      expect(
        _texts,
        contains(lookupAppLocalizations(const Locale('id')).pdfTipGeneric),
      );
    });

    test('a 1-question quiz, no photo', () async {
      final bytes = await QuizPdfService.generatePdfBytes(
        _record(questions: const [_q1]),
      );
      _save('report_one_question', bytes);
      expect(_pages(bytes), 2);
      expect(latin1.decode(bytes), isNot(matches(r'/Subtype\s*/Image')));
    });

    test('a long essay answer flows onto more pages, nothing is cut', () async {
      final long = List.filled(
        120,
        'Plastik dipilah, dicuci, dicacah dan diolah kembali.',
      ).join(' ');
      final bytes = await QuizPdfService.generatePdfBytes(
        _record(
          questions: [
            RecordQuestion(
              question: 'Jelaskan proses daur ulang plastik.',
              yourAnswer: long,
              rightAnswer: 'Pilah, cuci, cacah dan proses ulang.',
              isCorrect: true,
              isEssay: true,
              essayScore: 9,
              explanation: _essayExplanation,
            ),
          ],
        ),
      );
      _save('report_long_answer', bytes);
      expect(_pages(bytes), greaterThan(2));
      expect(_count(long), 1);
      // Continuation pages get the slim header, never an empty band. (The
      // pdf package builds a page's header and footer more than once, so
      // headers are checked for presence, not counted.)
      final t = lookupAppLocalizations(const Locale('id'));
      expect(
        _texts.where((x) => x.endsWith(t.pdfContinued('Sisa makanan', 1))),
        isNotEmpty,
      );
    });
  });

  group('old export bugs', () {
    test('(a) an explanation paragraph is printed once', () async {
      await QuizPdfService.generatePdfBytes(_record(questions: const [_q1]));
      expect(_count(_why), 1);
      await QuizPdfService.generateQuestionPdfBytes(
        _record(questions: const [_q1]),
        0,
      );
      expect(_count(_why), 1);
    });

    test('(b) no page starts with an empty heading', () async {
      const record3 = [_q1, _q2, _q3];
      final bytes = await QuizPdfService.generatePdfBytes(_record());
      _save('report_no_photo', bytes);
      final t = lookupAppLocalizations(const Locale('id'));
      // Short content: exactly the cover and one page per question.
      expect(_pages(bytes), 1 + 3);
      expect(_texts.where((x) => x.trim().isEmpty), isEmpty);
      // Each question page opens with its own header and title, and no page
      // is a continuation (the old export's page 2 began with an empty
      // heading and divider lines).
      for (var i = 1; i <= 3; i++) {
        expect(_texts, contains(t.pdfQuestionOf(i, 3)));
        // Once in the cover's question map, once on its own page.
        expect(_count(record3[i - 1].question), 2);
      }
      expect(_texts.where((x) => x.contains('(lanjutan)')), isEmpty);
    });

    test('(c) an essay with saved data prints it, not "not saved"', () async {
      final t = lookupAppLocalizations(const Locale('id'));
      final graded = _record(
        questions: const [
          RecordQuestion(
            question: 'Jelaskan pengaruh air pada saringan.',
            yourAnswer: 'Karena basah.',
            rightAnswer: 'Kadar air berpindah ke kertas.',
            isCorrect: true,
            isEssay: true,
            essayScore: 6,
            explanation: _essayExplanation,
          ),
        ],
      );
      await QuizPdfService.generatePdfBytes(graded);
      expect(_texts, isNot(contains(t.pdfNoExplTitle)));
      expect(_texts, isNot(contains(t.pdfNoExplanation)));
      expect(_texts, contains('Tambahkan akibatnya pada saringan.'));
      expect(_texts, contains('Sebabnya sudah benar.'));
      expect(_texts, contains('6 / 10'));
      // The essay feedback is the summary too: still printed once.
      expect(_count('Tambahkan akibatnya pada saringan.'), 1);

      // Nothing saved (skipped): the box with its hint, never a bare line.
      await QuizPdfService.generatePdfBytes(_record(questions: const [_q2]));
      expect(_count(t.pdfNoExplTitle), 1);
      expect(_count(t.pdfNoExplHint), 1);
      expect(_texts, isNot(contains(t.pdfNoExplanation)));
      expect(_texts, contains(t.essaySkipped));
    });
  });

  group('single question', () {
    for (final lang in ['id', 'en']) {
      for (final dark in [false, true]) {
        test(
          'question and notes pages, $lang ${dark ? 'dark' : 'light'}',
          () async {
            debugSetL10n(Locale(lang));
            final t = lookupAppLocalizations(Locale(lang));
            final bytes = await QuizPdfService.generateQuestionPdfBytes(
              _record(photo: photo),
              0,
              options: QuestionPdfOptions(photo: true, notes: true, dark: dark),
            );
            _save('single_${lang}_${dark ? 'dark' : 'light'}', bytes);
            expect(_pages(bytes), 2);
            expect(latin1.decode(bytes), matches(r'/Subtype\s*/Image'));
            expect(_texts, contains(t.h3HowTo));
            expect(_texts, contains(t.pdfNotesTitle));
            expect(_texts, contains(t.pdfSign));
          },
        );
      }
    }

    test(
      'the notes prompts come from the question, not a fixed text',
      () async {
        final t = lookupAppLocalizations(const Locale('id'));
        const q = RecordQuestion(
          question: 'Mengapa botol kaca bisa didaur ulang berkali-kali?',
          yourAnswer: 'Karena berat',
          rightAnswer: 'Karena kaca dilebur tanpa turun mutu',
          isCorrect: false,
          explanation: QuizExplanation(
            summary: 'Kaca dilebur lagi.',
            correctAnswerReason: 'Kaca dilebur lagi.',
            keyIdea: 'Kaca tidak turun mutu saat dilebur.',
            source: 'bank',
            groundingStatus: GroundingStatus.bankGrounded,
          ),
        );
        await QuizPdfService.generateQuestionPdfBytes(
          _record(questions: const [q], item: 'Botol kaca'),
          0,
          options: const QuestionPdfOptions(notes: true),
        );
        expect(_texts, contains(t.pdfN1Prompt(q.question)));
        expect(
          _texts,
          contains(t.pdfCheckIdea('Kaca tidak turun mutu saat dilebur.')),
        );
        expect(_texts, contains(t.pdfCheckWrong));
        expect(_texts, contains(t.pdfChallenge('Botol kaca')));
        expect(_texts.join(' '), isNot(contains('Sisa makanan')));
        expect(_texts.join(' '), isNot(contains('luas permukaan')));
      },
    );

    test('every include option still works', () async {
      final t = lookupAppLocalizations(const Locale('id'));
      for (var mask = 0; mask < 16; mask++) {
        final o = QuestionPdfOptions(
          answers: mask & 1 != 0,
          explanation: mask & 2 != 0,
          photo: mask & 4 != 0,
          notes: mask & 8 != 0,
        );
        final bytes = await QuizPdfService.generateQuestionPdfBytes(
          _record(photo: photo),
          0,
          options: o,
        );
        expect(_texts.contains(_q1.question), o.answers, reason: '$mask');
        expect(_texts.contains(_why), o.explanation, reason: '$mask');
        expect(_texts.contains(t.h3HowTo), o.explanation, reason: '$mask');
        expect(_texts.contains(t.pdfNotesTitle), o.notes, reason: '$mask');
        expect(
          RegExp(r'/Subtype\s*/Image').hasMatch(latin1.decode(bytes)),
          o.photo,
          reason: '$mask',
        );
        expect(_pages(bytes), o.notes ? 2 : 1, reason: '$mask');
      }
    });
  });

  group('theme', () {
    testWidgets('both export sheets offer the theme, and it is saved', (
      t,
    ) async {
      debugSetL10n(const Locale('id'));
      Future<void> open(Widget sheet) async {
        await t.pumpWidget(
          MaterialApp(
            locale: const Locale('id'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SingleChildScrollView(child: sheet)),
          ),
        );
        await t.pumpAndSettle();
      }

      // Single question sheet: light by default.
      await open(QuestionExportSheet(record: _record(), questionIndex: 0));
      expect(find.text('Tema PDF'), findsOneWidget);
      expect(find.text('Terang'), findsOneWidget);
      expect(find.text('Gelap'), findsOneWidget);
      expect(QuizPdfService.darkTheme.value, isFalse);
      await t.tap(find.text('Gelap'));
      await t.pumpAndSettle();
      expect(QuizPdfService.darkTheme.value, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool('pdf_theme_dark'),
        isTrue,
      );

      // The full report sheet shows the remembered choice.
      await t.pumpWidget(
        MaterialApp(
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showQuizReportSheet(context, _record()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('quiz_report_sheet')), findsOneWidget);
      final seg = t.widget<SegmentedButton<bool>>(
        find.byKey(const ValueKey('pdf_theme')),
      );
      expect(seg.selected, {true});
      await t.tap(find.text('Terang'));
      await t.pumpAndSettle();
      expect(QuizPdfService.darkTheme.value, isFalse);
    });

    test('light is the default and the choice is remembered', () async {
      await QuizPdfService.loadTheme();
      expect(QuizPdfService.darkTheme.value, isFalse);
      expect(const QuestionPdfOptions().dark, isNull);

      await QuizPdfService.setDarkTheme(true);
      expect(QuizPdfService.darkTheme.value, isTrue);
      // A restart: the in-memory value is gone, the saved one is read back.
      QuizPdfService.darkTheme.value = false;
      await QuizPdfService.loadTheme();
      expect(QuizPdfService.darkTheme.value, isTrue);
    });

    test('the remembered theme is used unless the options name one', () async {
      Future<int> size({bool? dark}) async =>
          (await QuizPdfService.generateQuestionPdfBytes(
            _record(),
            0,
            options: QuestionPdfOptions(dark: dark),
          )).length;
      final light = await size(dark: false), darkSize = await size(dark: true);
      expect(light, isNot(darkSize), reason: 'the two themes differ');
      QuizPdfService.darkTheme.value = true;
      expect(await size(), darkSize);
      expect(await size(dark: false), light);
    });

    test('dark uses the dark ELIOS tokens; the header stays green', () {
      final light = PdfPalette(false), dark = PdfPalette(true);
      expect(dark.bg.toHex(), startsWith('#0f172a'));
      expect(dark.surface.toHex(), startsWith('#1e293b'));
      expect(dark.text.toHex(), startsWith('#f1f5f9'));
      expect(light.bg.toHex(), startsWith('#f8fafc'));
      expect(dark.green.toHex(), light.green.toHex());
      expect(dark.onGreen.toHex(), light.onGreen.toHex());
    });

    test('body text meets WCAG AA (4.5:1) in both themes', () {
      for (final p in [PdfPalette(false), PdfPalette(true)]) {
        final where = p.dark ? 'dark' : 'light';
        for (final bg in [p.bg, p.surface, p.quiet]) {
          expect(
            _contrast(p.text, bg),
            greaterThanOrEqualTo(4.5),
            reason: where,
          );
          expect(
            _contrast(p.text2, bg),
            greaterThanOrEqualTo(4.5),
            reason: where,
          );
        }
        // Text on the tinted cards and on the green header.
        for (final tone in [p.greenActive, p.err, p.warn, p.info]) {
          expect(
            _contrast(p.text, p.soft(tone)),
            greaterThanOrEqualTo(4.5),
            reason: where,
          );
        }
        expect(_contrast(p.onGreen, p.green), greaterThanOrEqualTo(4.5));
        for (final (fg, tone) in [
          (p.okText, p.greenActive),
          (p.errText, p.err),
          (p.warn, p.warn),
          (p.info, p.info),
        ]) {
          expect(
            _contrast(fg, p.soft(tone)),
            greaterThanOrEqualTo(4.5),
            reason: '$where label',
          );
        }
      }
    });
  });
}
