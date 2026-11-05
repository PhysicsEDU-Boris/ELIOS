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
              learnRoute<void>(QuizPage(moduleId: intent.moduleId ?? intent.id)),
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
            children: [LearnModulesError(onRetry: onRetry)],
          );
        }
        if (!modulesSnap.hasData) {
          return const LearnListView(children: [LearnHubSkeleton()]);
        }
        final modules = modulesSnap.data!;
        if (modules.isEmpty) {
          return const LearnListView(children: [LearnNoModules()]);
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

class _HubContent extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    final physics = ref.watch(physicsProgressProvider).valueOrNull;
    final lessonsLoaded = videos != null && guides != null;
    final lessons = mergeLessons(guides ?? const [], videos ?? const []);
    final firstLaunch = isFirstLaunch(progress);
    final overall = progress?.weightedProgressFor(
          totalVideos: videos?.length ?? 0,
          totalGuides: guides?.length ?? 0,
          totalQuizModules: modules.length,
        ) ??
        0;
    final started = modules
        .where((m) => moduleProgress(m.id, lessons, progress) > 0)
        .length;
    final continuing = inProgressLessons(lessons, progress);
    final recentModule = continuing.firstOrNull?.moduleId;

    void push(Widget page) => Navigator.of(context).push(learnRoute<void>(page));
    void openLesson(LearnLesson l) => push(LessonPage(lesson: l));

    return LearnListView(
      children: [
        const SizedBox(height: 8),
        if (firstLaunch)
          _Hero(
            title: l10n.lnWelcome,
            body:
                l10n.lnWelcomeBody(binLabel(modules.first.id), lessons.where((l) => l.moduleId == modules.first.id).length),
            buttonLabel: l10n.lnStartModule1,
            onPressed: () => push(ModulePage(module: modules.first)),
          )
        else
          _Hero(
            title: l10n.quizKnowledgeChallenge,
            body: quizSets == null || quizSets!.isEmpty
                ? l10n.lnTestElio
                : l10n.lnQuizzesTest(quizSets!.length),
            buttonLabel: l10n.lnTakeQuiz,
            buttonIcon: Icons.help_outline_rounded,
            onPressed: () => push(
              const QuizPage(),
            ),
          ),
        const SizedBox(height: 16),
        ProgressSummaryCard(
          onTap: () => push(const ProgressPage()),
          title: l10n.lnYourProgress,
          subtitle: started == 0
              ? l10n.lnNoModulesStarted
              : l10n.lnModulesInProgress(started, modules.length),
          value: overall,
          footer: l10n.lnOverall((overall * 100).round()),
        ),
        LearnSectionHeader(
          title: l10n.lnCourseModules,
          actionLabel: l10n.lnSeeAll,
          onAction: () => push(const ProgressPage()),
        ),
        _BinRow(
          modules: modules,
          selectedId: recentModule,
          onTap: (m) => push(ModulePage(module: m)),
        ),
        LearnSectionHeader(
          title: l10n.lnContinueLearning,
          actionLabel: l10n.lnSeeAll,
          onAction: () => push(
            LessonListPage(title: l10n.lnAllLessons, lessons: lessons),
          ),
        ),
        if (!lessonsLoaded)
          const LearnSkeleton(height: 200)
        else if (continuing.isEmpty)
          LearnHintCard(
            text:
                l10n.lnNothingInProgress,
          )
        else
          LearnCarousel(
            children: [
              for (final l in continuing)
                LessonTile(lesson: l, progress: progress, onTap: () => openLesson(l)),
            ],
          ),
        LearnSectionHeader(
          title: l10n.lnWatchLearn,
          actionLabel: videos == null ? null : l10n.lnVideoCount(videos!.length),
          onAction: () => push(
            LessonListPage(
              title: l10n.lnVideos,
              lessons: [for (final v in videos!) LearnLesson.video(v)],
            ),
          ),
        ),
        if (videos == null)
          const LearnSkeleton(height: 150)
        else if (videos!.isEmpty)
          LearnHintCard(text: l10n.lnNoVideos)
        else
          LearnCarousel(
            itemWidth: 180,
            children: [
              for (final v in videos!)
                VideoTile(
                  lesson: LearnLesson.video(v),
                  moduleTitle: moduleTitleFor(modules, v.moduleId),
                  onTap: () => openLesson(LearnLesson.video(v)),
                ),
            ],
          ),
        LearnSectionHeader(
          title: l10n.lnPhysicsSims,
          actionLabel: l10n.lnModuleCount(physicsModules.length),
          onAction: () => push(const SimulationListPage()),
        ),
        LearnCarousel(
          itemWidth: 200,
          children: [
            for (final m in physicsModules)
              SimulationCard(
                canvasAsset: LearnArt.simulation(m.id),
                tag: l10n.lnSimTag(m.tag.split(' · ').first),
                title: m.title,
                minutes: m.durationMinutes,
                done: physics?.viewedModuleIds.contains(m.id.name) ?? false,
                onTap: () => openSimulation(context, ref, m),
              ),
          ],
        ),
        LearnSectionHeader(
          title: l10n.lnGuides,
          actionLabel: l10n.lnSeeAll,
          onAction: () => push(
            LessonListPage(
              title: l10n.lnGuides,
              lessons: [for (final g in guides ?? const <GuideLesson>[]) LearnLesson.guide(g)],
            ),
          ),
        ),
        if (guides == null)
          const LearnSkeleton(height: 160)
        else if (guides!.isEmpty)
          LearnHintCard(text: l10n.lnNoGuides)
        else
          LearnListCard(
            children: [
              for (final g in guides!.take(4))
                LessonRow(
                  lesson: LearnLesson.guide(g),
                  progress: progress,
                  subtitle: '${moduleTitleFor(modules, g.moduleId)} · ${g.description}',
                  onTap: () => openLesson(LearnLesson.guide(g)),
                ),
            ],
          ),
        const SizedBox(height: 24),
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
    this.buttonIcon,
  });

  final String title;
  final String body;
  final String buttonLabel;
  final IconData? buttonIcon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return LearnCard(
      color: p.primary,
      borderColor: p.primary,
      radius: learnRadiusXl,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.headlineLarge?.copyWith(color: p.onPrimary)),
                const SizedBox(height: 8),
                Text(body, style: context.text.bodySmall?.copyWith(color: p.onPrimary)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onPressed,
                  icon: buttonIcon == null ? null : Icon(buttonIcon),
                  label: Text(buttonLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.surface,
                    foregroundColor: p.textPrimary,
                    minimumSize: const Size(48, 48),
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(flex: 2, child: LearnIllustration(LearnArt.mascot, height: 120)),
        ],
      ),
    );
  }
}

