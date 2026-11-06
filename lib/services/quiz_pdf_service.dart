import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/quiz_explanation.dart';
import '../models/scan_record.dart';
import '../models/trophy_rules.dart';
import 'quiz_explanation_service.dart' show bankSourceTitle;

// ---------------------------------------------------------------------------
// Colors (approximated from Figma palette for PDF)
// ---------------------------------------------------------------------------
final _green = PdfColor.fromHex('00694C');
final _greenLight = PdfColor.fromHex('D0E4E2');
final _ink = PdfColor.fromHex('191C1C');
final _subtext = PdfColor.fromHex('3D4943');
final _caption = PdfColor.fromHex('6D7A73');
final _borderGray = PdfColor.fromHex('BCCAC1');
final _correctGreen = PdfColor.fromHex('00694C');
final _incorrectRed = PdfColor.fromHex('E74C3C');
final _goldYellow = PdfColor.fromHex('D89E00');

class QuestionPdfOptions {
  const QuestionPdfOptions({this.answers = true, this.explanation = true,
    this.photo = false, this.notes = false});
  final bool answers, explanation, photo, notes;
}

/// Generates and saves PDF reports for [ScanRecord] sessions.
///
/// Layout: A4 portrait, 24 pt margins (decision 0031).
class QuizPdfService {
  const QuizPdfService._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generate a PDF for [record] and save it to the reports directory.
  /// Returns the absolute file path.
  static Future<String> generateAndSave(ScanRecord record, {Directory? targetDir}) async {
    final bytes = await generatePdfBytes(record);
    final dir = targetDir ?? await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/reports');
    if (!reportsDir.existsSync()) reportsDir.createSync(recursive: true);
    final filename = _safeFilename(record);
    final file = File('${reportsDir.path}/$filename');
    file.writeAsBytesSync(bytes, flush: true);
    return file.path;
  }

  /// Generate raw PDF bytes for [record].
  static Future<Uint8List> generatePdfBytes(ScanRecord record) async {
    final bytes = await _buildBytes(record);
    return Uint8List.fromList(bytes);
  }

  /// Share / export the PDF using the system share sheet (printing package).
  static Future<void> shareOrSave(ScanRecord record) async {
    try {
      final bytes = await generatePdfBytes(record);
      final filename = _safeFilename(record);
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      debugPrint('[QuizPdfService] share failed: $e');
      rethrow;
    }
  }

  static String questionFilename(ScanRecord record, int index) {
    final item = record.itemName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    return 'ELIOS_${item.isEmpty ? 'scan' : item}_Q${index + 1}.pdf';
  }

