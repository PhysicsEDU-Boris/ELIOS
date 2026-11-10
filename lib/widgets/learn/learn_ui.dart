import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/elio_theme.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_tokens.dart';
import 'package:elio/l10n/l10n.dart';

/// L1 v2 Learn components (Figma 295:2372 to 300:3329). Colours come only
/// from the active [ElioPalette]; text from the theme's [TextTheme].
extension LearnTheme on BuildContext {
  ElioPalette get elio => Theme.of(this).brightness == Brightness.dark
      ? ElioTokens.dark
      : ElioTokens.light;
  TextTheme get text => Theme.of(this).textTheme;
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}

/// Pushes a Learn page inside the ELIO theme (routes do not inherit it).
/// Learn sub-pages slide in 24 px and fade (ELIOS 3 motion, Figma 13 · 10).
Route<T> learnRoute<T>(Widget page) =>
    ElioPageRoute<T>(builder: (_) => ElioTheme.wrap(page));

// M3 shape scale with continuous corners.
const learnRadiusM = 12.0;
const learnRadiusL = 16.0;
const learnRadiusXl = 28.0;

ShapeBorder learnShape(double r, [BorderSide side = BorderSide.none]) =>
    RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(r),
      side: side,
    );

/// Surface card with a subtle border; tappable when [onTap] is set.
class LearnCard extends StatelessWidget {
  const LearnCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = learnRadiusL,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final shape = learnShape(
      radius,
      BorderSide(color: borderColor ?? p.borderSubtle),
    );
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: color ?? p.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Section header 295:2511: title left, green action right.
class LearnSectionHeader extends StatelessWidget {
  const LearnSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.text.titleLarge),
            ),
          ),
          if (actionLabel != null && onAction == null)
            Text(
              actionLabel!,
              style: context.text.labelLarge?.copyWith(color: p.primaryText),
            )
          else if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: p.primaryText,
                minimumSize: const Size(48, 48),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

enum LearnTone { success, warning, error, info, neutral }

Color _toneFg(ElioPalette p, LearnTone t) => switch (t) {
  LearnTone.success => p.primaryText,
  LearnTone.warning => p.secondaryText,
  LearnTone.error => p.errorText,
  LearnTone.info => p.tertiaryText,
  LearnTone.neutral => p.textSecondary,
};

/// Level chip 300:3146 (tinted pill).
class LevelChip extends StatelessWidget {
  const LevelChip({
    super.key,
    required this.label,
    this.tone = LearnTone.success,
  });

  final String label;
  final LearnTone tone;

  @override
  Widget build(BuildContext context) {
    final fg = _toneFg(context.elio, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(
        color: fg.withValues(alpha: 0.12),
        shape: const StadiumBorder(),
      ),
      child: Text(label, style: context.text.labelMedium?.copyWith(color: fg)),
    );
  }
}

/// Thin progress bar used by cards and summaries.
class LearnProgressBar extends StatelessWidget {
  const LearnProgressBar({super.key, required this.value, this.height = 6});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: p.borderSubtle,
        color: p.primary,
      ),
    );
  }
}

/// Icon + text pair ("7:22", "Done").
class LearnMeta extends StatelessWidget {
  const LearnMeta({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.elio.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(color: c),
          ),
        ),
      ],
    );
  }
}

/// Network image (Cloudinary) with the bundled illustration as placeholder
/// and fallback for an empty or failing URL (decision 0171).
class LearnThumbnail extends StatelessWidget {
  const LearnThumbnail({
    super.key,
    required this.url,
    required this.fallbackAsset,
    this.fit = BoxFit.cover,
    this.cacheManager,
  });

  final String url;
  final String fallbackAsset;
  final BoxFit fit;

  /// Default cache unless a test passes one.
  final BaseCacheManager? cacheManager;

  @override
  Widget build(BuildContext context) {
    final fallback = LearnIllustration(fallbackAsset, fit: fit);
    if (url.trim().isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url.trim(),
      cacheManager: cacheManager,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

/// Bundled SVG illustration; decorative, so excluded from semantics.
class LearnIllustration extends StatelessWidget {
  const LearnIllustration(
    this.asset, {
    super.key,
    this.fit = BoxFit.contain,
    this.height,
  });

  final String asset;
  final BoxFit fit;
  final double? height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      asset,
      fit: fit,
      height: height,
      width: height == null ? double.infinity : null,
    ),
  );
}

/// Rounded cover area of a card.
class LearnCover extends StatelessWidget {
  const LearnCover({
    super.key,
    required this.child,
    this.aspectRatio = 16 / 9,
    this.badge,
  });

