import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/l10n.dart';
import '../../../../services/daily_guide_service.dart';
import '../../../../services/guide_progress.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../learn_content.dart';

/// G4 Daily Guides building blocks (Figma 537:2358). Colours come from the ELIOS palette; the only
/// fixed colours are the polaroid shadow and the yellow NEW pill.
const _polaroidShadow = Color(0x24000000);
const _newPill = Color(0xFFFDE68A);
const _onNewPill = Color(0xFF92400E);

/// Image cache for guide photos; tests swap it.
BaseCacheManager? guideImageCache;

/// The guide language: the student's pick, else the app language.
String guideLangOf(WidgetRef ref) =>
    ref.watch(guideProgressProvider.select((s) => s.guideLang)) ??
    (l10n.localeName == 'id' ? 'id' : 'en');

/// Content JSON per (issue, language); null while missing.
final guideContentProvider =
    FutureProvider.family<GuideContent?, (DailyGuide, String)>(
      (ref, key) => ref.read(dailyGuideServiceProvider).content(key.$1, key.$2),
    );

LearnTone topicTone(String? theme) => switch (theme) {
  'water' || 'storm' => LearnTone.info,
  'heat' || 'energy' => LearnTone.warning,
  'waste' => LearnTone.success,
  _ => LearnTone.neutral,
};

Color toneText(BuildContext context, LearnTone t) {
  final p = context.elio;
  return switch (t) {
    LearnTone.success => p.primaryText,
    LearnTone.warning => p.secondaryText,
    LearnTone.error => p.errorText,
    LearnTone.info => p.tertiaryText,
    LearnTone.neutral => p.textSecondary,
  };
}

String topicName(String? theme) => switch (theme) {
  'water' => l10n.g4TopicWater,
  'heat' => l10n.g4TopicHeat,
  'air' => l10n.g4TopicAir,
  'energy' => l10n.g4TopicEnergy,
  'waste' => l10n.g4TopicWaste,
  'storm' => l10n.g4TopicStorm,
  _ => l10n.g4TopicOther,
};

String _topicArt(String? theme) => switch (theme) {
  'air' => 'assets/illustrations/guides/topic_air.png',
  'water' || 'storm' => 'assets/illustrations/guides/topic_water.png',
  'heat' => 'assets/illustrations/guides/topic_heat.png',
  'energy' => 'assets/illustrations/guides/topic_energy.png',
  'waste' => LearnArt.coverB3,
  _ => LearnArt.coverIntro,
};

String guideDate(DailyGuide g, {String pattern = 'd MMM y'}) =>
    DateFormat(pattern, dateLocale).format(g.day);

/// Tilted photo card. The photo is the manifest photo (never the PDF cover); without one the
/// topic illustration sits on the topic tint. Decoded at the shown size x device pixel ratio.
class GuidePolaroid extends StatelessWidget {
  const GuidePolaroid({
    super.key,
    required this.guide,
    required this.width,
    this.caption,
    this.angle = -4,
    this.thumb = false,
  });

  final DailyGuide guide;
  final double width;
  final String? caption;
  final double angle;

