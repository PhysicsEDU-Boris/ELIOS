import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/scan_record.dart';
import '../services/ai_quiz_service.dart';
import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;

// H3 History components. Sizes, gaps and tokens follow
// docs/design/h3-figma/README.md (Figma 433:2358); colours come only from the
// active ElioPalette.

String historyCategory(ScanCategory c) => switch (c) {
  ScanCategory.b3 => 'B3',
  ScanCategory.recyclable => 'Daur ulang',
  ScanCategory.organic => 'Organik',
  ScanCategory.residu => 'Residu',
};
String historyDifficulty(QuizDifficulty d) => switch (d) {
  QuizDifficulty.easy => 'Mudah',
  QuizDifficulty.medium => 'Sedang',
  QuizDifficulty.hard => 'Sulit',
};
String historyTime(DateTime time) {
  final now = DateTime.now();
  final day = DateTime(time.year, time.month, time.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today.subtract(const Duration(days: 1))) return 'Kemarin';
  if (day == today) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  return '${time.day}/${time.month}/${time.year}';
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

/// Filter chip: height 40, pill, `primary/fill` when selected, else `raised`.
class HistoryFilterChip extends StatelessWidget {
  const HistoryFilterChip(
    this.label, {
    super.key,
    required this.selected,
    this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Semantics(
      selected: selected,
      button: onSelected != null,
      child: Material(
        color: selected ? p.primary : p.surfaceRaised,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onSelected,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: historyButtonText.copyWith(
                  color: selected ? p.onPrimary : p.textPrimary,
                ),
              ),
            ),
          ),
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
    category == ScanCategory.b3 ? 'B3 · Berbahaya' : historyCategory(category),
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
          q.gradingPending ? 'Menunggu penilaian' : 'Skor ${q.essayScore}/10',
          tone: HistoryTone.info,
        )
      : q.isCorrect
      ? const HistoryChip('Benar', tone: HistoryTone.success, icon: Icons.check)
      : const HistoryChip('Salah', tone: HistoryTone.error);
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

class HistoryPhoto extends StatelessWidget {
  const HistoryPhoto(
    this.record, {
    super.key,
    this.width = 64,
    this.height = 64,
  });
  final ScanRecord record;
  final double width, height;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final large = height > 100;
    final name = switch (record.category) {
      ScanCategory.b3 => 'b3',
      ScanCategory.organic => 'organik',
      _ => 'anorganik',
    };
    final color = historyTint(p, historyCategoryTone(record.category)).fg;
    final placeholder = Center(
      child: SizedBox.square(
        dimension: large ? 88 : 40,
        child: SvgPicture.asset(
          'assets/illustrations/home/history_bin_$name.svg',
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          excludeFromSemantics: true,
        ),
      ),
    );
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(large ? 16 : 12),
      child: Container(
        width: width,
        height: height,
        color: p.surfaceRaised,
        child: record.cropPhotoPath == null
            ? placeholder
            : Image.file(
                File(record.cropPhotoPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) =>
                    Icon(Icons.broken_image_outlined, color: p.textSecondary),
              ),
      ),
    );
  }
}

/// Trophy summary: badge 44, count and level, progress, next level + chip.
class HistoryTrophySummary extends StatelessWidget {
  const HistoryTrophySummary({
    super.key,
    required this.total,
    required this.level,
    required this.progress,
    required this.next,
  });
  final int total;
  final String level, next;
  final double progress;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final warn = historyTint(p, HistoryTone.warning);
    return HistoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: warn.bg,
                  shape: CircleBorder(side: BorderSide(color: warn.border!)),
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  size: 24,
                  color: warn.fg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$total piala',
                      style: ElioTokens.subhead.copyWith(color: p.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level,
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
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: p.primary,
              backgroundColor: p.surfaceRaised,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  next,
                  style: ElioTokens.caption.copyWith(color: p.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              const HistoryChip(
                'Tersimpan lokal',
                tone: HistoryTone.success,
                icon: Icons.check,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Scan row: photo 64, title/chip/meta column, trophies on the right.
class HistoryScanRow extends StatelessWidget {
  const HistoryScanRow(this.record, {super.key, this.onTap});
  final ScanRecord record;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), warn = p.secondaryText;
    return HistoryCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          HistoryPhoto(record),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.itemName,
                  style: ElioTokens.body.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: 4),
                HistoryCategoryChip(record.category),
                const SizedBox(height: 4),
                Text(
                  '${historyTime(record.time)} · ${record.totalQuestions} soal',
                  style: ElioTokens.caption.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.emoji_events_outlined, size: 18, color: warn),
          const SizedBox(width: 4),
          Text(
            '+${record.trophies}',
            style: historyButtonText.copyWith(color: warn),
          ),
        ],
      ),
    );
  }
}