class _BinRow extends StatelessWidget {
  const _BinRow({required this.modules, required this.selectedId, required this.onTap});

  final List<ElearningModule> modules;
  final String? selectedId;
  final ValueChanged<ElearningModule> onTap;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final m in modules)
        BinCard(
          label: binLabel(m.id),
          iconAsset: LearnArt.bin(m.id),
          selected: m.id == selectedId,
          onTap: () => onTap(m),
        ),
    ];
    if (cards.length <= 3) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    }
    return LearnCarousel(itemWidth: 120, children: cards);
  }
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
      cover: LearnThumbnail(url: lesson.imageUrl, fallbackAsset: lesson.fallbackArt),
      meta: lesson.meta,
      title: lesson.title,
      leading: lesson.lengthLabel.isEmpty
          ? null
          : LearnMeta(
              icon: lesson.isVideo ? Icons.play_circle_outline_rounded : Icons.description_outlined,
              label: lesson.isVideo ? lesson.lengthLabel : l10n.lnGuide,
            ),
      trailing: switch (state) {
        LessonState.done => LearnMeta(icon: Icons.check_rounded, label: l10n.lnDone, color: p.primaryText),
        LessonState.inProgress => LearnMeta(icon: Icons.trending_up_rounded, label: '$pct%', color: p.primaryText),
        LessonState.start => LearnMeta(icon: Icons.trending_up_rounded, label: l10n.lnNew, color: p.primaryText),
      },
      buttonLabel: showButton ? lesson.actionLabel(progress) : null,
      primaryButton: state != LessonState.done,
    );
  }
}

/// Video card with thumbnail and fallback.
class VideoTile extends StatelessWidget {
  const VideoTile({super.key, required this.lesson, required this.moduleTitle, required this.onTap});

  final LearnLesson lesson;
  final String moduleTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => VideoCard(
    thumbnail: LearnThumbnail(url: lesson.imageUrl, fallbackAsset: lesson.fallbackArt),
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
      icon: lesson.isVideo ? Icons.play_circle_outline_rounded : Icons.description_outlined,
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
    message:
        l10n.lnLoadFailedBody,
    primaryLabel: l10n.cfgTryAgain,
    onPrimary: onRetry,
    secondaryLabel: l10n.lnOpenOffline,
    onSecondary: () => Navigator.of(context).push(learnRoute<void>(const OfflineLessonsPage())),
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
            LearnStateView(asset: LearnArt.stateEmpty, title: l10n.lnNothingHere)
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
                    onTap: () => Navigator.of(context).push(learnRoute<void>(LessonPage(lesson: l))),
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
  const LessonThumbTile({super.key, required this.lesson, required this.progress, required this.onTap});

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
      semanticLabel: '${lesson.isVideo ? l10n.lnVideo : l10n.lnGuide} ${lesson.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LearnCover(
            aspectRatio: lesson.isVideo ? 16 / 9 : 3 / 4,
            badge: lesson.isVideo ? lesson.lengthLabel : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                LearnThumbnail(url: lesson.imageUrl, fallbackAsset: lesson.fallbackArt),
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
                  lesson.isVideo ? lesson.meta.replaceFirst('${l10n.lnVideo} · ', '') : lesson.meta.replaceFirst('${l10n.lnGuide} · ', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(color: p.textSecondary),
                ),
              ),
              if (done) Icon(Icons.check_circle_rounded, size: 16, color: p.primaryText),
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
  late final Future<({List<GuideLesson> guides, List<VideoLesson> videos})> _cached =
      ref.read(elearningContentServiceProvider).fetchCachedLessons();

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
          final lessons = data == null ? <LearnLesson>[] : mergeLessons(data.guides, data.videos);
          return LearnListView(
            children: [
              Text(
                l10n.lnOfflineNote,
                style: context.text.bodySmall?.copyWith(color: context.elio.textSecondary),
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
                            : openGuideLesson(context: context, ref: ref, lesson: l.guide!),
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
