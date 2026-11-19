// The quiz PDF pages (Figma "17 · Quiz PDF export · A4", 874:30391; decision
// 0228): cover, one page per question, the single-question page and its notes
// page, in the light or dark ELIOS tokens. A4, sizes in pt as in Figma.
part of 'quiz_pdf_service.dart';

const _w = 595.0, _pad = 40.0;

PdfColor _pc(Color c) => PdfColor(c.r, c.g, c.b);

/// [over] at [a] opacity on [base], as one opaque colour (PDF viewers differ
/// on transparency; a tint is always the same everywhere).
PdfColor _mix(PdfColor base, PdfColor over, double a) => PdfColor(
  base.red + (over.red - base.red) * a,
  base.green + (over.green - base.green) * a,
  base.blue + (over.blue - base.blue) * a,
);

/// The PDF's colours: the ELIOS tokens of one mode. The green header and the
/// stickers stay green in both.
class PdfPalette {
  PdfPalette(this.dark) : t = dark ? ElioTokens.dark : ElioTokens.light;
  final bool dark;
  final ElioPalette t;
  static const _l = ElioTokens.light;

  PdfColor get bg => _pc(t.background);
  PdfColor get surface => _pc(t.surface);
  PdfColor get raised => _pc(t.surfaceRaised);

  /// Fill of the quiet (skipped, not saved) boxes: `raised` in light; in dark
  /// `surface`, where secondary text still meets AA.
  PdfColor get quiet => dark ? surface : raised;
  PdfColor get text => _pc(t.textPrimary);
  PdfColor get text2 => _pc(t.textSecondary);
  PdfColor get text3 => _pc(t.textTertiary);
  PdfColor get border => _pc(dark ? t.borderMedium : t.borderSubtle);
  PdfColor get borderMed => _pc(dark ? t.borderStrong : t.borderMedium);
  PdfColor get green => _pc(_l.primary);
  PdfColor get greenHover => _pc(_l.primaryHover);
  PdfColor get greenActive => _pc(_l.primaryActive);
  PdfColor get onGreen => _pc(_l.onPrimary);
  PdfColor get okText => _pc(t.primaryText);
  PdfColor get err => _pc(t.error);
  PdfColor get errText => _pc(t.errorText);
  PdfColor get warn => _pc(t.secondaryText);
  PdfColor get info => _pc(t.tertiaryText);

  /// Chip background / border of a tone (as `historyTint` in the app).
  PdfColor tintBg(PdfColor c, [double light = .06]) =>
      _mix(dark ? surface : bg, c, dark ? .1 : light);

  /// The tint of a tone at the strength that keeps its label AA-readable
  /// (green 5 %, red 8 %, amber 4 %, cyan 6 % in light).
  PdfColor soft(PdfColor c) =>
      tintBg(c, c == err ? .08 : (c == warn ? .04 : (c == info ? .06 : .05)));
  PdfColor tintEdge(PdfColor c) =>
      _mix(dark ? surface : bg, c, dark ? .4 : .35);
}

/// Fonts and art, loaded once. The art is the app's own Figma exports.
class PdfAssets {
  PdfAssets._(this.regular, this.medium, this.semi, this.bold, this.svg);
  final pw.Font regular, medium, semi, bold;
  final Map<String, String> svg;

  static const _art = {
    'robot_sad': 'robot/robot_sad',
    'robot_sleepy': 'robot/robot_sleepy',
    'robot_talking': 'robot/robot_talking',
    'bin_organik': 'home/bin_organik',
    'bin_anorganik': 'home/bin_anorganik',
    'bin_b3': 'home/bin_b3',
    'medal': 'home/medal_gold',
    'bulb': 'home/bulb_buddy',
    'target': 'home/quest_target',
    'xp': 'history/icon_xp',
    'squiggle': 'scan/squiggle',
  };

  static Future<PdfAssets>? _cache;
  static Future<PdfAssets> load() => _cache ??= _load();
  static Future<PdfAssets> _load() async {
    Future<pw.Font> font(String weight) async => pw.Font.ttf(
      await rootBundle.load('assets/fonts/pdf/GoogleSansFlex-$weight.ttf'),
    );
    return PdfAssets._(
      await font('Regular'),
      await font('Medium'),
      await font('SemiBold'),
      await font('Bold'),
      {
        for (final e in _art.entries)
          e.key: await rootBundle.loadString(
            'assets/illustrations/${e.value}.svg',
          ),
      },
    );
  }
}

/// The ELIOS leaf mark, from the same vector as `ElioLeaf` (Figma 208:1144).
String _markSvg(PdfColor c) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 150">'
    '<path fill="${c.toHex().substring(0, 7)}" d="M17.6954 122.7C12.7454 66 '
    '59.9954 18 128.6954 14.7L17.6954 122.7ZM135.2954 21.3C137.9954 90 92.9954 '
    '135 24.2954 129.3L135.2954 21.3Z"/>'
    '<rect fill="${c.toHex().substring(0, 7)}" x="92.9954" y="126" width="39" '
    'height="12" rx="2.25"/></svg>';

enum _Result { right, wrong, skipped, essay, pending }

class _PdfBuilder {
  _PdfBuilder(this.a, this.record, {required bool dark, this.photo})
    : c = PdfPalette(dark),
      t = l10n;
  final PdfAssets a;
  final ScanRecord record;
  final PdfPalette c;
  final pw.MemoryImage? photo;
  final AppLocalizations t;

  /// Off while a page is only being measured.
  bool _logging = true;

  // ── Text ────────────────────────────────────────────────────────────────

  pw.TextStyle s(
    double size,
    int weight,
    PdfColor color, {
    double spacing = 0,
    double leading = 0,
  }) => pw.TextStyle(
    font: switch (weight) {
      >= 700 => a.bold,
      >= 600 => a.semi,
      >= 500 => a.medium,
      _ => a.regular,
    },
    fontSize: size,
    color: color,
    letterSpacing: spacing,
    lineSpacing: leading,
  );

  pw.Widget tx(
    String text,
    pw.TextStyle style, {
    pw.TextAlign? align,
    int? maxLines,
    bool span = false,
    bool log = true,
  }) {
    if (_logging && log) QuizPdfService.debugTexts?.add(text);
    return pw.Text(
      text,
      style: style,
      textAlign: align,
      maxLines: maxLines,
      // [span]: a long text continues on the next page instead of clipping.
      overflow: maxLines != null
          ? pw.TextOverflow.clip
          : (span ? pw.TextOverflow.span : null),
    );
  }

