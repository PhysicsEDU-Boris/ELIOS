import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/elearning_module.dart';
import '../../../models/guide_lesson.dart';
import '../../../models/physics_module.dart';
import '../../../models/quiz_set.dart';
import '../../../models/video_lesson.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../providers/physics_progress_provider.dart';
import '../../../services/elearning_content_service.dart';
import '../../../widgets/learn/learn_ui.dart';
import '../elearning_tab.dart';
import 'learn_content.dart';
import 'module_page.dart';
import 'quiz_review_page.dart';
import 'package:elio/l10n/l10n.dart';

/// My progress (Figma 310:6126): summaries, module cards, quiz history.
class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});

  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  late LearnStreams _streams = LearnStreams(ref.read(elearningContentServiceProvider));
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return LearnPageScaffold(
      title: l10n.lnMyProgress,
      centerTitle: false,
      body: StreamBuilder<List<ElearningModule>>(
        stream: _streams.modules,
        builder: (context, modulesSnap) {
          if (modulesSnap.hasError) {
            return LearnListView(
              children: [
                LearnModulesError(
                  onRetry: () => setState(
                    () => _streams = LearnStreams(ref.read(elearningContentServiceProvider)),
                  ),
                ),
              ],
            );
          }
          if (!modulesSnap.hasData) {
            return const LearnListView(children: [LearnHubSkeleton()]);
          }
          return StreamBuilder<List<VideoLesson>>(
            stream: _streams.videos,
            builder: (context, videosSnap) => StreamBuilder<List<GuideLesson>>(
              stream: _streams.guides,
              builder: (context, guidesSnap) => StreamBuilder<List<QuizSet>>(
                stream: _streams.quizSets,
                builder: (context, quizSnap) => _body(
                  modulesSnap.data!,
                  videosSnap.data ?? const [],
                  guidesSnap.data ?? const [],
                  quizSnap.data ?? const [],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(
    List<ElearningModule> modules,
    List<VideoLesson> videos,
    List<GuideLesson> guides,
    List<QuizSet> quizSets,
  ) {
    final p = context.elio;
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    final physics = ref.watch(physicsProgressProvider).valueOrNull;
    final lessons = mergeLessons(guides, videos);
    final overall = progress?.weightedProgressFor(
          totalVideos: videos.length,
          totalGuides: guides.length,
          totalQuizModules: modules.length,
        ) ??
        0;
    final values = {for (final m in modules) m.id: moduleProgress(m.id, lessons, progress)};
    final started = values.values.where((v) => v > 0).length;
    final simsDone = physicsModules.where((m) => physics?.viewedModuleIds.contains(m.id.name) ?? false).length;
    final shown = modules.where((m) => _tab == 0 ? values[m.id]! < 1 : values[m.id]! >= 1).toList();
    final reviews = progress?.quizReviews ?? const {};
    final scores = progress?.quizScores ?? const <String, int>{};
    final order = {for (final m in modules) m.id: m.order};
    final quizIds = {...scores.keys, ...reviews.keys}.toList()
      ..sort((a, b) => (order[a] ?? 99).compareTo(order[b] ?? 99));
    QuizSet? setFor(String id) => quizSets.where((q) => q.moduleId == id).firstOrNull;

    if (isFirstLaunch(progress) && simsDone == 0) {
      return LearnListView(
        children: [
          LearnStateView(
            asset: LearnArt.stateEmpty,
            title: l10n.lnNoProgress,
            message: l10n.lnNoProgressBody,
            primaryLabel: modules.isEmpty ? null : l10n.lnStartModule1,
            onPrimary: modules.isEmpty
                ? null
                : () => Navigator.of(context).push(learnRoute<void>(ModulePage(module: modules.first))),
          ),
        ],
      );
    }

    return LearnListView(
      children: [
        LearnSegmented(
          labels: [l10n.lnInProgress, l10n.lnCompleted],
          selected: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 16),
        ProgressSummaryCard(
          title: l10n.lnYourProgress,
          subtitle: l10n.lnModulesInProgress(started, modules.length),
          value: overall,
          footer: l10n.lnOverall((overall * 100).round()),
        ),
        const SizedBox(height: 12),
        ProgressSummaryCard(
          title: l10n.lnSimProgress,
          subtitle: l10n.lnSimsDone(simsDone, physicsModules.length),
          value: simsDone / physicsModules.length,
          footer: l10n.lnPercentDone((simsDone * 100 / physicsModules.length).round()),
        ),
        LearnSectionHeader(title: l10n.lnCourseModules),
        if (shown.isEmpty)
          LearnHintCard(text: _tab == 0 ? l10n.lnAllComplete : l10n.lnNoneComplete)
        else
          LessonCardGrid(
            children: [
              for (final m in shown)
                LessonCard(
                  onTap: () => Navigator.of(context).push(learnRoute<void>(ModulePage(module: m))),
                  cover: LearnThumbnail(url: m.thumbnailUrl, fallbackAsset: LearnArt.cover(m.id)),
                  meta: [
                    if (m.order > 0) l10n.lnModuleN(m.order),
                    if (m.durationMinutes > 0) l10n.lnMinutes(m.durationMinutes),
                  ].join(' · '),
                  title: m.title,
                  footer: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LearnProgressBar(value: values[m.id]!),
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        children: [
                          Text(
                            l10n.lnPercentDone((values[m.id]! * 100).round()),
                            style: context.text.labelMedium?.copyWith(color: p.textSecondary),
                          ),
                          Text(
                            l10n.lnLessonCount(lessons.where((l) => l.moduleId == m.id).length),
                            style: context.text.labelMedium?.copyWith(color: p.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        LearnSectionHeader(title: l10n.lnQuizHistory),
        if (quizIds.isEmpty)
          LearnHintCard(text: l10n.lnQuizHistoryHint)
        else
          LearnListCard(
            children: [
              for (final id in quizIds)
                GuideLessonRow(
                  icon: Icons.help_outline_rounded,
                  title: reviews[id]?.quizTitle ?? setFor(id)?.title ?? l10n.lnBinQuiz(binLabel(id)),
                  subtitle: [
                    if (scores[id] != null) l10n.lnBest(scores[id]!),
                    l10n.lqQuestions(reviews[id]?.totalQuestions ?? setFor(id)?.questionCount ?? 0),
                  ].join(' · '),
                  trailing: LevelChip(
                    label: (reviews[id]?.passed ?? (scores[id] ?? 0) >= 70) ? l10n.rvPassed : l10n.cfgTryAgain,
                    tone: (reviews[id]?.passed ?? (scores[id] ?? 0) >= 70) ? LearnTone.success : LearnTone.warning,
                  ),
                  onTap: reviews[id] == null
                      ? null
                      : () => Navigator.of(context).push(learnRoute<void>(QuizReviewPage(review: reviews[id]!))),
                ),
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
