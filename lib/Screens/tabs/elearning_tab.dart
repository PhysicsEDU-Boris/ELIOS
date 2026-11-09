import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/elearning_module.dart';
import '../../models/guide_lesson.dart';
import '../../models/learning_progress.dart';
import '../../models/physics_module.dart';
import '../../models/quiz_set.dart';
import '../../models/video_lesson.dart';
import '../../providers/learning_progress_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/physics_progress_provider.dart';
import '../../services/elearning_content_service.dart';
import '../../theme/elio_theme.dart';
import '../../widgets/learn/learn_ui.dart';
import 'elearning/guides_page.dart';
import 'elearning/daily_guides_page.dart';
import 'elearning/guides/guide_lab_page.dart';
import 'elearning/learn_hub_v3.dart';
import '../../providers/daily_guide_provider.dart';
import '../../providers/learn_shortcut_provider.dart';
import '../../services/guide_progress.dart' show guideProgressProvider;
import '../../widgets/learn/learn_shortcuts.dart' show LearnTabTitle;
import 'elearning/learn_content.dart';
import 'elearning/lesson_page.dart';
import 'elearning/module_page.dart';
import 'elearning/progress_page.dart';
import 'elearning/quiz_page.dart';
import 'elearning/simulations/simulations_page.dart';
import 'elearning/video_lessons_page.dart';
import 'package:elio/l10n/l10n.dart';

/// Learn hub, L1 v2 (Figma 309:4863). Content streams from Firestore
/// through [elearningContentServiceProvider]; progress from the providers.
class ElearningTab extends ConsumerStatefulWidget {
  final ValueChanged<bool>? onQuizActiveChanged;

  /// Kept for the shell; quizzes now run on their own route.
  final int quizResetGeneration;

  const ElearningTab({
    super.key,
    this.onQuizActiveChanged,
    this.quizResetGeneration = 0,
  });

  @override
  ConsumerState<ElearningTab> createState() => _ElearningTabState();
}

class _ElearningTabState extends ConsumerState<ElearningTab> {
  late LearnStreams _streams;

  @override
  void initState() {
    super.initState();
    _streams = LearnStreams(ref.read(elearningContentServiceProvider));
  }

  void _retry() => setState(
    () => _streams = LearnStreams(ref.read(elearningContentServiceProvider)),
  );

  Future<void> _handleResumeIntent(LearningResumeIntent intent) async {
    final service = ref.read(elearningContentServiceProvider);
    ref.read(learningResumeIntentProvider.notifier).state = null;
    try {
      switch (intent.type) {
        case LearningResumeType.video:
          final videos = await service
              .watchVideoLessons(moduleId: intent.moduleId)
              .first;
          final video = videos.where((v) => v.id == intent.id).firstOrNull;
          if (video != null && mounted) {
            await openVideoLesson(context, ref, video);
          }
        case LearningResumeType.guide:
          final guides = await service
              .watchGuideLessons(moduleId: intent.moduleId)
              .first;
          final guide = guides.where((g) => g.id == intent.id).firstOrNull;
          if (guide != null && mounted) {
            await openGuideLesson(context: context, ref: ref, lesson: guide);
          }
        case LearningResumeType.quiz:
          if (mounted) {
            await Navigator.of(context).push(
              learnRoute<void>(
                QuizPage(moduleId: intent.moduleId ?? intent.id),
              ),
            );
          }
      }
    } catch (error) {
      debugPrint('[Learn] resume failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LearningResumeIntent?>(learningResumeIntentProvider, (_, next) {
      if (next != null) _handleResumeIntent(next);
    });
    final pending = ref.read(learningResumeIntentProvider);
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final intent = ref.read(learningResumeIntentProvider);
        if (mounted && intent != null) _handleResumeIntent(intent);
      });
    }

    return ElioTheme.wrap(
      Builder(
        builder: (context) => ColoredBox(
          color: context.elio.background,
          child: LearnHub(streams: _streams, onRetry: _retry),
        ),
      ),
    );
  }
}

