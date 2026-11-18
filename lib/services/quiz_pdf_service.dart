import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/quiz_explanation.dart';
import '../models/scan_record.dart';
import '../theme/elio_tokens.dart';
import 'ai_quiz_service.dart' show QuizDifficulty;
import 'quiz_explanation_service.dart' show bankSourceTitle;

part 'quiz_pdf_design.dart';

/// What a single-question export includes, and its theme.
class QuestionPdfOptions {
  const QuestionPdfOptions({
    this.answers = true,
    this.explanation = true,
    this.photo = false,
    this.notes = false,
    this.dark,
  });
  final bool answers, explanation, photo, notes;

  /// PDF theme: true = dark tokens, false = light; null = the remembered
  /// choice ([QuizPdfService.darkTheme], light by default).
  final bool? dark;
}

/// Generates and saves the quiz PDFs for [ScanRecord] sessions: the full
/// report and the single-question export (decision 0228; A4, design in
/// `quiz_pdf_design.dart`).
class QuizPdfService {
  const QuizPdfService._();

  /// Every text drawn by the last build, in order (tests only: the embedded
  /// font writes glyph ids, so the text cannot be read back from the bytes).
  @visibleForTesting
  static List<String>? debugTexts;

  // ---------------------------------------------------------------------------
  // Theme (remembered)
  // ---------------------------------------------------------------------------

  static const _themeKey = 'pdf_theme_dark';

  /// "PDF theme: Light / Dark" of both export sheets; light until chosen.
  static final darkTheme = ValueNotifier<bool>(false);

  static Future<void> loadTheme() async {
    try {
      darkTheme.value =
          (await SharedPreferences.getInstance()).getBool(_themeKey) ?? false;
    } catch (e) {
      debugPrint('[QuizPdfService] theme not loaded: $e');
    }
  }

  static Future<void> setDarkTheme(bool dark) async {
    darkTheme.value = dark;
    try {
      await (await SharedPreferences.getInstance()).setBool(_themeKey, dark);
    } catch (e) {
      debugPrint('[QuizPdfService] theme not saved: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generate a PDF for [record] and save it to the reports directory.
  /// Returns the absolute file path.
  static Future<String> generateAndSave(
    ScanRecord record, {
    Directory? targetDir,
    bool? dark,
  }) async {
    final bytes = await generatePdfBytes(record, dark: dark);
    final dir = targetDir ?? await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/reports');
    if (!reportsDir.existsSync()) reportsDir.createSync(recursive: true);
    final file = File('${reportsDir.path}/${_safeFilename(record)}');
    file.writeAsBytesSync(bytes, flush: true);
    return file.path;
  }

  /// The full report: cover, then one page per question.
  static Future<Uint8List> generatePdfBytes(
    ScanRecord record, {
    bool? dark,
  }) async {
    debugTexts?.clear();
    final builder = _PdfBuilder(
      await PdfAssets.load(),
      record,
      dark: dark ?? darkTheme.value,
      photo: await _loadCrop(record.cropPhotoPath),
    );
    return builder.report().save();
  }

  /// Share / export the PDF using the system share sheet (printing package).
  static Future<void> shareOrSave(ScanRecord record, {bool? dark}) async {
    try {
      await Printing.sharePdf(
        bytes: await generatePdfBytes(record, dark: dark),
        filename: _safeFilename(record),
      );
    } catch (e) {
      debugPrint('[QuizPdfService] share failed: $e');
      rethrow;
    }
  }

  static String questionFilename(ScanRecord record, int index) {
    final item = record.itemName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'ELIOS_${item.isEmpty ? 'scan' : item}_Q${index + 1}.pdf';
  }

  /// Saved text only: export must never generate or refresh an explanation.
  static Future<Uint8List> generateQuestionPdfBytes(
    ScanRecord record,
    int index, {
    QuestionPdfOptions options = const QuestionPdfOptions(),
  }) async {
    debugTexts?.clear();
    final builder = _PdfBuilder(
      await PdfAssets.load(),
      record,
      dark: options.dark ?? darkTheme.value,
      photo: options.photo ? await _loadCrop(record.cropPhotoPath) : null,
    );
    return builder.single(index, options).save();
  }

  static Future<String> saveQuestion(
    ScanRecord record,
    int index, {
    QuestionPdfOptions options = const QuestionPdfOptions(),
    Directory? targetDir,
  }) async {
    final bytes = await generateQuestionPdfBytes(
      record,
      index,
      options: options,
    );
    if (targetDir == null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      final location = await const MethodChannel('elio/pdf')
          .invokeMethod<String>('saveToDownloads', {
            'filename': questionFilename(record, index),
            'bytes': bytes,
          });
      if (location == null || location.isEmpty) {
        throw StateError('No saved PDF location');
      }
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
    final image = pw.MemoryImage(
      await File(record.cropPhotoPath!).readAsBytes(),
    );
    final doc = pw.Document()
      ..addPage(
        pw.Page(
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: _safeFilename(
        record,
      ).replaceFirst(RegExp(r'\.pdf$'), '_photo.pdf'),
    );
  }

  static Future<void> shareQuestion(
    ScanRecord record,
    int index, {
    QuestionPdfOptions options = const QuestionPdfOptions(),
  }) async {
    await Printing.sharePdf(
      bytes: await generateQuestionPdfBytes(record, index, options: options),
      filename: questionFilename(record, index),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// The scan photo for the polaroid, made small: at most 640 px, JPEG 80
  /// (keeps a 3-question report with a photo well under 1 MB).
  static Future<pw.MemoryImage?> _loadCrop(String? path) async {
    if (path == null) return null;
    try {
      final decoded = img.decodeImage(await File(path).readAsBytes());
      if (decoded == null) return null;
      final small = decoded.width > 640 || decoded.height > 640
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? 640 : null,
              height: decoded.height > decoded.width ? 640 : null,
            )
          : decoded;
      return pw.MemoryImage(img.encodeJpg(small, quality: 80));
    } catch (_) {
      return null; // Old records may point to missing or unreadable photos.
    }
  }

  /// "3 Nov 2026 23:29" in the app language.
  static String _dateTime(DateTime t) =>
      DateFormat.yMMMd(dateLocale).add_Hm().format(t.toLocal());

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
