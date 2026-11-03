import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/quiz_explanation.dart';
import '../models/scan_record.dart';
import '../models/trophy_rules.dart';

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
                child: pw.Text(
                  'ELIO - Laporan Kuis Sampah',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _green,
                  ),
                ),
              ),
              pw.Text(
                record.time.toLocal().toString().substring(0, 16),
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
            pw.Text(
              'ELIO - ${record.itemName}',
              style: pw.TextStyle(fontSize: 11, color: _subtext, fontWeight: pw.FontWeight.bold),
            ),
            pw.Spacer(),
            pw.Text('Hal. $page / $total', style: pw.TextStyle(fontSize: 10, color: _caption)),
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
              child: pw.Text(
                'ELIO Waste Sorting Education | Halaman $page dari $total | Session ID: ${record.id}',
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
      _sectionTitle('Informasi Sesi'),
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
                ? pw.Text('PHOTO', style: pw.TextStyle(fontSize: 10, color: _caption))
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

  static pw.Widget _sectionTitle(String title) => pw.Text(
        title,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _green),
      );

  static pw.Widget _metadataTable(ScanRecord record, QuizGrade grade) {
    final rows = [
      ['Item', record.itemName],
      ['Kategori', record.category.badgeLabel],
      ['Tanggal / Waktu', record.time.toLocal().toString().substring(0, 16)],
      ['Tingkat Kesulitan', record.difficultyLabel],
      ['Jumlah Soal', '${record.totalQuestions}'],
      ['Benar', '${record.correctCount} dari ${record.totalQuestions}'],
      ['Piala Diperoleh', '${record.trophies} Piala'],
      ['Nilai', record.questions.any((q) => q.gradingPending) ? 'Menunggu penilaian' : grade.label],
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
            child: pw.Text(row[0],
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _subtext)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(row[1], style: pw.TextStyle(fontSize: 10, color: _ink)),
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
          child: pw.Text(
            'Soal $index: ${q.question}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink),
          ),
        ),
        pw.SizedBox(height: 4),
        // Answers
        ..._answerRow('Jawaban Kamu', q.yourAnswer, q.isCorrect ? _correctGreen : _incorrectRed),
        ..._answerRow('Jawaban Benar', q.rightAnswer, _correctGreen),
        if (q.isEssay)
          ..._answerRow('Skor Essay', q.gradingPending ? 'Menunggu penilaian' : '${q.essayScore} / 10 (+${q.trophies} Piala)', _goldYellow),
        pw.SizedBox(height: 6),
        // Explanation section
        if (exp != null && !exp.isUnavailable) ...[
          ..._explanationSection(exp),
        ] else ...[
          pw.Text(
            'Penjelasan tidak tersimpan untuk soal ini.',
            style: pw.TextStyle(fontSize: 10, color: _caption, fontStyle: pw.FontStyle.italic),
          ),
        ],
        if (index < totalQuestions) pw.Divider(color: _borderGray, height: 16),
    ];
  }

  // Keep variable-length text directly in MultiPage so it can span pages.
  static List<pw.Widget> _answerRow(String label, String value, PdfColor color) => [
    pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 9,
        fontWeight: pw.FontWeight.bold, color: _caption)),
    pw.Text(value, overflow: pw.TextOverflow.span,
        style: pw.TextStyle(fontSize: 10, color: color, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 4),
  ];

  /// "Sumber: Bank Soal ELIO · bagian 1.3 · hal. 6 · organik-mc-01" (decision 0175).
  static String? sourceLine(QuizExplanation exp) {
    if (exp.sourceTitle == null && exp.bankId == null) return null;
    return [
      'Sumber: ${exp.sourceTitle ?? 'Bank Soal ELIO'}',
      if (exp.sourceSection != null) 'bagian ${exp.sourceSection}',
      if (exp.sourcePage != null) 'hal. ${exp.sourcePage}',
      ?exp.bankId,
    ].join(' · ');
  }

  static List<pw.Widget> _explanationSection(QuizExplanation exp) {
    return [
        pw.Text('Penjelasan',
            overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _green)),
        pw.SizedBox(height: 4),
        if (exp.summary.isNotEmpty)
          pw.Text(exp.summary, overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 10, color: _ink)),
        if (exp.correctAnswerReason.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(exp.correctAnswerReason, overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 10, color: _ink)),
        ],
        if (exp.selectedAnswerFeedback.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(exp.selectedAnswerFeedback,
              overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 10, color: _incorrectRed)),
        ],
        if (exp.conceptExplanation.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(exp.conceptExplanation, overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 10, color: _ink)),
        ],
        if (exp.comparisonRows.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text('Table 1. Perbandingan Kategori Sampah',
              overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _subtext)),
          pw.SizedBox(height: 4),
          _comparisonTable(exp.comparisonRows),
        ],
        if (exp.rubricRows != null && exp.rubricRows!.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text('Table 1. Scoring breakdown',
              overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _subtext)),
          pw.SizedBox(height: 4),
          _rubricTable(exp.rubricRows!),
        ],
        if (exp.learningTakeaway.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            exp.learningTakeaway,
            overflow: pw.TextOverflow.span, style: pw.TextStyle(
                fontSize: 10, fontStyle: pw.FontStyle.italic, color: _subtext),
          ),
        ],
        if (exp.quote != null) ...[
          pw.SizedBox(height: 4),
          pw.Text('"${exp.quote}"',
              overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: _subtext)),
        ],
        if (sourceLine(exp) != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(sourceLine(exp)!, overflow: pw.TextOverflow.span, style: pw.TextStyle(fontSize: 9, color: _caption)),
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
          children: ['Kategori', 'Material', 'Diterima'].map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(h,
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
                child: pw.Text(cell,
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
          children: ['Kriteria', 'Maks', 'Diperoleh', 'Komentar'].map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(h,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink)),
            );
          }).toList(),
        ),
        ...rows.map((row) {
          return pw.TableRow(children: [
            pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(row.criterion, style: pw.TextStyle(fontSize: 9, color: _ink))),
            pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text('${row.maxScore}', style: pw.TextStyle(fontSize: 9, color: _ink))),
            pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text('${row.awardedScore}',
                    style: pw.TextStyle(
                        fontSize: 9,
                        color: row.awardedScore >= row.maxScore * 0.6 ? _correctGreen : _incorrectRed,
                        fontWeight: pw.FontWeight.bold))),
            pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(row.comment, style: pw.TextStyle(fontSize: 9, color: _caption))),
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
