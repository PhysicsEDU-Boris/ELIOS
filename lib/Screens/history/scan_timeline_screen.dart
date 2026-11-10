// ELIOS 3 Scan timeline by device (Figma 629:99557, decision 0199): tabs All /
// Phone / ELIOS / Drone (locked), a device hero and day groups on a rail.
// "All" also holds older records, which never stored a device.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/scan_record.dart';
import '../../services/scan_record_store.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/elio_page_title.dart';
import '../../widgets/history_ui.dart';
import '../../widgets/learn/learn_ui.dart';
import '../scan/scan_hub_screen.dart' show scanArt;
import '../scan_history_screen.dart' show ScanDetailScreen;

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
    final theme = Theme.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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
          return Scaffold(
            backgroundColor: p.background,
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  ElioPageTitle(
                    title: t.histTimeline,
                    subtitle: t.histTimelineSub,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 16),
                  _Tabs(
                    selected: _device,
                    onSelect: (d) => setState(() => _device = d),
                  ),
                  const SizedBox(height: 16),
                  if (_device != null) ...[
                    _DeviceHero(device: _device!, count: records.length),
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
                  if (records.isEmpty)
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
                  for (final group in groups) ...[
                    _DayPill(historyDay(t, group.first.time)),
                    for (final (i, r) in group.indexed)
                      _RailRow(
                        first: i == 0,
                        last: i == group.length - 1,
                        child: HistoryScanRow(
                          record: r,
                          highlighted: identical(r, records.first),
                          showDevice: _device == null,
                          trailingLabel: DateFormat.Hm(
                            dateLocaleOf(t),
                          ).format(r.time),
                          onTap: () => _open(r),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});
  final HistoryDevice? selected;
  final ValueChanged<HistoryDevice?> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final t = context.l10n;
    Widget tab(String label, IconData? icon, bool on, VoidCallback? tap) =>
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
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 16,
                          color: on
                              ? p.onPrimary
                              : tap == null
                              ? p.textTertiary
                              : p.textSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: ElioTokens.button.copyWith(
                            color: on
                                ? p.onPrimary
                                : tap == null
                                ? p.textTertiary
                                : p.textSecondary,
                          ),
                        ),
                      ),
                      if (tap == null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: p.textTertiary,
                        ),
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
              historyDeviceIcon(d),
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
  const _DeviceHero({required this.device, required this.count});
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
              ? Icon(Icons.smartphone_rounded, size: 48, color: p.onPrimary)
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
                style: ElioTokens.subhead.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
              Text(
                t.histDeviceScans(
                  count,
                  phone ? t.histPhoneCamera : 'MaixCAM2',
                ),
                style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: ShapeDecoration(
          color: p.primary,
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: ElioTokens.label.copyWith(color: p.onPrimary),
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