  final Widget child;
  final double aspectRatio;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(learnRadiusM),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: p.surfaceRaised, child: child),
            if (badge != null && badge!.isNotEmpty)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: ShapeDecoration(
                    color: p.tooltipBg,
                    shape: learnShape(6),
                  ),
                  child: Text(
                    badge!,
                    style: context.text.labelMedium?.copyWith(
                      color: p.tooltipText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bin card 295:2372: module name and bin icon; [selected] fills green.
class BinCard extends StatelessWidget {
  const BinCard({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final fg = selected ? p.onPrimary : p.textPrimary;
    return LearnCard(
      onTap: onTap,
      semanticLabel: l10n.lnModuleLabel(label),
      color: selected ? p.primary : null,
      borderColor: selected ? p.primary : null,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 64,
        child: Stack(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: SvgPicture.asset(
                iconAsset,
                height: 32,
                colorFilter: ColorFilter.mode(
                  selected ? p.onPrimary : p.primaryText,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lesson card 295:2373: cover, meta, title, footer, optional button.
class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.cover,
    required this.meta,
    required this.title,
    this.leading,
    this.trailing,
    this.buttonLabel,
    this.primaryButton = false,
    this.onTap,
    this.coverBadge,
    this.footer,
  });

  /// Full-width content under the meta row (progress bars).
  final Widget? footer;
  final Widget cover;
  final String meta;
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final String? buttonLabel;
  final bool primaryButton;
  final VoidCallback? onTap;
  final String? coverBadge;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return LearnCard(
      onTap: buttonLabel == null ? onTap : null,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LearnCover(badge: coverBadge, child: cover),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (leading != null || trailing != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (leading != null) Flexible(child: leading!),
                      const Spacer(),
                      ?trailing,
                    ],
                  ),
                ],
                if (footer != null) ...[const SizedBox(height: 6), footer!],
              ],
            ),
          ),
          if (buttonLabel != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: primaryButton
                  ? FilledButton(onPressed: onTap, child: Text(buttonLabel!))
                  : FilledButton.tonal(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: p.surfaceRaised,
                        foregroundColor: p.textPrimary,
                        side: BorderSide.none,
                      ),
                      child: Text(buttonLabel!),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lesson card grid 295:2420: two columns on phones, each row as tall as
/// its tallest card (text scale 1.3 never clips).
class LessonCardGrid extends StatelessWidget {
  const LessonCardGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.gap = 12,
  });

  final List<Widget> children;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: gap),
                Expanded(
                  child: i + c < children.length
                      ? children[i + c]
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ),
      );
      if (i + columns < children.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }
}

/// Horizontal carousel of fixed-width cards.
class LearnCarousel extends StatelessWidget {
  const LearnCarousel({
    super.key,
    required this.children,
    this.itemWidth = 220,
  });

