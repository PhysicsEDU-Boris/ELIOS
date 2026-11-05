import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/quiz_explanation.dart';
import '../models/scan_record.dart';
import '../services/history_explanation_service.dart';
import '../services/history_translation_service.dart';
import '../services/quiz_pdf_service.dart';
import '../services/quiz_tts_service.dart';
import '../services/scan_record_store.dart';
import '../l10n/l10n.dart';
import '../theme/elio_tokens.dart';
import '../widgets/auth/auth_widgets.dart' show authPalette;
import '../widgets/history_ui.dart';
import 'home/home_parts.dart' show homeArt;

class QuestionExplanationScreen extends StatefulWidget {
  const QuestionExplanationScreen({
    super.key,
    required this.record,
    required this.questionIndex,
    required this.store,
    this.loadTimeout = const Duration(seconds: 45),
  });
  final ScanRecord record;
  final int questionIndex;
  final ScanRecordStore store;
  final Duration loadTimeout;
  @override
  State<QuestionExplanationScreen> createState() =>
      _QuestionExplanationScreenState();
}

class _QuestionExplanationScreenState extends State<QuestionExplanationScreen>
    with WidgetsBindingObserver {
  late int _index = widget.questionIndex;
  QuizExplanation? _explanation;
  bool _loading = true, _whole = false;

  /// The app language shown ('en'/'id'); [_original]: its translation is not
  /// available (offline), so the record's own language is shown with a note.
  String? _lang;
  bool _original = false;
  String? _playing;
  int _loadEpoch = 0, _speechEpoch = 0;
  final _scroll = ScrollController();
  ScanRecord get _record =>
      widget.store.records.where((r) => r.id == widget.record.id).firstOrNull ??
      widget.record;
  ScanRecord get _shown => _record.localized(_lang ?? _record.lang);
  RecordQuestion get _q => _shown.questions[_index];
  String get _speechLang => _original ? _record.lang : _lang!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.l10n.localeName == 'en' ? 'en' : 'id';
    if (lang == _lang) return;
    // A live language switch stops speech and shows the record in the new language.
    if (_lang != null) _stop();
    _lang = lang;
    _loading = true;
    Future.microtask(_load);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speechEpoch++;
    _loadEpoch++;
    unawaited(QuizTtsService.instance.stop());
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool retry = false}) async {
    final epoch = ++_loadEpoch;
    setState(() {
      _loading = true;
      _explanation = _q.explanation;
    });
    try {
      final lang = _lang!;
      final result = await HistoryExplanationService.load(
        widget.store,
        _record,
        _index,
        retry: retry,
      ).timeout(widget.loadTimeout);
      // Texts made in another language are translated once and cached.
      final translated = await HistoryTranslationService.ensure(
        widget.store,
        _record,
        lang,
      ).timeout(widget.loadTimeout);
      if (mounted && epoch == _loadEpoch) {
        setState(() {
          _loading = false;
          _original = !translated;
          _explanation = _inLanguage(result, lang);
        });
      }
    } catch (_) {
      if (mounted && epoch == _loadEpoch) {
        setState(() {
          _loading = false;
          _original = _record.needsTranslation(_lang!);
        });
      }
    }
  }

  /// [result] when it is already in [lang], else its cached translation, else
  /// the original (shown with the "connect to translate" note).
  QuizExplanation _inLanguage(QuizExplanation result, String lang) {
    if ((result.lang ?? _record.lang) == lang) return result;
    if (result.alt?.lang == lang) return result.alt!;
    final cached = _record.localized(lang).questions[_index].explanation;
    return cached != null && (cached.lang ?? _record.lang) == lang
        ? cached
        : result;
  }

  void _stop() {
    _speechEpoch++;
    unawaited(QuizTtsService.instance.stop());
    if (mounted) {
      setState(() {
        _playing = null;
        _whole = false;
      });
    }
  }

  List<(String, String, String)> get _sections {
    final e = _explanation, t = context.l10n;
    if (e == null) return [];
    return [
      if (e.correctAnswerReason.isNotEmpty)
        ('correct', t.h3WhyCorrect, e.correctAnswerReason),
      if (!_q.isCorrect && !_q.isEssay && e.selectedAnswerFeedback.isNotEmpty)
        ('wrong', t.h3WhyWrong, e.selectedAnswerFeedback),
      if (_q.isEssay && (e.essayFeedback ?? '').isNotEmpty)
        ('feedback', t.h3Feedback, e.essayFeedback!),
      if (e.keyIdea.isNotEmpty) ('idea', t.h3KeyIdeaTitle, e.keyIdea),
      if (e.steps.isNotEmpty) ('steps', t.h3HowTo, e.steps.join('\n')),
    ];
  }

  Future<void> _listen(String id, String text) async {
    if (_playing == id || (id == 'question' && _whole)) {
      _stop();
      return;
    }
    _stop();
    final epoch = _speechEpoch;
    final parts = id == 'question'
        ? [('question', '', _q.question), ..._sections]
        : [(id, '', text)];
    setState(() => _whole = id == 'question');
    for (final part in parts) {
      if (!mounted || epoch != _speechEpoch) return;
      setState(() => _playing = part.$1);
      await QuizTtsService.instance.speak(
        '${part.$2} ${part.$3}',
        lang: _speechLang,
      );
    }
    if (mounted && epoch == _speechEpoch) {
      setState(() {
        _playing = null;
        _whole = false;
      });
    }
  }

  Widget _listenButton(String id, String text) => HistoryListenButton(
    active: _playing == id || (id == 'question' && _whole),
    onPressed: () => _listen(id, text),
  );

  Future<void> _openExport() async {
    _stop();
    final theme = Theme.of(context), p = authPalette(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      barrierColor: const Color(0x8C0F172A), // Figma scrim #0F172A at 55 %
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Theme(
        data: theme,
        child: QuestionExportSheet(record: _shown, questionIndex: _index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), q = _q;
    final sections = _sections;
    String? body(String id) =>
        sections.where((s) => s.$1 == id).firstOrNull?.$3;
    final idea = body('idea'), steps = _explanation?.steps ?? const [];
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _stop();
      },
      child: Scaffold(
        backgroundColor: p.background,
        appBar: HistoryTopBar(
          title: context.l10n.h3ExplanationTitle,
          subtitle: context.l10n.h3ExplanationMeta(
            _record.itemName,
            _index + 1,
            _record.questions.length,
          ),
          trailing: ListenableBuilder(
            listenable: widget.store,
            builder: (_, child) =>
                HistoryTrophyPill(widget.store.totalTrophies),
          ),
        ),
        body: _loading
            ? const HistorySkeleton(HistoryLoadingLayout.explanation)
            : ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (_original)
                    HistoryOriginalNote(
                      lang: _record.lang,
                      onRetry: () => unawaited(_load()),
                    ),
                  ConstrainedBox(
                    // Figma meta row is 100 high with the chips centred.
                    constraints: const BoxConstraints(minHeight: 100),
                    child: Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              HistoryQuestionBadge(
                                _index + 1,
                                correct: q.isCorrect,
                                essay: q.isEssay,
                              ),
                              HistoryChip(
                                historyDifficulty(
                                  context.l10n,
                                  _record.difficulty,
                                ),
                              ),
                              HistoryResultChip(q),
                              HistoryTrophyChip(q.trophies),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _listenButton('question', q.question),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    q.question,
                    style: ElioTokens.headline.copyWith(color: p.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  HistoryAnswer(
                    context.l10n.h3YourAnswer,
                    q.yourAnswer,
                    tone: q.isEssay
                        ? HistoryTone.neutral
                        : q.isCorrect
                        ? HistoryTone.success
                        : HistoryTone.error,
                  ),
                  const SizedBox(height: 8),
                  HistoryAnswer(
                    q.isEssay
                        ? context.l10n.h3ReferenceAnswer
                        : context.l10n.h3CorrectAnswer,
                    q.rightAnswer,
                    tone: q.isEssay ? HistoryTone.neutral : HistoryTone.success,
                    check: !q.isEssay,
                  ),
                  const SizedBox(height: 16),
                  HistorySectionHeader(context.l10n.h3ExplanationTitle),
                  const SizedBox(height: 16),
                  for (final (i, s)
                      in sections
                          .where((s) => s.$1 != 'idea' && s.$1 != 'steps')
                          .indexed) ...[
                    if (i > 0) const SizedBox(height: 4),
                    HistoryExplanationSection(
                      title: s.$2,
                      body: s.$3,
                      active: _playing == s.$1,
                      onListen: () => _listen(s.$1, s.$3),
                    ),
                  ],
                  if (idea != null) ...[
                    const SizedBox(height: 16),
                    HistoryKeyIdea(
                      active: _playing == 'idea',
                      text: idea,
                      art: homeArt(
                        switch (_record.category) {
                          ScanCategory.b3 => 'history_buddy_b3',
                          ScanCategory.organic => 'bin_organik',
                          _ => 'bin_anorganik',
                        },
                        width: 64,
                        height: 76,
                      ),
                    ),
                  ],
                  if (body('steps') != null) ...[
                    const SizedBox(height: 16),
                    HistorySteps(
                      title: context.l10n.h3HowTo,
                      steps: steps,
                      active: _playing == 'steps',
                    ),
                  ],
                  if (_explanation == null ||
                      (!_explanation!.isComplete && !q.isEssay) ||
                      _explanation!.isUnavailable)
                    HistoryError(onRetry: () => _load(retry: true)),
                ],
              ),
        bottomNavigationBar: HistoryActionsBar(
          children: [
            OutlinedButton.icon(
              style: historyOutlineStyle(p),
              onPressed: _openExport,
              icon: const Icon(Icons.description_outlined),
              label: Text(context.l10n.h3ExportPdf),
            ),
            if (_index + 1 < _record.questions.length)
              FilledButton.icon(
                style: historyPrimaryStyle(p),
                iconAlignment: IconAlignment.end,
                onPressed: () {
                  _stop();
                  setState(() => _index++);
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                  unawaited(_load());
                },
                icon: const Icon(Icons.chevron_right),
                label: Text(context.l10n.h3NextQuestion),
              ),
          ],
        ),
      ),
    );
  }
}

