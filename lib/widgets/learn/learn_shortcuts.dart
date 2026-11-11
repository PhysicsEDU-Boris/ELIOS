// Learn shortcuts: the sidebar body on the Learn tab (Figma 571:5567,
// decision 0195). Rows are features of the Learn screen, not app navigation.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../models/guide_lesson.dart';
import '../../models/physics_module.dart';
import '../../models/video_lesson.dart';
import '../../providers/daily_guide_provider.dart';
import '../../providers/learn_shortcut_provider.dart';
import '../../providers/learning_progress_provider.dart';
import '../../services/elio_feedback.dart';
import '../../services/guide_progress.dart';
import '../../theme/elio_motion.dart';
import '../../theme/elio_tokens.dart';
import '../../Screens/tabs/elearning/learn_content.dart';
import '../auth/auth_widgets.dart' show authPalette;
import 'learn_l3.dart';

const _minTap = 48.0;

class LearnShortcutsMenu extends ConsumerStatefulWidget {
  const LearnShortcutsMenu({super.key, required this.onPick});

  /// Called with the tapped row; the caller closes the drawer.
  final ValueChanged<LearnShortcut> onPick;

  @override
  ConsumerState<LearnShortcutsMenu> createState() => _LearnShortcutsMenuState();
}

class _LearnShortcutsMenuState extends ConsumerState<LearnShortcutsMenu> {
  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    int? count<T>(AsyncValue<List<T>> v) => v.valueOrNull?.length;
    final modules = ref.watch(learnModulesProvider);
    final videos = ref.watch(learnVideosProvider);
    final guides = ref.watch(learnGuidesProvider);
    final quizzes = ref.watch(learnQuizSetsProvider);
    final feed = ref.watch(dailyGuideFeedProvider).valueOrNull;
    final today = feed?.guides.firstOrNull;
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    final tab = ref.watch(learnExploreTabProvider);
    final continueOpen = ref.watch(learnContinueOpenProvider);
    final stops = today == null
        ? 0
        : ref.watch(
            guideProgressProvider.select((s) => s.of(today.date).stopsDone),
          );
    final lessons = mergeLessons(
      guides.valueOrNull ?? const <GuideLesson>[],
      videos.valueOrNull ?? const <VideoLesson>[],
    );
    final resume = inProgressLessons(lessons, progress).firstOrNull;
    final overall = progress?.weightedProgressFor(
      totalVideos: count(videos) ?? 0,
      totalGuides: count(guides) ?? 0,
      totalQuizModules: count(modules) ?? 0,
    );

    Widget row(
      LearnShortcut s,
      IconData icon,
      String title, {
      String? subtitle,
      String? badge,
      bool active = false,
    }) => _Row(
      icon: icon,
      title: title,
      subtitle: subtitle,
      badge: badge,
      active: active,
      onTap: () => widget.onPick(s),
    );

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Text(
        text.toUpperCase(),
        style: ElioTokens.overline.copyWith(color: p.textSecondary),
      ),
    );

    final continueRows = [
      if (today != null)
        row(
          LearnShortcut.today,
          Icons.menu_book_outlined,
          l10n.lnTodaysGuide,
          subtitle: l10n.lnGuideStops(today.issue ?? '', stops),
        ),
      if (resume != null)
        row(
          LearnShortcut.resume,
          Icons.play_arrow_rounded,
          l10n.lnJumpBackIn,
          subtitle:
              '${resume.title} · ${(resume.progress(progress) * 100).round()}%',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (continueRows.isNotEmpty) ...[
          _Row(
            icon: Icons.play_circle_outline_rounded,
            title: l10n.lnContinue,
            badge: '${continueRows.length}',
            strong: true,
            filled: continueOpen,
            trailing: Icon(
              continueOpen
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: p.textSecondary,
            ),
            expanded: continueOpen,
            onTap: () => ref.read(learnContinueOpenProvider.notifier).state =
                !continueOpen,
          ),
          if (continueOpen)
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: p.borderSubtle, width: 2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(children: continueRows),
                ),
              ),
            ),
        ],
        label(l10n.lnExplore),
        row(
          LearnShortcut.modules,
          Icons.recycling_rounded,
          l10n.lnModules,
          badge: count(modules)?.toString(),
          active: tab == LearnExploreTab.modules,
        ),
        row(
          LearnShortcut.videos,
          Icons.play_arrow_rounded,
          l10n.lnVideos,
          badge: count(videos)?.toString(),
          active: tab == LearnExploreTab.videos,
        ),
        row(
          LearnShortcut.simulations,
          Icons.science_outlined,
          l10n.lnSimulations,
          badge: '${physicsModules.length}',
          active: tab == LearnExploreTab.simulations,
        ),
        row(
          LearnShortcut.guides,
          Icons.description_outlined,
          l10n.lnPdfGuides,
          badge: count(guides)?.toString(),
          active: tab == LearnExploreTab.guides,
        ),
        label(l10n.lnPractice),
        row(
          LearnShortcut.quiz,
          Icons.help_outline_rounded,
          l10n.quizKnowledgeChallenge,
          subtitle: count(quizzes) == null
              ? null
              : l10n.lnQuizCount(count(quizzes)!),
        ),
        if (today != null)
          row(
            LearnShortcut.miniLab,
            Icons.bolt_rounded,
            l10n.lnMiniLab,
            subtitle: l10n.lnTodaysLab,
          ),
        label(l10n.lnYou),
        row(
          LearnShortcut.progress,
          Icons.trending_up_rounded,
          l10n.lnMyProgress,
          badge: overall == null ? null : '${(overall * 100).round()}%',
        ),
        row(
          LearnShortcut.archive,
          Icons.newspaper_rounded,
          l10n.g4GuideArchive,
          badge: feed == null ? null : '${feed.guides.length}',
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.active = false,
    this.strong = false,
    this.filled = false,
    this.trailing,
    this.expanded,
  });

  final IconData icon;
  final String title;
  final String? subtitle, badge;
  final bool active, strong, filled;
  final Widget? trailing;
  final bool? expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(12),
      side: active ? BorderSide(color: p.borderMedium) : BorderSide.none,
    );
    return Semantics(
      button: true,
      selected: active,
      expanded: expanded,
      label: [title, ?subtitle, ?badge].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Material(
          color: active || filled ? p.background : Colors.transparent,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minTap),
              child: Stack(
                children: [
                  if (active)
                    Positioned(
                      left: 0,
                      top: 10,
                      bottom: 10,
                      child: Container(width: 3, color: p.primaryText),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 22,
                          color: active || strong
                              ? p.primaryText
                              : p.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ElioTokens.bodySmall.copyWith(
                                  color: p.textPrimary,
                                  fontWeight: active || strong
                                      ? FontWeight.w700
                                      : FontWeight.w500,
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
                        if (badge != null)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 1,
                            ),
                            decoration: ShapeDecoration(
                              color: active || strong
                                  ? p.primary
                                  : p.surfaceRaised,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              badge!,
                              style: ElioTokens.caption.copyWith(
                                color: active || strong
                                    ? p.onPrimary
                                    : p.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (trailing != null) ...[
                          const SizedBox(width: 4),
                          trailing!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Learn" title and the reward pills on the curved green header (ELIOS 3:
/// no top bar).
class LearnTabTitle extends StatelessWidget {
  const LearnTabTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.navLearn,
                  style: ElioTokens.body.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.64,
                    color: p.onPrimary,
                  ),
                ),
                // Figma 629:82489: the squiggle under "Learn" draws itself in.
                LearnIntroSquiggle(
                  from: 100,
                  to: 500,
                  width: 72,
                  color: p.onPrimary,
                ),
              ],
            ),
          ),
        ),
        const LearnTopPills(),
      ],
    );
  }
}