  final List<Widget> children;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              SizedBox(
                width: itemWidth * scale.clamp(1.0, 1.3),
                child: children[i],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress summary 300:3206 / Progress card 295:2469.
class ProgressSummaryCard extends StatelessWidget {
  const ProgressSummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.footer,
    this.icon = Icons.trending_up_rounded,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final double value;
  final String footer;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return LearnCard(
      onTap: onTap,
      semanticLabel: context.l10n.a11yPercent(title, (value * 100).round()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconTile(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleSmall),
                    Text(
                      subtitle,
                      style: context.text.labelMedium?.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: context.text.headlineLarge?.copyWith(
                  color: p.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LearnProgressBar(value: value),
          const SizedBox(height: 8),
          Text(
            footer,
            style: context.text.labelMedium?.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.tone = LearnTone.success});

  final IconData icon;
  final LearnTone tone;

  @override
  Widget build(BuildContext context) {
    final fg = _toneFg(context.elio, tone);
    return Container(
      width: 40,
      height: 40,
      decoration: ShapeDecoration(
        color: fg.withValues(alpha: 0.12),
        shape: learnShape(learnRadiusM),
      ),
      child: Icon(icon, color: fg, size: 22),
    );
  }
}

/// Guide lesson row 300:3220 and quiz history rows.
class GuideLessonRow extends StatelessWidget {
  const GuideLessonRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon = Icons.description_outlined,
    this.trailing,
    this.highlighted = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData icon;
  final Widget? trailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Material(
      color: highlighted ? p.surfaceRaised : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: p.primaryText, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text.titleSmall),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: context.text.labelMedium?.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bordered list that separates rows with dividers.
class LearnListCard extends StatelessWidget {
  const LearnListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return LearnCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: p.borderSubtle),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Green round check used on finished rows.
class DoneCheck extends StatelessWidget {
  const DoneCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      label: l10n.lnDone,
      child: Container(
        width: 24,
        height: 24,
        decoration: ShapeDecoration(color: p.primary, shape: learnShape(6)),
        child: Icon(Icons.check_rounded, size: 18, color: p.onPrimary),
      ),
    );
  }
}

/// Video card 300:3233.
class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.thumbnail,
    required this.duration,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget thumbnail;
  final String duration;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      button: true,
      label: l10n.lnVideoLabel(title),
      child: InkWell(
        onTap: onTap,
        customBorder: learnShape(learnRadiusM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            LearnCover(
              badge: duration,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  thumbnail,
                  const Center(child: PlayBadge()),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall,
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// White play disc over video covers.
class PlayBadge extends StatelessWidget {
  const PlayBadge({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
        child: Icon(
          Icons.play_arrow_rounded,
          color: p.textPrimary,
          size: size * 0.6,
        ),
      ),
    );
  }
}

/// Quiz card 300:3274: mascot, title, subtitle, action.
class QuizCard extends StatelessWidget {
  const QuizCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return LearnCard(
      child: Row(
        children: [
          const SizedBox(
            width: 48,
            child: LearnIllustration(
              'assets/illustrations/learn/elio_quiz_mascot.svg',
              height: 48,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                Text(
                  subtitle,
                  style: context.text.labelMedium?.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

/// Simulation row 300:3294 (module page) with icon, meta, status, formula.
class SimulationRow extends StatelessWidget {
  const SimulationRow({
    super.key,
    required this.icon,
    required this.tag,
    required this.title,
    required this.description,
    required this.formula,
    required this.minutes,
    required this.done,
    required this.onTap,
  });

  final IconData icon;
  final String tag;
  final String title;
  final String description;
  final String formula;
  final int minutes;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return LearnCard(
      onTap: onTap,
      semanticLabel: l10n.lnSimLabel(title),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(icon: icon, tone: LearnTone.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      tag,
                      style: context.text.labelMedium?.copyWith(
                        color: p.errorText,
                      ),
                    ),
                    if (done) LevelChip(label: l10n.lnDone),
                  ],
                ),
                const SizedBox(height: 4),
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: context.text.labelMedium?.copyWith(
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FormulaChip(formula: formula),
                    LearnMeta(
                      icon: Icons.schedule_rounded,
                      label: l10n.lnMinutes(minutes),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.textSecondary),
        ],
      ),
    );
  }
}

class FormulaChip extends StatelessWidget {
  const FormulaChip({super.key, required this.formula});

  final String formula;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(color: p.surfaceRaised, shape: learnShape(6)),
      child: Text(
        'Σ  $formula',
        style: ElioTokens.chip.copyWith(color: p.textPrimary),
      ),
    );
  }
}

/// Simulation card for the hub carousel: canvas, tag, title, time, status.
class SimulationCard extends StatelessWidget {
  const SimulationCard({
    super.key,
    required this.canvasAsset,
    required this.tag,
    required this.title,
    required this.minutes,
    required this.done,
    required this.onTap,
  });

  final String canvasAsset;
  final String tag;
  final String title;
  final int minutes;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return LessonCard(
      onTap: onTap,
      cover: LearnIllustration(canvasAsset, fit: BoxFit.cover),
      meta: tag,
      title: title,
      leading: LearnMeta(
        icon: Icons.schedule_rounded,
        label: l10n.lnMinutes(minutes),
      ),
      trailing: done
          ? LearnMeta(
              icon: Icons.check_rounded,
              label: l10n.lnDone,
              color: p.primaryText,
            )
          : null,
    );
  }
}

/// Segmented tabs (lesson filter, Materi / Rumus / Simulasi, In progress /
/// Completed).
class LearnSegmented extends StatelessWidget {
  const LearnSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.icons,
  });

  final List<String> labels;
  final List<IconData>? icons;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: p.surfaceRaised,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: Material(
                  color: i == selected ? p.surface : Colors.transparent,
                  shape: StadiumBorder(
                    side: i == selected
                        ? BorderSide(color: p.borderMedium)
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onSelected(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icons != null) ...[
                                Icon(icons![i], size: 18, color: p.textPrimary),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  labels[i],
                                  textAlign: TextAlign.center,
                                  style: context.text.labelLarge?.copyWith(
                                    color: i == selected
                                        ? p.textPrimary
                                        : p.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shared page scaffold for pushed Learn pages: back, centred title,
/// optional action and sticky bottom button.
class LearnPageScaffold extends StatelessWidget {
  const LearnPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottom,
    this.centerTitle = true,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: centerTitle,
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(top: false, bottom: bottom == null, child: body),
      bottomNavigationBar: bottom == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(top: BorderSide(color: p.borderSubtle)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: bottom,
                ),
              ),
            ),
    );
  }
}

/// Phone-first list padding with a 600 dp max width.
class LearnListView extends StatelessWidget {
  const LearnListView({super.key, required this.children, this.onRefresh});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      // In the Learn tab (no top bar since ELIOS 3) this clears the status
      // bar; under an AppBar the inset is already 0.
      padding: EdgeInsets.fromLTRB(
        16,
        8 + MediaQuery.paddingOf(context).top,
        16,
        32,
      ),
      children: [
        for (final c in children)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              // Full width so free text aligns left, not centred.
              child: SizedBox(width: double.infinity, child: c),
            ),
          ),
      ],
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Skeleton block shown while a Firestore stream has no first value.
class LearnSkeleton extends StatelessWidget {
  const LearnSkeleton({
    super.key,
    this.height = 80,
    this.width,
    this.radius = learnRadiusL,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    decoration: ShapeDecoration(
      color: context.elio.borderSubtle,
      shape: learnShape(radius),
    ),
  );
}

/// Hub skeleton (Figma 312:6154).
class LearnHubSkeleton extends StatelessWidget {
  const LearnHubSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: l10n.lnLoadingModules,
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LearnSkeleton(height: 156, radius: learnRadiusXl),
        SizedBox(height: 24),
        LearnSkeleton(height: 84),
        SizedBox(height: 24),
        LearnSkeleton(height: 20, width: 120, radius: 6),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: LearnSkeleton(height: 80)),
            SizedBox(width: 12),
            Expanded(child: LearnSkeleton(height: 80)),
            SizedBox(width: 12),
            Expanded(child: LearnSkeleton(height: 80)),
          ],
        ),
        SizedBox(height: 24),
        LearnSkeleton(height: 20, width: 160, radius: 6),
        SizedBox(height: 16),
        LearnSkeleton(height: 200),
      ],
    ),
  );
}