class QuestionExportSheet extends StatefulWidget {
  const QuestionExportSheet({
    super.key,
    required this.record,
    required this.questionIndex,
  });
  final ScanRecord record;
  final int questionIndex;
  @override
  State<QuestionExportSheet> createState() => _QuestionExportSheetState();
}

class _QuestionExportSheetState extends State<QuestionExportSheet> {
  final _include = [true, true, false, false];
  bool _busy = false;
  String? _error;
  QuestionPdfOptions get _options => QuestionPdfOptions(
    answers: _include[0],
    explanation: _include[1],
    photo: _include[2],
    notes: _include[3],
  );
  Future<void> _export(bool share) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (share) {
        await QuizPdfService.shareQuestion(
          widget.record,
          widget.questionIndex,
          options: _options,
        );
      } else {
        final path = await QuizPdfService.saveQuestion(
          widget.record,
          widget.questionIndex,
          options: _options,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.h3PdfSaved(path))),
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.h3PdfFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), paper = ElioTokens.light;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, math.max(28, inset + 12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: ShapeDecoration(
                color: p.borderMedium,
                shape: const StadiumBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.h3ExportQuestion,
            style: ElioTokens.subhead.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.h3ExportOnly(
              widget.questionIndex + 1,
              widget.record.itemName,
            ),
            style: ElioTokens.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: ShapeDecoration(
              color: p.surfaceRaised,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // The page is always white (the PDF prints light).
                Container(
                  width: 52,
                  height: 72,
                  padding: const EdgeInsets.fromLTRB(7, 9, 5, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: paper.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (w, c) in [
                        (18.0, paper.error),
                        (36.0, paper.textPrimary),
                        (30.0, paper.textPrimary),
                        (40.0, paper.borderMedium),
                        (34.0, paper.borderMedium),
                        (40.0, paper.borderMedium),
                        (22.0, paper.primaryText),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            width: w,
                            height: 3,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        QuizPdfService.questionFilename(
                          widget.record,
                          widget.questionIndex,
                        ),
                        style: ElioTokens.body.copyWith(color: p.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.h3A4Pdf,
                        style: ElioTokens.caption.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.h3Include,
            style: ElioTokens.overline.copyWith(color: p.textTertiary),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < 4; i++)
            CheckboxListTile(
              contentPadding: const EdgeInsets.only(left: 4),
              minTileHeight: 48,
              minVerticalPadding: 0,
              dense: true,
              horizontalTitleGap: 12,
              checkboxScaleFactor: 24 / 18,
              checkboxShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
              visualDensity: const VisualDensity(vertical: -4),
              controlAffinity: ListTileControlAffinity.leading,
              value: _include[i],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _include[i] = value!),
              title: Text(
                [
                  context.l10n.h3IncAnswers,
                  context.l10n.h3IncExplanation,
                  context.l10n.h3IncPhoto,
                  context.l10n.h3IncNotes,
                ][i],
                style: ElioTokens.body.copyWith(color: p.textPrimary),
              ),
            ),
          if (_error != null)
            Text(
              _error!,
              style: ElioTokens.bodySmall.copyWith(color: p.errorText),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: historyOutlineStyle(p),
                  onPressed: _busy ? null : () => _export(true),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(context.l10n.h3Share),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: historyPrimaryStyle(p),
                  onPressed: _busy ? null : () => _export(false),
                  icon: const Icon(Icons.description_outlined),
                  label: Text(
                    _busy ? context.l10n.h3Saving : context.l10n.h3SavePdf,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
