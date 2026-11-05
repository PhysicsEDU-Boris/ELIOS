import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/scan_record.dart';
import '../services/ai_quiz_service.dart';
import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;

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

class HistoryCard extends StatelessWidget {
  const HistoryCard({
    super.key,
    required this.child,
    this.tint,
    this.padding = 16,
    this.plain = false,
  });
  final bool plain;
  final Widget child;
  final Color? tint;
  final double padding;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: plain
            ? null
            : tint?.withValues(alpha: p.isDark ? .12 : .06) ?? p.surface,
        border: plain
            ? null
            : Border.all(color: tint?.withValues(alpha: .35) ?? p.borderSubtle),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class HistoryPill extends StatelessWidget {
  const HistoryPill(this.text, {super.key, this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context),
        c = color ?? authPalette(context).textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color == null
            ? p.surfaceRaised
            : c.withValues(alpha: p.isDark ? .12 : .06),
        borderRadius: BorderRadius.circular(999),
        border: color == null
            ? null
            : Border.all(color: c.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 4),
          ],
          Text(text, style: ElioTokens.caption.copyWith(color: c)),
        ],
      ),
    );
  }
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: essay
            ? p.surfaceRaised
            : correct
            ? p.primary
            : p.error,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Q$number',
        style: ElioTokens.button.copyWith(
          color: essay
              ? p.textPrimary
              : correct
              ? p.onPrimary
              : p.onError,
        ),
      ),
    );
  }
}

class HistoryCategoryChip extends StatelessWidget {
  const HistoryCategoryChip(this.category, {super.key});
  final ScanCategory category;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return HistoryPill(
      historyCategory(category),
      color: switch (category) {
        ScanCategory.b3 => p.errorText,
        ScanCategory.organic => p.secondaryText,
        ScanCategory.recyclable => p.primaryText,
        ScanCategory.residu => p.textSecondary,
      },
    );
  }
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
    final name = switch (record.category) {
      ScanCategory.b3 => 'b3',
      ScanCategory.organic => 'organik',
      _ => 'anorganik',
    };
    final color = switch (record.category) {
      ScanCategory.b3 => p.errorText,
      ScanCategory.organic => p.secondaryText,
      _ => p.primaryText,
    };
    final placeholder = Center(
      child: SizedBox.square(
        dimension: height > 100 ? 88 : 40,
        child: SvgPicture.asset(
          'assets/illustrations/home/history_bin_$name.svg',
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          excludeFromSemantics: true,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
        height: height,
        color: p.surfaceRaised,
        child: record.cropPhotoPath == null
            ? placeholder
            : Image.file(
                File(record.cropPhotoPath!),
                fit: BoxFit.contain,
                errorBuilder: (_, error, stack) =>
                    Icon(Icons.broken_image_outlined, color: p.textSecondary),
              ),
      ),
    );
  }
}

class HistoryAnswer extends StatelessWidget {
  const HistoryAnswer(this.label, this.answer, {super.key, this.color});
  final String label, answer;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return HistoryCard(
      padding: 12,
      tint: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: ElioTokens.overline.copyWith(
              fontFamily: ElioTokens.fontSans,
              color: color ?? p.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(answer, style: ElioTokens.body.copyWith(color: p.textPrimary)),
        ],
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    ),
  );
}

/// Shared H3 sweep; reduce-motion renders the same static blocks without a ticker.
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
    return AnimatedBuilder(
      animation: _sweep,
      builder: (_, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-3 + _sweep.value * 6, 0),
            end: Alignment(-1 + _sweep.value * 6, 0),
            colors: [
              p.borderMedium,
              p.textSecondary.withValues(alpha: .35),
              p.borderMedium,
            ],
            stops: const [0, .5, 1],
          ),
        ),
      ),
    );
  }
}

enum HistoryLoadingLayout { list, detail, explanation }

class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton(this.layout, {super.key});
  final HistoryLoadingLayout layout;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sedang memuat',
    child: ExcludeSemantics(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (layout == HistoryLoadingLayout.list) ...[
            const HistoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HistorySkeletonBlock(width: 190, height: 28),
                  SizedBox(height: 12),
                  HistorySkeletonBlock(height: 8),
                  SizedBox(height: 16),
                  HistorySkeletonBlock(width: 150),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _chips(),
            const SizedBox(height: 16),
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HistoryCard(
                  padding: 12,
                  child: Row(
                    children: [
                      const HistorySkeletonBlock(width: 64, height: 64),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            HistorySkeletonBlock(),
                            SizedBox(height: 8),
                            HistorySkeletonBlock(width: 84),
                            SizedBox(height: 8),
                            HistorySkeletonBlock(width: 130, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ] else ...[
            if (layout == HistoryLoadingLayout.detail)
              const HistorySkeletonBlock(height: 200, radius: 16),
            const SizedBox(height: 16),
            _chips(),
            const SizedBox(height: 40),
            const HistorySkeletonBlock(height: 28),
            const SizedBox(height: 10),
            const HistorySkeletonBlock(width: 220, height: 28),
            const SizedBox(height: 16),
            const HistorySkeletonBlock(height: 72),
            const SizedBox(height: 16),
            const HistorySkeletonBlock(height: 72),
            const SizedBox(height: 16),
            const HistorySkeletonBlock(width: 140, height: 22),
            const SizedBox(height: 16),
            for (var i = 0; i < 6; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: HistorySkeletonBlock(),
              ),
          ],
        ],
      ),
    ),
  );
  static Widget _chips() => const Wrap(
    spacing: 8,
    children: [
      HistorySkeletonBlock(width: 56, height: 36, radius: 999),
      HistorySkeletonBlock(width: 80, height: 36, radius: 999),
      HistorySkeletonBlock(width: 96, height: 36, radius: 999),
    ],
  );
}
