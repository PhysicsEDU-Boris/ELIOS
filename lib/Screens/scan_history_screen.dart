import 'dart:async';
import 'package:flutter/material.dart';
import '../models/scan_record.dart';
import '../services/quiz_pdf_service.dart';
import '../services/history_translation_service.dart';
import '../services/scan_record_store.dart';
import '../l10n/l10n.dart';
import '../theme/elio_tokens.dart';
import '../widgets/auth/auth_widgets.dart' show authPalette;
import '../widgets/elio_page_title.dart';
import '../widgets/history_ui.dart';
import 'home/home_parts.dart' show homeArt;
import 'device_scan_screen.dart';
import 'history/scan_timeline_screen.dart';
import 'history_photo_viewer.dart';
import 'question_explanation_screen.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({
    super.key,
    this.store,
    this.onClose,
    this.onStartScan,
    this.showHeader = true,
    this.compact = false,
    this.loadTimeout = const Duration(seconds: 15),
  });
  final bool showHeader;

  /// ELIOS 3 History tab (Figma 629:99388, decision 0199): its own title and
  /// sync chip, trophy strip, tiles, the latest 3 scans, By device and
  /// Questions to review. The full list lives on the timeline.
  final bool compact;
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

  Future<void> _importLegacy() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.historyImport),
        content: Text(context.l10n.historyImportBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.historyImport),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await _store.importLegacyHistory();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.historyImportFailed)),
        );
      }
    }
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
      // In the tab shell the bottom nav owns the gesture inset; reserving it
      // here too left an empty band above the nav (other tabs have none).
      body: SafeArea(
        bottom: widget.showHeader,
        child: Column(
          children: [
            if (widget.compact)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ElioPageTitle(
                  title: context.l10n.navHistory,
                  subtitle: context.l10n.histSubtitle3,
                  trailing: _store.cloud == null ? null : _syncChip(p),
                ),
              ),
            if (_store.cloud != null && !widget.compact)
              ListTile(
                dense: true,
                leading: Icon(
                  _store.syncing
                      ? Icons.cloud_sync_outlined
                      : _store.syncError != null ||
                            _store.lastSynced == null ||
                            _store.pendingCount > 0
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
                ),
                title: Text(
                  _store.syncing
                      ? context.l10n.historySyncing
                      : _store.syncError != null ||
                            _store.lastSynced == null ||
                            _store.pendingCount > 0
                      ? context.l10n.historyLocalOnly
                      : context.l10n.historySynced,
                ),
                trailing: IconButton(
                  tooltip: context.l10n.historySyncRetry,
                  onPressed: _store.syncing ? null : _store.sync,
                  icon: const Icon(Icons.sync),
                ),
              ),
            if (_store.ownerId != null)
              FutureBuilder<bool>(
                future: _store.hasLegacyHistory(),
                builder: (context, snapshot) => snapshot.data == true
                    ? TextButton(
                        onPressed: _importLegacy,
                        child: Text(context.l10n.historyImport),
                      )
                    : const SizedBox.shrink(),
              ),
            Expanded(
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
                  if (widget.compact) {
                    return ListView(
                      key: const ValueKey('history_list'),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: _compact(records),
                    );
                  }
                  final list = ListView(
                    key: const ValueKey('history_list'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _summary(),
                      const SizedBox(height: 16),
                      _tiles(),
                      const SizedBox(height: 24),
                      HistorySectionHeader(
                        context.l10n.h3RecentScans,
                        action: context.l10n.h3ScanCount(records.length),
                      ),
                      // Day groups (Overline, 12 above the group, 20 apart), each a
                      // card grid: 2 columns, 3 when the list pane is over 560 dp.
                      for (final (i, group) in _byDay(records).indexed) ...[
                        SizedBox(height: i == 0 ? 16 : 20),
                        Text(
                          historyDay(
                            context.l10n,
                            group.first.time,
                          ).toUpperCase(),
                          style: ElioTokens.overline.copyWith(
                            color: p.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        HistoryScanGrid(
                          records: [
                            for (final r in group)
                              r.localized(context.l10n.localeName),
                          ],
                          columns:
                              (box.maxWidth >= 750
                                          ? box.maxWidth * .42
                                          : box.maxWidth) -
                                      32 >
                                  560
                              ? 3
                              : 2,
                          onOpen: (r) {
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
                      ],
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
          ],
        ),
      ),
    );
  }

  /// Consecutive records of the same day (records are newest first).
  List<List<ScanRecord>> _byDay(List<ScanRecord> records) {
    final groups = <List<ScanRecord>>[];
    for (final r in records) {
      if (groups.isNotEmpty &&
          historyDay(context.l10n, groups.last.first.time) ==
              historyDay(context.l10n, r.time)) {
        groups.last.add(r);
      } else {
        groups.add([r]);
      }
    }
    return groups;
  }

  Widget _syncChip(ElioPalette p) {
    final ok =
        !_store.syncing &&
        _store.syncError == null &&
        _store.lastSynced != null &&
        _store.pendingCount == 0;
    final label = _store.syncing
        ? context.l10n.historySyncing
        : ok
        ? context.l10n.historySynced
        : context.l10n.historyLocalOnly;
    return Tooltip(
      message: context.l10n.historySyncRetry,
      child: ActionChip(
        onPressed: _store.syncing ? null : _store.sync,
        avatar: Icon(
          _store.syncing
              ? Icons.cloud_sync_outlined
              : ok
              ? Icons.cloud_done_outlined
              : Icons.cloud_off_outlined,
          size: 18,
          color: ok ? p.primaryText : p.textSecondary,
        ),
        label: Text(
          label,
          style: ElioTokens.button.copyWith(
            color: ok ? p.primaryText : p.textSecondary,
          ),
        ),
        backgroundColor: ok
            ? p.primary.withValues(alpha: 0.12)
            : p.surfaceRaised,
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
    );
  }

  void _openDetail(ScanRecord r) {
    final theme = Theme.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: theme,
          child: ScanDetailScreen(record: r, store: _store),
        ),
      ),
    );
  }

  void _openTimeline({HistoryDevice? device}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ScanTimelineScreen(store: _store, device: device, category: _filter),
    ),
  );

  List<Widget> _compact(List<ScanRecord> records) {
    final t = context.l10n;
    final p = authPalette(context);
    final level = _store.userLevel, total = _store.totalTrophies;
    final latest = [for (final r in records.take(3)) r.localized(t.localeName)];
    final toReview = [
      for (final r in _store.records)
        if (r.questions.isNotEmpty && r.correctCount < r.totalQuestions)
          r.localized(t.localeName),
    ];
    ScanRecord? lastOf(HistoryDevice d) =>
        _store.records.where((r) => historyDeviceOf(r) == d).firstOrNull;
    return [
      HistoryTrophyStrip(
        total: total,
        levelNumber: level.levelNumber,
        level: level.levelAndTitle,
        progress: _store.levelProgress,
        next: level.nextLevelThreshold == null
            ? t.h3TopLevel
            : t.h3ToNextLevel(
                level.nextLevelThreshold! - total,
                level.levelNumber + 1,
              ),
      ),
      const SizedBox(height: 16),
      _tiles(),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                t.h3RecentScans,
                style: ElioTokens.subhead.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _openTimeline(),
            icon: const Icon(Icons.timeline_rounded, size: 18),
            label: Text(t.histSeeTimeline),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.primaryText,
              backgroundColor: p.primary.withValues(alpha: 0.08),
              side: BorderSide(color: p.primary.withValues(alpha: 0.5)),
              shape: const StadiumBorder(),
              minimumSize: const Size(48, 44),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (latest.isEmpty)
        Text(
          t.h3NoScansInCategory,
          style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
        ),
      for (final r in latest) ...[
        HistoryScanRow(
          record: r,
          trailingLabel: historyDay(t, r.time),
          onTap: () => _openDetail(r),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 16),
      Semantics(
        header: true,
        child: Text(
          t.histByDevice,
          style: ElioTokens.subhead.copyWith(
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
      ),
      Text(
        t.histByDeviceSub,
        style: ElioTokens.caption.copyWith(color: p.textSecondary),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final d in HistoryDevice.values) ...[
              Expanded(
                child: HistoryDeviceCard(
                  name: historyDeviceName(t, d),
                  icon: historyDeviceIcon(d),
                  last: lastOf(d) == null
                      ? t.histNoScansYet
                      : historyDay(t, lastOf(d)!.time),
                  onTap: () => _openTimeline(device: d),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: HistoryDeviceCard(
                name: t.vehicleDrone,
                icon: Icons.toys_outlined,
                last: t.vehicleComingSoon,
              ),
            ),
          ],
        ),
      ),
      if (toReview.isNotEmpty) ...[
        const SizedBox(height: 20),
        HistoryCard(
          tone: HistoryTone.warning,
          onTap: () => _openDetail(toReview.first),
          child: Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 40, color: p.secondaryText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.histToReview,
                      style: ElioTokens.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      [
                        for (final r in toReview.take(2))
                          '${r.itemName} ${r.correctCount}/${r.totalQuestions}',
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ElioTokens.caption.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: ShapeDecoration(
                  color: p.surface,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  t.histReview,
                  style: ElioTokens.button.copyWith(color: p.secondaryText),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _summary() {
    final level = _store.userLevel, total = _store.totalTrophies;
    return HistoryTrophyHero(
      total: total,
      levelNumber: level.levelNumber,
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

  /// 2x2 category tiles; tapping one filters the list.
  Widget _tiles() {
    final t = context.l10n, all = _store.records;
    Widget tile(ScanCategory? c) => Expanded(
      child: HistoryCategoryTile(
        label: c == null
            ? t.h3All
            : c == ScanCategory.b3
            ? t.h3CatB3Long
            : historyCategory(t, c),
        count: c == null
            ? all.length
            : all.where((r) => r.category == c).length,
        art: historyBinArt(c),
        selected: _filter == c,
        onTap: () => setState(() {
          _filter = c;
          _selected = null;
        }),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            tile(null),
            const SizedBox(width: 12),
            tile(ScanCategory.b3),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            tile(ScanCategory.recyclable),
            const SizedBox(width: 12),
            tile(ScanCategory.organic),
          ],
        ),
      ],
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
  ScanRecord get _saved =>
      widget.store.records.where((r) => r.id == widget.record.id).firstOrNull ??
      widget.record;

  /// The record as shown in the app language (cached translation or original).
  ScanRecord get record => _saved.localized(_lang ?? _saved.lang);
  String? _lang;
  bool _translating = false, _original = false;
  int _translateEpoch = 0;
  ScanRecordStore get store => widget.store;
  bool get embedded => widget.embedded;
  late bool _ready = store.isLoaded;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    if (!_ready) unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.l10n.localeName == 'en' ? 'en' : 'id';
    if (lang == _lang) return;
    _lang = lang;
    _original = false;
    if (_saved.needsTranslation(lang)) {
      _translating = true;
      Future.microtask(_translate);
    }
  }

  /// One ELIOS AI call translates the record into the app language and caches
  /// it; offline the original language stays with a note (decision 0185).
  Future<void> _translate() async {
    final epoch = ++_translateEpoch, lang = _lang!;
    setState(() => _translating = true);
    var ok = false;
    try {
      ok = await HistoryTranslationService.ensure(
        store,
        _saved,
        lang,
      ).timeout(widget.loadTimeout);
    } catch (_) {}
    if (mounted && epoch == _translateEpoch) {
      setState(() {
        _translating = false;
        _original = !ok;
      });
    }
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
    if (!_ready || _failed || store.loadError != null || _translating) {
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
          if (_original)
            HistoryOriginalNote(
              lang: _saved.lang,
              onRetry: () => unawaited(_translate()),
            ),
          HistoryPhotoFrame(
            record,
            onOpen: historyHasPhoto(record)
                ? () => HistoryPhotoViewer.open(context, record)
                : null,
          ),
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
          const SizedBox(height: 16),
          HistoryResultStats(record),
          const SizedBox(height: 16),
          HistoryDifficultyTabs(record),
          const SizedBox(height: 16),
          HistorySectionHeader(context.l10n.h3Questions),
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
                          record: _saved,
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
      // The PDF uses the cached text of the current language (decision 0185).
      await QuizPdfService.shareOrSave(record);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.h3PdfFailed)));
      }
    }
  }
}
