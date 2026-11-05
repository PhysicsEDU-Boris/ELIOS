import 'dart:async';
import 'package:flutter/material.dart';
import '../models/scan_record.dart';
import '../services/ai_quiz_service.dart';
import '../services/quiz_pdf_service.dart';
import '../services/scan_record_store.dart';
import '../theme/elio_tokens.dart';
import '../widgets/auth/auth_widgets.dart' show authPalette;
import '../widgets/history_ui.dart';
import 'home/home_parts.dart' show homeArt;
import 'device_scan_screen.dart';
import 'question_explanation_screen.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({
    super.key,
    this.store,
    this.onClose,
    this.onStartScan,
    this.showHeader = true,
    this.loadTimeout = const Duration(seconds: 15),
  });
  final bool showHeader;
  final ScanRecordStore? store;
  final VoidCallback? onClose, onStartScan;
  final Duration loadTimeout;
  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  late final ScanRecordStore _store = widget.store ?? ScanRecordStore.instance;
  ScanCategory? _filter;
  String? _selected;
  bool _failed = false;
  int _loadEpoch = 0;
  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    if (!_store.isLoaded) unawaited(_load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    setState(() => _failed = false);
    try {
      await _store.load(force: true).timeout(widget.loadTimeout);
      if (_store.loadError != null) {
        throw StateError('History could not be loaded');
      }
    } catch (_) {
      if (mounted && epoch == _loadEpoch) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _scan() {
    if (widget.onStartScan != null) {
      widget.onStartScan!();
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DeviceScanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final records = _store.records
        .where((r) => _filter == null || r.category == _filter)
        .toList();
    final selected =
        records.where((r) => r.id == _selected).firstOrNull ??
        records.firstOrNull;
    return Scaffold(
      backgroundColor: p.background,
      appBar: widget.showHeader
          ? AppBar(
              backgroundColor: p.background,
              leading: widget.onClose == null
                  ? Icon(Icons.person_outline, color: p.primaryText)
                  : IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Kembali',
                    ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Riwayat',
                    style: ElioTokens.subhead.copyWith(
                      fontFamily: ElioTokens.fontSans,
                      color: p.textPrimary,
                    ),
                  ),
                  Text(
                    'Hasil scan, kuis, dan piala',
                    style: ElioTokens.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            if (_failed || _store.loadError != null) {
              return HistoryError(
                message: 'Riwayat belum dapat dimuat',
                onRetry: _load,
              );
            }
            if (!_store.isLoaded) {
              return const HistorySkeleton(HistoryLoadingLayout.list);
            }
            if (_store.records.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      homeArt('history_empty', width: 240, height: 180),
                      const SizedBox(height: 24),
                      Text(
                        'Belum ada scan',
                        style: ElioTokens.subhead.copyWith(
                          fontFamily: ElioTokens.fontSans,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Scan benda dengan ELIOS. Hasil kuis dan pialamu akan muncul di sini.',
                        textAlign: TextAlign.center,
                        style: ElioTokens.bodySmall.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _scan,
                        child: const Text('Mulai scan'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final list = ListView(
              key: const ValueKey('history_list'),
              padding: const EdgeInsets.all(16),
              children: [
                _summary(context),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in [
                      null,
                      ScanCategory.b3,
                      ScanCategory.recyclable,
                      ScanCategory.organic,
                    ])
                      ChoiceChip(
                        label: Text(c == null ? 'Semua' : historyCategory(c)),
                        selected: _filter == c,
                        shape: const StadiumBorder(),
                        side: BorderSide.none,
                        showCheckmark: false,
                        backgroundColor: p.surfaceRaised,
                        selectedColor: p.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        labelStyle: ElioTokens.bodySmall.copyWith(
                          color: _filter == c ? p.onPrimary : p.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() {
                          _filter = c;
                          _selected = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Scan terbaru',
                        style: ElioTokens.subhead.copyWith(
                          fontFamily: ElioTokens.fontSans,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${records.length} scan',
                      style: ElioTokens.caption.copyWith(color: p.primaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final r in records)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        if (box.maxWidth >= 750) {
                          setState(() => _selected = r.id);
                        } else {
                          final theme = Theme.of(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Theme(
                                data: theme,
                                child: ScanDetailScreen(
                                  record: r,
                                  store: _store,
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      child: HistoryCard(
                        padding: 12,
                        child: Row(
                          children: [
                            HistoryPhoto(r),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.itemName,
                                    style: ElioTokens.body.copyWith(
                                      color: p.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  HistoryCategoryChip(r.category),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${historyTime(r.time)} · ${r.totalQuestions} soal',
                                    style: ElioTokens.caption.copyWith(
                                      color: p.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            HistoryPill(
                              '+${r.trophies}',
                              color: p.secondaryText,
                              icon: Icons.emoji_events_outlined,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Belum ada scan untuk kategori ini.'),
                  ),
              ],
            );
            if (box.maxWidth < 750) return list;
            return Row(
              children: [
                SizedBox(width: box.maxWidth * .42, child: list),
                VerticalDivider(width: 1, color: p.borderSubtle),
                Expanded(
                  child: selected == null
                      ? const SizedBox.shrink()
                      : ScanDetailScreen(
                          key: ValueKey(selected.id),
                          record: selected,
                          store: _store,
                          embedded: true,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final p = authPalette(context), level = _store.userLevel;
    return HistoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 40,
                color: p.secondaryText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_store.totalTrophies} piala',
                      style: ElioTokens.subhead.copyWith(
                        fontFamily: ElioTokens.fontSans,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      level.levelAndTitle,
                      style: ElioTokens.caption.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _store.levelProgress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            color: p.primary,
            backgroundColor: p.surfaceRaised,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                level.nextLevelThreshold == null
                    ? 'Level tertinggi'
                    : '${level.nextLevelThreshold! - _store.totalTrophies} piala ke Level ${level.levelNumber + 1}',
                style: ElioTokens.caption.copyWith(color: p.textSecondary),
              ),
              HistoryPill(
                'Tersimpan lokal',
                color: p.primaryText,
                icon: Icons.check,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ScanDetailScreen extends StatefulWidget {
  const ScanDetailScreen({
    super.key,
    required this.record,
    required this.store,
    this.embedded = false,
    this.loadTimeout = const Duration(seconds: 15),
  });
  final ScanRecord record;
  final ScanRecordStore store;
  final bool embedded;
  final Duration loadTimeout;
  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  ScanRecord get record =>
      widget.store.records.where((r) => r.id == widget.record.id).firstOrNull ??
      widget.record;
  ScanRecordStore get store => widget.store;
  bool get embedded => widget.embedded;
  late bool _ready = store.isLoaded;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    if (!_ready) unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _ready = false;
    });
    try {
      await store.load(force: true).timeout(widget.loadTimeout);
      if (store.loadError != null) {
        throw StateError('History could not be loaded');
      }
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    if (!_ready || _failed || store.loadError != null) {
      return Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          title: Text(
            'Detail scan',
            style: ElioTokens.subhead.copyWith(
              fontFamily: ElioTokens.fontSans,
              color: p.textPrimary,
            ),
          ),
          automaticallyImplyLeading: !embedded,
        ),
        body: _failed || store.loadError != null
            ? HistoryError(
                message: 'Detail scan belum dapat dimuat',
                onRetry: _load,
              )
            : const HistorySkeleton(HistoryLoadingLayout.detail),
      );
    }
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text(
          'Detail scan',
          style: ElioTokens.subhead.copyWith(
            fontFamily: ElioTokens.fontSans,
            color: p.textPrimary,
          ),
        ),
        backgroundColor: p.background,
        actions: [
          IconButton(
            tooltip: 'Ekspor PDF',
            icon: const Icon(Icons.description_outlined),
            onPressed: () => _export(context),
          ),
        ],
      ),
      body: ListView(
        key: const ValueKey('detail_list_view'),
        padding: const EdgeInsets.all(16),
        children: [
          HistoryPhoto(record, width: double.infinity, height: 200),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                record.itemName,
                style: ElioTokens.headline.copyWith(
                  fontFamily: ElioTokens.fontSans,
                  color: p.textPrimary,
                ),
              ),
              HistoryCategoryChip(record.category),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Scan ${historyTime(record.time)} · foto dan ${record.totalQuestions} soal tersimpan lokal',
            style: ElioTokens.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in QuizDifficulty.values)
                HistoryPill(
                  '${historyDifficulty(d)} · ${d == record.difficulty ? record.totalQuestions : d.questionCount} soal',
                  color: d == record.difficulty ? p.primaryText : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          HistoryCard(
            tint: p.secondaryText,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_outlined, color: p.secondaryText),
                    const SizedBox(width: 8),
                    Text(
                      '${record.trophies}',
                      style: ElioTokens.headline.copyWith(
                        fontFamily: ElioTokens.fontSans,
                        color: p.secondaryText,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${record.correctCount} dari ${record.totalQuestions} benar',
                ),
                const SizedBox(height: 4),
                Text(
                  '10 piala untuk setiap jawaban benar',
                  style: ElioTokens.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Soal',
                  style: ElioTokens.subhead.copyWith(
                    fontFamily: ElioTokens.fontSans,
                    color: p.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _export(context),
                child: const Text('Ekspor PDF'),
              ),
            ],
          ),
          for (var i = 0; i < record.questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _question(context, record.questions[i], i),
            ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      await QuizPdfService.shareOrSave(
        store.records.where((r) => r.id == record.id).firstOrNull ?? record,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF belum dapat diekspor. Coba lagi.')),
        );
      }
    }
  }

  Widget _question(BuildContext context, RecordQuestion q, int i) {
    final p = authPalette(context),
        tint = q.isEssay
            ? authPalette(context).textSecondary
            : q.isCorrect
            ? authPalette(context).primaryText
            : authPalette(context).errorText;
    return HistoryCard(
      padding: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HistoryQuestionBadge(
                i + 1,
                correct: q.isCorrect,
                essay: q.isEssay,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  q.question,
                  style: ElioTokens.body.copyWith(color: p.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
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
          const SizedBox(height: 12),
          HistoryAnswer('Jawabanmu', q.yourAnswer),
          if (!q.isCorrect && !q.isEssay) ...[
            const SizedBox(height: 8),
            HistoryAnswer('Jawaban benar', q.rightAnswer, color: p.primaryText),
          ],
          TextButton.icon(
            onPressed: () {
              final theme = Theme.of(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Theme(
                    data: theme,
                    child: QuestionExplanationScreen(
                      record: record,
                      questionIndex: i,
                      store: store,
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Lihat penjelasan'),
          ),
        ],
      ),
    );
  }
}