/// The four content streams of the hub, created once per load or retry.
class LearnStreams {
  LearnStreams(ElearningContentService service)
    : modules = service.watchModules(),
      videos = service.watchVideoLessons(),
      guides = service.watchGuideLessons(),
      quizSets = service.watchQuizSets();

  final Stream<List<ElearningModule>> modules;
  final Stream<List<VideoLesson>> videos;
  final Stream<List<GuideLesson>> guides;
  final Stream<List<QuizSet>> quizSets;
}

/// Hub body with its states: skeleton, error, no modules, first launch.
class LearnHub extends ConsumerWidget {
  const LearnHub({super.key, required this.streams, required this.onRetry});

  final LearnStreams streams;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<ElearningModule>>(
      stream: streams.modules,
      builder: (context, modulesSnap) {
        if (modulesSnap.hasError) {
          return LearnListView(
            children: [
              const GuidesHubSection(),
              LearnModulesError(onRetry: onRetry),
            ],
          );
        }
        if (!modulesSnap.hasData) {
          return const LearnListView(
            children: [GuidesHubSection(), LearnHubSkeleton()],
          );
        }
        final modules = modulesSnap.data!;
        if (modules.isEmpty) {
          return const LearnListView(
            children: [GuidesHubSection(), LearnNoModules()],
          );
        }
        return StreamBuilder<List<VideoLesson>>(
          stream: streams.videos,
          builder: (context, videosSnap) => StreamBuilder<List<GuideLesson>>(
            stream: streams.guides,
            builder: (context, guidesSnap) => StreamBuilder<List<QuizSet>>(
              stream: streams.quizSets,
              builder: (context, quizSnap) => _HubContent(
                modules: modules,
                videos: videosSnap.data,
                guides: guidesSnap.data,
                quizSets: quizSnap.data,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HubContent extends ConsumerStatefulWidget {
  const _HubContent({
    required this.modules,
    required this.videos,
    required this.guides,
    required this.quizSets,
  });

  final List<ElearningModule> modules;
  final List<VideoLesson>? videos;
  final List<GuideLesson>? guides;
  final List<QuizSet>? quizSets;

  @override
  ConsumerState<_HubContent> createState() => _HubContentState();
}

/// Learn hub L2 v3 (Figma 570:5147, decision 0195).
class _HubContentState extends ConsumerState<_HubContent> {
  final _exploreKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // A shortcut tapped while the hub was still loading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(learnShortcutProvider);
      if (mounted && s != null) _onShortcut(s);
    });
  }

  void _push(Widget page) => Navigator.of(context).push(learnRoute<void>(page));

  List<LearnLesson> get _lessons =>
      mergeLessons(widget.guides ?? const [], widget.videos ?? const []);

  void _onShortcut(LearnShortcut s) {
    ref.read(learnShortcutProvider.notifier).state = null;
    final today = ref
        .read(dailyGuideFeedProvider)
        .valueOrNull
        ?.guides
        .firstOrNull;
    void tab(LearnExploreTab t) {
      ref.read(learnExploreTabProvider.notifier).state = t;
      final c = _exploreKey.currentContext;
      if (c != null) {
        Scrollable.ensureVisible(
          c,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }

    switch (s) {
      case LearnShortcut.today:
        today == null
            ? _push(const DailyGuidesPage())
            : openGuideIssue(context, today);
      case LearnShortcut.resume:
        final l = inProgressLessons(
          _lessons,
          ref.read(learningProgressProvider).valueOrNull,
        ).firstOrNull;
        _push(
          l == null
              ? ModulePage(module: widget.modules.first)
              : LessonPage(lesson: l),
        );
      case LearnShortcut.modules:
        tab(LearnExploreTab.modules);
      case LearnShortcut.videos:
        tab(LearnExploreTab.videos);
      case LearnShortcut.simulations:
        tab(LearnExploreTab.simulations);
      case LearnShortcut.guides:
        tab(LearnExploreTab.guides);
      case LearnShortcut.quiz:
        _push(const QuizPage());
      case LearnShortcut.miniLab:
        _push(
          today == null ? const DailyGuidesPage() : GuideLabPage(guide: today),
        );
      case LearnShortcut.progress:
        _push(const ProgressPage());
      case LearnShortcut.archive:
        _push(const DailyGuidesPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LearnShortcut?>(learnShortcutProvider, (_, next) {
      if (next != null) _onShortcut(next);
    });
    final modules = widget.modules;
    final videos = widget.videos;
    final guides = widget.guides;
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    final viewed = viewedSimulations(ref);
    final feed = ref.watch(dailyGuideFeedProvider).valueOrNull;
    final today = feed?.guides.firstOrNull;
    final tab = ref.watch(learnExploreTabProvider);
    final lessons = _lessons;
    final lessonsLoaded = videos != null && guides != null;
    final firstLaunch = isFirstLaunch(progress);
    final overall =
        progress?.weightedProgressFor(
          totalVideos: videos?.length ?? 0,
          totalGuides: guides?.length ?? 0,
          totalQuizModules: modules.length,
        ) ??
        0;
    final values = [
      for (final m in modules) moduleProgress(m.id, lessons, progress),
    ];
    final started = values.where((v) => v > 0).length;
    final recentModule = inProgressLessons(
      lessons,
      progress,
    ).firstOrNull?.moduleId;

    List<LearnLesson> recentFirst(List<LearnLesson> list) {
      final active = inProgressLessons(list, progress);
      return [...active, ...list.where((l) => !active.contains(l))];
    }

    ExploreItem lessonItem(LearnLesson l, int i, LearnTone tone) {
      final v = l.progress(progress);
      final resume = i == 0 && l.state(progress) == LessonState.inProgress;
      final st = stickerFor(v, done: l.state(progress) == LessonState.done);
      return ExploreItem(
        title: l.title,
        meta: l.lengthLabel,
        tag: resume
            ? l10n.lnJumpBackIn
            : (l.isVideo ? l10n.lnVideo : l10n.lnGuide),
        art: popArt(url: l.imageUrl, fallback: l.fallbackArt),
        tone: tone,
        progress: v,
        sticker: st.text,
        done: st.done,
        highlight: resume,
        onTap: () => _push(LessonPage(lesson: l)),
      );
    }

    final videoLessons = [
      for (final v in videos ?? const <VideoLesson>[]) LearnLesson.video(v),
    ];
    final guideLessons = [
      for (final g in guides ?? const <GuideLesson>[]) LearnLesson.guide(g),
    ];
    final orderedModules = [
      ...modules.where((m) => m.id == recentModule),
      ...modules.where((m) => m.id != recentModule),
    ];
    final items = switch (tab) {
      LearnExploreTab.modules => [
        for (final (i, m) in orderedModules.indexed)
          () {
            final v = moduleProgress(m.id, lessons, progress);
            final resume = i == 0 && m.id == recentModule;
            final start = i == 0 && firstLaunch;
            final st = stickerFor(v);
            return ExploreItem(
              title: m.title,
              meta: l10n.lnLessonCount(
                lessons.where((l) => l.moduleId == m.id).length,
              ),
              tag: resume
                  ? l10n.lnJumpBackIn
                  : start
                  ? l10n.lnStartHere
                  : l10n.lnModuleN(m.order),
              art: popArt(svg: moduleBuddy(m.id)),
              tone: moduleTone(m.id),
              progress: v,
              sticker: st.text,
              done: st.done,
              highlight: resume || start,
              onTap: () => _push(ModulePage(module: m)),
            );
          }(),
      ],
      LearnExploreTab.videos => [
        for (final (i, l) in recentFirst(videoLessons).indexed)
          lessonItem(l, i, LearnTone.success),
      ],
      LearnExploreTab.simulations => [
        for (final m in physicsModules)
          ExploreItem(
            title: m.title,
            meta: l10n.lnMinutes(m.durationMinutes),
            tag: m.tag.split(' · ').first,
            art: popArt(svg: LearnArt.simulation(m.id), rounded: true),
            tone: LearnTone.info,
            progress: viewed.contains(m.id.name) ? 1 : 0,
            sticker: stickerFor(0, done: viewed.contains(m.id.name)).text,
            done: viewed.contains(m.id.name),
            onTap: () => openSimulation(context, ref, m),
          ),
      ],
      LearnExploreTab.guides => [
        for (final (i, l) in recentFirst(guideLessons).indexed)
          lessonItem(l, i, LearnTone.warning),
      ],
    };
    final seeAll = switch (tab) {
      LearnExploreTab.modules => () => _push(const ProgressPage()),
      LearnExploreTab.videos => () => _push(
        LessonListPage(title: l10n.lnVideos, lessons: videoLessons),
      ),
      LearnExploreTab.simulations => () => _push(const SimulationListPage()),
      LearnExploreTab.guides => () => _push(
        LessonListPage(title: l10n.lnPdfGuides, lessons: guideLessons),
      ),
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        LearnCurvedHeader(
          modules: modules,
          moduleValues: values,
          overall: overall,
          title: firstLaunch ? l10n.lnWelcome : l10n.lnYourProgress,
          subtitle: started == 0
              ? l10n.lnNoModulesStarted
              : l10n.lnModulesInProgress(started, modules.length),
          onOpenProgress: () => _push(const ProgressPage()),
          top: const LearnTabTitle(),
          rewards: l10n.lnGuideRewards(
            ref.watch(guideProgressProvider.select((s) => s.totalXp)),
            l10n.lnClovers(
              ref.watch(guideProgressProvider.select((s) => s.streak)),
            ),
          ),
          ticket: today == null
              ? null
              : GuideTicket(
                  guide: today,
                  onOpen: () => openGuideIssue(context, today),
                ),
        ),
        LearnBubbles(
          items: [
            LearnBubble(
              label: l10n.lnQuizShort,
              asset: LearnArt.mascot,
              tone: LearnTone.info,
              badge: widget.quizSets?.length,
              onTap: () => _push(const QuizPage()),
            ),
            if (today != null)
              LearnBubble(
                label: l10n.lnMiniLab,
                asset: 'assets/illustrations/home/bulb_buddy.svg',
                tone: LearnTone.warning,
                onTap: () => _push(GuideLabPage(guide: today)),
              ),
            LearnBubble(
              label: l10n.lnArchive,
              asset: 'assets/illustrations/learn/clover.svg',
              tone: LearnTone.success,
              badge: feed?.guides.length,
              onTap: () => _push(const DailyGuidesPage()),
            ),
            LearnBubble(
              label: l10n.lnProgressShort,
              asset: 'assets/illustrations/home/tree_lv3.svg',
              tone: LearnTone.error,
              onTap: () => _push(const ProgressPage()),
            ),
          ],
        ),
        KeyedSubtree(
          key: _exploreKey,
          child: ExploreSection(
            subtitle: l10n.lnExploreSub(lessons.length, modules.length),
            counts: {
              LearnExploreTab.modules: modules.length,
              if (videos != null) LearnExploreTab.videos: videos.length,
              LearnExploreTab.simulations: physicsModules.length,
              if (guides != null) LearnExploreTab.guides: guides.length,
            },
            items: items,
            loading:
                !lessonsLoaded &&
                (tab == LearnExploreTab.videos ||
                    tab == LearnExploreTab.guides),
            onSeeAll: seeAll,
          ),
        ),
      ],
    );
  }
}

/// True when the learner has not touched any lesson or quiz yet.
bool isFirstLaunch(LearningProgress? p) =>
    p == null ||
    (p.completedVideoIds.isEmpty &&
        p.completedGuideIds.isEmpty &&
        p.videoLastAccessed.isEmpty &&
        p.guideLastAccessed.isEmpty &&
        p.quizScores.isEmpty &&
        p.completedQuizModules.isEmpty);

String moduleTitleFor(List<ElearningModule> modules, String id) {
  final m = modules.where((m) => m.id == id).firstOrNull;
  return m == null || m.order <= 0 ? binLabel(id) : l10n.lnModuleN(m.order);
}

/// Lesson card for carousels and the module grid.
class LessonTile extends StatelessWidget {
  const LessonTile({
    super.key,
    required this.lesson,
    required this.progress,
    required this.onTap,
    this.showButton = false,
  });

  final LearnLesson lesson;
  final LearningProgress? progress;
  final VoidCallback onTap;
  final bool showButton;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final state = lesson.state(progress);
    final pct = (lesson.progress(progress) * 100).round();
    return LessonCard(
      onTap: onTap,
      cover: LearnThumbnail(
        url: lesson.imageUrl,
        fallbackAsset: lesson.fallbackArt,
      ),
      meta: lesson.meta,
      title: lesson.title,
      leading: lesson.lengthLabel.isEmpty
          ? null
          : LearnMeta(
              icon: lesson.isVideo
                  ? Icons.play_circle_outline_rounded
                  : Icons.description_outlined,
              label: lesson.isVideo ? lesson.lengthLabel : l10n.lnGuide,
            ),
      trailing: switch (state) {
        LessonState.done => LearnMeta(
          icon: Icons.check_rounded,
          label: l10n.lnDone,
          color: p.primaryText,
        ),
        LessonState.inProgress => LearnMeta(
          icon: Icons.trending_up_rounded,
          label: '$pct%',
          color: p.primaryText,
        ),
        LessonState.start => LearnMeta(
          icon: Icons.trending_up_rounded,
          label: l10n.lnNew,
          color: p.primaryText,
        ),
      },
      buttonLabel: showButton ? lesson.actionLabel(progress) : null,
      primaryButton: state != LessonState.done,
    );
  }
}

/// Video card with thumbnail and fallback.
class VideoTile extends StatelessWidget {
  const VideoTile({
    super.key,
    required this.lesson,
    required this.moduleTitle,
    required this.onTap,
  });

  final LearnLesson lesson;
  final String moduleTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => VideoCard(
    thumbnail: LearnThumbnail(
      url: lesson.imageUrl,
      fallbackAsset: lesson.fallbackArt,
    ),
    duration: lesson.lengthLabel,
    title: lesson.title,
    subtitle: moduleTitle,
    onTap: onTap,
  );
}

/// Guide / video row with a done check.
class LessonRow extends StatelessWidget {
  const LessonRow({
    super.key,
    required this.lesson,
    required this.progress,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final LearnLesson lesson;
  final LearningProgress? progress;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final done = lesson.state(progress) == LessonState.done;
    return GuideLessonRow(
      title: lesson.title,
      subtitle: subtitle,
      icon: lesson.isVideo
          ? Icons.play_circle_outline_rounded
          : Icons.description_outlined,
      highlighted: highlighted,
      trailing: done ? const DoneCheck() : null,
      onTap: onTap,
    );
  }
}

/// "Learning modules could not be loaded." (Figma 312:6466).
class LearnModulesError extends StatelessWidget {
  const LearnModulesError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => LearnStateView(
    asset: LearnArt.stateOffline,
    title: l10n.lnLoadFailed,
    message: l10n.lnLoadFailedBody,
    primaryLabel: l10n.cfgTryAgain,
    onPrimary: onRetry,
    secondaryLabel: l10n.lnOpenOffline,
    onSecondary: () => Navigator.of(
      context,
    ).push(learnRoute<void>(const OfflineLessonsPage())),
  );
}

/// "No learning modules available yet." (Figma 312:6660).
class LearnNoModules extends StatelessWidget {
  const LearnNoModules({super.key});

  @override
  Widget build(BuildContext context) => LearnStateView(
    asset: LearnArt.stateEmpty,
    title: l10n.lnNoModules,
    message: l10n.lnNoModulesBody,
  );
}

/// Plain list of lessons ("See all").
class LessonListPage extends ConsumerWidget {
  const LessonListPage({super.key, required this.title, required this.lessons});

  final String title;
  final List<LearnLesson> lessons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    return LearnPageScaffold(
      title: title,
      body: LearnListView(
        children: [
          if (lessons.isEmpty)
            LearnStateView(
              asset: LearnArt.stateEmpty,
              title: l10n.lnNothingHere,
            )
          else
            // Three columns of thumbnails (owner request, 1 Nov).
            LessonCardGrid(
              columns: 3,
              gap: 8,
              children: [
                for (final l in lessons)
                  LessonThumbTile(
                    lesson: l,
                    progress: progress,
                    onTap: () => Navigator.of(
                      context,
                    ).push(learnRoute<void>(LessonPage(lesson: l))),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Compact thumbnail card for the three-column lesson lists.
class LessonThumbTile extends StatelessWidget {
  const LessonThumbTile({
    super.key,
    required this.lesson,
    required this.progress,
    required this.onTap,
  });

  final LearnLesson lesson;
  final LearningProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final done = lesson.state(progress) == LessonState.done;
    return LearnCard(
      onTap: onTap,
      padding: const EdgeInsets.all(6),
      radius: learnRadiusM,
      semanticLabel:
          '${lesson.isVideo ? l10n.lnVideo : l10n.lnGuide} ${lesson.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LearnCover(
            aspectRatio: lesson.isVideo ? 16 / 9 : 3 / 4,
            badge: lesson.isVideo ? lesson.lengthLabel : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                LearnThumbnail(
                  url: lesson.imageUrl,
                  fallbackAsset: lesson.fallbackArt,
                ),
                if (lesson.isVideo) const Center(child: PlayBadge(size: 28)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lesson.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelLarge,
          ),
          const Spacer(),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  lesson.isVideo
                      ? lesson.meta.replaceFirst('${l10n.lnVideo} · ', '')
                      : lesson.meta.replaceFirst('${l10n.lnGuide} · ', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ),
              if (done)
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: p.primaryText,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// All nine simulations as rows.
class SimulationListPage extends ConsumerWidget {
  const SimulationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final physics = ref.watch(physicsProgressProvider).valueOrNull;
    return LearnPageScaffold(
      title: l10n.lnSimulations,
      body: LearnListView(
        children: [
          for (final m in physicsModules) ...[
            SimulationRow(
              icon: m.icon,
              tag: m.tag,
              title: m.title,
              description: m.description,
              formula: m.formula,
              minutes: m.durationMinutes,
              done: physics?.viewedModuleIds.contains(m.id.name) ?? false,
              onTap: () => openSimulation(context, ref, m),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Lessons from the Firestore offline cache (modules error state).
class OfflineLessonsPage extends ConsumerStatefulWidget {
  const OfflineLessonsPage({super.key});

  @override
  ConsumerState<OfflineLessonsPage> createState() => _OfflineLessonsPageState();
}

class _OfflineLessonsPageState extends ConsumerState<OfflineLessonsPage> {
  late final Future<({List<GuideLesson> guides, List<VideoLesson> videos})>
  _cached = ref.read(elearningContentServiceProvider).fetchCachedLessons();

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    return LearnPageScaffold(
      title: l10n.lnOfflineLessons,
      body: FutureBuilder(
        future: _cached,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: LearnSpinner(label: l10n.lnLoadingOffline));
          }
          final data = snap.data;
          final lessons = data == null
              ? <LearnLesson>[]
              : mergeLessons(data.guides, data.videos);
          return LearnListView(
            children: [
              Text(
                l10n.lnOfflineNote,
                style: context.text.bodySmall?.copyWith(
                  color: context.elio.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (lessons.isEmpty)
                LearnStateView(
                  asset: LearnArt.stateOffline,
                  title: l10n.lnNoSaved,
                )
              else
                LearnListCard(
                  children: [
                    for (final l in lessons)
                      LessonRow(
                        lesson: l,
                        progress: progress,
                        subtitle: l.meta,
                        onTap: () => l.isVideo
                            ? openVideoLesson(context, ref, l.video!)
                            : openGuideLesson(
                                context: context,
                                ref: ref,
                                lesson: l.guide!,
                              ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
