import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/elearning_module.dart';
import '../../../models/guide_lesson.dart';
import '../../../models/physics_module.dart';
import '../../../models/quiz_set.dart';
import '../../../models/video_lesson.dart';
import '../../../models/waste_category.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../providers/physics_progress_provider.dart';
import '../../../services/elearning_content_service.dart';
import '../../../widgets/learn/learn_ui.dart';
import '../elearning_tab.dart';
import 'learn_content.dart';
import 'lesson_page.dart';
import 'quiz_page.dart';
import 'quiz_review_page.dart';
import 'simulations/simulations_page.dart';

/// One page for every waste module (Figma 309:5927).
class ModulePage extends ConsumerStatefulWidget {
  const ModulePage({super.key, required this.module});

  final ElearningModule module;

  @override
  ConsumerState<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends ConsumerState<ModulePage> {
  late Stream<List<VideoLesson>> _videos;
  late Stream<List<GuideLesson>> _guides;
  late Stream<List<QuizSet>> _quizSets;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final service = ref.read(elearningContentServiceProvider);
    final id = widget.module.id;
    _videos = service.watchVideoLessons(moduleId: id);
    _guides = service.watchGuideLessons(moduleId: id);
    _quizSets = service.watchQuizSets(moduleId: id);
  }

  @override
  Widget build(BuildContext context) {
    return LearnPageScaffold(
      title: binLabel(widget.module.id),
      body: StreamBuilder<List<GuideLesson>>(
        stream: _guides,
        builder: (context, guidesSnap) => StreamBuilder<List<VideoLesson>>(
          stream: _videos,
          builder: (context, videosSnap) => StreamBuilder<List<QuizSet>>(
            stream: _quizSets,
            builder: (context, quizSnap) {
              if (guidesSnap.hasError || videosSnap.hasError) {
                return LearnListView(
                  children: [LearnModulesError(onRetry: () => setState(_load))],
                );
              }
              return _ModuleBody(
                module: widget.module,
                lessons: guidesSnap.hasData && videosSnap.hasData
                    ? mergeLessons(guidesSnap.data!, videosSnap.data!)
                    : null,
                quizSet: quizSnap.data?.firstOrNull,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ModuleBody extends ConsumerWidget {
  const _ModuleBody({required this.module, required this.lessons, required this.quizSet});

  final ElearningModule module;

  /// Null until both lesson streams have a first value.
  final List<LearnLesson>? lessons;
  final QuizSet? quizSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    final physics = ref.watch(physicsProgressProvider).valueOrNull;
    final list = lessons ?? const <LearnLesson>[];
    final value = moduleProgress(module.id, list, progress);
    final examples = wasteCategories
        .where((c) => c.id == module.id)
        .expand((c) => c.examples)
        .map((e) => e.split(' (').first)
        .toList();
    final sim = physicsModules.firstWhere((m) => m.id == relatedSimulation(module.id));
    final review = progress?.quizReviews[module.id];
    final best = progress?.quizScores[module.id];
    final attempted = (progress?.categories[module.id]?.quizAttempts ?? 0) > 0;

    void push(Widget page) => Navigator.of(context).push(learnRoute<void>(page));

    return LearnListView(
      children: [
        LearnCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LearnCover(
                child: LearnThumbnail(
                  url: module.thumbnailUrl,
                  fallbackAsset: LearnArt.cover(module.id),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (module.level.isNotEmpty) LevelChip(label: module.level),
                  if (module.durationMinutes > 0)
                    LearnMeta(icon: Icons.schedule_rounded, label: '${module.durationMinutes} min'),
                  LearnMeta(
                    icon: Icons.menu_book_outlined,
                    label: '${lessons?.length ?? module.lessonCount} lessons',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(module.title, style: context.text.titleLarge),
              if (module.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(module.description, style: context.text.bodySmall?.copyWith(color: p.textSecondary)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Module progress', style: context.text.labelMedium)),
                  Text(
                    '${(value * 100).round()}%',
                    style: context.text.labelLarge?.copyWith(color: p.primaryText),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LearnProgressBar(value: value),
              if (examples.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in examples)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: ShapeDecoration(color: p.surfaceRaised, shape: learnShape(8)),
                        child: Text(e, style: context.text.labelMedium?.copyWith(color: p.textSecondary)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Videos and guides as separate sections (owner request, 1 Nov).
        for (final (title, isVideo, unit) in const [
          ('Videos', true, 'videos'),
          ('Guides', false, 'guides'),
        ]) ...[
          LearnSectionHeader(
            title: title,
            actionLabel: lessons == null
                ? null
                : switch (list.where((l) => l.isVideo == isVideo).length) {
                    1 => '1 ${unit.substring(0, unit.length - 1)}',
                    final n => '$n $unit',
                  },
          ),
          if (lessons == null)
            const LearnSkeleton(height: 220)
          else if (!list.any((l) => l.isVideo == isVideo))
            LearnHintCard(text: 'No $unit in this module yet.')
          else
            LessonCardGrid(
              children: [
                for (final l in list.where((l) => l.isVideo == isVideo))
                  LessonTile(
                    lesson: l,
                    progress: progress,
                    showButton: true,
                    onTap: () => push(LessonPage(lesson: l)),
                  ),
              ],
            ),
        ],
        const LearnSectionHeader(title: 'Simulation for this module'),
        SimulationRow(
          icon: sim.icon,
          tag: sim.tag,
          title: sim.title,
          description: sim.description,
          formula: sim.formula,
          minutes: sim.durationMinutes,
          done: physics?.viewedModuleIds.contains(sim.id.name) ?? false,
          onTap: () => openSimulation(context, ref, sim),
        ),
        LearnSectionHeader(
          title: 'Quiz',
          actionLabel: review == null ? null : 'History',
          onAction: review == null ? null : () => push(QuizReviewPage(review: review)),
        ),
        if (quizSet case final q?)
          QuizCard(
            title: q.title,
            subtitle: [
              '${q.questionCount} questions',
              if (best != null) 'best score $best%',
            ].join(' · '),
            buttonLabel: attempted ? 'Open' : 'Start',
            onPressed: () => push(QuizPage(moduleId: module.id)),
          )
        else
          const LearnHintCard(text: 'No quiz published for this module yet.'),
        const SizedBox(height: 24),
      ],
    );
  }
}
