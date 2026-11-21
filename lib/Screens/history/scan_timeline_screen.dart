// ELIOS 3 Scan timeline by device (Figma 629:99557, decision 0199): tabs All /
// Phone / ELIOS / Drone (locked), a device hero and day groups on a rail.
// "All" also holds older records, which never stored a device.
import '../../widgets/tour/app_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/scan_record.dart';
import '../../services/elio_feedback.dart';
import '../../services/scan_record_store.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/history_ui.dart';
import '../../widgets/learn/learn_ui.dart';
import '../scan/scan_hub_screen.dart' show scanArt;
import '../home/home_parts.dart';
import '../scan_history_screen.dart' show ScanDetailScreen;
import 'history_tab.dart';
import '../../widgets/xp_icon.dart';

class ScanTimelineScreen extends StatefulWidget {
  const ScanTimelineScreen({
    super.key,
    required this.store,
    this.device,
    this.category,
  });

  final ScanRecordStore store;

  /// Starting tab: null = All.
  final HistoryDevice? device;

  /// The category tile chosen on the History tab, if any.
  final ScanCategory? category;

  @override
  State<ScanTimelineScreen> createState() => _ScanTimelineScreenState();
}

class _ScanTimelineScreenState extends State<ScanTimelineScreen> {
  late HistoryDevice? _device = widget.device;
  bool _cued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cued) return;
    _cued = true;
    elioOnRouteEntered(
      context,
      () => elioEntryCue(ElioSfx.tick, ElioHaptics.select),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(_changed);
    super.dispose();
  }

  void _open(ScanRecord r) {
    elioFeedback(ElioSfx.pop, ElioHaptics.light);
    final theme = Theme.of(context);
    Navigator.of(context).push(
      ElioPageRoute<void>(
        builder: (_) => Theme(
          data: theme,
          child: ScanDetailScreen(record: r, store: widget.store),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = context.elio;
          final t = context.l10n;
          final records = [
            for (final r in widget.store.records)
              if ((_device == null || historyDeviceOf(r) == _device) &&
                  (widget.category == null || r.category == widget.category))
                r.localized(t.localeName),
          ];
          final groups = <List<ScanRecord>>[];
          for (final r in records) {
            if (groups.isNotEmpty &&
                historyDay(t, groups.last.first.time) ==
                    historyDay(t, r.time)) {
              groups.last.add(r);
            } else {
              groups.add([r]);
            }
          }
          var n = 0;
          return TourTip(
            id: 'scan_timeline',
            label: () => l10n.tourLblTimeline,
            steps: (k) => [
              TourStep(k[0], l10n.tipTl1T, l10n.tipTl1B),
              TourStep(k[1], l10n.tipTl2T, l10n.tipTl2B),
              TourStep(k[2], l10n.tipTl3T, l10n.tipTl3B),
            ],
            builder: (context, k) => Scaffold(
              backgroundColor: p.background,
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    // Header (629:99559-64): round Back, title, subtitle under it.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ElioPress(
                            child: Material(
                              color: p.surface,
                              shape: CircleBorder(
                                side: BorderSide(color: p.borderSubtle),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: IconButton(
                                tooltip: t.h3Back,
                                constraints: const BoxConstraints.tightFor(
                                  width: 44,
                                  height: 44,
                                ),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  elioFeedback(
                                    ElioSfx.tick,
                                    ElioHaptics.select,
                                  );
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
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  t.histTimeline,
                                  style: ElioTokens.headline.copyWith(
                                    color: p.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                t.histTimelineSub,
                                style: ElioTokens.bodySmall.copyWith(
                                  color: p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Tabs(
                      key: k[0],
                      selected: _device,
                      onSelect: (d) {
                        elioFeedback(ElioSfx.tick, ElioHaptics.select);
                        setState(() => _device = d);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_device != null) ...[
                      // Pops in again for each device.
                      ElioPopIn(
                        key: ValueKey(_device),
                        scale: 0.9,
                        curve: ElioMotion.pop,
                        child: _DeviceHero(
                          key: k[1],
                          device: _device!,
                          count: records.length,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Text(
                        t.histNoDevice,
                        style: ElioTokens.caption.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Section 12 skeleton while History is still loading.
                    if (!widget.store.isLoaded)
                      const SizedBox(
                        height: 480,
                        child: HistorySkeleton(HistoryLoadingLayout.list),
                      )
                    else if (records.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          t.histNoScansYet,
                          textAlign: TextAlign.center,
                          style: ElioTokens.bodySmall.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                    // Day pills and rows rise in one after another, again on
                    // a device change.
                    for (final group in groups) ...[
                      ElioPopIn(
                        key: ValueKey('$_device-day-${group.first.id}'),
                        index: n++,
                        scale: 0.8,
                        curve: ElioMotion.pop,
                        child: _DayPill(historyDay(t, group.first.time)),
                      ),
                      for (final (i, r) in group.indexed)
                        ElioPopIn(
                          key: ValueKey('$_device-${r.id}'),
                          index: n++,
                          child: ElioPress(
                            key: identical(r, records.first) ? k[2] : null,
                            child: _RailRow(
                              first: identical(r, records.first),
                              last: i == group.length - 1,
                              child: _Item(
                                record: r,
                                highlighted: identical(r, records.first),
                                showDevice: _device == null,
                                time: DateFormat.Hm(
                                  dateLocaleOf(t),
                                ).format(r.time),
                                onTap: () => _open(r),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({super.key, required this.selected, required this.onSelect});
  final HistoryDevice? selected;
  final ValueChanged<HistoryDevice?> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final t = context.l10n;
    Color fg(bool on, VoidCallback? tap) => on
        ? p.onPrimary
        : tap == null
        ? p.textTertiary
        : p.textSecondary;
    Widget tab(String label, Object? icon, bool on, VoidCallback? tap) =>
        Expanded(
          child: Semantics(
            button: true,
            selected: on,
            enabled: tap != null,
            label: label,
            excludeSemantics: true,
            child: Material(
              color: on ? p.primary : Colors.transparent,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: tap,
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        if (icon is String)
                          historyIcon(icon, 16, fg(on, tap))
                        else
                          Icon(icon as IconData, size: 16, color: fg(on, tap)),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: homeWeight(
                            ElioTokens.button,
                            600,
                          ).copyWith(color: fg(on, tap)),
                        ),
                      ),
                      if (tap == null) ...[
                        const SizedBox(width: 4),
                        historyIcon('icon_lock', 12, p.textTertiary),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: p.surfaceRaised,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          tab(t.histAllScans, null, selected == null, () => onSelect(null)),
          for (final d in HistoryDevice.values)
            tab(
              historyDeviceName(t, d),
              d == HistoryDevice.phone ? 'chip_phone' : 'chip_robot',
              selected == d,
              () => onSelect(d),
            ),
          tab(t.vehicleDrone, Icons.toys_outlined, false, null),
        ],
      ),
    );
  }
}

class _DeviceHero extends StatelessWidget {
  const _DeviceHero({super.key, required this.device, required this.count});
  final HistoryDevice device;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final t = context.l10n;
    final phone = device == HistoryDevice.phone;
    return Row(
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
          child: phone
              ? historyIcon('icon_phone', 48, p.onPrimary)
              : SvgPicture.asset(
                  '$scanArt/elios_robot.svg',
                  excludeFromSemantics: true,
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                phone ? t.histPhoneTitle : t.histEliosTitle,
                style: homeTitle(p),
              ),
              const SizedBox(height: 4),
              ElioCountUp(
                value: count,
                builder: (context, v) => Text(
                  t.histDeviceScans(v, phone ? t.histPhoneCamera : 'MaixCAM2'),
                  style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: ShapeDecoration(
          color: p.primary,
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: homeCaption(p, color: p.onPrimary, weight: 700),
        ),
      ),
    );
  }
}

/// A timeline rail on the left: line, then a dot level with the row.
class _RailRow extends StatelessWidget {
  const _RailRow({
    required this.child,
    required this.first,
    required this.last,
  });
  final Widget child;
  final bool first, last;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  bottom: last ? null : 0,
                  height: last ? 40 : null,
                  child: Container(width: 3, color: p.borderMedium),
                ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: first ? p.primary : p.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.primary, width: 3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Timeline item (629:99603): leaf card with a leaf photo, the time above the
/// name, kind chip and XP, then a chevron. The newest is tinted with a green
/// edge.
class _Item extends StatelessWidget {
  const _Item({
    required this.record,
    required this.time,
    required this.highlighted,
    required this.showDevice,
    required this.onTap,
  });
  final ScanRecord record;
  final String time;
  final bool highlighted, showDevice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio, t = context.l10n, r = record;
    final device = historyDeviceOf(r);
    final shape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(8),
        bottomRight: Radius.circular(24),
        bottomLeft: Radius.circular(8),
      ),
      side: highlighted
          ? BorderSide(color: p.primary, width: 2)
          : BorderSide(color: p.borderSubtle),
    );
    return Semantics(
      button: true,
      label:
          '${r.itemName}, ${historyCategory(t, r.category)}, $time, '
          '+${r.trophies}',
      excludeSemantics: true,
      child: Material(
        color: highlighted ? historyTint(p, HistoryTone.success).bg : p.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                HistoryLeafThumb(r, size: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(time, style: homeCaption(p, color: p.textTertiary)),
                      Text(
                        r.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeWeight(
                          ElioTokens.body,
                          600,
                        ).copyWith(color: p.textPrimary, height: 1.5),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (showDevice && device != null)
                            historyDevicePill(context, device),
                          historyKindPill(context, r),
                          if (r.isContribution || r.questions.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const XpIcon(14),
                                const SizedBox(width: 3),
                                Text(
                                  '+${r.trophies}',
                                  style: homeCaption(
                                    p,
                                    color: p.secondaryText,
                                    weight: 700,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: p.textPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
