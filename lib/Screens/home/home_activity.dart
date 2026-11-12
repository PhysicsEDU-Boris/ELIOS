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
import '../../widgets/history_ui.dart'
    show HistoryTone, historyPhotoImage, historyTint;
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

/// Opacity of the primary fill for 1, 2, 3 and 4+ scans (month calendar).
double activityAlpha(int scans) => switch (scans) {
  <= 0 => 0,
  1 => 0.3,
  2 => 0.5,
  3 => 0.75,
  _ => 1,
};

/// Heatmap levels 0-4 (Figma 629:80453): raised, success edge, primary fill,
/// fill-hover, fill-active.
Color activityColor(ElioPalette p, int scans) => switch (scans) {
  <= 0 => p.surfaceRaised,
  1 => historyTint(p, HistoryTone.success).border!,
  2 => p.primary,
  3 => p.primaryHover,
  _ => p.primaryActive,
};

/// 17 weeks × 7 days, 14 px cells (Figma 629:80453). The cells fade in on a
/// diagonal once [reveal] is under way, and again when the grid comes back
/// from the month view.
class YearGrid extends StatelessWidget {
  const YearGrid({
    super.key,
    required this.stats,
    required this.onSelectDay,
    this.reveal = kAlwaysCompleteAnimation,
  });

  final HomeStats stats;
  final ValueChanged<DateTime> onSelectDay;
  final Animation<double> reveal;

  // Figma pitch: 18.3 across and 17.6 down for a 14 px cell.
  static const _gapX = 4.3 / 14, _gapY = 3.6 / 14;
  static const _sweepMs = 16 * 8 + 6 * 8 + 220 + 300;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return LayoutBuilder(
      builder: (context, c) {
        final cell = c.maxWidth / (17 + 16 * _gapX);
        final stepX = cell * (1 + _gapX), stepY = cell * (1 + _gapY);
        final height = 6 * stepY + cell;
        DateTime? dayAt(Offset o) {
          final col = (o.dx / stepX).floor();
          final row = (o.dy / stepY).floor();
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
            // Diagonal stagger (8 ms per step, 220 ms each), then today
            // pulses once (Figma 13 · 14).
            child: AnimatedBuilder(
              animation: reveal,
              builder: (context, _) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: reveal.value > 0.2 ? 1 : 0),
                duration: ElioMotion.reduced(context)
                    ? Duration.zero
                    : const Duration(milliseconds: _sweepMs),
                builder: (context, ms, _) => CustomPaint(
                  size: Size(c.maxWidth, height),
                  painter: _YearGridPainter(
                    progressMs: ms * _sweepMs,
                    stats: stats,
                    cell: cell,
                    stepX: stepX,
                    stepY: stepY,
                    colors: [for (var n = 0; n <= 4; n++) activityColor(p, n)],
                  ),
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
    required this.progressMs,
    required this.stats,
    required this.cell,
    required this.stepX,
    required this.stepY,
    required this.colors,
  });

  final HomeStats stats;
  final double cell, stepX, stepY;
  final List<Color> colors;

  /// Time since the grid appeared, for the entrance.
  final double progressMs;

  /// Cell opacity 0 → 1 over 220 ms after a diagonal delay of 8 ms per step.
  double _fade(int col, int row) =>
      ((progressMs - (col + row) * 8) / 220).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    for (var col = 0; col < 17; col++) {
      final weekStart = addDays(stats.gridStart, col * 7);
      for (var row = 0; row < 7; row++) {
        final day = addDays(weekStart, row);
        if (day.isAfter(stats.today)) continue;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(col * stepX, row * stepY, cell, cell),
          Radius.circular(cell * 4 / 14),
        );
        final base = colors[stats.scansOn(day).clamp(0, 4)];
        // Today pulses once after the sweep: scale 1 → 1.15 → 1.
        final pulse = day == stats.today
            ? math.sin(((progressMs - 396) / 300).clamp(0.0, 1.0) * math.pi)
            : 0.0;
        canvas.drawRRect(
          pulse == 0 ? rect : rect.inflate(cell * 0.075 * pulse),
          Paint()..color = base.withValues(alpha: base.a * _fade(col, row)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_YearGridPainter old) =>
      old.progressMs != progressMs ||
      old.stats != stats ||
      old.cell != cell ||
      old.colors.toString() != colors.toString();
}

/// "Less ▢▢▢▢ More" (Figma 629:80577); the squares pop in along [reveal].
class ActivityLegend extends StatelessWidget {
  const ActivityLegend({super.key, this.reveal = kAlwaysCompleteAnimation});
  final Animation<double> reveal;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final label = homeCaption(p, color: p.textTertiary);
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.activityLess, style: label),
          for (final (i, n) in const [0, 1, 2, 4].indexed)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: HomeRise(
                reveal,
                0.55 + 0.07 * i,
                0.8 + 0.07 * i,
                rise: 0,
                scale: 0,
                curve: ElioMotion.pop,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: activityColor(p, n),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 4),
          Text(context.l10n.activityMore, style: label),
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
                style: homeWeight(homeTitle(p), 500),
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
    padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
    child: Row(
      children: [
        HomeThumb(child: historyPhotoImage(r)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            r.itemName,
            style: ElioTokens.body.copyWith(color: p.textPrimary),
          ),
        ),
        const SizedBox(width: 8),
        BinChip(HomeBin.of(r.category)),
        const SizedBox(width: 12),
        TrophyAmount('+${r.trophies}'),
      ],
    ),
  );
}