/// Spinner that stays static under reduced motion (lesson loading 312:6239).
class LearnSpinner extends StatelessWidget {
  const LearnSpinner({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      label: label ?? l10n.lnLoadingLesson,
      child: SizedBox.square(
        dimension: 40,
        child: CircularProgressIndicator(
          value: context.reduceMotion ? 0.25 : null,
          strokeWidth: 4,
          color: p.primary,
          backgroundColor: p.borderSubtle,
        ),
      ),
    );
  }
}

/// Full-width state (empty, error, offline) with illustration and actions.
class LearnStateView extends StatelessWidget {
  const LearnStateView({
    super.key,
    required this.asset,
    required this.title,
    this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String asset;
  final String title;
  final String? message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        children: [
          LearnIllustration(asset, height: 160),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleLarge,
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: p.textSecondary),
            ),
          ],
          if (primaryLabel != null) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
              child: Text(primaryLabel!),
            ),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onSecondary,
              style: FilledButton.styleFrom(
                minimumSize: const Size(120, 48),
                backgroundColor: p.surfaceRaised,
                foregroundColor: p.textPrimary,
                side: BorderSide.none,
              ),
              child: Text(secondaryLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dashed hint card ("Nothing in progress yet ...").
class LearnHintCard extends StatelessWidget {
  const LearnHintCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return LearnCard(
      color: p.background,
      borderColor: p.borderMedium,
      child: Row(
        children: [
          const SizedBox(
            width: 48,
            child: LearnIllustration(
              'assets/illustrations/learn/elio_quiz_mascot.svg',
              height: 40,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Question header (Kuis fisika 310:6089): counter, level chip, progress.
class QuizProgressHeader extends StatelessWidget {
  const QuizProgressHeader({
    super.key,
    required this.counter,
    required this.level,
    required this.value,
  });

  final String counter;
  final String level;
  final double value;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                counter,
                style: context.text.bodySmall?.copyWith(color: p.textSecondary),
              ),
            ),
            if (level.isNotEmpty)
              LevelChip(label: level, tone: LearnTone.error),
          ],
        ),
        const SizedBox(height: 12),
        LearnProgressBar(value: value),
      ],
    );
  }
}