/// "1 clover" sticker on the Learn header (Figma 629:82550): the Daily Guides
/// reading streak, shown as clovers (ELIOS 3, decision 0197).
class LearnTopPills extends ConsumerWidget {
  const LearnTopPills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = authPalette(context);
    final streak = ref.watch(guideProgressProvider.select((s) => s.streak));
    // Intro: drops in from above, turning and bouncing (spring/bounce).
    return LearnIntroSlice(
      from: 200,
      to: 1000,
      curve: ElioMotion.bounce,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -36 * (1 - t)),
          child: Transform.rotate(
            angle: -0.45 * (1 - t),
            child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
          ),
        ),
      ),
      child: _cloverSticker(context, p, streak),
    );
  }

  Widget _cloverSticker(BuildContext context, ElioPalette p, int streak) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Semantics(
        label: l10n.g4StreakDays(streak),
        excludeSemantics: true,
        // Card 20: a new clover spins in (0 → 360°, 0.6 → 1.1 → 1), the
        // count flips up, three leaves float off and the sticker wiggles.
        child: RiseWatcher(
          value: streak,
          onRise: (_, _) =>
              elioFeedback(ElioSfx.sparkleShort, ElioHaptics.success),
          builder: (context, bump) => Replay(
            trigger: bump,
            duration: const Duration(milliseconds: 700),
            builder: (context, t, _) {
              final spin = ElioMotion.bounce.transform(t.clamp(0.0, 1.0));
              final wiggle = 4 * math.sin(t * 2 * math.pi) * (1 - t);
              return Transform.rotate(
                angle: -0.06 + wiggle * math.pi / 180,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: p.isDark ? p.background : p.surface,
                        shape: const StadiumBorder(),
                        shadows: const [
                          BoxShadow(
                            color: Color(0x24000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.rotate(
                              angle: t * 2 * math.pi,
                              child: Transform.scale(
                                scale: 0.6 + 0.4 * spin,
                                child: SvgPicture.asset(
                                  'assets/illustrations/learn/clover.svg',
                                  width: 18,
                                  height: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedSwitcher(
                              duration: ElioMotion.base,
                              transitionBuilder: (child, a) => SlideTransition(
                                position: Tween(
                                  begin: const Offset(0, 0.6),
                                  end: Offset.zero,
                                ).animate(a),
                                child: FadeTransition(opacity: a, child: child),
                              ),
                              child: Text(
                                l10n.lnClovers(streak),
                                key: ValueKey(streak),
                                style: ElioTokens.button.copyWith(
                                  color: p.primaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (bump > 0 && t < 1)
                      for (var i = 0; i < 3; i++)
                        Positioned(
                          left: 6.0 + i * 8,
                          top:
                              -24 *
                              ((t * 1.3 - i * 0.11).clamp(0.0, 1.0).toDouble()),
                          child: Opacity(
                            opacity:
                                1 -
                                (t * 1.3 - i * 0.11).clamp(0.0, 1.0).toDouble(),
                            child: SvgPicture.asset(
                              'assets/illustrations/learn/clover.svg',
                              width: 8,
                              height: 8,
                            ),
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