/// Score card: trophy 28 + Display score, "n dari m benar", hint.
class HistoryScoreCard extends StatelessWidget {
  const HistoryScoreCard(this.record, {super.key});
  final ScanRecord record;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return HistoryCard(
      tone: HistoryTone.warning,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 28,
                color: p.secondaryText,
              ),
              const SizedBox(width: 8),
              Text(
                '${record.trophies}',
                style: ElioTokens.display.copyWith(color: p.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${record.correctCount} dari ${record.totalQuestions} benar',
            style: historyButtonText.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '10 piala untuk setiap jawaban benar',
            textAlign: TextAlign.center,
            style: ElioTokens.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Question card: Q badge + question, chips, answers panel, explanation link.
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
    final p = authPalette(context);
    final yours = q.isEssay
        ? p.textPrimary
        : q.isCorrect
        ? p.primaryText
        : p.errorText;
    Widget answer(String label, String text, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: ElioTokens.overline.copyWith(color: p.textTertiary),
        ),
        const SizedBox(height: 4),
        Text(text, style: ElioTokens.bodySmall.copyWith(color: color)),
      ],
    );
    return HistoryCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HistoryQuestionBadge(
                index + 1,
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
            spacing: 8,
            runSpacing: 8,
            children: [HistoryResultChip(q), HistoryTrophyChip(q.trophies)],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: ShapeDecoration(
              color: p.surfaceRaised,
              shape: _shape(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                answer('Jawabanmu', q.yourAnswer, yours),
                if (!q.isCorrect && !q.isEssay) ...[
                  const SizedBox(height: 12),
                  answer('Jawaban benar', q.rightAnswer, p.primaryText),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            child: InkWell(
              onTap: onExplain,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 18,
                      color: p.primaryText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lihat penjelasan',
                      style: historyButtonText.copyWith(color: p.primaryText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
                    tooltip: 'Kembali',
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

/// Trophy pill: warning tint, trophy 18 + count Button.
class HistoryTrophyPill extends StatelessWidget {
  const HistoryTrophyPill(this.count, {super.key});
  final int count;
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
          Text('$count', style: historyButtonText.copyWith(color: t.fg)),
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
      tooltip: active ? 'Jeda' : 'Dengarkan',
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

/// Tinted answer block of the explanation screen (pad 12, r12).
class HistoryAnswer extends StatelessWidget {
  const HistoryAnswer(
    this.label,
    this.answer, {
    super.key,
    this.tone = HistoryTone.neutral,
    this.check = false,
  });
  final String label, answer;
  final HistoryTone tone;
  final bool check;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = historyTint(p, tone);
    final fg = tone == HistoryTone.neutral ? p.textTertiary : t.fg;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: t.bg,
        shape: _shape(12, t.border ?? Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (check) ...[
                Icon(Icons.check, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  style: ElioTokens.overline.copyWith(color: fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(answer, style: ElioTokens.body.copyWith(color: p.textPrimary)),
        ],
      ),
    );
  }
}

/// "SEDANG DIBACAKAN" row (volume 14 + Overline `primary/text`).
class HistoryReadingLabel extends StatelessWidget {
  const HistoryReadingLabel({super.key});
  @override
  Widget build(BuildContext context) {
    final c = authPalette(context).primaryText;
    return Row(
      children: [
        Icon(Icons.volume_up_outlined, size: 14, color: c),
        const SizedBox(width: 6),
        Text('SEDANG DIBACAKAN', style: ElioTokens.overline.copyWith(color: c)),
      ],
    );
  }
}

/// Explanation section: pad 12, gap 8, r12, no fill; success tint while read.
class HistoryExplanationSection extends StatelessWidget {
  const HistoryExplanationSection({
    super.key,
    required this.title,
    required this.body,
    required this.active,
    required this.onListen,
  });
  final String title, body;
  final bool active;
  final VoidCallback onListen;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = historyTint(p, HistoryTone.success);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: active ? t.bg : null,
        shape: _shape(12, active ? t.border : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active) ...[
            const HistoryReadingLabel(),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: ElioTokens.subhead.copyWith(color: p.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              HistoryListenButton(active: active, onPressed: onListen),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: ElioTokens.body.copyWith(color: p.textPrimary)),
        ],
      ),
    );
  }
}

/// Key idea card: info tint, buddy art 64x76, IDE UTAMA + Body Small. No
/// listen button (it is read with the whole question).
class HistoryKeyIdea extends StatelessWidget {
  const HistoryKeyIdea({
    super.key,
    required this.art,
    required this.text,
    this.active = false,
  });
  final Widget art;
  final String text;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final t = historyTint(p, active ? HistoryTone.success : HistoryTone.info);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
      decoration: ShapeDecoration(color: t.bg, shape: _shape(16, t.border)),
      child: Row(
        children: [
          art,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (active)
                  const HistoryReadingLabel()
                else
                  Text(
                    'IDE UTAMA',
                    style: ElioTokens.overline.copyWith(color: t.fg),
                  ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: ElioTokens.bodySmall.copyWith(color: p.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Steps block: pad 0/12, gap 12, numbered rows (circle 28 `raised`).
class HistorySteps extends StatelessWidget {
  const HistorySteps({
    super.key,
    required this.title,
    required this.steps,
    this.active = false,
  });
  final String title;
  final List<String> steps;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context), t = historyTint(p, HistoryTone.success);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: active
          ? ShapeDecoration(color: t.bg, shape: _shape(12, t.border))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active) ...[
            const SizedBox(height: 8),
            const HistoryReadingLabel(),
            const SizedBox(height: 8),
          ],
          Text(title, style: ElioTokens.subhead.copyWith(color: p.textPrimary)),
          for (var i = 0; i < steps.length; i++) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: p.surfaceRaised,
                    shape: const CircleBorder(),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: historyButtonText.copyWith(color: p.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    steps[i],
                    style: ElioTokens.body.copyWith(color: p.textPrimary),
                  ),
                ),
              ],
            ),
          ],
          if (active) const SizedBox(height: 12),
        ],
      ),
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

class HistoryError extends StatelessWidget {
  const HistoryError({
    super.key,
    required this.onRetry,
    this.message = 'Penjelasan lengkap belum tersedia',
  });
  final VoidCallback onRetry;
  final String message;
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
              message,
              textAlign: TextAlign.center,
              style: ElioTokens.body.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: historyOutlineStyle(p),
              onPressed: onRetry,
              child: const Text('Coba lagi'),
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
    label: 'Sedang memuat',
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

  List<Widget> _list() => [
    HistoryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _b(width: 44, height: 44, radius: 22),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _b(width: 140, height: 18),
                  _gap(8),
                  _b(width: 190, height: 12),
                ],
              ),
            ],
          ),
          _gap(),
          _b(height: 8, radius: 4),
          _gap(),
          _b(width: 150, height: 12),
        ],
      ),
    ),
    _gap(),
    _pills([56, 44, 96, 80], 40),
    _gap(),
    _b(width: 140, height: 22),
    _gap(),
    for (var i = 0; i < 5; i++) ...[
      HistoryCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _b(width: 64, height: 64, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _b(width: 190, height: 16),
                  _gap(8),
                  _b(width: 84, height: 20, radius: 999),
                  _gap(8),
                  _b(width: 130, height: 12),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _b(width: 40, height: 16, radius: 999),
          ],
        ),
      ),
      _gap(12),
    ],
  ];

  List<Widget> _detail() => [
    _b(height: 200, radius: 16),
    _gap(),
    Row(
      children: [
        _b(width: 190, height: 28),
        const Spacer(),
        _b(width: 84, height: 24, radius: 999),
      ],
    ),
    _gap(),
    _b(width: 260, height: 12),
    _gap(),
    _pills([76, 100, 84], 40),
    _gap(),
    _b(height: 112, radius: 16),
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
    SizedBox(
      height: 100,
      child: Row(
        children: [
          _pills([36, 64, 76, 44], 24),
          const Spacer(),
          const SizedBox(
            width: 48,
            child: Center(
              child: HistorySkeletonBlock(width: 36, height: 36, radius: 18),
            ),
          ),
        ],
      ),
    ),
    _gap(16),
    _b(width: 320, height: 28),
    _gap(8),
    _b(width: 220, height: 28),
    _gap(),
    _b(height: 72, radius: 12),
    _gap(),
    _b(height: 72, radius: 12),
    _gap(),
    _b(width: 140, height: 22),
    _gap(),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _b(width: 240, height: 20),
          for (final w in [
            double.infinity,
            double.infinity,
            300.0,
            double.infinity,
            210.0,
          ]) ...[_gap(12), _b(width: w, height: 12)],
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
              'Belum ada scan',
              style: ElioTokens.subhead.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 280,
              child: Text(
                'Scan benda dengan ELIOS. Hasil kuis dan pialamu akan muncul di sini.',
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
              child: const Text('Mulai scan'),
            ),
          ],
        ),
      ),
    );
  }
}