  /// Archive cards use photo.thumb; the Today card and the issue hero use photo.src.
  final bool thumb;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final s = width / 86.4;
    final photoW = width - 8.64 * s;
    final photoH = photoW * 110.16 / 77.76;
    final image = GuidePhotoImage(
      guide: guide,
      width: photoW,
      height: photoH,
      thumb: thumb,
      artPadding: 6 * s,
    );
    return Transform.rotate(
      angle: angle * math.pi / 180,
      child: Container(
        width: width,
        padding: EdgeInsets.fromLTRB(4.32 * s, 4.32 * s, 4.32 * s, 5.76 * s),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(4.32 * s),
          boxShadow: [
            BoxShadow(
              color: _polaroidShadow,
              blurRadius: 5.04 * s,
              offset: Offset(0, 4.32 * s),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2.16 * s),
              child: SizedBox(width: photoW, height: photoH, child: image),
            ),
            if (caption != null) ...[
              SizedBox(height: 4.32 * s),
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(
                  fontSize: math.max(7.2 * s, 9),
                  color: p.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The guide's manifest photo (or topic art on the topic tint), decoded at the
/// shown size x device pixel ratio. Used by [GuidePolaroid] and the archive stack.
class GuidePhotoImage extends StatelessWidget {
  const GuidePhotoImage({
    super.key,
    required this.guide,
    required this.width,
    required this.height,
    this.thumb = true,
    this.artPadding = 6,
  });
  final DailyGuide guide;
  final double width, height, artPadding;
  final bool thumb;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final photo = guide.photo;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final Widget image;
    if (photo == null) {
      final art = _topicArt(guide.theme);
      image = ColoredBox(
        color: toneText(
          context,
          topicTone(guide.theme),
        ).withValues(alpha: 0.08),
        child: art.endsWith('.svg')
            ? Padding(
                padding: EdgeInsets.all(artPadding),
                child: LearnIllustration(art),
              )
            : Image.asset(
                art,
                fit: BoxFit.cover,
                cacheWidth: (width * dpr).round(),
                excludeFromSemantics: true,
              ),
      );
    } else {
      // Decode just enough pixels for a sharp cover crop at this size: never blurry, never wasteful.
      final aspect = photo.width / photo.height;
      final coverW = math.max(width, height * aspect);
      image = CachedNetworkImage(
        key: const ValueKey('guide-photo'),
        imageUrl: guide.asset(thumb ? photo.thumb : photo.src).toString(),
        cacheManager: guideImageCache,
        memCacheWidth: (coverW * dpr).round(),
        fit: BoxFit.cover,
        width: width,
        height: height,
        placeholder: (_, _) => ColoredBox(color: p.borderSubtle),
        errorWidget: (_, _, _) =>
            Image.asset(_topicArt(guide.theme), fit: BoxFit.cover),
      );
    }
    return image;
  }
}

/// Small tinted pill ("Water", "+60 XP").
class GuideChip extends StatelessWidget {
  const GuideChip(
    this.label, {
    super.key,
    this.tone = LearnTone.neutral,
    this.fill,
    this.color,
  });
  final String label;
  final LearnTone tone;
  final Color? fill, color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? toneText(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(
        color: fill ?? fg.withValues(alpha: 0.08),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Three stop segments.
class GuideStopBars extends StatelessWidget {
  const GuideStopBars({
    super.key,
    required this.done,
    this.on,
    this.off,
    this.height = 5,
  });
  final int done;
  final Color? on, off;
  final double height;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: i < done
                  ? on ?? context.elio.primary
                  : off ?? context.elio.borderSubtle,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    ],
  );
}

String nextStopLabel(IssueProgress p) => !p.story
    ? l10n.g4StopStory
    : !p.physics
    ? l10n.g4StopPhysics
    : l10n.g4StopMission;

/// Today card 537:2364: newest issue with its polaroid, stops and Continue.
class GuideTodayCard extends ConsumerWidget {
  const GuideTodayCard({super.key, required this.guide, required this.onOpen});
  final DailyGuide guide;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final lang = guide.lang(guideLangOf(ref));
    final progress = ref.watch(
      guideProgressProvider.select((s) => s.of(guide.date)),
    );
    final content = ref.watch(guideContentProvider((guide, lang))).valueOrNull;
    final done = progress.stopsDone;
    final on = p.onPrimary;
    final readTime = content?.text('cover.read_time');
    return Semantics(
      container: true,
      label: l10n.g4TodayLabel(guide.title[lang]!, done),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: p.primary,
          shape: learnShape(learnRadiusXl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    guide.issue == null
                        ? l10n.g4TodaysGuide
                        : l10n.g4TodaysGuideIssue(guide.issue!),
                    style: context.text.labelMedium?.copyWith(
                      color: on,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (done == 0)
                  GuideChip(l10n.g4New, fill: _newPill, color: _onNewPill),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4, right: 12),
                    child: GuidePolaroid(
                      guide: guide,
                      width: 118,
                      caption:
                          content?.text('cover.image_caption') ??
                          guide.photo?.caption[lang],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide.title[lang]!,
                        style: context.text.titleLarge?.copyWith(color: on),
                      ),
                      if (content?.text('cover.subtitle') case final sub?) ...[
                        const SizedBox(height: 6),
                        Text(
                          sub,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(color: on),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (guide.topic[lang] case final t?)
                            GuideChip(t, fill: p.surface, color: p.primaryText),
                          GuideChip(
                            l10n.g4PlusXp(guide.xp.total),
                            tone: LearnTone.warning,
                            fill: p.surface.withValues(alpha: 0.35),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LearnMeta(
                        icon: Icons.schedule_rounded,
                        color: on,
                        label: [?readTime, guideDate(guide)].join(' · '),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GuideStopBars(
              done: done,
              on: on,
              off: on.withValues(alpha: 0.2),
              height: 6,
            ),
            const SizedBox(height: 8),
            Text(
              done == 3
                  ? l10n.g4AllStopsDone
                  : l10n.g4StopsDoneNext(done, nextStopLabel(progress)),
              style: context.text.labelMedium?.copyWith(color: on),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: p.surface,
                  foregroundColor: p.primaryText,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(done == 0 ? l10n.g4StartGuide : l10n.g4ContinueGuide),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Archive card 550:3665 (one tap target).
class GuideArchiveCard extends ConsumerWidget {
  const GuideArchiveCard({
    super.key,
    required this.guide,
    required this.tiltLeft,
    required this.onTap,
  });
  final DailyGuide guide;
  final bool tiltLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final lang = guide.lang(guideLangOf(ref));
    final progress = ref.watch(
      guideProgressProvider.select((s) => s.of(guide.date)),
    );
    final tone = topicTone(guide.theme);
    final complete = progress.stopsDone == 3;
    final date = [
      guideDate(guide, pattern: 'd MMM'),
      if (guide.issue != null) '#${guide.issue}',
    ].join(' · ');
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: l10n.g4ArchiveLabel(
        guide.title[lang]!,
        guideDate(guide),
        progress.stopsDone,
        progress.xp,
      ),
      child: LearnCard(
        onTap: onTap,
        padding: const EdgeInsets.all(10),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: Color.alphaBlend(
                  toneText(context, tone).withValues(alpha: 0.06),
                  p.surfaceRaised,
                ),
                shape: learnShape(14),
              ),
              child: GuidePolaroid(
                guide: guide,
                width: 86.4,
                thumb: true,
                angle: tiltLeft ? -4 : 4,
                caption: guide.photo?.caption[lang],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(
                      color: p.textTertiary,
                    ),
                  ),
                ),
                const Spacer(),
                Flexible(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GuideChip(topicName(guide.theme), tone: tone),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              guide.title[lang]!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium,
            ),
            const SizedBox(height: 8),
            GuideStopBars(done: progress.stopsDone),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Text(
                    l10n.g4StopsOf(progress.stopsDone),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                Flexible(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: complete
                        ? GuideChip(
                            l10n.g4XpDone(progress.xp),
                            tone: LearnTone.success,
                          )
                        : GuideChip(
                            l10n.g4XpOf(progress.xp, guide.xp.total),
                            tone: LearnTone.warning,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Streak card: count, guide XP and this week's 7 days.
class GuideStreakCard extends ConsumerWidget {
  const GuideStreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final s = ref.watch(guideProgressProvider);
    final letters = l10n.g4WeekLetters.split(',');
    return LearnCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: ShapeDecoration(
                  color: p.secondaryText.withValues(alpha: 0.1),
                  shape: learnShape(12),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: p.secondaryText,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.g4StreakDays(s.streak),
                      style: context.text.titleMedium,
                    ),
                    Text(
                      l10n.g4StreakHint,
                      style: context.text.bodySmall?.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmtNum(s.totalXp),
                    style: context.text.titleLarge?.copyWith(
                      color: p.secondaryText,
                    ),
                  ),
                  Text(
                    l10n.g4GuideXp,
                    style: context.text.labelSmall?.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (s.week.length == 7) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (i, (date, status)) in s.week.indexed)
                  _WeekDay(
                    letter: letters.length == 7 ? letters[i] : '',
                    status: status,
                    date: date,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.letter,
    required this.status,
    required this.date,
  });
  final String letter, status, date;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final today = status == 'today';
    final (fill, border, icon) = switch (status) {
      'read' => (p.primary, p.primary, Icons.check_rounded),
      'today' => (
        p.surface,
        p.primaryText,
        Icons.local_fire_department_rounded,
      ),
      'missed' => (p.surfaceRaised, p.surfaceRaised, null),
      _ => (p.surface, p.borderMedium, null),
    };
    return Semantics(
      label:
          '${DateFormat('EEEE', dateLocale).format(DateTime.parse(date))}: ${switch (status) {
            'read' => l10n.g4DayRead,
            'missed' => l10n.g4DayMissed,
            'today' => l10n.g4DayToday,
            _ => l10n.g4DayFuture,
          }}',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            letter,
            style: context.text.labelMedium?.copyWith(
              color: today ? p.primaryText : p.textSecondary,
              fontWeight: today ? FontWeight.w700 : null,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: today ? 2 : 1),
            ),
            child: icon == null
                ? null
                : Icon(
                    icon,
                    size: 18,
                    color: status == 'read' ? p.onPrimary : p.primaryText,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Mini polaroid stack for the Learn hub's "Guide archive" row.
class GuideMiniStack extends StatelessWidget {
  const GuideMiniStack({super.key, required this.guides});
  final List<DailyGuide> guides;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: 56,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (i, g) in guides.take(3).toList().reversed.indexed)
          Positioned(
            left: 4.0 + i * 16,
            top: 2,
            child: GuidePolaroid(
              guide: g,
              width: 34,
              thumb: true,
              angle: (i - 1) * 6.0,
            ),
          ),
      ],
    ),
  );
}

/// Top bar 537:2540: back, title + subtitle, optional action.
class GuideTopBar extends StatelessWidget implements PreferredSizeWidget {
  const GuideTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.leadingIcon = Icons.arrow_back_rounded,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData leadingIcon;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return AppBar(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      titleSpacing: 0,
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: Icon(leadingIcon, color: p.textPrimary),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: p.textSecondary),
            ),
        ],
      ),
      actions: [
        if (action != null)
          Padding(padding: const EdgeInsets.only(right: 12), child: action),
      ],
    );
  }
}

/// Guide language choice (feed pill and issue switch share it): follow the app, English or Indonesian.
Future<void> showGuideLanguageSheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.elio.surface,
      showDragHandle: true,
      builder: (sheet) {
        final current = ref.read(guideProgressProvider).guideLang;
        Widget option(String? value, String label) =>
            RadioListTile<String?>(value: value, title: Text(label));
        return SafeArea(
          child: RadioGroup<String?>(
            groupValue: current,
            onChanged: (v) {
              ref.read(guideProgressProvider.notifier).setGuideLang(v);
              Navigator.of(sheet).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    l10n.g4GuideLanguage,
                    style: sheet.text.titleMedium,
                  ),
                ),
                option(null, l10n.g4FollowApp),
                option('en', l10n.g4LangEn),
                option('id', l10n.g4LangId),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
