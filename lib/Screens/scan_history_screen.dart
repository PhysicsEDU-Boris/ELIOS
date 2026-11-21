import 'dart:async';
import '../widgets/tour/app_tour.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/scan_record.dart';
import '../services/elio_feedback.dart';
import '../services/history_translation_service.dart';
import '../services/scan_record_store.dart';
import '../l10n/l10n.dart';
import '../theme/elio_tokens.dart';
import '../widgets/auth/auth_widgets.dart' show authPalette;
import '../theme/elio_motion.dart';
import '../widgets/elio_page_title.dart';
import '../widgets/history_ui.dart';
import 'home/home_parts.dart';
import 'device_scan_screen.dart';
import 'history/history_tab.dart';
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
  int _jump = 0;
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

  String? _lang;

  /// Opening History or switching the language translates the newest scans
  /// in the background, so their names and details are ready (0218).
  void _prefetch() {
    final lang = _lang;
    if (lang != null) {
      unawaited(HistoryTranslationService.prefetch(_store, lang));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.l10n.localeName == 'en' ? 'en' : 'id';
    if (lang == _lang) return;
    _lang = lang;
    _prefetch();
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    setState(() => _failed = false);
    try {
      await _store.load(force: true).timeout(widget.loadTimeout);
      if (_store.loadError != null) {
        throw StateError('History could not be loaded');
      }
      _prefetch();
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
    // The loaded ELIOS 3 tab; loading, empty and error keep the plain title.
    final tab =
        widget.compact &&
        !_failed &&
        _store.loadError == null &&
        _store.isLoaded &&
        _store.records.isNotEmpty;
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
      body: tab
          ? HistoryTab(
              store: _store,
              filter: _filter,
              onFilter: (c) => setState(() {
                _filter = c;
                _selected = null;
              }),
              onOpenDetail: _openDetail,
              onOpenTimeline: (d) => _openTimeline(device: d),
              banner: _store.ownerId == null ? null : _legacyOffer(),
            )
          : SafeArea(
              bottom: widget.showHeader,
              child: Column(
                children: [
                  if (widget.compact)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: ElioPageTitle(
                        title: context.l10n.navHistory,
                        subtitle: context.l10n.histSubtitle3,
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
                  if (_store.ownerId != null) _legacyOffer(),
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
                          return const HistorySkeleton(
                            HistoryLoadingLayout.list,
                          );
                        }
                        if (_store.records.isEmpty) {
                          return HistoryEmpty(
                            art: homeArt(
                              'history_empty',
                              width: 240,
                              height: 180,
                            ),
                            onScan: _scan,
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
                            for (final (i, group) in _byDay(
                              records,
                            ).indexed) ...[
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

  Widget _legacyOffer() => FutureBuilder<bool>(
    future: _store.hasLegacyHistory(),
    builder: (context, snapshot) => snapshot.data == true
        ? TextButton(
            onPressed: _importLegacy,
            child: Text(context.l10n.historyImport),
          )
        : const SizedBox.shrink(),
  );

  void _openDetail(ScanRecord r) {
    final theme = Theme.of(context);
    Navigator.of(context).push(
      ElioPageRoute(
        builder: (_) => Theme(
          data: theme,
          child: ScanDetailScreen(record: r, store: _store),
        ),
      ),
    );
  }

  void _openTimeline({HistoryDevice? device}) => Navigator.of(context).push(
    ElioPageRoute<void>(
      builder: (_) =>
          ScanTimelineScreen(store: _store, device: device, category: _filter),
    ),
  );

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
        art: historyBinArt(c, jump: _filter == c ? _jump : null),
        selected: _filter == c,
        onTap: () => setState(() {
          _filter = c;
          _selected = null;
          _jump++;
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
  final _exportKey = GlobalKey();
  ScanRecord get _saved =>
      widget.store.records.where((r) => r.id == widget.record.id).firstOrNull ??
      widget.record;

  /// The record as shown in the app language (cached translation or original).
  ScanRecord get record => _saved.localized(_lang ?? _saved.lang);
  String? _lang;
  bool _translating = false, _original = false, _cued = false;
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
    if (!_cued && !embedded) {
      _cued = true;
      elioOnRouteEntered(
        context,
        () => elioEntryCue(ElioSfx.tick, ElioHaptics.select),
      );
    }
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
    final clock = Stopwatch()..start();
    var ok = false;
    try {
      ok = await HistoryTranslationService.ensure(
        store,
        _saved,
        lang,
      ).timeout(widget.loadTimeout);
    } catch (_) {}
    debugPrint(
      '[HistoryTranslation] ${_saved.id} -> $lang: '
      '${ok ? 'cached' : 'failed'} after ${clock.elapsedMilliseconds} ms',
    );
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

  /// Category chip (629:99679): tone tint and edge, dot, bold caption.
  Widget _categoryChip(ElioPalette p, AppLocalizations t) {
    final c = record.category;
    final tint = historyTint(p, switch (c) {
      ScanCategory.b3 => HistoryTone.error,
      ScanCategory.organic => HistoryTone.success,
      ScanCategory.recyclable => HistoryTone.info,
      _ => HistoryTone.neutral,
    });
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: tint.bg,
        shape: StadiumBorder(
          side: BorderSide(color: tint.border ?? p.borderSubtle),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: tint.fg),
          const SizedBox(width: 4),
          Text(
            c == ScanCategory.b3 ? t.h3CatB3Long : historyCategory(t, c),
            style: homeCaption(p, color: tint.fg, weight: 700),
          ),
        ],
      ),
    );
  }

  final _seen = <Object>{};

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final bar = _DetailBar(
      exportKey: _exportKey,
      showBack: !embedded,
      onExport: () {
        elioFeedback(ElioSfx.pop, ElioHaptics.light);
        _export(context);
      },
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
    var n = 0;
    Widget enter(Widget child, {bool pop = false}) => ElioPopIn(
      key: ValueKey('enter-$n'),
      index: n++,
      scale: pop ? 0.9 : 0.96,
      curve: pop ? ElioMotion.pop : ElioMotion.emphasized,
      child: child,
    );
    return TourTip(
      id: 'scan_detail',
      label: () => l10n.tourLblDetail,
      steps: (_) => [TourStep(_exportKey, l10n.tipDetailT, l10n.tipDetailB)],
      builder: (context, _) => Scaffold(
        backgroundColor: p.background,
        appBar: bar,
        body: ListView(
          key: const ValueKey('detail_list_view'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // The saved text shows at once; its translation fills in place.
            if (_original || _translating)
              HistoryOriginalNote(
                lang: _saved.lang,
                busy: _translating,
                onRetry: () => unawaited(_translate()),
              ),
            // Polaroid (629:99667): tilted 2°, the photo morphs in (Hero), the
            // date sticker drops onto its top edge.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 22, 4, 0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Transform.rotate(
                    angle: 2 * math.pi / 180,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x29000000),
                            blurRadius: 8,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HistoryPhotoFrame(
                            record,
                            height: 163,
                            radius: 18,
                            onOpen: historyHasPhoto(record)
                                ? () {
                                    elioFeedback(
                                      ElioSfx.pop,
                                      ElioHaptics.light,
                                    );
                                    HistoryPhotoViewer.open(context, record);
                                  }
                                : null,
                          ),
                          const SizedBox(height: 55),
                          Text(
                            '${record.itemName} · ${historyDay(t, record.time)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: homeCaption(p),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 44,
                    top: -22,
                    child: ElioPopIn(
                      delay: const Duration(milliseconds: 320),
                      rise: -24,
                      scale: 0.4,
                      curve: ElioMotion.pop,
                      child: HomeBoing(
                        turn: 0.12,
                        sfx: ElioSfx.tick,
                        haptic: ElioHaptics.select,
                        child: Transform.rotate(
                          angle: -8 * math.pi / 180,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: ShapeDecoration(
                              color: p.secondaryText,
                              shape: const StadiumBorder(),
                              shadows: const [
                                BoxShadow(
                                  color: Color(0x24000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 13,
                                  color: p.onPrimary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  historyDay(t, record.time),
                                  style: homeCaption(
                                    p,
                                    color: p.onPrimary,
                                    weight: 700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            enter(
              Row(
                children: [
                  Flexible(
                    child: Text(
                      record.itemName,
                      style: ElioTokens.headline.copyWith(color: p.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _categoryChip(p, t),
                ],
              ),
            ),
            const SizedBox(height: 18),
            HistoryResultStats(record),
            const SizedBox(height: 16),
            enter(HistoryDifficultyTabs(record)),
            const SizedBox(height: 24),
            HomeReveal(
              id: 'questions',
              seen: _seen,
              delay: const Duration(milliseconds: 300),
              builder: (context, a) =>
                  HomeHead(a: a, title: t.h3Questions, squiggle: 84),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < record.questions.length; i++)
              enter(
                HistoryQuestionCard(
                  record.questions[i],
                  i,
                  onExplain: () {
                    elioFeedback(ElioSfx.pop, ElioHaptics.light);
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
      ),
    );
  }

  // The PDF uses the cached text of the current language (decision 0185);
  // the sheet adds the theme choice (decision 0228).
  Future<void> _export(BuildContext context) =>
      showQuizReportSheet(context, record);
}

/// Scan detail top bar (629:99655-66): round Back, title, Export PDF pill.
class _DetailBar extends StatelessWidget implements PreferredSizeWidget {
  const _DetailBar({
    required this.showBack,
    required this.onExport,
    this.exportKey,
  });
  final bool showBack;

  /// Spotlight target of the first-visit tour (Figma 18 · H).
  final Key? exportKey;
  final VoidCallback onExport;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final edge = BorderSide(color: p.borderSubtle);
    return ColoredBox(
      color: p.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (showBack) ...[
                  ElioPress(
                    child: Material(
                      color: p.surface,
                      shape: CircleBorder(side: edge),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        tooltip: t.h3Back,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          elioFeedback(ElioSfx.tick, ElioHaptics.select);
                          Navigator.of(context).maybePop();
                        },
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          size: 22,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    t.h3DetailTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: homeTitle(p),
                  ),
                ),
                const SizedBox(width: 8),
                ElioPress(
                  key: exportKey,
                  child: Tooltip(
                    message: t.h3ExportPdf,
                    child: Material(
                      color: p.surface,
                      shape: StadiumBorder(side: edge),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onExport,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 18,
                                color: p.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                t.h3ExportPdf,
                                style: homeWeight(
                                  ElioTokens.button,
                                  600,
                                ).copyWith(color: p.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