  /// Saved text only: export must never generate or refresh an explanation.
  static Future<Uint8List> generateQuestionPdfBytes(ScanRecord record, int index,
      {QuestionPdfOptions options = const QuestionPdfOptions()}) async {
    final q = record.questions[index];
    final exp = q.explanation;
    final crop = options.photo ? await _loadCrop(record.cropPhotoPath) : null;
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32), build: (_) => [
        _text(l10n.pdfQuestionHeader(record.itemName, index + 1),
          style: pw.TextStyle(fontSize: 12, color: _green, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 16),
        if (options.answers) ...[
          _text(q.question, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          ..._answerRow(l10n.h3YourAnswer, q.yourAnswer, _ink),
          ..._answerRow(q.isEssay ? l10n.h3ReferenceAnswer : l10n.h3CorrectAnswer, q.rightAnswer, _correctGreen),
          if (q.isEssay) ..._answerRow(l10n.pdfEssayScore, q.gradingPending ? l10n.h3AwaitingGrading : '${q.essayScore}/10', _ink),
        ],
        if (options.explanation) ...[
          if (exp != null) ...[
            for (final section in <(String, String)>[
              (l10n.h3WhyCorrect, exp.correctAnswerReason),
              if (!q.isCorrect && !q.isEssay) (l10n.h3WhyWrong, exp.selectedAnswerFeedback),
              if (q.isEssay) (l10n.h3Feedback, exp.essayFeedback ?? ''),
              (l10n.h3KeyIdeaTitle, exp.keyIdea),
            ]) if (section.$2.isNotEmpty) ...[
              pw.SizedBox(height: 14), _sectionTitle(section.$1),
              pw.SizedBox(height: 6), _text(section.$2, overflow: pw.TextOverflow.span),
            ],
            if (exp.steps.isNotEmpty) ...[
              pw.SizedBox(height: 14), _sectionTitle(l10n.h3HowTo),
              for (var i = 0; i < exp.steps.length; i++)
                pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: _text('${i + 1}. ${exp.steps[i]}')),
            ],
          ],
          if (exp == null || (!exp.isComplete && !q.isEssay)) ...[
            pw.SizedBox(height: 14), _text(l10n.h3ExplanationUnavailable),
          ],
        ],
        if (crop != null) ...[pw.SizedBox(height: 16), pw.Image(crop, height: 160, fit: pw.BoxFit.contain)],
        if (options.notes) ...[
          pw.SizedBox(height: 18),
          // Keep the notes heading and writing lines together on one page.
          pw.Inseparable(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _sectionTitle(l10n.h3IncNotes),
            for (var i = 0; i < 5; i++) pw.Container(height: 24,
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGray)))),
          ])),
        ],
      ]));
    return doc.save();
  }

  static Future<String> saveQuestion(ScanRecord record, int index,
      {QuestionPdfOptions options = const QuestionPdfOptions(), Directory? targetDir}) async {
    final bytes = await generateQuestionPdfBytes(record, index, options: options);
    if (targetDir == null && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final location = await const MethodChannel('elio/pdf').invokeMethod<String>('saveToDownloads', {
        'filename': questionFilename(record, index), 'bytes': bytes,
      });
      if (location == null || location.isEmpty) throw StateError('No saved PDF location');
      return location;
    }
    final dir = targetDir ?? await getApplicationDocumentsDirectory();
    final reports = Directory('${dir.path}/reports');
    await reports.create(recursive: true);
    final file = File('${reports.path}/${questionFilename(record, index)}');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Shares the saved scan photo through the same share sheet as the reports.
  /// `printing` only shares PDFs, so the photo goes out as a one-page PDF
  /// (no extra share dependency).
  static Future<void> sharePhoto(ScanRecord record) async {
    final image = pw.MemoryImage(await File(record.cropPhotoPath!).readAsBytes());
    final doc = pw.Document()
      ..addPage(pw.Page(build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))));
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: _safeFilename(record).replaceFirst(RegExp(r'\.pdf$'), '_photo.pdf'),
    );
  }

  static Future<void> shareQuestion(ScanRecord record, int index,
      {QuestionPdfOptions options = const QuestionPdfOptions()}) async {
    await Printing.sharePdf(bytes: await generateQuestionPdfBytes(record, index, options: options),
      filename: questionFilename(record, index));
  }

  // ---------------------------------------------------------------------------
  // PDF construction
  // ---------------------------------------------------------------------------

  static Future<List<int>> _buildBytes(ScanRecord record) async {
    final doc = pw.Document();

    // Build page list — one content page + question sections.
    final allWidgets = _buildContent(record, await _loadCrop(record.cropPhotoPath));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24 * PdfPageFormat.point),
        header: (ctx) => _buildPageHeader(record, ctx.pageNumber, ctx.pagesCount),
        footer: (ctx) => _buildPageFooter(record, ctx.pageNumber, ctx.pagesCount),
        build: (ctx) => allWidgets,
      ),
    );

    return doc.save();
  }

  // ---------------------------------------------------------------------------
  // Header / Footer
  // ---------------------------------------------------------------------------

  static pw.Widget _buildPageHeader(ScanRecord record, int page, int total) {
    if (page == 1) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: _text(
                  l10n.pdfReportTitle,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _green,
                  ),
                ),
              ),
              _text(
                _dateTime(record.time),
                style: pw.TextStyle(fontSize: 10, color: _caption),
              ),
            ],
          ),
          pw.Divider(color: _green, thickness: 1.5),
          pw.SizedBox(height: 4),
        ],
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          children: [
            _text(
              'ELIOS - ${record.itemName}',
              style: pw.TextStyle(fontSize: 11, color: _subtext, fontWeight: pw.FontWeight.bold),
            ),
            pw.Spacer(),
            _text(l10n.pdfPageShort(page, total), style: pw.TextStyle(fontSize: 10, color: _caption)),
          ],
        ),
        pw.Divider(color: _borderGray),
        pw.SizedBox(height: 2),
      ],
    );
  }

  static pw.Widget _buildPageFooter(ScanRecord record, int page, int total) {
    return pw.Column(
      children: [
        pw.Divider(color: _borderGray),
        pw.Row(
          children: [
            pw.Expanded(
              child: _text(
                l10n.pdfFooter(page, total, record.id),
                style: pw.TextStyle(fontSize: 8, color: _caption),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Content
  // ---------------------------------------------------------------------------

  static Future<pw.MemoryImage?> _loadCrop(String? path) async {
    if (path == null) return null;
    try {
      final bytes = await File(path).readAsBytes();
      if (img.decodeImage(bytes) == null) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null; // Old records may point to missing or unreadable photos.
    }
  }

  static List<pw.Widget> _buildContent(ScanRecord record, pw.MemoryImage? crop) {
    final grade = gradeFor(trophies: record.trophies, totalQuestions: record.totalQuestions);
    return [
      // Session metadata table
      _sectionTitle(l10n.pdfSessionInfo),
      pw.SizedBox(height: 4),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 120,
            height: 120,
            color: PdfColor.fromHex('EAECEE'),
            alignment: pw.Alignment.center,
            child: crop == null
                ? _text(l10n.pdfPhoto, style: pw.TextStyle(fontSize: 10, color: _caption))
                : pw.Image(crop, width: 120, height: 120, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _metadataTable(record, grade)),
        ],
      ),
      pw.SizedBox(height: 16),
      // Question sections
      for (var i = 0; i < record.questions.length; i++) ...[
        pw.SizedBox(height: 8),
        ..._questionSection(i + 1, record.questions[i], record.totalQuestions),
      ],
    ];
  }

  /// "3 Nov 2026 23:29" in the app language.
  static String _dateTime(DateTime t) =>
      DateFormat.yMMMd(dateLocale).add_Hm().format(t.toLocal());

  static pw.Widget _sectionTitle(String title) => _text(
        title,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _green),
      );

  static pw.Widget _metadataTable(ScanRecord record, QuizGrade grade) {
    final rows = [
      [l10n.pdfItem, record.itemName],
      [l10n.pdfCategory, record.category.badgeLabel],
      [l10n.pdfDateTime, _dateTime(record.time)],
      [l10n.pdfDifficulty, record.difficultyLabel],
      [l10n.pdfQuestionCount, '${record.totalQuestions}'],
      [l10n.pdfCorrect, l10n.pdfCorrectOf(record.correctCount, record.totalQuestions)],
      [l10n.pdfTrophies, l10n.pdfTrophyCount(record.trophies)],
      [l10n.pdfGrade, record.questions.any((q) => q.gradingPending) ? l10n.h3AwaitingGrading : grade.label],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _borderGray, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(130),
        1: pw.FlexColumnWidth(),
      },
      children: rows.map((row) {
        return pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: _text(row[0],
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _subtext)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: _text(row[1], style: pw.TextStyle(fontSize: 10, color: _ink)),
          ),
        ]);
      }).toList(),
    );
  }

  static List<pw.Widget> _questionSection(int index, RecordQuestion q, int totalQuestions) {
    final exp = q.explanation;
    return [
        // Question header
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: q.isCorrect ? PdfColor.fromHex('E8F5F0') : PdfColor.fromHex('FDEDED'),
            border: pw.Border.all(color: q.isCorrect ? _correctGreen : _incorrectRed, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: _text(
            l10n.pdfQuestionLine(index, q.question),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink),
          ),
        ),
        pw.SizedBox(height: 4),
        // Answers
        ..._answerRow(l10n.h3YourAnswer, q.yourAnswer, q.isCorrect ? _correctGreen : _incorrectRed),
        ..._answerRow(l10n.h3CorrectAnswer, q.rightAnswer, _correctGreen),
        if (q.isEssay)
          ..._answerRow(l10n.pdfEssayScore, q.gradingPending ? l10n.h3AwaitingGrading : l10n.pdfEssayLine(q.essayScore ?? 0, q.trophies), _goldYellow),
        pw.SizedBox(height: 6),
        // Explanation section
        if (exp != null && !exp.isUnavailable) ...[
          ..._explanationSection(exp),
        ] else ...[
          _text(
            l10n.pdfNoExplanation,
            style: pw.TextStyle(fontSize: 10, color: _caption, fontStyle: pw.FontStyle.italic),
          ),
        ],
        if (index < totalQuestions) pw.Divider(color: _borderGray, height: 16),
    ];
  }

  // Keep variable-length text directly in MultiPage so it can span pages.
  static List<pw.Widget> _answerRow(String label, String value, PdfColor color) => [
    _text(label.toUpperCase(), style: pw.TextStyle(fontSize: 9,
        fontWeight: pw.FontWeight.bold, color: _caption)),
    _text(value, overflow: pw.TextOverflow.span,
        style: pw.TextStyle(fontSize: 10, color: color, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 4),
  ];

  /// "Sumber: Bank Soal ELIOS · bagian 1.3 · hal. 6 · organik-mc-01" (decision 0175).
  static String? sourceLine(QuizExplanation exp) {
    if (exp.sourceTitle == null && exp.bankId == null) return null;
    return [
      l10n.pdfSource(switch (exp.sourceTitle) {
        // Older records stored the pre-rename bank title.
        null || bankSourceTitle || 'Bank Soal ELIO' => l10n.pdfBankTitle,
        final title => title,
      }),
      if (exp.sourceSection != null) l10n.pdfSection(exp.sourceSection!),
      if (exp.sourcePage != null) l10n.pdfPage(exp.sourcePage!),
      ?exp.bankId,
    ].join(' · ');
  }

  static List<pw.Widget> _explanationSection(QuizExplanation exp) {
    return [
        _text(l10n.h3ExplanationTitle,
            overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _green)),
        pw.SizedBox(height: 4),
        if (exp.summary.isNotEmpty)
          _text(exp.summary, overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 10, color: _ink)),
        if (exp.correctAnswerReason.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _text(exp.correctAnswerReason, overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 10, color: _ink)),
        ],
        if (exp.selectedAnswerFeedback.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _text(exp.selectedAnswerFeedback,
              overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 10, color: _incorrectRed)),
        ],
        if (exp.conceptExplanation.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _text(exp.conceptExplanation, overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 10, color: _ink)),
        ],
        if (exp.comparisonRows.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _text(l10n.pdfTableCategories,
              overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _subtext)),
          pw.SizedBox(height: 4),
          _comparisonTable(exp.comparisonRows),
        ],
        if (exp.rubricRows != null && exp.rubricRows!.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _text(l10n.pdfTableScoring,
              overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _subtext)),
          pw.SizedBox(height: 4),
          _rubricTable(exp.rubricRows!),
        ],
        if (exp.learningTakeaway.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _text(
            exp.learningTakeaway,
            overflow: pw.TextOverflow.span, style: pw.TextStyle(
                fontSize: 10, fontStyle: pw.FontStyle.italic, color: _subtext),
          ),
        ],
        if (exp.quote != null) ...[
          pw.SizedBox(height: 4),
          _text('"${exp.quote}"',
              overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: _subtext)),
        ],
        if (sourceLine(exp) != null) ...[
          pw.SizedBox(height: 4),
          _text(sourceLine(exp)!, overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 9, color: _caption)),
        ],
    ];
  }

  static pw.Widget _comparisonTable(List<ComparisonRow> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: _borderGray, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(100),
        1: pw.FlexColumnWidth(),
        2: pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _greenLight),
          children: [l10n.pdfColCategory, l10n.pdfColMaterial, l10n.pdfColAccepted].map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: _text(h,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink)),
            );
          }).toList(),
        ),
        ...rows.map((row) {
          final highlight = row.isCorrect;
          return pw.TableRow(
            decoration: highlight ? pw.BoxDecoration(color: PdfColor.fromHex('E8F5F0')) : null,
            children: [row.bin, row.material, row.accepted].map((cell) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: _text(cell,
                    style: pw.TextStyle(
                        fontSize: 9,
                        color: highlight ? _green : _ink,
                        fontWeight: highlight ? pw.FontWeight.bold : pw.FontWeight.normal)),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  static pw.Widget _rubricTable(List<RubricRow> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: _borderGray, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FixedColumnWidth(50),
        2: pw.FixedColumnWidth(60),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _greenLight),
          children: [l10n.pdfColCriterion, l10n.pdfColMax, l10n.pdfColAwarded, l10n.pdfColComment].map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: _text(h,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink)),
            );
          }).toList(),
        ),
        ...rows.map((row) {
          return pw.TableRow(children: [
            pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: _text(row.criterion, style: pw.TextStyle(fontSize: 9, color: _ink))),
            pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: _text('${row.maxScore}', style: pw.TextStyle(fontSize: 9, color: _ink))),
            pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: _text('${row.awardedScore}',
                    style: pw.TextStyle(
                        fontSize: 9,
                        color: row.awardedScore >= row.maxScore * 0.6 ? _correctGreen : _incorrectRed,
                        fontWeight: pw.FontWeight.bold))),
            pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: _text(row.comment, style: pw.TextStyle(fontSize: 9, color: _caption))),
          ]);
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _safeFilename(ScanRecord record) {
    final safeName = record.itemName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final safeId = record.id
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final namePart = safeName.isNotEmpty ? '${safeName}_' : '';
    return 'elio_quiz_$namePart$safeId.pdf';
  }
}

/// pdf's built-in Helvetica covers Latin-1 only: curly quotes and dashes from
/// AI or ARB text would print as gaps (decision 0185 phone check).
String pdfSafe(String s) => s
    .replaceAll(RegExp('[\u2018\u2019]'), "'")
    .replaceAll(RegExp('[\u201C\u201D]'), '"')
    .replaceAll(RegExp('[\u2013\u2014]'), '-')
    .replaceAll('\u2026', '...');

pw.Widget _text(String text, {pw.TextStyle? style, pw.TextOverflow? overflow, pw.TextAlign? textAlign}) =>
    pw.Text(pdfSafe(text), style: style, overflow: overflow, textAlign: textAlign);
