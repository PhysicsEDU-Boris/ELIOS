import 'dart:async';
import 'package:flutter/material.dart';
import '../models/quiz_explanation.dart';
import '../models/scan_record.dart';
import '../services/history_explanation_service.dart';
import '../services/quiz_pdf_service.dart';
import '../services/quiz_tts_service.dart';
import '../services/scan_record_store.dart';
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
  String? _playing;
  int _loadEpoch = 0, _speechEpoch = 0;
  final _scroll = ScrollController();
  ScanRecord get _record =>
      widget.store.records.where((r) => r.id == widget.record.id).firstOrNull ??
      widget.record;
  RecordQuestion get _q => _record.questions[_index];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
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
      final result = await HistoryExplanationService.load(
        widget.store,
        _record,
        _index,
        retry: retry,
      ).timeout(widget.loadTimeout);
      if (mounted && epoch == _loadEpoch) {
        setState(() {
          _loading = false;
          _explanation = result;
        });
      }
    } catch (_) {
      if (mounted && epoch == _loadEpoch) setState(() => _loading = false);
    }
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
    final e = _explanation;
    if (e == null) return [];
    return [
      if (e.correctAnswerReason.isNotEmpty)
        ('correct', 'Kenapa ini jawaban yang benar', e.correctAnswerReason),
      if (!_q.isCorrect && !_q.isEssay && e.selectedAnswerFeedback.isNotEmpty)
        ('wrong', 'Kenapa jawabanmu kurang tepat', e.selectedAnswerFeedback),
      if (_q.isEssay && (e.essayFeedback ?? '').isNotEmpty)
        ('feedback', 'Umpan balik', e.essayFeedback!),
      if (e.keyIdea.isNotEmpty) ('idea', 'Ide utama', e.keyIdea),
      if (e.steps.isNotEmpty)
        ('steps', 'Cara melakukannya', e.steps.join('\n')),
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
      await QuizTtsService.instance.speak('${part.$2} ${part.$3}');
    }
    if (mounted && epoch == _speechEpoch) {
      setState(() {
        _playing = null;
        _whole = false;
      });
    }
  }

  Widget _listenButton(String id, String text) {
    final p = authPalette(context),
        active = _playing == id || (id == 'question' && _whole);
    return IconButton(
      tooltip: active ? 'Jeda' : 'Dengarkan',
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: () => _listen(id, text),
      icon: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.primaryText.withValues(alpha: p.isDark ? .12 : .06),
          border: Border.all(color: p.primaryText.withValues(alpha: .35)),
        ),
        child: Icon(
          active ? Icons.pause : Icons.play_arrow,
          size: 18,
          color: p.primaryText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), q = _q;
    final tint = q.isEssay
        ? p.textSecondary
        : q.isCorrect
        ? p.primaryText
        : p.errorText;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _stop();
      },
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kembali',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          backgroundColor: p.background,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Penjelasan',
                style: ElioTokens.subhead.copyWith(
                  fontFamily: ElioTokens.fontSans,
                  color: p.textPrimary,
                ),
              ),
              Text(
                '${_record.itemName} · Soal ${_index + 1} dari ${_record.questions.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ElioTokens.caption.copyWith(color: p.textSecondary),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ListenableBuilder(
                listenable: widget.store,
                builder: (_, child) => HistoryPill(
                  '${widget.store.totalTrophies}',
                  color: p.secondaryText,
                  icon: Icons.emoji_events_outlined,
                ),
              ),
            ),
          ],
        ),
        body: _loading
            ? const HistorySkeleton(HistoryLoadingLayout.explanation)
            : ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 8,
                          children: [
                            HistoryQuestionBadge(
                              _index + 1,
                              correct: q.isCorrect,
                              essay: q.isEssay,
                            ),
                            HistoryPill(historyDifficulty(_record.difficulty)),
                            HistoryPill(
                              q.isEssay
                                  ? (q.gradingPending
                                        ? 'Menunggu penilaian'
                                        : 'Skor ${q.essayScore}/10')
                                  : q.isCorrect
                                  ? 'Benar'
                                  : 'Salah',
                              color: tint,
                            ),
                            HistoryPill(
                              '+${q.trophies}',
                              color: p.secondaryText,
                              icon: Icons.emoji_events_outlined,
                            ),
                          ],
                        ),
                      ),
                      _listenButton('question', q.question),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    q.question,
                    style: ElioTokens.headline.copyWith(
                      fontFamily: ElioTokens.fontSans,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  HistoryAnswer(
                    'Jawabanmu',
                    q.yourAnswer,
                    color: q.isEssay
                        ? null
                        : q.isCorrect
                        ? p.primaryText
                        : p.errorText,
                  ),
                  const SizedBox(height: 8),
                  HistoryAnswer(
                    q.isEssay ? 'Jawaban acuan' : 'Jawaban benar',
                    q.rightAnswer,
                    color: q.isEssay ? null : p.primaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Penjelasan',
                    style: ElioTokens.subhead.copyWith(
                      fontFamily: ElioTokens.fontSans,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final section in _sections) _section(section),
                  if (_explanation == null ||
                      (!_explanation!.isComplete && !q.isEssay) ||
                      _explanation!.isUnavailable)
                    HistoryError(onRetry: () => _load(retry: true)),
                ],
              ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(top: BorderSide(color: p.borderSubtle)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () async {
                        _stop();
                        await showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: p.surface,
                          showDragHandle: true,
                          builder: (_) => Theme(
                            data: Theme.of(context),
                            child: QuestionExportSheet(
                              record: _record,
                              questionIndex: _index,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.description_outlined, size: 20),
                      label: const Text('Ekspor PDF'),
                    ),
                  ),
                  if (_index + 1 < _record.questions.length) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: () {
                          _stop();
                          setState(() => _index++);
                          if (_scroll.hasClients) _scroll.jumpTo(0);
                          unawaited(_load());
                        },
                        child: const Text('Soal berikutnya'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section((String, String, String) section) {
    final p = authPalette(context), active = _playing == section.$1;
    final idea = section.$1 == 'idea';
    if (idea) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: HistoryCard(
          padding: 12,
          tint: active ? p.primaryText : p.tertiaryText,
          child: Row(
            children: [
              homeArt(
                switch (_record.category) {
                  ScanCategory.b3 => 'history_buddy_b3',
                  ScanCategory.organic => 'bin_organik',
                  _ => 'bin_anorganik',
                },
                width: 64,
                height: 76,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            section.$2.toUpperCase(),
                            style: ElioTokens.overline.copyWith(
                              fontFamily: ElioTokens.fontSans,
                              color: p.tertiaryText,
                            ),
                          ),
                        ),
                        _listenButton(section.$1, section.$3),
                      ],
                    ),
                    if (active)
                      Text(
                        'Sedang dibacakan',
                        style: ElioTokens.caption.copyWith(
                          color: p.primaryText,
                        ),
                      ),
                    Text(
                      section.$3,
                      style: ElioTokens.bodySmall.copyWith(
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: HistoryCard(
        padding: 12,
        plain: !active,
        tint: active ? p.primaryText : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    section.$2,
                    style: ElioTokens.subhead.copyWith(
                      fontFamily: ElioTokens.fontSans,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                _listenButton(section.$1, section.$3),
              ],
            ),
            if (active)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Sedang dibacakan',
                  style: ElioTokens.caption.copyWith(color: p.primaryText),
                ),
              ),
            if (section.$1 == 'steps') ...[
              for (var i = 0; i < _explanation!.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HistoryPill('${i + 1}'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _explanation!.steps[i],
                          style: ElioTokens.body.copyWith(color: p.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
            ] else
              Text(
                section.$3,
                style: ElioTokens.body.copyWith(color: p.textPrimary),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('PDF tersimpan: $path')));
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'PDF belum dapat diekspor. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ekspor soal ini',
              style: ElioTokens.subhead.copyWith(
                fontFamily: ElioTokens.fontSans,
                color: p.textPrimary,
              ),
            ),
            Text(
              'Hanya soal ${widget.questionIndex + 1} dari ${widget.record.itemName} masuk ke PDF.',
              style: ElioTokens.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 16),
            HistoryCard(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 74,
                    padding: const EdgeInsets.all(6),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              width: i.isEven ? 34 : 22,
                              height: 3,
                              color: i == 0
                                  ? p.errorText
                                  : i == 6
                                  ? p.primaryText
                                  : p.borderMedium,
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
                          style: ElioTokens.bodySmall.copyWith(
                            color: p.textPrimary,
                          ),
                        ),
                        Text(
                          'A4 · PDF',
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
              'SERTAKAN',
              style: ElioTokens.overline.copyWith(
                fontFamily: ElioTokens.fontSans,
                color: p.textSecondary,
              ),
            ),
            for (var i = 0; i < 4; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _include[i],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _include[i] = value!),
                title: Text(
                  [
                    'Soal dan kedua jawaban',
                    'Penjelasan dan langkah',
                    'Foto scan',
                    'Ruang catatan',
                  ][i],
                ),
              ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: p.errorText)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _busy ? null : () => _export(true),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Bagikan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _busy ? null : () => _export(false),
                    icon: const Icon(Icons.description_outlined),
                    label: Text(_busy ? 'Menyimpan…' : 'Simpan PDF'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