  pw.Widget over(String text, PdfColor color) =>
      tx(text.toUpperCase(), s(7, 600, color, spacing: 0.9));

  pw.Widget art(String name, double w, double h) =>
      pw.SvgImage(svg: a.svg[name]!, width: w, height: h);

  pw.Widget mark(double size, PdfColor color) =>
      pw.SvgImage(svg: _markSvg(color), width: size, height: size);

  pw.Widget squiggle(double width) => pw.SvgImage(
    svg: a.svg['squiggle']!.replaceAll(
      RegExp(r'stroke="[^"]*"'),
      'stroke="${c.greenHover.toHex().substring(0, 7)}"',
    ),
    width: width,
    height: 7,
    fit: pw.BoxFit.fill,
  );

  /// Check, cross or minus in a filled circle.
  pw.Widget badge(_Result r, double size) {
    final fill = switch (r) {
      _Result.right => c.greenHover,
      _Result.wrong => c.err,
      _ => c.text3,
    };
    return pw.CustomPaint(
      size: PdfPoint(size, size),
      painter: (g, box) {
        final m = box.x / 2;
        g
          ..setFillColor(fill)
          ..drawEllipse(m, m, m, m)
          ..fillPath()
          ..setStrokeColor(PdfColors.white)
          ..setLineWidth(box.x * .13)
          ..setLineCap(PdfLineCap.round);
        if (r == _Result.right) {
          g
            ..moveTo(box.x * .28, box.y * .5)
            ..lineTo(box.x * .44, box.y * .34)
            ..lineTo(box.x * .72, box.y * .66);
        } else if (r == _Result.wrong) {
          g
            ..moveTo(box.x * .33, box.y * .33)
            ..lineTo(box.x * .67, box.y * .67)
            ..moveTo(box.x * .67, box.y * .33)
            ..lineTo(box.x * .33, box.y * .67);
        } else {
          g
            ..moveTo(box.x * .3, m)
            ..lineTo(box.x * .7, m);
        }
        g.strokePath();
      },
    );
  }

  /// Four-point sparkle before a label.
  pw.Widget sparkle(double size, PdfColor color) => pw.CustomPaint(
    size: PdfPoint(size, size),
    painter: (g, box) {
      final m = box.x / 2, k = box.x * .14;
      g
        ..setFillColor(color)
        ..moveTo(m, box.y)
        ..lineTo(m + k, m + k)
        ..lineTo(box.x, m)
        ..lineTo(m + k, m - k)
        ..lineTo(m, 0)
        ..lineTo(m - k, m - k)
        ..lineTo(0, m)
        ..lineTo(m - k, m + k)
        ..closePath()
        ..fillPath();
    },
  );

  pw.BoxDecoration box(
    PdfColor fill, {
    PdfColor? edge,
    double radius = 12,
    pw.BorderRadius? shape,
    bool dashed = false,
    double width = 1,
  }) => pw.BoxDecoration(
    color: fill,
    borderRadius: shape ?? pw.BorderRadius.circular(radius),
    border: edge == null
        ? null
        : pw.Border.all(
            color: edge,
            width: width,
            style: dashed ? pw.BorderStyle.dashed : pw.BorderStyle.solid,
          ),
  );

  pw.Widget pill(String text, PdfColor bg, PdfColor fg, {double size = 7.5}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: box(bg, radius: 7),
        child: tx(text, s(size, 600, fg)),
      );

  /// Writing lines, 22 pt apart, over the space it is given.
  pw.Widget lines(double height) => pw.CustomPaint(
    size: PdfPoint(_w - 2 * _pad, height),
    painter: (g, box) {
      g
        ..setStrokeColor(c.border)
        ..setLineWidth(.8);
      for (var y = box.y - 20; y > 0; y -= 22) {
        g
          ..moveTo(0, y)
          ..lineTo(box.x, y);
      }
      g.strokePath();
    },
  );

  // ── Page furniture ──────────────────────────────────────────────────────

  /// The curved green band, [h] tall, with the two darker blobs.
  pw.Widget band(double h, {bool slim = false}) => pw.CustomPaint(
    size: PdfPoint(_w, h),
    painter: (g, box) {
      final wave = slim ? 6.0 : 22.0;
      void shape() => g
        ..moveTo(0, box.y)
        ..lineTo(box.x, box.y)
        ..lineTo(box.x, wave * 1.4)
        ..curveTo(box.x * .7, -wave * .6, box.x * .35, wave * 2, 0, wave * .7)
        ..closePath();
      g.setFillColor(c.green);
      shape();
      g.fillPath();
      if (slim) return;
      g.saveContext();
      shape();
      g
        ..clipPath()
        ..setFillColor(c.greenActive)
        ..drawEllipse(box.x - 30, box.y - 8, 78, 78)
        ..fillPath()
        ..setFillColor(c.greenHover)
        ..drawEllipse(-8, wave + 22, 38, 38)
        ..fillPath()
        ..restoreContext();
    },
  );

