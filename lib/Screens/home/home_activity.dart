import 'dart:math' as math;
// Scan activity (decision 0144): 17-week year grid (Figma 333:4383) and the
// month calendar with the selected day's scans (Figma 329:3836).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../models/home_stats.dart';
import '../../models/scan_record.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/auth/auth_widgets.dart' show authPalette;
import 'home_parts.dart';
import 'package:elio/l10n/l10n.dart';

List<String> get monthNames => [
  for (var m = 1; m <= 12; m++)
    DateFormat.MMMM(dateLocale).format(DateTime(2000, m)),
];

/// Monday first (3 Jan 2000 was a Monday).
List<String> get weekdayNames => [
  for (var d = 3; d <= 9; d++)
    DateFormat.EEEE(dateLocale).format(DateTime(2000, 1, d)),
];

String shortDate(DateTime d) =>
    '${d.day} ${monthNames[d.month - 1].substring(0, 3)}';

/// Opacity of the primary fill for 1, 2, 3 and 4+ scans.
double activityAlpha(int scans) => switch (scans) {
  <= 0 => 0,
  1 => 0.3,
  2 => 0.5,
  3 => 0.75,
  _ => 1,
};

class YearGrid extends StatelessWidget {
  const YearGrid({super.key, required this.stats, required this.onSelectDay});

