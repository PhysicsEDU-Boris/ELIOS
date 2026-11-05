import 'dart:async';
import 'package:flutter/material.dart';
import '../models/scan_record.dart';
import '../services/ai_quiz_service.dart';
import '../services/quiz_pdf_service.dart';
import '../services/scan_record_store.dart';
import '../l10n/l10n.dart';
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
                      tooltip: context.l10n.h3Back,
                    ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.h3Title,
                    style: ElioTokens.subhead.copyWith(color: p.textPrimary),
                  ),
                  Text(
                    context.l10n.h3Subtitle,
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
                message: context.l10n.h3LoadFailed,
                onRetry: _load,
              );
            }
            if (!_store.isLoaded) {
              return const HistorySkeleton(HistoryLoadingLayout.list);
            }
            if (_store.records.isEmpty) {
              return HistoryEmpty(
                art: homeArt('history_empty', width: 240, height: 180),
                onScan: _scan,
              );
            }
            final list = ListView(
              key: const ValueKey('history_list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _summary(),
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
                      HistoryFilterChip(
                        c == null
                            ? context.l10n.h3All
                            : historyCategory(context.l10n, c),
                        selected: _filter == c,
                        onSelected: () => setState(() {
                          _filter = c;
                          _selected = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                HistorySectionHeader(
                  context.l10n.h3RecentScans,
                  action: context.l10n.h3ScanCount(records.length),
                ),
                const SizedBox(height: 16),
                for (final r in records)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: HistoryScanRow(
                      r,
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
                    ),
                  ),
                if (records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.l10n.h3NoScansInCategory,
                      style: ElioTokens.bodySmall.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
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

  Widget _summary() {
    final level = _store.userLevel, total = _store.totalTrophies;
    return HistoryTrophySummary(
      total: total,
      level: level.levelAndTitle,
      progress: _store.levelProgress,
      next: level.nextLevelThreshold == null
          ? context.l10n.h3TopLevel
          : context.l10n.h3ToNextLevel(
              level.nextLevelThreshold! - total,
              level.levelNumber + 1,
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
    final bar = HistoryTopBar(
      title: context.l10n.h3DetailTitle,
      showBack: !embedded,
      trailing: IconButton(
        tooltip: context.l10n.h3ExportPdf,
        icon: Icon(Icons.description_outlined, color: p.textPrimary),
        onPressed: () => _export(context),
      ),
    );
    if (!_ready || _failed || store.loadError != null) {
      return Scaffold(
        backgroundColor: p.background,
        appBar: bar,
        body: _failed || store.loadError != null
            ? HistoryError(
                message: context.l10n.h3DetailLoadFailed,
                onRetry: _load,
              )
            : const HistorySkeleton(HistoryLoadingLayout.detail),
      );
    }
    return Scaffold(
      backgroundColor: p.background,
      appBar: bar,
      body: ListView(
        key: const ValueKey('detail_list_view'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          HistoryPhoto(record, width: double.infinity, height: 200),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  record.itemName,
                  style: ElioTokens.headline.copyWith(color: p.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              HistoryCategoryChip(record.category),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.schedule_outlined,
                  size: 16,
                  color: p.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.h3ScannedMeta(
                    historyTime(context.l10n, record.time),
                    record.totalQuestions,
                  ),
                  style: ElioTokens.caption.copyWith(color: p.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // One row as in Figma ("Mudah · 1Q", like the Q badges); scrolls on
          // phones narrower than the three chips.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final d in QuizDifficulty.values) ...[
                  if (d.index > 0) const SizedBox(width: 8),
                  HistoryFilterChip(
                    context.l10n.h3DiffChip(
                      historyDifficulty(context.l10n, d),
                      d == record.difficulty
                          ? record.totalQuestions
                          : d.questionCount,
                    ),
                    selected: d == record.difficulty,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          HistoryScoreCard(record),
          const SizedBox(height: 16),
          HistorySectionHeader(
            context.l10n.h3Questions,
            action: context.l10n.h3ExportPdf,
            onAction: () => _export(context),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < record.questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: HistoryQuestionCard(
                record.questions[i],
                i,
                onExplain: () {
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
              ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.h3PdfFailed)));
      }
    }
  }
}