/// Answer option with the fixed quiz letter colours (A red, B blue,
/// C green, D yellow with navy text).
class QuizAnswerOption extends StatelessWidget {
  const QuizAnswerOption({
    super.key,
    required this.index,
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.answered,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool answered;
  final VoidCallback onTap;

  static const _fills = [
    ElioTokens.answerRed,
    ElioTokens.answerBlue,
    ElioTokens.answerGreen,
    ElioTokens.answerYellow,
  ];
  static const _onFills = [
    ElioTokens.onAnswerRed,
    ElioTokens.onAnswerBlue,
    ElioTokens.onAnswerGreen,
    ElioTokens.onAnswerYellow,
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final revealCorrect = answered && isCorrect;
    final revealWrong = answered && selected && !isCorrect;
    final edge = revealCorrect
        ? p.primaryText
        : revealWrong
        ? p.errorText
        : selected
        ? p.textPrimary
        : p.borderMedium;
    final fill = revealCorrect
        ? p.primaryText.withValues(alpha: 0.08)
        : revealWrong
        ? p.errorText.withValues(alpha: 0.08)
        : p.surface;
    final letter = String.fromCharCode(65 + index);
    final shape = learnShape(
      learnRadiusL,
      BorderSide(color: edge, width: selected || revealCorrect ? 2 : 1),
    );
    final reduced = ElioMotion.reduced(context);
    // Figma 13 · 28: a wrong pick shakes x ±6 × 3; the right answer pulses
    // once (1.04) when it was not the one chosen; the check pops in.
    final pulse = revealCorrect && !selected && !reduced;
    return ElioShake(
      trigger: revealWrong ? label : null,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: pulse ? 1 : 0),
        duration: ElioMotion.slow,
        builder: (context, v, child) => Transform.scale(
          scale: 1 + 0.04 * math.sin(v * math.pi),
          child: child,
        ),
        child: Semantics(
          button: true,
          selected: selected,
          label:
              l10n.lnAnswerLabel(letter, label) +
              (revealCorrect
                  ? l10n.lnCorrectSuffix
                  : revealWrong
                  ? l10n.lnWrongSuffix
                  : ''),
          excludeSemantics: true,
          child: Material(
            color: fill,
            shape: shape,
            child: InkWell(
              onTap: answered ? null : onTap,
              customBorder: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: _fills[index % 4],
                          shape: learnShape(8),
                        ),
                        child: Text(
                          letter,
                          style: context.text.labelLarge?.copyWith(
                            color: _onFills[index % 4],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(label, style: context.text.bodyMedium),
                      ),
                      if (revealCorrect)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.4, end: 1),
                          duration: reduced ? Duration.zero : ElioMotion.slow,
                          curve: ElioMotion.pop,
                          builder: (context, s, child) =>
                              Transform.scale(scale: s, child: child),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: p.primaryText,
                          ),
                        ),
                      if (revealWrong)
                        Icon(Icons.cancel_rounded, color: p.errorText),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
