import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/scan_record.dart';
import '../services/ai_quiz_service.dart';
import '../theme/elio_motion.dart';
import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;

// H3 History components. Sizes, gaps and tokens follow
// docs/design/h3-figma/README.md (Figma 433:2358); colours come only from the
// active ElioPalette.

String historyCategory(AppLocalizations t, ScanCategory c) => switch (c) {
  ScanCategory.b3 => t.h3CatB3,
  ScanCategory.recyclable => t.h3CatRecyclable,
  ScanCategory.organic => t.h3CatOrganic,
  ScanCategory.residu => t.h3CatResidu,
};
String historyDifficulty(AppLocalizations t, QuizDifficulty d) => switch (d) {
  QuizDifficulty.easy => t.h3Easy,
  QuizDifficulty.medium => t.h3Medium,
  QuizDifficulty.hard => t.h3Hard,
};

/// "Today", "Yesterday", else "3 Nov" (with the year when not this year).
String historyDay(AppLocalizations t, DateTime time, {DateTime? now}) {
  now ??= DateTime.now();
  final day = DateTime(time.year, time.month, time.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return t.h3Today;
  if (day == today.subtract(const Duration(days: 1))) return t.h3Yesterday;
  return (time.year == now.year
          ? DateFormat.MMMd(dateLocaleOf(t))
          : DateFormat.yMMMd(dateLocaleOf(t)))
      .format(time);
}

/// "23:29" today, else [historyDay].
String historyTime(AppLocalizations t, DateTime time, {DateTime? now}) {
  final day = historyDay(t, time, now: now);
  return day == t.h3Today ? DateFormat.Hm(dateLocaleOf(t)).format(time) : day;
}

/// Figma Button style (SemiBold 14, line height 1.4).
final historyButtonText = ElioTokens.button.copyWith(height: 1.4);

enum HistoryTone { success, error, warning, info, neutral }

/// `chip/{tone}-bg`, `chip/{tone}-border` and `{tone}/text`. Light tints 6/8/4/6 %
/// with a 35 % edge, dark 12 % with a 25 % edge (design.md status chip).
({Color bg, Color? border, Color fg}) historyTint(
  ElioPalette p,
  HistoryTone t,
) {
  if (t == HistoryTone.neutral) {
    return (bg: p.surfaceRaised, border: null, fg: p.textSecondary);
  }
  final (base, fg, light) = switch (t) {
    HistoryTone.success => (
      p.isDark ? p.primary : p.primaryActive,
      p.primaryText,
      .06,
    ),
    HistoryTone.error => (p.error, p.errorText, .08),
    HistoryTone.warning => (p.secondaryText, p.secondaryText, .04),
    _ => (p.tertiaryText, p.tertiaryText, .06),
  };
  return (
    bg: base.withValues(alpha: p.isDark ? .12 : light),
    border: base.withValues(alpha: p.isDark ? .25 : .35),
    fg: fg,
  );
}

ShapeBorder _shape(double r, [Color? side]) => RoundedSuperellipseBorder(
  borderRadius: BorderRadius.circular(r),
  side: side == null ? BorderSide.none : BorderSide(color: side),
);

/// Card r16: `surface` + `border/subtle`, or a tone tint.
class HistoryCard extends StatelessWidget {
  const HistoryCard({
    super.key,
    required this.child,
    this.tone,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.onTap,
  });
  final Widget child;
  final HistoryTone? tone;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final tint = tone == null ? null : historyTint(p, tone!);
    final shape = _shape(radius, tint?.border ?? p.borderSubtle);
    return Material(
      color: tint?.bg ?? p.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Container(
          width: double.infinity,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Status chip: height 24, pad 2/8, gap 4, icon 14, Caption.
class HistoryChip extends StatelessWidget {
  const HistoryChip(
    this.text, {
    super.key,
    this.tone = HistoryTone.neutral,
    this.icon,
  });
  final String text;
  final HistoryTone tone;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final t = historyTint(authPalette(context), tone);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: ShapeDecoration(
        color: t.bg,
        shape: StadiumBorder(
          side: BorderSide(color: t.border ?? Colors.transparent),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: t.fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ElioTokens.caption.copyWith(color: t.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category tile (2x2 grid, 96 high): label, "n scan", bin buddy art cut by
/// the bottom edge. Selected = success tint, 2 dp `primary/fill`, check badge.
class HistoryCategoryTile extends StatelessWidget {
  const HistoryCategoryTile({
    super.key,
    required this.label,
    required this.count,
    required this.art,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final Widget art;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(16),
      side: selected
          ? BorderSide(color: p.primary, width: 2)
          : BorderSide(color: p.borderSubtle),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? historyTint(p, HistoryTone.success).bg : p.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: SizedBox(
            height: 96,
            child: Stack(
              children: [
                Positioned(
                  right: 7,
                  top: 44,
                  child: Transform.rotate(
                    angle: selected ? 8 * math.pi / 180 : 0,
                    child: art,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ElioTokens.body.copyWith(color: p.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.h3ScanCount(count),
                        style: ElioTokens.caption.copyWith(
                          color: selected ? p.primaryText : p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 10,
                    right: 10,
                    // The check badge pops in (spring/pop).
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.4, end: 1),
                      duration: ElioMotion.reduced(context)
                          ? Duration.zero
                          : ElioMotion.slow,
                      curve: ElioMotion.pop,
                      builder: (context, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: ShapeDecoration(
                          color: p.primary,
                          shape: const CircleBorder(),
                        ),
                        child: Icon(Icons.check, size: 14, color: p.onPrimary),
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

/// Bin buddy art of a category tile; "all" (null) shows the three bins.
/// A new [jump] value makes the buddies jump (ELIOS 3 motion, Figma 13 · 31);
/// the three of "all" jump in a 40 ms wave.
Widget historyBinArt(ScanCategory? c, {Object? jump}) {
  var wave = 0;
  Widget bin(String name, double w, double h) => ElioJump(
    trigger: jump,
    delay: Duration(milliseconds: 40 * wave++),
    child: SvgPicture.asset(
      'assets/illustrations/home/bin_$name.svg',
      width: w,
      height: h,
      excludeFromSemantics: true,
    ),
  );
  if (c != null) {
    return bin(
      switch (c) {
        ScanCategory.b3 => 'b3',
        ScanCategory.organic => 'organik',
        _ => 'anorganik',
      },
      52,
      62,
    );
  }
  return SizedBox(
    width: 84,
    height: 62,
    child: Stack(
      children: [
        for (final (i, name) in ['organik', 'anorganik', 'b3'].indexed)
          Positioned(left: i * 24.0, top: 4, child: bin(name, 36, 43)),
      ],
    ),
  );
}

/// Difficulty tabs (L1 switch look): track 48 `raised`, segments 40, the
/// record's set selected with a count badge. Display only (one set is saved).
class HistoryDifficultyTabs extends StatelessWidget {
  const HistoryDifficultyTabs(this.record, {super.key});
  final ScanRecord record;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: p.surfaceRaised,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          for (final d in QuizDifficulty.values) ...[
            if (d.index > 0) const SizedBox(width: 4),
            Expanded(child: _tab(context, p, d, d == record.difficulty)),
          ],
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, ElioPalette p, QuizDifficulty d, bool on) {
    final count = on ? record.totalQuestions : d.questionCount;
    return Semantics(
      selected: on,
      child: Container(
        height: 40,
        decoration: on
            ? ShapeDecoration(color: p.primary, shape: const StadiumBorder())
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                historyDifficulty(context.l10n, d),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: historyButtonText.copyWith(
                  color: on ? p.onPrimary : p.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              height: 20,
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: on ? p.primaryHover : p.surface,
                shape: const StadiumBorder(),
              ),
              child: Text(
                '$count',
                style: ElioTokens.caption.copyWith(
                  color: on ? p.onPrimary : p.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header: title Subhead, optional action Button `primary/text`.
class HistorySectionHeader extends StatelessWidget {
  const HistorySectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final label = action == null
        ? null
        : Text(
            action!,
            style: historyButtonText.copyWith(color: p.primaryText),
          );
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: ElioTokens.subhead.copyWith(color: p.textPrimary),
              ),
            ),
          ),
          if (label != null && onAction == null) label,
          if (label != null && onAction != null)
            HistoryTapArea(onTap: onAction!, child: label),
        ],
      ),
    );
  }
}

/// Plain tap target for a Figma text action (keeps the 28 dp row height).
class HistoryTapArea extends StatelessWidget {
  const HistoryTapArea({super.key, required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    ),
  );
}

class HistoryQuestionBadge extends StatelessWidget {
  const HistoryQuestionBadge(
    this.number, {
    super.key,
    required this.correct,
    this.essay = false,
  });
  final int number;
  final bool correct, essay;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final (bg, fg) = essay
        ? (p.surfaceRaised, p.textPrimary)
        : correct
        ? (p.primary, p.onPrimary)
        : (p.error, p.onError);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: ShapeDecoration(color: bg, shape: _shape(8)),
      child: Text('Q$number', style: historyButtonText.copyWith(color: fg)),
    );
  }
}

HistoryTone historyCategoryTone(ScanCategory c) => switch (c) {
  ScanCategory.b3 => HistoryTone.error,
  ScanCategory.organic => HistoryTone.warning,
  ScanCategory.recyclable => HistoryTone.success,
  ScanCategory.residu => HistoryTone.neutral,
};

class HistoryCategoryChip extends StatelessWidget {
  const HistoryCategoryChip(this.category, {super.key});
  final ScanCategory category;
  @override
  Widget build(BuildContext context) => HistoryChip(
    category == ScanCategory.b3
        ? context.l10n.h3CatB3Long
        : historyCategory(context.l10n, category),
    tone: historyCategoryTone(category),
  );
}

/// Result chip of a saved question (Benar with a check, Salah, essay score).
class HistoryResultChip extends StatelessWidget {
  const HistoryResultChip(this.q, {super.key});
  final RecordQuestion q;
  @override
  Widget build(BuildContext context) => q.isEssay
      ? HistoryChip(
          q.gradingPending
              ? context.l10n.h3AwaitingGrading
              : context.l10n.h3EssayScore(q.essayScore ?? 0),
          tone: HistoryTone.info,
        )
      : q.isCorrect
      ? HistoryChip(
          context.l10n.h3Correct,
          tone: HistoryTone.success,
          icon: Icons.check,
        )
      : HistoryChip(context.l10n.h3Incorrect, tone: HistoryTone.error);
}

class HistoryTrophyChip extends StatelessWidget {
  const HistoryTrophyChip(this.trophies, {super.key});
  final int trophies;
  @override
  Widget build(BuildContext context) => HistoryChip(
    '+$trophies',
    tone: HistoryTone.warning,
    icon: Icons.emoji_events_outlined,
  );
}

/// True when the record's saved crop exists on disk (the viewer needs it).
bool historyHasPhoto(ScanRecord r) =>
    r.cropPhotoPath != null && File(r.cropPhotoPath!).existsSync();

/// The saved crop, contained (never cropped); the category bin buddy when
/// there is no photo or it cannot be read.
Widget historyPhotoImage(ScanRecord r) {
  final art = Padding(
    padding: const EdgeInsets.all(6),
    child: SvgPicture.asset(
      'assets/illustrations/home/bin_${switch (r.category) {
        ScanCategory.b3 => 'b3',
        ScanCategory.organic => 'organik',
        _ => 'anorganik',
      }}.svg',
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
  if (!historyHasPhoto(r)) return art;
  return Image.file(
    File(r.cropPhotoPath!),
    fit: BoxFit.contain,
    errorBuilder: (_, error, stack) => art,
  );
}

/// Polaroid: `surface` frame pad 4 r8, soft shadow, rotated, the image
/// letterboxed on `raised`.
class HistoryPolaroid extends StatelessWidget {
  const HistoryPolaroid(
    this.record, {
    super.key,
    required this.width,
    required this.height,
    this.degrees = -4,
  });
  final ScanRecord record;
  final double width, height, degrees;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Transform.rotate(
      angle: degrees * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(8),
          // Fixed polaroid shadow (#0F172A 14 %), allowed by the spec.
          boxShadow: const [
            BoxShadow(
              color: Color(0x240F172A),
              offset: Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Container(
            width: width,
            height: height,
            color: p.surfaceRaised,
            child: historyPhotoImage(record),
          ),
        ),
      ),
    );
  }
}

/// Category-tinted cover with a corner circle and sparkles; [child] centred.
class _TintCover extends StatelessWidget {
  const _TintCover({
    required this.category,
    required this.height,
    required this.radius,
    required this.circles,
    required this.sparkles,
    required this.child,
  });
  final ScanCategory category;
  final double height, radius;
  final List<
    (double size, double? left, double? top, double? right, double? bottom)
  > circles,
      sparkles;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = historyTint(authPalette(context), historyCategoryTone(category));
    final edge = t.border ?? authPalette(context).borderMedium;
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        color: t.bg,
        child: Stack(
          children: [
            for (final (s, l, tp, r, b) in circles)
              Positioned(
                left: l,
                top: tp,
                right: r,
                bottom: b,
                child: _circle(s, edge),
              ),
            for (final (s, l, tp, r, b) in sparkles)
              Positioned(
                left: l,
                top: tp,
                right: r,
                bottom: b,
                child: HistorySparkle(s, t.fg),
              ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

/// Scan card (2-column grid): polaroid cover with sticker and trophies, meta,
/// 2-line title slot, score bar and "Lihat hasil". One tap target: the card.
class HistoryScanCard extends StatelessWidget {
  const HistoryScanCard(this.record, {super.key, required this.onTap});
  final ScanRecord record;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final tint = historyTint(p, historyCategoryTone(record.category));
    final cat = historyCategory(t, record.category);
    final total = record.totalQuestions, correct = record.correctCount;
    final ratio = total == 0 ? 0.0 : correct / total;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: p.borderSubtle),
    );
    final title = ElioTokens.body.copyWith(color: p.textPrimary);
    final soft = [
      BoxShadow(color: p.textPrimary.withValues(alpha: .12), blurRadius: 4),
    ];
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: t.h3CardSemantics(
        record.itemName,
        cat,
        correct,
        total,
        record.trophies,
      ),
      child: Material(
        color: p.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TintCover(
                  category: record.category,
                  height: 116,
                  radius: 16,
                  circles: const [(110, null, -40, -30, null)],
                  sparkles: const [
                    (14, 14, 14, null, null),
                    (10, null, null, 10, 34),
                    (8, 30, null, null, 40),
                  ],
                  child: Stack(
                    children: [
                      Center(
                        child: HistoryPolaroid(record, width: 104, height: 58),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: ShapeDecoration(
                            color: p.surface,
                            shape: const StadiumBorder(),
                            shadows: soft,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _circle(8, tint.fg),
                              const SizedBox(width: 4),
                              Text(
                                cat,
                                style: ElioTokens.caption.copyWith(
                                  color: tint.fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
                          decoration: ShapeDecoration(
                            color: p.secondaryText,
                            shape: const StadiumBorder(),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emoji_events_outlined,
                                size: 14,
                                color: p.surface,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '+${record.trophies}',
                                style: ElioTokens.caption.copyWith(
                                  color: p.surface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.h3RowMeta(historyTime(t, record.time), total),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ElioTokens.caption.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Always two lines high, so every card lines up.
                      Stack(
                        children: [
                          Text('\n', style: title, maxLines: 2),
                          Text(
                            record.itemName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: title,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 6,
                          alignment: Alignment.centerLeft,
                          decoration: ShapeDecoration(
                            color: p.surfaceRaised,
                            shape: const StadiumBorder(),
                          ),
                          child: ratio == 0
                              ? null
                              : FractionallySizedBox(
                                  key: const ValueKey('score_fill'),
                                  widthFactor: ratio,
                                  child: Container(
                                    decoration: ShapeDecoration(
                                      color: p.primary,
                                      shape: const StadiumBorder(),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$correct/$total',
                        style: ElioTokens.caption.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: ShapeDecoration(
                    color: p.primary,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          t.h3SeeResults,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: historyButtonText.copyWith(color: p.onPrimary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: p.onPrimary),
                    ],
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

/// Scan cards in rows of [columns]; rows share one height, a lone last card
/// keeps its column width.
class HistoryScanGrid extends StatelessWidget {
  const HistoryScanGrid({
    super.key,
    required this.records,
    required this.columns,
    required this.onOpen,
  });
  final List<ScanRecord> records;
  final int columns;
  final ValueChanged<ScanRecord> onOpen;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < records.length; i += columns) ...[
        if (i > 0) const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(
                  child: i + c < records.length
                      ? HistoryScanCard(
                          records[i + c],
                          onTap: () => onOpen(records[i + c]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ],
    ],
  );
}

/// Scan detail photo frame: category tint, blobs, sparkles, the polaroid
/// (contain), time pill and a 48 dp fullscreen button when [onOpen] is set.
class HistoryPhotoFrame extends StatelessWidget {
  const HistoryPhotoFrame(
    this.record, {
    super.key,
    this.onOpen,
    this.height = 184,
    this.radius = 20,
  });
  final ScanRecord record;
  final VoidCallback? onOpen;
  final double height, radius;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final shadow = [
      BoxShadow(color: p.textPrimary.withValues(alpha: .14), blurRadius: 8),
    ];
    return _TintCover(
      category: record.category,
      height: height,
      radius: radius,
      circles: const [(150, -50, null, null, -70), (120, null, -50, -30, null)],
      sparkles: const [
        (14, 92, 40, null, null),
        (10, null, 44, 96, null),
        (12, null, 28, 36, null),
        (8, 30, null, null, 30),
      ],
      child: Stack(
        children: [
          Center(
            child: Semantics(
              container: true,
              image: true,
              button: onOpen != null,
              label: t.h3ScanPhoto(record.itemName),
              child: GestureDetector(
                onTap: onOpen,
                child: Hero(
                  tag: 'history-photo-${record.id}',
                  child: HistoryPolaroid(
                    record,
                    width: 224,
                    height: 126,
                    degrees: -3,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
              decoration: ShapeDecoration(
                color: p.surface,
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: p.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    historyTime(t, record.time),
                    style: ElioTokens.caption.copyWith(color: p.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          if (onOpen != null)
            Positioned(
              right: 6,
              bottom: 6,
              child: IconButton(
                tooltip: t.h3OpenPhoto,
                onPressed: onOpen,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                icon: Container(
                  width: 44,
                  height: 44,
                  decoration: ShapeDecoration(
                    color: p.surface,
                    shape: const CircleBorder(),
                    shadows: shadow,
                  ),
                  child: Icon(
                    Icons.open_in_full,
                    size: 20,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Four-point sparkle star of the hero and section headers.
class HistorySparkle extends StatelessWidget {
  const HistorySparkle(this.size, this.color, {super.key});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SparklePainter(color));
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero), k = s.width * .12;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, 0)
        ..quadraticBezierTo(c.dx + k, c.dy - k, s.width, c.dy)
        ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, s.height)
        ..quadraticBezierTo(c.dx - k, c.dy + k, 0, c.dy)
        ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, 0),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

/// Pill on a filled hero (`*-fill-hover` bg, on-fill content).
Widget _heroPill(Color bg, Widget child, EdgeInsets padding) => Container(
  padding: padding,
  decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
  child: child,
);

/// Trophy hero: `primary/fill` block (green in both modes) with the total,
/// level, progress and the level art cut by the corner.
class HistoryTrophyHero extends StatelessWidget {
  const HistoryTrophyHero({
    super.key,
    required this.total,
    required this.levelNumber,
    required this.level,
    required this.progress,
    required this.next,
  });
  final int total, levelNumber;
  final String level, next;
  final double progress;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), on = p.onPrimary, t = context.l10n;
    final soft = on.withValues(alpha: .72);
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: p.primary,
        child: Stack(
          children: [
            Positioned(
              right: -42,
              top: -40,
              child: _circle(190, p.primaryHover),
            ),
            Positioned(
              right: 12,
              top: 34,
              child: SvgPicture.asset(
                levelNumber >= 3
                    ? 'assets/illustrations/home/tree_lv3.svg'
                    : 'assets/illustrations/home/sprout_lv1.svg',
                width: 120,
                height: 124,
                excludeFromSemantics: true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          t.h3YourTrophies.toUpperCase(),
                          style: ElioTokens.overline.copyWith(color: soft),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _heroPill(
                        p.primaryHover,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 12, color: on),
                            const SizedBox(width: 4),
                            Text(
                              t.h3SavedLocally,
                              style: ElioTokens.caption.copyWith(color: on),
                            ),
                          ],
                        ),
                        const EdgeInsets.fromLTRB(6, 2, 8, 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$total',
                        style: ElioTokens.display.copyWith(color: on),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.h3TrophyUnit(total),
                        style: ElioTokens.body.copyWith(color: on),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 110),
                    child: Text(
                      level,
                      style: ElioTokens.bodySmall.copyWith(color: on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 190,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        color: on,
                        backgroundColor: p.primaryHover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(next, style: ElioTokens.caption.copyWith(color: soft)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _circle(double size, Color color) => Container(
  width: size,
  height: size,
  decoration: ShapeDecoration(color: color, shape: const CircleBorder()),
);

/// Result stats: Trofi | Benar | Dipindai, split by 1x40 lines.
class HistoryResultStats extends StatelessWidget {
  const HistoryResultStats(this.record, {super.key});
  final ScanRecord record;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    // Figma 629:99682-99: three tilted leaf blobs (XP, Correct, Scanned).
    Widget stat(
      int i,
      Widget icon,
      Color bg,
      double degrees,
      double drop,
      String value,
      String label,
    ) => Expanded(
      child: Padding(
        padding: EdgeInsets.only(top: drop),
        // Pops in tilted, one after another.
        child: ElioPopIn(
          index: i,
          stagger: const Duration(milliseconds: 70),
          delay: const Duration(milliseconds: 120),
          scale: 0.6,
          curve: ElioMotion.pop,
          child: Transform.rotate(
            angle: degrees * math.pi / 180,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(26),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      icon,
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bold(
                            ElioTokens.subhead,
                          ).copyWith(color: p.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ElioTokens.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stat(
          0,
          SvgPicture.asset(
            'assets/illustrations/history/icon_xp.svg',
            width: 18,
            height: 18,
            excludeFromSemantics: true,
          ),
          historyTint(p, HistoryTone.warning).bg,
          3,
          2,
          '+${record.trophies}',
          t.h3StatTrophies,
        ),
        const SizedBox(width: 14),
        stat(
          1,
          Icon(Icons.check_rounded, size: 18, color: p.primaryText),
          historyTint(p, HistoryTone.success).bg,
          -2,
          6,
          '${record.correctCount}/${record.totalQuestions}',
          t.h3Correct,
        ),
        const SizedBox(width: 14),
        stat(
          2,
          Icon(Icons.calendar_today_outlined, size: 16, color: p.textSecondary),
          p.surfaceRaised,
          2,
          0,
          historyDay(t, record.time),
          t.h3StatScanned,
        ),
      ],
    );
  }
}

/// Bold on the variable font ('wght' axis as well as fontWeight).
TextStyle _bold(TextStyle s, [int weight = 700]) => s.copyWith(
  fontWeight: FontWeight.values[weight ~/ 100 - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
);

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0.75), Offset(x + 4, 0.75), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Question (Figma 629:99713): round Q badge, question, one result chip with
/// the XP, the answer as a leaf quote and "See explanation". No card; a
/// dashed line separates it from the question above.
class HistoryQuestionCard extends StatelessWidget {
  const HistoryQuestionCard(
    this.q,
    this.index, {
    super.key,
    required this.onExplain,
  });
  final RecordQuestion q;
  final int index;
  final VoidCallback onExplain;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final wrong = !q.isCorrect && !q.isEssay;
    final tint = historyTint(
      p,
      q.isEssay
          ? HistoryTone.warning
          : wrong
          ? HistoryTone.error
          : HistoryTone.success,
    );
    final result = q.isEssay
        ? (q.gradingPending
              ? t.h3AwaitingGrading
              : t.h3EssayScore(q.essayScore ?? 0))
        : wrong
        ? t.h3Incorrect
        : '✓ ${t.h3Correct}';
    Widget answer(String label, String text, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: _bold(
            ElioTokens.overline,
            600,
          ).copyWith(color: p.textTertiary, letterSpacing: 1.1),
        ),
        const SizedBox(height: 2),
        Text(text, style: ElioTokens.bodySmall.copyWith(color: color)),
      ],
    );
    return Column(
      children: [
        if (index > 0)
          CustomPaint(
            size: const Size(double.infinity, 1.5),
            painter: _DashPainter(p.borderMedium),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: ShapeDecoration(
                  color: wrong ? p.error : p.primary,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Q${index + 1}',
                  style: _bold(
                    ElioTokens.caption,
                  ).copyWith(color: wrong ? p.onError : p.onPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.question,
                      style: _bold(
                        ElioTokens.body,
                        600,
                      ).copyWith(color: p.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: ShapeDecoration(
                        color: tint.bg,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        // No XP yet while an essay waits for its grade.
                        q.isEssay && q.gradingPending
                            ? result
                            : '$result · +${q.trophies}',
                        style: _bold(
                          ElioTokens.caption,
                        ).copyWith(color: tint.fg),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: p.surfaceRaised,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          answer(t.h3YourAnswer, q.yourAnswer, p.textPrimary),
                          if (wrong) ...[
                            const SizedBox(height: 10),
                            answer(
                              t.h3CorrectAnswer,
                              q.rightAnswer,
                              p.primaryText,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      button: true,
                      child: InkWell(
                        onTap: onExplain,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.h3SeeExplanation,
                                style: historyButtonText.copyWith(
                                  color: p.primaryText,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: p.primaryText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Top bar: back 48, title Subhead (+ Caption), optional trailing.
class HistoryTopBar extends StatelessWidget implements PreferredSizeWidget {
  const HistoryTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = true,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;
  bool get _tall => subtitle != null;
  @override
  Size get preferredSize => Size.fromHeight(_tall ? 64 : 56);
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return ColoredBox(
      color: p.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: EdgeInsets.fromLTRB(_tall ? 4 : 12, 4, _tall ? 16 : 12, 4),
            child: Row(
              children: [
                if (showBack) ...[
                  IconButton(
                    tooltip: context.l10n.h3Back,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back, color: p.textPrimary),
                  ),
                  const SizedBox(width: 4),
                ] else
                  const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ElioTokens.subhead.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ElioTokens.caption.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Trophy pill (explanation top bar): warning tint, trophy 18 + label.
class HistoryTrophyPill extends StatelessWidget {
  const HistoryTrophyPill(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = historyTint(authPalette(context), HistoryTone.warning);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: ShapeDecoration(
        color: t.bg,
        shape: StadiumBorder(side: BorderSide(color: t.border!)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined, size: 18, color: t.fg),
          const SizedBox(width: 6),
          Text(label, style: historyButtonText.copyWith(color: t.fg)),
        ],
      ),
    );
  }
}

/// Listen button: 48 dp target, 36 dp circle. Play tinted, Pause filled.
class HistoryListenButton extends StatelessWidget {
  const HistoryListenButton({
    super.key,
    required this.active,
    required this.onPressed,
  });
  final bool active;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = historyTint(p, HistoryTone.success);
    return IconButton(
      tooltip: active ? context.l10n.h3Pause : context.l10n.h3Listen,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      onPressed: onPressed,
      icon: Container(
        width: 36,
        height: 36,
        decoration: ShapeDecoration(
          color: active ? p.primary : t.bg,
          shape: CircleBorder(
            side: active ? BorderSide.none : BorderSide(color: t.border!),
          ),
        ),
        child: Icon(
          active ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 16,
          color: active ? p.onPrimary : p.primaryText,
        ),
      ),
    );
  }
}

/// Result hero of the explanation: green "Mantap!" or red "Belum tepat!"
/// block with question dots, trophies and the bottle buddy (both modes).
class HistoryResultHero extends StatelessWidget {
  const HistoryResultHero({
    super.key,
    required this.correct,
    required this.index,
    required this.total,
    required this.trophies,
  });
  final bool correct;
  final int index, total, trophies;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final (fill, on, hover) = correct
        ? (p.primary, p.onPrimary, p.primaryHover)
        : (p.error, p.onError, p.destructiveHover);
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: fill,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 176),
          child: Stack(
            children: [
              Positioned(right: -42, top: -40, child: _circle(200, hover)),
              Positioned(
                right: 22,
                top: 46,
                child: SvgPicture.asset(
                  correct
                      ? 'assets/illustrations/control/bottle_buddy_happy.svg'
                      : 'assets/illustrations/control/bottle_buddy_sad.svg',
                  width: 90,
                  height: 122,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned(right: 106, top: 34, child: HistorySparkle(18, on)),
              Positioned(right: 14, top: 24, child: HistorySparkle(12, on)),
              Positioned(right: 118, top: 118, child: HistorySparkle(10, on)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          t.h3QuestionOf(index + 1, total).toUpperCase(),
                          style: ElioTokens.overline.copyWith(
                            color: on.withValues(alpha: .8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        for (var i = 0; i < total; i++)
                          Container(
                            width: i == index ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: ShapeDecoration(
                              color: on.withValues(alpha: i == index ? 1 : .45),
                              shape: const StadiumBorder(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      correct ? t.h3HeroRight : t.h3HeroWrong,
                      style: ElioTokens.headline.copyWith(color: on),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 200,
                      child: Text(
                        correct ? t.h3HeroRightBody : t.h3HeroWrongBody,
                        style: ElioTokens.bodySmall.copyWith(color: on),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _heroPill(
                      hover,
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events_outlined,
                            size: 16,
                            color: on,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            t.h3PlusTrophies(trophies),
                            style: historyButtonText.copyWith(color: on),
                          ),
                        ],
                      ),
                      const EdgeInsets.fromLTRB(8, 4, 10, 4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card shape r20 with a 2 dp `primary/fill` edge while it is read aloud.
ShapeBorder _cardShape(ElioPalette p, bool active) => RoundedSuperellipseBorder(
  borderRadius: BorderRadius.circular(20),
  side: active
      ? BorderSide(color: p.primary, width: 2)
      : BorderSide(color: p.borderSubtle),
);

/// The question card: info tile, "PERTANYAAN", listen button, Subhead text.
class HistoryQuestionPanel extends StatelessWidget {
  const HistoryQuestionPanel({
    super.key,
    required this.question,
    required this.listen,
  });
  final String question;
  final Widget listen;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), info = historyTint(p, HistoryTone.info);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      decoration: ShapeDecoration(
        color: p.surface,
        shape: _cardShape(p, false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: ShapeDecoration(color: info.bg, shape: _shape(8)),
                child: Icon(Icons.help_outline, size: 18, color: info.fg),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.h3TheQuestion.toUpperCase(),
                  style: ElioTokens.overline.copyWith(color: p.textTertiary),
                ),
              ),
              listen,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question,
            style: ElioTokens.subhead.copyWith(color: p.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Answer tile: 2 dp edge, 32 badge (X / check). Neutral (essay) has no badge.
class HistoryAnswerTile extends StatelessWidget {
  const HistoryAnswerTile(
    this.label,
    this.answer, {
    super.key,
    this.tone = HistoryTone.success,
  });
  final String label, answer;
  final HistoryTone tone;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = historyTint(p, tone);
    final (fill, onFill, tag) = switch (tone) {
      HistoryTone.success => (p.primary, p.onPrimary, p.primaryText),
      HistoryTone.error => (p.error, p.onError, p.errorText),
      _ => (p.borderSubtle, p.textPrimary, p.textTertiary),
    };
    final badge = tone == HistoryTone.success || tone == HistoryTone.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: ShapeDecoration(
        color: t.bg,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: fill, width: badge ? 2 : 1),
        ),
      ),
      child: Row(
        children: [
          if (badge) ...[
            Container(
              width: 32,
              height: 32,
              decoration: ShapeDecoration(
                color: fill,
                shape: const CircleBorder(),
              ),
              child: Icon(
                tone == HistoryTone.success ? Icons.check : Icons.close,
                size: 18,
                color: onFill,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: ElioTokens.overline.copyWith(color: tag),
                ),
                const SizedBox(height: 2),
                Text(
                  answer,
                  style: ElioTokens.body.copyWith(color: p.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "SEDANG DIBACAKAN" pill (`primary/fill`, volume 14 + Overline on-fill).
class HistoryReadingLabel extends StatelessWidget {
  const HistoryReadingLabel({super.key});
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return _heroPill(
      p.primary,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_up_outlined, size: 14, color: p.onPrimary),
          const SizedBox(width: 6),
          Text(
            context.l10n.h3ReadingNow,
            style: ElioTokens.overline.copyWith(color: p.onPrimary),
          ),
        ],
      ),
      const EdgeInsets.fromLTRB(8, 4, 10, 4),
    );
  }
}

/// A card that turns success-tinted with a reading pill while it is read.
class _ReadCard extends StatelessWidget {
  const _ReadCard({
    required this.active,
    required this.padding,
    required this.children,
  });
  final bool active;
  final EdgeInsets padding;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: ShapeDecoration(
        color: active ? historyTint(p, HistoryTone.success).bg : p.surface,
        shape: _cardShape(p, active),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active) ...[
            const HistoryReadingLabel(),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// 52 dp r16 art tile of the learn, key idea and mission cards.
Widget historyArtTile(Color bg, Widget art) => Container(
  width: 52,
  height: 52,
  alignment: Alignment.center,
  decoration: ShapeDecoration(color: bg, shape: _shape(16)),
  child: art,
);

/// Learn card: art tile, title Subhead, listen button, Body text.
class HistoryLearnCard extends StatelessWidget {
  const HistoryLearnCard({
    super.key,
    required this.art,
    required this.title,
    required this.body,
    required this.active,
    required this.onListen,
  });
  final Widget art;
  final String title, body;
  final bool active;
  final VoidCallback onListen;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return _ReadCard(
      active: active,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      children: [
        Row(
          children: [
            art,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: ElioTokens.subhead.copyWith(color: p.textPrimary),
              ),
            ),
            HistoryListenButton(active: active, onPressed: onListen),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            body,
            style: ElioTokens.body.copyWith(color: p.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// Key idea card: info tint, quest art on a `surface` tile, IDE UTAMA + Body.
/// No listen button (it is read with the whole question).
class HistoryKeyIdea extends StatelessWidget {
  const HistoryKeyIdea({super.key, required this.text, this.active = false});
  final String text;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final t = historyTint(p, active ? HistoryTone.success : HistoryTone.info);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: t.bg,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
          side: active
              ? BorderSide(color: p.primary, width: 2)
              : BorderSide(color: t.border!),
        ),
      ),
      child: Row(
        children: [
          historyArtTile(
            p.surface,
            SvgPicture.asset(
              'assets/illustrations/home/quest_target.svg',
              width: 40,
              height: 40,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (active)
                  const HistoryReadingLabel()
                else
                  Row(
                    children: [
                      HistorySparkle(12, t.fg),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.h3KeyIdea,
                        style: ElioTokens.overline.copyWith(color: t.fg),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: ElioTokens.body.copyWith(color: p.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mission card: flag tile, "Misimu" + step count, listen, numbered path
/// with a `primary/fill` rail and a medal finish row. The finish line is a
/// fixed sentence: the saved AI summary repeats the "why" text at length.
class HistoryMission extends StatelessWidget {
  const HistoryMission({
    super.key,
    required this.steps,
    required this.active,
    required this.onListen,
  });
  final List<String> steps;
  final bool active;
  final VoidCallback onListen;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = context.l10n;
    final warn = historyTint(p, HistoryTone.warning);
    Widget rail(Widget head) => SizedBox(
      width: 28,
      child: Column(
        children: [
          head,
          Expanded(child: Container(width: 2, color: p.primary)),
        ],
      ),
    );
    return _ReadCard(
      active: active,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            historyArtTile(
              warn.bg,
              Icon(Icons.outlined_flag, size: 26, color: warn.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.h3Mission,
                    style: ElioTokens.subhead.copyWith(color: p.textPrimary),
                  ),
                  Text(
                    t.h3MissionSteps(steps.length),
                    style: ElioTokens.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            HistoryListenButton(active: active, onPressed: onListen),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rail(
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: p.primary,
                      shape: const CircleBorder(),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: historyButtonText.copyWith(color: p.onPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 16),
                    child: Text(
                      steps[i],
                      style: ElioTokens.body.copyWith(color: p.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            SvgPicture.asset(
              'assets/illustrations/home/medal_gold.svg',
              width: 28,
              height: 33,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.h3MissionDone,
                style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 48 dp pill buttons of the actions bar and export sheet.
ButtonStyle historyOutlineStyle(ElioPalette p) => OutlinedButton.styleFrom(
  shape: const StadiumBorder(),
  minimumSize: const Size(0, 48),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  side: BorderSide(color: p.borderMedium),
  foregroundColor: p.textPrimary,
  textStyle: historyButtonText,
  iconSize: 20,
);
ButtonStyle historyPrimaryStyle(ElioPalette p) => FilledButton.styleFrom(
  shape: const StadiumBorder(),
  minimumSize: const Size(0, 48),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  backgroundColor: p.primary,
  foregroundColor: p.onPrimary,
  textStyle: historyButtonText,
  iconSize: 20,
);

/// Bottom actions: pad 12/16/28/16, gap 12, `surface`, top border.
class HistoryActionsBar extends StatelessWidget {
  const HistoryActionsBar({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.borderSubtle)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, math.max(28, inset + 12)),
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: children[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Shown in Bahasa Indonesia, connect to translate" with a retry, when a
/// record's translation could not be made (offline). Never invents text.
class HistoryOriginalNote extends StatelessWidget {
  const HistoryOriginalNote({
    super.key,
    required this.lang,
    required this.onRetry,
  });
  final String lang;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = historyTint(p, HistoryTone.info);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: ShapeDecoration(color: t.bg, shape: _shape(12, t.border)),
      child: Row(
        children: [
          Icon(Icons.translate_rounded, size: 16, color: t.fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.h3ShownInOriginal(
                lookupAppLocalizations(Locale(lang)).languageName,
              ),
              style: ElioTokens.caption.copyWith(color: p.textPrimary),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: p.primaryText),
            child: Text(context.l10n.h3TryAgain),
          ),
        ],
      ),
    );
  }
}

class HistoryError extends StatelessWidget {
  const HistoryError({super.key, required this.onRetry, this.message});
  final VoidCallback onRetry;

  /// Defaults to "explanation not available yet".
  final String? message;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message ?? context.l10n.h3ExplanationUnavailable,
              textAlign: TextAlign.center,
              style: ElioTokens.body.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: historyOutlineStyle(p),
              onPressed: onRetry,
              child: Text(context.l10n.h3TryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton: `border/medium` (the Figma PNGs render it opaque; the README's
/// 60 % reads too light) with a white sweep (peak 16 %).
/// Reduce-motion renders the same static blocks without a ticker.
class HistorySkeletonBlock extends StatefulWidget {
  const HistorySkeletonBlock({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
  });
  final double width, height, radius;
  @override
  State<HistorySkeletonBlock> createState() => _HistorySkeletonBlockState();
}

class _HistorySkeletonBlockState extends State<HistorySkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final base = p.borderMedium;
    final shine = Color.alphaBlend(const Color(0x29FFFFFF), base);
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (_, child) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-3 + _sweep.value * 6, 0),
              end: Alignment(-1 + _sweep.value * 6, 0),
              colors: [base, shine, base],
              stops: const [0, .5, 1],
            ),
          ),
        ),
      ),
    );
  }
}

enum HistoryLoadingLayout { list, detail, explanation }

/// Skeleton layouts mirror the real cards (Figma 03, 04, 09).
class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton(this.layout, {super.key});
  final HistoryLoadingLayout layout;
  static const _b = HistorySkeletonBlock.new;
  static Widget _gap([double h = 16]) => SizedBox(height: h);
  static Widget _pills(List<double> widths, double h, {double radius = 999}) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final w in widths) _b(width: w, height: h, radius: radius),
        ],
      );

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.h3Loading,
    child: ExcludeSemantics(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: switch (layout) {
          HistoryLoadingLayout.list => _list(),
          HistoryLoadingLayout.detail => _detail(),
          HistoryLoadingLayout.explanation => _explanation(),
        },
      ),
    ),
  );

  static Widget _pair(double h, double r) => Row(
    children: [
      Expanded(
        child: _b(height: h, radius: r),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _b(height: h, radius: r),
      ),
    ],
  );

  List<Widget> _list() => [
    _b(height: 164, radius: 20),
    _gap(),
    _pair(96, 16),
    _gap(12),
    _pair(96, 16),
    _gap(),
    _b(width: 140, height: 22),
    _gap(),
    for (var i = 0; i < 2; i++) ...[
      Row(
        children: [
          Expanded(child: _card()),
          const SizedBox(width: 12),
          Expanded(child: _card()),
        ],
      ),
      _gap(12),
    ],
  ];

  /// Scan card skeleton: 116 cover, meta, 2 title lines, bar, 36 button.
  static Widget _card() => HistoryCard(
    radius: 20,
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _b(height: 116, radius: 16),
        _gap(10),
        _b(width: 90, height: 12),
        _gap(8),
        _b(height: 16),
        _gap(6),
        _b(width: 80, height: 16),
        _gap(14),
        _b(height: 6, radius: 999),
        _gap(12),
        _b(height: 36, radius: 999),
      ],
    ),
  );

  List<Widget> _detail() => [
    _b(height: 184, radius: 20),
    _gap(),
    Row(
      children: [
        _b(width: 190, height: 28),
        const Spacer(),
        _b(width: 84, height: 24, radius: 999),
      ],
    ),
    _gap(),
    _b(height: 80, radius: 16),
    _gap(),
    _b(height: 48, radius: 999),
    _gap(),
    _b(width: 120, height: 22),
    _gap(),
    HistoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _b(width: 36, height: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _b(width: 250, height: 12),
                  _gap(10),
                  _b(width: 180, height: 12),
                ],
              ),
            ],
          ),
          _gap(),
          _pills([76, 56], 20),
          _gap(12),
          _b(height: 88, radius: 12),
        ],
      ),
    ),
  ];

  List<Widget> _explanation() => [
    _b(height: 176, radius: 20),
    _gap(),
    HistoryCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _b(width: 110, height: 12),
          _gap(12),
          _b(height: 16),
          _gap(12),
          _b(width: 200, height: 16),
        ],
      ),
    ),
    _gap(),
    _b(height: 64, radius: 16),
    _gap(8),
    _b(height: 64, radius: 16),
    _gap(),
    _b(width: 150, height: 22),
    _gap(),
    HistoryCard(
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _b(width: 52, height: 52, radius: 16),
              const SizedBox(width: 12),
              _b(width: 200, height: 16),
            ],
          ),
          for (final w in [double.infinity, double.infinity, 280.0]) ...[
            _gap(12),
            _b(width: w, height: 12),
          ],
        ],
      ),
    ),
  ];
}

/// Empty History: illustration, title, body 280 wide, primary pill button.
class HistoryEmpty extends StatelessWidget {
  const HistoryEmpty({super.key, required this.art, required this.onScan});
  final Widget art;
  final VoidCallback onScan;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            art,
            const SizedBox(height: 16),
            Text(
              context.l10n.h3EmptyTitle,
              style: ElioTokens.subhead.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 280,
              child: Text(
                context.l10n.h3EmptyBody,
                textAlign: TextAlign.center,
                style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: historyPrimaryStyle(p).copyWith(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
              onPressed: onScan,
              child: Text(context.l10n.h3StartScan),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- ELIOS 3

/// Devices a scan can come from (decision 0199). Null device = an older record.
enum HistoryDevice { phone, elios }

HistoryDevice? historyDeviceOf(ScanRecord r) => switch (r.device) {
  'phone' => HistoryDevice.phone,
  'elios' => HistoryDevice.elios,
  _ => null,
};

IconData historyDeviceIcon(HistoryDevice d) => switch (d) {
  HistoryDevice.phone => Icons.smartphone_rounded,
  HistoryDevice.elios => Icons.smart_toy_outlined,
};

String historyDeviceName(AppLocalizations t, HistoryDevice d) =>
    d == HistoryDevice.phone ? t.histPhone : 'ELIOS';

/// "Contribution", "Quiz 2/3" or "Scan only" for a record.
Widget historyKindChip(AppLocalizations t, ScanRecord r) => r.isContribution
    ? HistoryChip(
        t.histContribution,
        tone: HistoryTone.warning,
        icon: Icons.circle,
      )
    : r.questions.isEmpty
    ? HistoryChip(t.histScanOnly)
    : HistoryChip(
        t.histQuiz(r.correctCount, r.totalQuestions),
        tone: HistoryTone.info,
      );

/// One compact scan row (Figma 629:99388 "Recent scans", 629:99557 timeline):
/// polaroid, name, device + kind chips, then the day/time and trophies.
class HistoryScanRow extends StatelessWidget {
  const HistoryScanRow({
    super.key,
    required this.record,
    required this.onTap,
    this.trailingLabel,
    this.highlighted = false,
    this.showDevice = true,
  });

  final ScanRecord record;
  final VoidCallback onTap;

  /// Day ("Yesterday") on the tab, time on the timeline.
  final String? trailingLabel;
  final bool highlighted, showDevice;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final t = context.l10n;
    final r = record;
    final device = historyDeviceOf(r);
    return Semantics(
      button: true,
      label:
          '${r.itemName}, ${historyCategory(t, r.category)}, '
          '${trailingLabel ?? ''}, +${r.trophies}',
      excludeSemantics: true,
      child: HistoryCard(
        tone: highlighted ? HistoryTone.success : null,
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        onTap: onTap,
        child: Row(
          children: [
            // Morphs into the scan detail photo (Figma 13 · 32, container
            // transform 320 ms).
            Hero(
              tag: 'history-photo-${r.id}',
              child: HistoryPolaroid(r, width: 52, height: 44, degrees: -3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ElioTokens.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (showDevice && device != null)
                        HistoryChip(
                          historyDeviceName(t, device),
                          icon: historyDeviceIcon(device),
                        ),
                      historyKindChip(t, r),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (trailingLabel != null)
                  Text(
                    trailingLabel!,
                    style: ElioTokens.caption.copyWith(color: p.textSecondary),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 16,
                      color: p.secondaryText,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '+${r.trophies}',
                      style: ElioTokens.button.copyWith(color: p.secondaryText),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim trophy strip at the top of the History tab (Figma 629:99388).
class HistoryTrophyStrip extends StatelessWidget {
  const HistoryTrophyStrip({
    super.key,
    required this.total,
    required this.levelNumber,
    required this.level,
    required this.progress,
    required this.next,
  });
  final int total, levelNumber;
  final String level, next;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final t = context.l10n;
    return Semantics(
      container: true,
      label: '${t.h3Trophies(total)}, $level. $next',
      excludeSemantics: true,
      child: HistoryCard(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SvgPicture.asset(
                'assets/illustrations/home/${levelNumber >= 3 ? 'tree_lv3' : 'sprout_lv1'}.svg',
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$total ',
                          style: ElioTokens.subhead.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: '${t.h3TrophiesWord} · $level',
                          style: ElioTokens.caption.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 8,
                      color: p.primary,
                      backgroundColor: p.surfaceRaised,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next,
                    style: ElioTokens.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A "By device" card; without [onTap] it is locked ("Coming soon").
class HistoryDeviceCard extends StatelessWidget {
  const HistoryDeviceCard({
    super.key,
    required this.name,
    required this.icon,
    required this.last,
    this.onTap,
  });
  final String name, last;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final locked = onTap == null;
    return Semantics(
      button: !locked,
      enabled: !locked,
      label: '$name, $last',
      excludeSemantics: true,
      child: HistoryCard(
        tone: locked ? HistoryTone.neutral : HistoryTone.success,
        radius: 20,
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: locked ? p.textTertiary : p.primaryText,
                  ),
                ),
                const Spacer(),
                Icon(
                  locked ? Icons.lock_rounded : Icons.chevron_right_rounded,
                  size: 18,
                  color: p.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ElioTokens.body.copyWith(
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            Text(
              last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ElioTokens.caption.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
