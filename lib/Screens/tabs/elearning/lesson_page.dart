import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/elearning_module.dart';
import '../../../models/guide_lesson.dart';
import '../../../models/quiz_set.dart';
import '../../../models/video_lesson.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../services/elearning_content_service.dart';
import '../../../widgets/learn/learn_ui.dart';
import 'guides_page.dart';
import 'learn_content.dart';
import 'quiz_page.dart';
import 'video_lessons_page.dart';
import 'package:elio/l10n/l10n.dart';

/// Lesson page for videos and guides (Figma 310:5798). The sticky button
/// opens the existing YouTube player or PDF viewer.
class LessonPage extends ConsumerStatefulWidget {
  const LessonPage({super.key, required this.lesson});

  final LearnLesson lesson;

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends ConsumerState<LessonPage> {
  late LearnLesson _lesson = widget.lesson;
  late final Stream<List<ElearningModule>> _modules;
  late final Stream<List<GuideLesson>> _guides;
  late final Stream<List<VideoLesson>> _videos;
  late final Stream<List<QuizSet>> _quizSets;
  late int _tab = _lesson.isVideo ? 1 : 0;

  @override
  void initState() {
    super.initState();
    final service = ref.read(elearningContentServiceProvider);
    final id = _lesson.moduleId;
    _modules = service.watchModules();
    _guides = service.watchGuideLessons(moduleId: id);
    _videos = service.watchVideoLessons(moduleId: id);
    _quizSets = service.watchQuizSets(moduleId: id);
  }

  Future<void> _open(LearnLesson lesson) => lesson.isVideo
      ? openVideoLesson(context, ref, lesson.video!)
      : openGuideLesson(context: context, ref: ref, lesson: lesson.guide!);

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    final lesson = _lesson;
    final pct = (lesson.progress(progress) * 100).round();
    final state = lesson.state(progress);
    final buttonLabel = switch (state) {
      LessonState.start => lesson.isVideo ? l10n.lnPlayVideo : l10n.lnOpenGuide,
      LessonState.inProgress => lesson.isVideo ? l10n.lnContinueVideo(pct) : l10n.lnContinueGuide(pct),
      LessonState.done => lesson.isVideo ? l10n.lnWatchAgain : l10n.lnReadAgain,
    };

    return LearnPageScaffold(
      title: l10n.lnLesson,
      bottom: FilledButton.icon(
        onPressed: () => _open(lesson),
        icon: Icon(lesson.isVideo ? Icons.play_circle_outline_rounded : Icons.description_outlined),
        label: Text(buttonLabel),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
      ),
      body: StreamBuilder<List<ElearningModule>>(
        stream: _modules,
        builder: (context, modulesSnap) => StreamBuilder<List<GuideLesson>>(
          stream: _guides,
          builder: (context, guidesSnap) => StreamBuilder<List<VideoLesson>>(
            stream: _videos,
            builder: (context, videosSnap) => StreamBuilder<List<QuizSet>>(
              stream: _quizSets,
              builder: (context, quizSnap) {
                final loaded = guidesSnap.hasData && videosSnap.hasData;
                final siblings = loaded
                    ? mergeLessons(guidesSnap.data!, videosSnap.data!)
                    : const <LearnLesson>[];
                final module = modulesSnap.data?.where((m) => m.id == lesson.moduleId).firstOrNull;
                final position = siblings.indexWhere((l) => l.id == lesson.id && l.isVideo == lesson.isVideo);
                final quizzes = quizSnap.data ?? const <QuizSet>[];
                final guides = siblings.where((l) => !l.isVideo).toList();
                final videos = siblings.where((l) => l.isVideo).toList();
                final shown = _tab == 0 ? guides : videos;

                return LearnListView(
                  children: [
                    LearnCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            button: true,
                            label: buttonLabel,
                            child: GestureDetector(
                              onTap: () => _open(lesson),
                              child: LearnCover(
                                badge: lesson.isVideo ? lesson.lengthLabel : null,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    LearnThumbnail(url: lesson.imageUrl, fallbackAsset: lesson.fallbackArt),
                                    Center(
                                      child: lesson.isVideo
                                          ? const PlayBadge(size: 56)
                                          : Icon(Icons.description_outlined, size: 40, color: p.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            [
                              lesson.isVideo ? l10n.lnVideo : l10n.lnGuide,
                              if (module != null && module.order > 0) l10n.lnModuleN(module.order),
                              if (lesson.isVideo && lesson.video!.level.isNotEmpty) lesson.video!.level,
                            ].join(' · '),
                            style: context.text.labelMedium?.copyWith(color: p.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(lesson.title, style: context.text.titleLarge),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Stat(
                                icon: Icons.schedule_rounded,
                                value: lesson.lengthLabel.isEmpty ? '–' : lesson.lengthLabel,
                                label: lesson.isVideo ? l10n.lnDuration : l10n.lnReading,
                                color: p.tertiaryText,
                              ),
                              _Stat(
                                icon: Icons.menu_book_outlined,
                                value: position < 0 ? '–' : l10n.lnPositionOf(position + 1, siblings.length),
                                label: l10n.lnLesson,
                                color: p.primaryText,
                              ),
                              _Stat(
                                icon: Icons.check_rounded,
                                value: '$pct%',
                                label: lesson.isVideo ? l10n.lnWatched : l10n.lnRead,
                                color: p.primaryText,
                                end: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (module != null)
                      LearnCard(
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 48,
                              child: LearnIllustration(LearnArt.mascot, height: 44),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(module.title, style: context.text.titleSmall),
                                  Text(
                                    [
                                      if (module.order > 0) l10n.lnModuleN(module.order),
                                      if (module.level.isNotEmpty) module.level,
                                      '${(moduleProgress(module.id, siblings, progress) * 100).round()}%',
                                    ].join(' · '),
                                    style: context.text.labelMedium?.copyWith(color: p.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (lesson.description.isNotEmpty) ...[
                      LearnSectionHeader(title: l10n.lnAbout),
                      Text(lesson.description, style: context.text.bodySmall?.copyWith(color: p.textSecondary)),
                    ],
                    const SizedBox(height: 16),
                    LearnSegmented(
                      labels: [
                        l10n.lnGuidesTab(guides.length),
                        l10n.lnVideosTab(videos.length),
                        l10n.lnQuizTab(quizzes.length),
                      ],
                      icons: const [
                        Icons.menu_book_outlined,
                        Icons.play_circle_outline_rounded,
                        Icons.help_outline_rounded,
                      ],
                      selected: _tab,
                      onSelected: (i) => setState(() => _tab = i),
                    ),
                    const SizedBox(height: 12),
                    if (!loaded)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: LearnSpinner()),
                      )
                    else if (_tab == 2)
                      quizzes.isEmpty
                          ? LearnHintCard(text: l10n.lnNoQuizModule)
                          : LearnListCard(
                              children: [
                                for (final q in quizzes)
                                  GuideLessonRow(
                                    icon: Icons.help_outline_rounded,
                                    title: q.title,
                                    subtitle: '${q.questionCount} questions',
                                    onTap: () => Navigator.of(context).push(
                                      learnRoute<void>(QuizPage(moduleId: q.moduleId)),
                                    ),
                                  ),
                              ],
                            )
                    else if (shown.isEmpty)
                      LearnHintCard(text: l10n.lnNothingModule)
                    else
                      LearnListCard(
                        children: [
                          for (final l in shown)
                            GuideLessonRow(
                              icon: l.state(progress) == LessonState.done
                                  ? Icons.check_rounded
                                  : l.isVideo
                                  ? Icons.play_circle_outline_rounded
                                  : Icons.description_outlined,
                              title: l.title,
                              subtitle: [
                                if (l.lengthLabel.isNotEmpty) l.lengthLabel,
                                if (l.id == lesson.id) l10n.lnThisLesson,
                              ].join(' · '),
                              highlighted: l.id == lesson.id,
                              onTap: l.id == lesson.id ? null : () => setState(() => _lesson = l),
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.end = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool end;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        LearnMeta(icon: icon, label: value, color: color),
        Text(label, style: context.text.labelMedium?.copyWith(color: context.elio.textSecondary)),
      ],
    ),
  );
}