  final HomeStats stats;
  final ValueChanged<DateTime> onSelectDay;

  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final scaler = MediaQuery.textScalerOf(context);
    final labelStyle = ElioTokens.caption.copyWith(
      color: p.textSecondary,
      fontSize: 11,
    );
    final probe = TextPainter(
      text: TextSpan(
        text: l10n.heatmapDayLabels.split(',')[1],
        style: labelStyle,
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final labelW = probe.width + 8;
    final topH = probe.height + 6;
    return LayoutBuilder(
      builder: (context, c) {
        final cell = (c.maxWidth - labelW - 16 * _gap) / 17;
        final height = topH + 7 * cell + 6 * _gap;
        DateTime? dayAt(Offset o) {
          final col = ((o.dx - labelW) / (cell + _gap)).floor();
          final row = ((o.dy - topH) / (cell + _gap)).floor();
          if (col < 0 || col > 16 || row < 0 || row > 6) return null;
          final d = addDays(stats.gridStart, col * 7 + row);
          return d.isAfter(stats.today) ? null : d;
        }

        return Semantics(
          label: l10n.scansIn17Weeks(l10n.scanCount(stats.scansInGrid)),
          hint: l10n.activityScansHint,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final day = dayAt(d.localPosition);
              if (day != null) onSelectDay(day);
            },
            // Cells fade in with a diagonal stagger (8 ms per column,
            // 220 ms each) and today pulses once (Figma 13 · 14).
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: ElioMotion.reduced(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 16 * 8 + 6 * 8 + 220 + 300),
              builder: (context, ms, _) => CustomPaint(
                size: Size(c.maxWidth, height),
                painter: _YearGridPainter(
                  progressMs: ms * (16 * 8 + 6 * 8 + 220 + 300),
                  stats: stats,
                  cell: cell,
                  gap: _gap,
                  labelW: labelW,
                  topH: topH,
                  labelStyle: labelStyle,
                  scaler: scaler,
                  empty: p.borderSubtle,
                  fill: p.primary,
                  todayRing: p.textTertiary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _YearGridPainter extends CustomPainter {
  _YearGridPainter({
    this.progressMs = double.infinity,
    required this.stats,
    required this.cell,
    required this.gap,
    required this.labelW,
    required this.topH,
    required this.labelStyle,
    required this.scaler,
    required this.empty,
    required this.fill,
    required this.todayRing,
  });

  final HomeStats stats;
  final double cell, gap, labelW, topH;

  /// Time since the grid appeared, for the entrance (infinity = at rest).
  final double progressMs;

  /// Cell opacity 0 → 1 over 220 ms after a diagonal delay of 8 ms per step.
  double _fade(int col, int row) =>
      ((progressMs - (col + row) * 8) / 220).clamp(0.0, 1.0);
  final TextStyle labelStyle;
  final TextScaler scaler;
  final Color empty, fill, todayRing;

  void _text(Canvas canvas, String s, Offset at) => (TextPainter(
    text: TextSpan(text: s, style: labelStyle),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout()).paint(canvas, at);

  @override
  void paint(Canvas canvas, Size size) {
    final step = cell + gap;
    for (final (row, name) in [
      for (final (i, n) in l10n.heatmapDayLabels.split(',').indexed)
        (1 + 2 * i, n),
    ]) {
      _text(
        canvas,
        name,
        Offset(0, topH + row * step + cell / 2 - labelStyle.fontSize! * 0.7),
      );
    }
    var lastLabel = -9;
    for (var col = 0; col < 17; col++) {
      final weekStart = addDays(stats.gridStart, col * 7);
      final prev = addDays(weekStart, -7);
      final newMonth = col == 0 || weekStart.month != prev.month;
      // A month starting inside the week is labelled on that week.
      final firstInWeek = [
        for (var i = 0; i < 7; i++) addDays(weekStart, i),
      ].where((d) => d.day == 1 && !d.isAfter(stats.today));
      if ((newMonth || firstInWeek.isNotEmpty) && col - lastLabel >= 3) {
        final month = firstInWeek.isNotEmpty
            ? firstInWeek.first.month
            : weekStart.month;
        _text(
          canvas,
          monthNames[month - 1].substring(0, 3),
          Offset(labelW + col * step, 0),
        );
        lastLabel = col;
      }
      for (var row = 0; row < 7; row++) {
        final day = addDays(weekStart, row);
        if (day.isAfter(stats.today)) continue;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(labelW + col * step, topH + row * step, cell, cell),
          Radius.circular(cell * 0.22),
        );
        final n = stats.scansOn(day);
        final f = _fade(col, row);
        final base = n == 0 ? empty : fill.withValues(alpha: activityAlpha(n));
        // Today pulses once after the sweep: scale 1 → 1.15 → 1.
        final pulse = day == stats.today
            ? math.sin(((progressMs - 396) / 300).clamp(0.0, 1.0) * math.pi)
            : 0.0;
        final r = pulse == 0 ? rect : rect.inflate(cell * 0.075 * pulse);
        canvas.drawRRect(
          r,
          Paint()..color = base.withValues(alpha: base.a * f),
        );
        if (day == stats.today) {
          canvas.drawRRect(
            r.deflate(0.75),
            Paint()
              ..color = todayRing
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_YearGridPainter old) =>
      old.progressMs != progressMs ||
      old.stats != stats ||
      old.cell != cell ||
      old.fill != fill ||
      old.empty != empty;
}

class ActivityLegend extends StatelessWidget {
  const ActivityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    Widget box(double a) => Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: ShapeDecoration(
        color: a == 0 ? p.borderSubtle : p.primary.withValues(alpha: a),
        shape: homeShape(3),
      ),
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.activityLess, style: homeSmall(p)),
          const SizedBox(width: 6),
          for (final n in [0, 1, 2, 3, 4]) box(activityAlpha(n)),
          const SizedBox(width: 6),
          Text(context.l10n.activityMore, style: homeSmall(p)),
        ],
      ),
    );
  }
}

class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.stats,
    required this.month,
    required this.selected,
    required this.onMonth,
    required this.onSelect,
  });

  final HomeStats stats;

  /// First day of the shown month.
  final DateTime month;
  final DateTime? selected;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final start = addDays(month, -(month.weekday % 7));
    final daysIn = DateTime(month.year, month.month + 1, 0).day;
    final weeks = ((month.weekday % 7) + daysIn + 6) ~/ 7;
    final isCurrent =
        month.year == stats.today.year && month.month == stats.today.month;
    final title = '${monthNames[month.month - 1]} ${month.year}';

    Widget navButton(IconData icon, String tip, VoidCallback? onTap) =>
        IconButton.outlined(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            minimumSize: const Size.square(48),
            foregroundColor: p.textPrimary,
            side: BorderSide(color: p.borderSubtle),
            shape: homeShape(homeRadiusM),
          ),
        );

    return Column(
      children: [
        Row(
          children: [
            navButton(
              Icons.chevron_left_rounded,
              l10n.previousMonth,
              () => onMonth(DateTime(month.year, month.month - 1)),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: homeTitle(p).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            navButton(
              Icons.chevron_right_rounded,
              l10n.nextMonth,
              isCurrent
                  ? null
                  : () => onMonth(DateTime(month.year, month.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final d in l10n.calendarWeekdays.split(','))
                Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: homeSmall(p),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (var w = 0; w < weeks; w++)
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _dayCell(context, p, addDays(start, w * 7 + i)),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(BuildContext context, ElioPalette p, DateTime day) {
    final inMonth = day.month == month.month;
    final future = day.isAfter(stats.today);
    final n = stats.scansOn(day);
    final isSelected = selected == day;
    final numberColor = isSelected
        ? p.onPrimary
        : (inMonth && !future ? p.textPrimary : p.textTertiary);
    return Semantics(
      button: !future,
      selected: isSelected,
      label: '${day.day} ${monthNames[day.month - 1]}, ${l10n.scanCount(n)}',
      container: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: future ? null : () => onSelect(day),
        customBorder: homeShape(homeRadiusM),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          margin: const EdgeInsets.all(2),
          decoration: isSelected
              ? ShapeDecoration(color: p.primary, shape: homeShape(homeRadiusM))
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: ElioTokens.body.copyWith(
                  color: numberColor,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 18,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: n == 0
                      ? null
                      : isSelected
                      ? p.onPrimary
                      : p.primary.withValues(alpha: activityAlpha(n)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Friday, 30 October · 2 scans" with the day's scans.
class DayScans extends StatelessWidget {
  const DayScans({
    super.key,
    required this.stats,
    required this.day,
    required this.onOpenHistory,
  });

  final HomeStats stats;
  final DateTime day;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final records = stats.recordsOn(day);
    final n = records.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${weekdayNames[day.weekday - 1]}, ${day.day} ${monthNames[day.month - 1]} · ${l10n.scanCount(n)}',
              style: homeTitle(p).copyWith(fontSize: 16),
            ),
            TextButton(
              onPressed: onOpenHistory,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: p.primaryText,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(context.l10n.activityOpenInHistory),
            ),
          ],
        ),
        const SizedBox(height: 4),
        HomeCard(
          padding: 0,
          child: n == 0
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.activityNoScans,
                    style: homeSmall(p),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < n; i++) ...[
                      if (i > 0) Divider(height: 1, color: p.borderSubtle),
                      _row(p, records[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(ElioPalette p, ScanRecord r) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            r.itemName,
            style: ElioTokens.body.copyWith(color: p.textPrimary),
          ),
        ),
        BinChip(HomeBin.of(r.category)),
        const SizedBox(width: 12),
        TrophyAmount('+${r.trophies}'),
      ],
    ),
  );
}