  pw.Widget brand(String trail) => pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      mark(15, c.greenActive),
      pw.SizedBox(width: 6),
      tx('ELIOS', s(12, 700, c.onGreen, spacing: .4)),
      pw.SizedBox(width: 8),
      tx('·  $trail', s(8.5, 500, c.onGreen), maxLines: 1),
    ],
  );

  String get _shortId {
    final id = record.id;
    return id.length <= 16
        ? id
        : '${id.substring(0, 9)}…${id.substring(id.length - 4)}';
  }

  pw.Widget footer(pw.Context ctx) => pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(_pad, 8, _pad, 22),
    child: pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(height: .8, color: c.border),
        pw.SizedBox(height: 9),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            mark(10, c.greenActive),
            pw.SizedBox(width: 5),
            tx(t.pdfFooterBrand, s(7.5, 500, c.text2)),
            pw.Spacer(),
            tx(t.pdfSessionId(_shortId), s(7, 400, c.text3)),
            pw.SizedBox(width: 10),
            pill(
              t.pdfPageShort(ctx.pageNumber, ctx.pagesCount),
              c.soft(c.greenActive),
              c.okText,
              size: 7,
            ),
          ],
        ),
      ],
    ),
  );

  pw.PageTheme get _theme => pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    theme: pw.ThemeData.withFont(base: a.regular, bold: a.bold),
    buildBackground: (_) =>
        pw.FullPage(ignoreMargins: true, child: pw.Container(color: c.bg)),
  );

  /// Slim header of a continuation page: never an empty band.
  pw.Widget _slim(String title) => pw.SizedBox(
    width: _w,
    height: 46,
    child: pw.Stack(
      children: [
        band(46, slim: true),
        pw.Positioned(left: _pad, top: 14, child: brand(title)),
      ],
    ),
  );

  pw.Widget _inset(pw.Widget child) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: _pad),
    child: child,
  );

  /// Adds [body] as flowing pages: [header] on the first, the slim header on
  /// the rest. Returns how many pages it took.
  int flow(
    pw.Document doc, {
    required pw.Widget header,
    required String continued,
    required List<pw.Widget> body,
  }) {
    final first = doc.document.pdfPageList.pages.length + 1;
    doc.addPage(
      pw.MultiPage(
        pageTheme: _theme,
        maxPages: 40,
        header: (ctx) => ctx.pageNumber == first ? header : _slim(continued),
        footer: footer,
        // An empty body still gets its page (header and footer).
        build: (_) => [
          for (final w in body) _inset(w),
          if (body.isEmpty) pw.SizedBox(height: 1),
        ],
      ),
    );
    return doc.document.pdfPageList.pages.length + 1 - first;
  }

  /// How many pages [build] needs (laid out on a scratch document).
  int measure(void Function(pw.Document doc) build) {
    final scratch = pw.Document();
    final was = _logging; // measures nest (report → question)
    _logging = false;
    try {
      build(scratch);
    } finally {
      _logging = was;
    }
    return scratch.document.pdfPageList.pages.length;
  }

  // ── Question parts ──────────────────────────────────────────────────────

  _Result resultOf(RecordQuestion q) => q.skipped
      ? _Result.skipped
      : q.isEssay
      ? (q.gradingPending ? _Result.pending : _Result.essay)
      : (q.isCorrect ? _Result.right : _Result.wrong);

  /// Red at 0-4, amber 5-9, green at 10 (essay), as in the app.
  PdfColor scoreTone(int got, int max) =>
      got >= max ? c.okText : (got * 2 < max ? c.errText : c.warn);

  ({String label, PdfColor fill, _Result icon}) chipOf(RecordQuestion q) =>
      switch (resultOf(q)) {
        _Result.right => (
          label: t.h3Correct,
          fill: c.greenActive,
          icon: _Result.right,
        ),
        _Result.wrong => (
          label: t.pdfChipWrong,
          fill: c.err,
          icon: _Result.wrong,
        ),
        _Result.skipped => (
          label: t.pdfChipSkipped,
          fill: _pc(ElioTokens.light.textTertiary),
          icon: _Result.skipped,
        ),
        _Result.pending => (
          label: t.h3AwaitingGrading,
          fill: _pc(ElioTokens.light.textTertiary),
          icon: _Result.skipped,
        ),
        _Result.essay => (
          label: '${q.essayScore}/10',
          fill: (q.essayScore ?? 0) >= 10
              ? c.greenActive
              : ((q.essayScore ?? 0) >= 5
                    ? _pc(ElioTokens.light.secondaryText)
                    : c.err),
          icon: (q.essayScore ?? 0) >= 10 ? _Result.right : _Result.wrong,
        ),
      };

  /// Tilted result sticker of the header.
  pw.Widget sticker(RecordQuestion q) {
    final chip = chipOf(q);
    return pw.Transform.rotateBox(
      angle: .07,
      child: pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(7, 5, 11, 5),
        decoration: box(chip.fill, radius: 10),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            badge(chip.icon, 11),
            pw.SizedBox(width: 5),
            tx(
              t.pdfStickerXp(chip.label, q.trophies),
              s(8, 600, PdfColors.white),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget polaroid(double size, String caption) => pw.Transform.rotateBox(
    angle: -.09,
    child: pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(6, 6, 6, 5),
      decoration: box(
        PdfColors.white,
        edge: _pc(ElioTokens.light.borderSubtle),
        radius: 6,
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.ClipRRect(
            horizontalRadius: 4,
            verticalRadius: 4,
            child: pw.Image(
              photo!,
              width: size,
              height: size,
              fit: pw.BoxFit.cover,
            ),
          ),
          pw.SizedBox(height: 5),
          tx(caption, s(6.5, 500, _pc(ElioTokens.light.textSecondary))),
        ],
      ),
    ),
  );

  String get _time => DateFormat.Hm(dateLocale).format(record.time.toLocal());

  /// Green header of a question page: brand, progress dots, result sticker,
  /// and the polaroid when [withPhoto].
  pw.Widget questionHeader(
    int index,
    String trail, {
    bool withPhoto = false,
    String? overline,
    pw.Widget? corner,
  }) {
    final q = record.questions[index];
    final total = record.questions.length;
    return pw.SizedBox(
      width: _w,
      height: 112,
      child: pw.Stack(
        overflow: pw.Overflow.visible,
        children: [
          band(112),
          pw.Positioned(left: _pad, top: 26, child: brand(trail)),
          pw.Positioned(
            left: _pad,
            top: 51,
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                over(overline ?? t.pdfQuestionOf(index + 1, total), c.onGreen),
                if (overline == null) ...[
                  pw.SizedBox(width: 7),
                  for (var i = 0; i < total; i++)
                    pw.Container(
                      width: i == index ? 14 : 5,
                      height: 5,
                      margin: const pw.EdgeInsets.only(right: 3),
                      decoration: box(
                        i == index ? c.onGreen : PdfColors.white,
                        radius: 3,
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (corner != null)
            pw.Positioned(right: 44, top: 24, child: corner)
          else ...[
            pw.Positioned(
              right: withPhoto ? 170 : _pad,
              top: 27,
              child: sticker(q),
            ),
            if (withPhoto)
              pw.Positioned(
                right: 46,
                top: 16,
                child: polaroid(88, t.pdfPhotoCaption(_time)),
              ),
          ],
        ],
      ),
    );
  }

  pw.Widget questionTitle(int index, {double rightGap = 0}) {
    final q = record.questions[index];
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: 12, right: rightGap),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Number leaf.
          pw.Container(
            width: 38,
            height: 38,
            alignment: pw.Alignment.center,
            decoration: box(
              c.green,
              shape: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(12),
                topRight: pw.Radius.circular(4),
                bottomRight: pw.Radius.circular(12),
                bottomLeft: pw.Radius.circular(4),
              ),
            ),
            child: tx('${index + 1}', s(16, 700, c.onGreen)),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                over(
                  t.pdfQuestionType(
                    index + 1,
                    q.isEssay ? t.pdfTypeEssay : t.pdfTypeMc,
                  ),
                  c.text3,
                ),
                pw.SizedBox(height: 4),
                tx(q.question, s(15, 600, c.text, leading: 2.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// PDF / Answer tile (875:30469): Wrong, Right, Your right, Skipped.
  pw.Widget tile(_Result r, String label, String text) {
    final tone = switch (r) {
      _Result.right => c.greenActive,
      _Result.wrong => c.err,
      _ => c.text3,
    };
    final skipped = r == _Result.skipped;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: box(
        skipped ? c.quiet : c.soft(tone),
        edge: skipped ? c.borderMed : c.tintEdge(tone),
        dashed: skipped,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Row(
            children: [
              badge(r, 14),
              pw.SizedBox(width: 7),
              over(label, switch (r) {
                _Result.right => c.okText,
                _Result.wrong => c.errText,
                _ => c.text2,
              }),
            ],
          ),
          pw.SizedBox(height: 7),
          tx(
            text,
            s(9.5, 500, skipped ? c.text2 : c.text, leading: 2.5),
            span: true,
          ),
        ],
      ),
    );
  }

  /// Your answer and the right answer, side by side and equally tall. A long
  /// answer (an essay) gets full-width tiles that can run over a page break.
  List<pw.Widget> answers(RecordQuestion q) {
    final r = resultOf(q);
    final right = q.rightAnswer.trim() == '-' ? '' : q.rightAnswer.trim();
    // Built only where used, so the text log holds each answer once.
    pw.Widget yours() => switch (r) {
      _Result.skipped => tile(_Result.skipped, t.pdfYourAnswer, t.essaySkipped),
      _Result.right => tile(_Result.right, t.pdfYourRight, q.yourAnswer),
      _Result.essay when (q.essayScore ?? 0) >= 10 => tile(
        _Result.right,
        t.pdfYourRight,
        q.yourAnswer,
      ),
      _Result.pending => tile(_Result.pending, t.pdfYourAnswer, q.yourAnswer),
      _ => tile(_Result.wrong, t.pdfYourAnswer, q.yourAnswer),
    };
    final showRight =
        right.isNotEmpty &&
        r != _Result.right &&
        !(r == _Result.essay && (q.essayScore ?? 0) >= 10);
    if (!showRight) return [yours()];
    pw.Widget model() => tile(
      _Result.right,
      q.isEssay ? t.pdfModelAnswer : t.pdfRightAnswer,
      right,
    );
    if (q.yourAnswer.length + right.length > 700) {
      // A card cannot break across pages, so a long answer is printed as
      // plain paragraphs under its label; they flow page to page.
      if (_logging) QuizPdfService.debugTexts?.add(q.yourAnswer);
      final wrongTone = r == _Result.wrong || r == _Result.essay;
      return [
        pw.Row(
          children: [
            badge(wrongTone ? _Result.wrong : r, 14),
            pw.SizedBox(width: 7),
            over(t.pdfYourAnswer, wrongTone ? c.errText : c.text2),
          ],
        ),
        for (final part in _paragraphs(q.yourAnswer))
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: tx(part, s(9.5, 500, c.text, leading: 2.5), log: false),
          ),
        pw.SizedBox(height: 12),
        model(),
      ];
    }
    return [
      pw.Table(
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
        columnWidths: const {
          0: pw.FlexColumnWidth(),
          1: pw.FixedColumnWidth(12),
          2: pw.FlexColumnWidth(),
        },
        children: [
          pw.TableRow(children: [yours(), pw.SizedBox(), model()]),
        ],
      ),
    ];
  }

  /// [text] in pieces of about 450 characters, cut at sentence ends.
  static List<String> _paragraphs(String text) {
    final parts = <String>[];
    var current = StringBuffer();
    for (final sentence in text.split(RegExp(r'(?<=[.!?])\s+'))) {
      if (current.isNotEmpty && current.length + sentence.length > 450) {
        parts.add(current.toString());
        current = StringBuffer();
      }
      if (current.isNotEmpty) current.write(' ');
      current.write(sentence);
    }
    if (current.isNotEmpty) parts.add(current.toString());
    return parts;
  }

  String _criterion(String name) => switch (name) {
    'Accuracy' => t.rubricAccuracy,
    'Key terms' => t.rubricKeyTerms,
    'Completeness' => t.rubricCompleteness,
    'Clarity' => t.rubricClarity,
    _ => name,
  };

  /// Essay rubric score card (same data as the app's score card).
  pw.Widget rubric(RecordQuestion q, List<RubricRow> rows) {
    final score = q.essayScore ?? 0;
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: box(c.surface, edge: c.border, radius: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              over(t.pdfEssayScoreLabel, scoreTone(score, 10)),
              pw.SizedBox(width: 8),
              tx(t.essayScoreOf(score), s(14, 700, c.text)),
              pw.SizedBox(width: 8),
              pill(
                t.h3PlusTrophies(q.trophies),
                c.soft(c.warn),
                c.warn,
                size: 7,
              ),
              pw.Spacer(),
              tx(t.pdfGradedBy, s(7, 400, c.text3)),
            ],
          ),
          if (rows.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: tx(
                                _criterion(rows[i].criterion),
                                s(8, 600, c.text),
                              ),
                            ),
                            tx(
                              '${rows[i].awardedScore}/${rows[i].maxScore}',
                              s(
                                7.5,
                                600,
                                scoreTone(
                                  rows[i].awardedScore,
                                  rows[i].maxScore,
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 5),
                        pw.Row(
                          children: [
                            for (var k = 0; k < rows[i].maxScore; k++)
                              pw.Container(
                                width: 16,
                                height: 4,
                                margin: const pw.EdgeInsets.only(right: 3),
                                decoration: box(
                                  k < rows[i].awardedScore
                                      ? scoreTone(
                                          rows[i].awardedScore,
                                          rows[i].maxScore,
                                        )
                                      : c.borderMed,
                                  radius: 2,
                                ),
                              ),
                          ],
                        ),
                        if (rows[i].comment.isNotEmpty) ...[
                          pw.SizedBox(height: 5),
                          tx(rows[i].comment, s(7, 400, c.text2, leading: 1.5)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// "Why this is the right answer": leaf card with the robot.
  pw.Widget whyCard(String label, String body) => pw.Stack(
    overflow: pw.Overflow.visible,
    children: [
      pw.Container(
        width: _w - 2 * _pad,
        padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: box(
          c.surface,
          edge: c.tintEdge(c.greenActive),
          shape: const pw.BorderRadius.only(
            topLeft: pw.Radius.circular(14),
            topRight: pw.Radius.circular(14),
            bottomRight: pw.Radius.circular(28),
            bottomLeft: pw.Radius.circular(14),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 44),
              child: over(label, c.okText),
            ),
            pw.SizedBox(height: 7),
            tx(body, s(9.2, 400, c.text, leading: 3.5)),
          ],
        ),
      ),
      // Talking robot (with signal), as in Figma 875:30470.
      pw.Positioned(right: 14, top: -20, child: art('robot_talking', 32, 37)),
    ],
  );

  /// Speech bubble beside a robot (why your answer fell short, feedback).
  pw.Widget bubble(String robot, String label, String body) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: art(robot, 30, 35),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: box(
            c.soft(c.err),
            edge: c.tintEdge(c.err),
            shape: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(4),
              topRight: pw.Radius.circular(12),
              bottomRight: pw.Radius.circular(12),
              bottomLeft: pw.Radius.circular(12),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              over(label, c.errText),
              pw.SizedBox(height: 5),
              tx(body, s(9.2, 400, c.text, leading: 3.5)),
            ],
          ),
        ),
      ),
    ],
  );

  /// A ticket: [child] in a tinted card with a notch on each side.
  pw.Widget ticket(PdfColor tone, pw.Widget child) => pw.Stack(
    overflow: pw.Overflow.visible,
    children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: box(c.soft(tone), edge: c.tintEdge(tone)),
        child: child,
      ),
      for (final left in [true, false])
        pw.Positioned(
          left: left ? -5 : null,
          right: left ? null : -5,
          top: 0,
          bottom: 0,
          child: pw.Center(
            child: pw.Container(
              width: 10,
              height: 10,
              decoration: pw.BoxDecoration(
                color: c.bg,
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: c.tintEdge(tone)),
              ),
            ),
          ),
        ),
    ],
  );

  pw.Widget ideaTicket(String idea) => ticket(
    c.info,
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        art('target', 30, 30),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Row(
                children: [
                  sparkle(7, c.info),
                  pw.SizedBox(width: 4),
                  over(t.h3KeyIdea, c.info),
                ],
              ),
              pw.SizedBox(height: 4),
              tx(idea, s(10, 600, c.text, leading: 3)),
            ],
          ),
        ),
      ],
    ),
  );

  /// "How to do it": numbered path ending in the medal.
  pw.Widget stepPath(List<String> steps) {
    final shown = steps.take(5).toList();
    pw.Widget dash() => pw.Expanded(
      child: pw.Container(
        height: 0,
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(
              color: c.greenHover,
              width: 1,
              style: pw.BorderStyle.dashed,
            ),
          ),
        ),
      ),
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        tx(t.h3HowTo, s(11, 600, c.text)),
        pw.SizedBox(height: 3),
        squiggle(44),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < shown.length; i++)
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 17,
                          height: 17,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            color: c.green,
                            shape: pw.BoxShape.circle,
                          ),
                          child: tx('${i + 1}', s(8, 700, c.onGreen)),
                        ),
                        dash(),
                      ],
                    ),
                    pw.SizedBox(height: 7),
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 8),
                      child: tx(shown[i], s(7.6, 400, c.text, leading: 2)),
                    ),
                  ],
                ),
              ),
            pw.SizedBox(
              width: 62,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  art('medal', 17, 20),
                  pw.SizedBox(height: 4),
                  tx(t.pdfStepsDone, s(7.6, 600, c.okText)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Never a bare sentence: the dashed box with the sleepy robot.
  pw.Widget noExplanation() => pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: box(c.quiet, edge: c.borderMed, dashed: true),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        art('robot_sleepy', 34, 39),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              tx(t.pdfNoExplTitle, s(10.5, 600, c.text)),
              pw.SizedBox(height: 3),
              tx(t.pdfNoExplHint, s(8.5, 400, c.text2, leading: 2.5)),
            ],
          ),
        ),
      ],
    ),
  );

  pw.Widget notesTitle() => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      tx(t.pdfMyNotes, s(10.5, 600, c.text)),
      pw.SizedBox(width: 6),
      tx('· ${t.pdfMyNotesHint}', s(7.5, 400, c.text3)),
    ],
  );

  /// The cards of one question, top to bottom. Each explanation text is
  /// printed once (the old export printed the summary and the reason, which
  /// are the same text for bank explanations).
  List<pw.Widget> questionBody(
    int index, {
    bool answersOn = true,
    bool explanationOn = true,
    double titleGap = 0,
  }) {
    final q = record.questions[index], e = q.explanation;
    final r = resultOf(q);
    final has = e != null && !e.isUnavailable;
    final essayFeedback = has ? (e.essayFeedback ?? '').trim() : '';
    var why = has ? e.correctAnswerReason.trim() : '';
    // Bank and fallback explanations carry their one text as the summary.
    if (why.isEmpty && has && e.summary.trim() != essayFeedback) {
      why = e.summary.trim();
    }
    final wrong = has ? e.selectedAnswerFeedback.trim() : '';
    final idea = has ? e.keyIdea.trim() : '';
    final steps = has ? e.steps : const <String>[];
    final graded = r == _Result.essay;
    final anything =
        why.isNotEmpty ||
        idea.isNotEmpty ||
        steps.isNotEmpty ||
        (graded && essayFeedback.isNotEmpty);
    pw.Widget gap(double h) => pw.SizedBox(height: h);
    return [
      if (answersOn) ...[
        questionTitle(index, rightGap: titleGap),
        gap(14),
        ...answers(q),
        if (graded) ...[gap(12), rubric(q, e?.rubricRows ?? const [])],
      ],
      if (explanationOn) ...[
        if (!anything) ...[gap(14), noExplanation()],
        if (why.isNotEmpty) ...[gap(28), whyCard(t.h3WhyCorrect, why)],
        if (r == _Result.wrong && wrong.isNotEmpty) ...[
          gap(14),
          bubble('robot_sad', t.h3WhyWrong, wrong),
        ],
        if (graded && (q.essayScore ?? 0) < 10 && essayFeedback.isNotEmpty) ...[
          gap(14),
          bubble('robot_talking', t.pdfFeedbackLabel, essayFeedback),
        ],
        if (idea.isNotEmpty) ...[gap(14), ideaTicket(idea)],
        if (steps.isNotEmpty) ...[gap(16), stepPath(steps)],
      ],
    ];
  }

  // ── Full report ─────────────────────────────────────────────────────────

  /// One question of the report: a single page whose remaining space is
  /// "My notes" lines, or flowing pages when the content is long.
  void addQuestion(pw.Document doc, int index) {
    final header = questionHeader(index, record.itemName);
    final continued = t.pdfContinued(record.itemName, index + 1);
    List<pw.Widget> body() => questionBody(index);
    final pages = measure(
      (d) => flow(
        d,
        header: header,
        continued: continued,
        // Room for the notes title and two lines.
        body: [...body(), pw.SizedBox(height: 78)],
      ),
    );
    if (pages > 1) {
      // ponytail: a card never splits; one taller than a page would not fit
      // (explanations are capped at 1,800 characters, far below that).
      flow(
        doc,
        header: header,
        continued: continued,
        body: [...body(), pw.SizedBox(height: 18), notesTitle(), lines(90)],
      );
      return;
    }
    doc.addPage(
      pw.Page(
        pageTheme: _theme,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            header,
            pw.Expanded(
              child: _inset(
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    ...body(),
                    pw.SizedBox(height: 18),
                    notesTitle(),
                    // The rest of the page is writing lines.
                    pw.Expanded(
                      child: pw.LayoutBuilder(
                        builder: (_, box) => lines(box!.maxHeight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            footer(ctx),
          ],
        ),
      ),
    );
  }

  String get _difficulty => switch (record.difficulty) {
    QuizDifficulty.easy => t.h3Easy,
    QuizDifficulty.medium => t.h3Medium,
    QuizDifficulty.hard => t.h3Hard,
  };

  ({String art, String bin}) get _bin => switch (record.category) {
    ScanCategory.organic => (art: 'bin_organik', bin: t.pdfBinGreen),
    ScanCategory.b3 => (art: 'bin_b3', bin: t.pdfBinRed),
    ScanCategory.recyclable => (art: 'bin_anorganik', bin: t.pdfBinYellow),
    ScanCategory.residu => (art: 'bin_anorganik', bin: t.pdfBinGrey),
  };

  pw.Widget _stat(String label, String value, String note, PdfColor tone) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          over(label, c.text3),
          pw.SizedBox(height: 6),
          tx(value, s(14, 700, c.text)),
          pw.SizedBox(height: 5),
          tx(note, s(7.5, 500, tone)),
        ],
      );

  pw.Widget coverHeader() {
    final qs = record.questions;
    final total = qs.length, right = record.correctCount;
    final essays = qs.where((q) => q.isEssay).length;
    final headline = right == 0
        ? t.pdfHeadNone
        : (right == total ? t.pdfHeadAll : t.pdfHeadSome);
    final sub = right == 0
        ? t.pdfSubNone(total)
        : (right == total ? t.pdfSubAll : t.pdfSubSome(total - right));
    final (stamp, stampTone) = right == total
        ? (t.pdfStampPerfect, _pc(ElioTokens.light.primaryText))
        // Same three cases as the headline: none, some, all correct.
        : (right > 0
              ? (t.pdfStampGood, _pc(ElioTokens.light.secondaryText))
              : (t.pdfStampRetry, _pc(ElioTokens.light.errorText)));
    final textWidth = photo == null ? _w - 2 * _pad : 330.0;
    return pw.SizedBox(
      width: _w,
      height: 312,
      child: pw.Stack(
        overflow: pw.Overflow.visible,
        children: [
          band(312),
          pw.Positioned(left: _pad, top: 32, child: brand(t.pdfReportHead)),
          pw.Positioned(
            right: photo == null ? _pad : 190,
            top: 30,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                over(t.pdfExportedLabel, c.onGreen),
                pw.SizedBox(height: 2),
                tx(
                  QuizPdfService._dateTime(DateTime.now()),
                  s(8, 600, c.onGreen),
                ),
              ],
            ),
          ),
          pw.Positioned(
            left: _pad,
            top: 78,
            child: pw.SizedBox(
              width: textWidth,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.fromLTRB(6, 3.5, 9, 3.5),
                    decoration: box(PdfColors.white, radius: 8),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Container(
                          width: 7,
                          height: 7,
                          decoration: pw.BoxDecoration(
                            color: c.greenActive,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                        pw.SizedBox(width: 5),
                        tx(
                          t.pdfScanResult(record.category.badgeLabel),
                          s(7.5, 600, c.onGreen),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  tx(record.itemName, s(30, 700, c.onGreen), maxLines: 2),
                  pw.SizedBox(height: 6),
                  tx(
                    t.pdfCoverMeta(
                      total,
                      _difficulty.toLowerCase(),
                      total - essays,
                      essays,
                    ),
                    s(9, 500, c.onGreen),
                  ),
                  pw.SizedBox(height: 22),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Score ring.
                      pw.Container(
                        width: 76,
                        height: 76,
                        alignment: pw.Alignment.center,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.white,
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Column(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            tx('$right/$total', s(19, 700, c.onGreen)),
                            pw.SizedBox(height: 2),
                            over(t.pdfRingLabel, c.onGreen),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            tx(headline, s(14, 700, c.onGreen)),
                            pw.SizedBox(height: 4),
                            tx(sub, s(8.5, 500, c.onGreen)),
                            pw.SizedBox(height: 7),
                            pw.Container(
                              padding: const pw.EdgeInsets.fromLTRB(6, 3, 9, 3),
                              decoration: box(PdfColors.white, radius: 8),
                              child: pw.Row(
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  art('xp', 11, 11),
                                  pw.SizedBox(width: 4),
                                  tx(
                                    t.pdfXpChip(record.trophies, total * 10),
                                    s(7.5, 600, c.onGreen),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (photo != null)
            pw.Positioned(
              right: 44,
              top: 96,
              child: polaroid(132, t.pdfPhotoCaption(_time)),
            ),
          // Grade stamp.
          pw.Positioned(
            right: 30,
            top: photo == null ? 250 : 268,
            child: pw.Transform.rotateBox(
              angle: -.2,
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: box(
                  PdfColors.white,
                  edge: stampTone,
                  radius: 5,
                  width: 1.4,
                ),
                child: tx(
                  t.pdfStamp(stamp),
                  s(7.5, 700, stampTone, spacing: .9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ticket summary: three stats, a dashed tear line with notches, the stub.
  pw.Widget summaryTicket() {
    final total = record.questions.length, right = record.correctCount;
    const stub = 132.0;
    pw.Widget notch(bool top) => pw.Positioned(
      right: stub + 11,
      top: top ? -6 : null,
      bottom: top ? null : -6,
      child: pw.Container(
        width: 12,
        height: 12,
        decoration: pw.BoxDecoration(
          color: c.bg,
          shape: pw.BoxShape.circle,
          border: pw.Border.all(color: c.border),
        ),
      ),
    );
    return pw.Stack(
      overflow: pw.Overflow.visible,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(18, 18, 0, 18),
          decoration: box(c.surface, edge: c.border, radius: 16),
          child: pw.Table(
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
            columnWidths: const {
              0: pw.FlexColumnWidth(),
              1: pw.FlexColumnWidth(),
              2: pw.FlexColumnWidth(),
              3: pw.FixedColumnWidth(stub + 17),
            },
            children: [
              pw.TableRow(
                children: [
                  _stat(
                    t.pdfCorrect,
                    t.pdfCorrectOf(right, total),
                    right == total
                        ? t.pdfAllRight
                        : t.pdfNeedReview(total - right),
                    right == total ? c.okText : c.errText,
                  ),
                  _stat(
                    t.pdfTrophies,
                    t.h3PlusTrophies(record.trophies),
                    t.pdfXpRule,
                    c.warn,
                  ),
                  _stat(
                    t.pdfDifficultyShort,
                    _difficulty,
                    t.pdfQuestionsCount(total),
                    c.info,
                  ),
                  // Stub behind the dashed tear line.
                  pw.Container(
                    padding: const pw.EdgeInsets.only(left: 16, right: 14),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(
                          color: c.borderMed,
                          style: pw.BorderStyle.dashed,
                        ),
                      ),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              over(t.pdfCategory, c.text3),
                              pw.SizedBox(height: 6),
                              tx(
                                record.category.badgeLabel,
                                s(11.5, 700, c.okText),
                              ),
                              pw.SizedBox(height: 4),
                              tx(_bin.bin, s(7.5, 500, c.text2)),
                            ],
                          ),
                        ),
                        art(_bin.art, 34, 40),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        notch(true),
        notch(false),
      ],
    );
  }

  /// One row of the question map; [page] is where its page starts.
  pw.Widget mapRow(int index, int page, bool last) {
    final q = record.questions[index], r = resultOf(q), chip = chipOf(q);
    final tone = switch (r) {
      _Result.right => c.greenActive,
      _Result.wrong => c.err,
      _Result.essay => chip.fill,
      _ => c.text3,
    };
    final toneText = switch (r) {
      _Result.right => c.okText,
      _Result.wrong => c.errText,
      _Result.essay => scoreTone(q.essayScore ?? 0, 10),
      _ => c.text2,
    };
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: last ? 0 : 12),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 27,
            height: 27,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: c.soft(tone),
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: c.tintEdge(tone), width: 1.2),
            ),
            child: tx('${index + 1}', s(10.5, 700, toneText)),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                over(
                  t.pdfMapPage(q.isEssay ? t.pdfTypeEssay : t.pdfTypeMc, page),
                  c.text3,
                ),
                pw.SizedBox(height: 3),
                tx(q.question, s(9.8, 600, c.text, leading: 2), maxLines: 3),
                pw.SizedBox(height: 3),
                tx(
                  r == _Result.skipped
                      ? t.essaySkipped
                      : t.pdfYourAnswerLine(q.yourAnswer),
                  s(8, 500, toneText),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pill(chip.label, c.soft(tone), toneText, size: 7),
        ],
      ),
    );
  }

  /// A tip made of this quiz's own key ideas.
  pw.Widget tipBubble() {
    // Each different idea once (two questions can share one).
    final ideas = {
      for (final q in record.questions)
        if ((q.explanation?.keyIdea ?? '').trim().isNotEmpty &&
            !(q.explanation?.isUnavailable ?? true))
          q.explanation!.keyIdea.trim(),
    }.toList();
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        art('bulb', 38, 44),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(14, 11, 14, 12),
            decoration: box(
              c.soft(c.warn),
              edge: c.tintEdge(c.warn),
              shape: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(14),
                bottomRight: pw.Radius.circular(14),
                bottomLeft: pw.Radius.circular(14),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                over(t.pdfTipLabel, c.warn),
                pw.SizedBox(height: 4),
                tx(
                  ideas.isEmpty
                      ? t.pdfTipGeneric
                      : t.pdfTipIdeas(
                          ideas.length,
                          [
                            for (var i = 0; i < ideas.length; i++)
                              '(${i + 1}) ${ideas[i]}',
                          ].join(' '),
                        ),
                  s(8.8, 400, c.text, leading: 3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Document report() {
    final n = record.questions.length;
    // Each question's page count first, so the map can print "P. n".
    final counts = [
      for (var i = 0; i < n; i++) measure((d) => addQuestion(d, i)),
    ];
    List<pw.Widget> cover(int coverPages) {
      var page = coverPages + 1;
      final rows = <pw.Widget>[];
      for (var i = 0; i < n; i++) {
        rows.add(mapRow(i, page, i == n - 1));
        page += counts[i];
      }
      return [
        pw.SizedBox(height: 22),
        summaryTicket(),
        pw.SizedBox(height: 22),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            tx(t.pdfMapTitle, s(13, 700, c.text)),
            pw.SizedBox(width: 8),
            tx('· ${t.pdfMapHint}', s(7.5, 400, c.text3)),
          ],
        ),
        pw.SizedBox(height: 3),
        squiggle(48),
        pw.SizedBox(height: 14),
        ...rows,
        pw.SizedBox(height: 18),
        tipBubble(),
      ];
    }

    void addCover(pw.Document d, int coverPages) => flow(
      d,
      header: coverHeader(),
      continued: t.pdfReportHead,
      body: cover(coverPages),
    );
    final coverPages = measure((d) => addCover(d, 1));
    final doc = pw.Document();
    addCover(doc, coverPages);
    for (var i = 0; i < n; i++) {
      addQuestion(doc, i);
    }
    return doc;
  }

  // ── Single question ─────────────────────────────────────────────────────

  pw.Document single(int index, QuestionPdfOptions o) {
    final doc = pw.Document();
    final withPhoto = o.photo && photo != null;
    flow(
      doc,
      header: questionHeader(
        index,
        t.pdfSingleExport(record.itemName),
        withPhoto: withPhoto,
      ),
      continued: t.pdfContinued(record.itemName, index + 1),
      body: [
        // The polaroid hangs below the band: keep the title clear of it.
        if (withPhoto && !o.answers) pw.SizedBox(height: 40),
        ...questionBody(
          index,
          answersOn: o.answers,
          explanationOn: o.explanation,
          titleGap: withPhoto ? 130 : 0,
        ),
      ],
    );
    if (o.notes) doc.addPage(notesPage(index));
    return doc;
  }

  pw.Widget _checkItem(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 11,
          height: 11,
          decoration: box(
            c.surface,
            edge: c.greenActive,
            radius: 3,
            width: 1.2,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(child: tx(text, s(8.5, 500, c.text, leading: 2))),
      ],
    ),
  );

  /// "Ruang catatan": every prompt is built from this question's own text.
  pw.Page notesPage(int index) {
    final q = record.questions[index], e = q.explanation;
    final idea = e == null || e.isUnavailable ? '' : e.keyIdea.trim();
    final wrong = !q.isCorrect;
    final half = (_w - 2 * _pad - 14) / 2;
    return pw.Page(
      pageTheme: _theme,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          questionHeader(
            index,
            t.pdfSingleExport(record.itemName),
            overline: t.pdfNotesOver(index + 1),
            // "Stick a sticker" circle.
            corner: pw.Container(
              width: 62,
              height: 62,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
                border: pw.Border.all(
                  color: _pc(ElioTokens.light.borderMedium),
                  style: pw.BorderStyle.dashed,
                ),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Opacity(opacity: .45, child: art('medal', 15, 18)),
                  pw.SizedBox(height: 2),
                  tx(
                    t.pdfSticker,
                    s(5.8, 500, _pc(ElioTokens.light.textSecondary)),
                    align: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            child: _inset(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 8),
                  tx(t.pdfNotesTitle, s(19, 700, c.text)),
                  pw.SizedBox(height: 3),
                  squiggle(60),
                  pw.SizedBox(height: 6),
                  tx(t.pdfNotesIntro, s(8.8, 400, c.text2, leading: 2.5)),
                  pw.SizedBox(height: 22),
                  // 1 · Explain again.
                  pw.Stack(
                    overflow: pw.Overflow.visible,
                    children: [
                      pw.Container(
                        width: _w - 2 * _pad,
                        padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 12),
                        decoration: box(
                          c.surface,
                          edge: c.tintEdge(c.greenActive),
                          shape: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(14),
                            topRight: pw.Radius.circular(14),
                            bottomRight: pw.Radius.circular(28),
                            bottomLeft: pw.Radius.circular(14),
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            over(t.pdfN1, c.okText),
                            pw.SizedBox(height: 6),
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(right: 30),
                              child: tx(
                                t.pdfN1Prompt(q.question),
                                s(10, 600, c.text, leading: 2.5),
                              ),
                            ),
                            if (idea.isNotEmpty) ...[
                              pw.SizedBox(height: 4),
                              tx(
                                t.pdfN1Idea(idea),
                                s(8.2, 400, c.text2, leading: 2),
                              ),
                            ],
                            pw.SizedBox(
                              width: _w - 2 * _pad - 32,
                              child: lines(72),
                            ),
                          ],
                        ),
                      ),
                      pw.Positioned(
                        right: 12,
                        top: -22,
                        child: art('bulb', 30, 35),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 14),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // 2 · Draw and compare: dotted sketch grid.
                      pw.Container(
                        width: half,
                        height: 268,
                        padding: const pw.EdgeInsets.all(14),
                        decoration: box(
                          c.surface,
                          edge: c.borderMed,
                          dashed: true,
                          radius: 14,
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            over(t.pdfN2, c.info),
                            pw.SizedBox(height: 6),
                            tx(
                              idea.isEmpty
                                  ? t.pdfN2Generic
                                  : t.pdfN2Prompt(idea),
                              s(8.5, 500, c.text, leading: 2),
                              maxLines: 4,
                            ),
                            pw.SizedBox(height: 8),
                            pw.Expanded(
                              child: pw.LayoutBuilder(
                                builder: (_, box) => pw.CustomPaint(
                                  size: PdfPoint(box!.maxWidth, box.maxHeight),
                                  painter: (g, size) {
                                    g.setFillColor(c.borderMed);
                                    for (var y = 4.0; y < size.y; y += 12) {
                                      for (var x = 4.0; x < size.x; x += 12) {
                                        g.drawEllipse(x, y, .6, .6);
                                      }
                                    }
                                    g.fillPath();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 14),
                      pw.SizedBox(
                        width: half,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            // 3 · Self-check.
                            pw.Container(
                              width: half,
                              padding: const pw.EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                14,
                              ),
                              decoration: box(
                                c.soft(c.greenActive),
                                edge: c.tintEdge(c.greenActive),
                                radius: 14,
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  over(t.pdfN3, c.okText),
                                  if (idea.isNotEmpty)
                                    _checkItem(t.pdfCheckIdea(idea)),
                                  _checkItem(
                                    wrong ? t.pdfCheckWrong : t.pdfCheckRight,
                                  ),
                                  _checkItem(t.pdfCheckTry(record.itemName)),
                                ],
                              ),
                            ),
                            pw.SizedBox(height: 12),
                            // 4 · Challenge ticket.
                            ticket(
                              c.warn,
                              pw.Row(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.center,
                                children: [
                                  art('xp', 22, 22),
                                  pw.SizedBox(width: 10),
                                  pw.Expanded(
                                    child: pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      mainAxisSize: pw.MainAxisSize.min,
                                      children: [
                                        over(t.pdfN4, c.warn),
                                        pw.SizedBox(height: 4),
                                        tx(
                                          t.pdfChallenge(record.itemName),
                                          s(8.5, 600, c.text, leading: 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            pw.SizedBox(height: 12),
                            // 5 · My question for the teacher.
                            pw.Container(
                              width: half,
                              padding: const pw.EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                8,
                              ),
                              decoration: box(
                                c.surface,
                                edge: c.border,
                                radius: 14,
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  over(t.pdfN5, c.text3),
                                  pw.SizedBox(
                                    width: half - 28,
                                    child: lines(50),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  // Signature and date.
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(height: .8, color: c.borderMed),
                            pw.SizedBox(height: 5),
                            tx(t.pdfSign, s(7.5, 400, c.text3)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 24),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(height: .8, color: c.borderMed),
                            pw.SizedBox(height: 5),
                            tx(t.pdfDate, s(7.5, 400, c.text3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          footer(ctx),
        ],
      ),
    );
  }
}
