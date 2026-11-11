import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/elearning_module.dart';
import '../../../models/guide_lesson.dart';
import '../../../models/learning_progress.dart';
import '../../../models/physics_module.dart';
import '../../../models/quiz_set.dart';
import '../../../models/video_lesson.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../providers/physics_progress_provider.dart';
import '../../../services/elearning_content_service.dart';
import '../../../services/elio_feedback.dart';
import '../../../theme/elio_motion.dart';
import '../../../widgets/learn/learn_l3.dart';
import '../../../widgets/learn/learn_ui.dart';
import '../elearning_tab.dart';
import 'learn_content.dart';
import 'learn_hub_v3.dart';
import 'lesson_page.dart';
import 'quiz_page.dart';
import 'quiz_review_page.dart';
import 'simulations/simulations_page.dart';
import 'package:elio/l10n/l10n.dart';

const _deg = math.pi / 180;

/// Module page, Learn L3 (Figma 704:29506 / 707:30078, card 20e).
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
    return Scaffold(
      backgroundColor: context.elio.background,
      body: StreamBuilder<List<GuideLesson>>(
        stream: _guides,
        builder: (context, guidesSnap) => StreamBuilder<List<VideoLesson>>(
          stream: _videos,
          builder: (context, videosSnap) => StreamBuilder<List<QuizSet>>(
            stream: _quizSets,
            builder: (context, quizSnap) {
              if (guidesSnap.hasError || videosSnap.hasError) {
                return SafeArea(
                  child: LearnListView(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: L3BackButton(),
                      ),
                      LearnModulesError(onRetry: () => setState(_load)),
                    ],
                  ),
                );
              }
              return ModuleBody(
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

class ModuleBody extends ConsumerStatefulWidget {
  const ModuleBody({
    super.key,
    required this.module,
    required this.lessons,
    required this.quizSet,
  });

  final ElearningModule module;

  /// Null until both lesson streams have a first value.
  final List<LearnLesson>? lessons;
  final QuizSet? quizSet;

  @override
  ConsumerState<ModuleBody> createState() => _ModuleBodyState();
}

class _ModuleBodyState extends ConsumerState<ModuleBody> {
  int? _lastDone;

  void _push(Widget page) => Navigator.of(context).push(learnRoute<void>(page));

  /// A lesson that just turned Done chimes; the whole module at 100 % sparkles.
  void _celebrate(int done, int total) {
    final last = _lastDone;
    _lastDone = done;
    if (last == null || done <= last || total == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (done >= total) {
        elioFeedback(ElioSfx.sparkle, ElioHaptics.celebrate);
      } else {
        elioFeedback(ElioSfx.chime, ElioHaptics.success);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final module = widget.module;
    final lessons = widget.lessons;
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    final physics = ref.watch(physicsProgressProvider).valueOrNull;
    final list = lessons ?? const <LearnLesson>[];
    final value = moduleProgress(module.id, list, progress);
    final done = list
        .where((l) => l.state(progress) == LessonState.done)
        .length;
    if (lessons != null) _celebrate(done, list.length);
    final next = list.indexWhere((l) => l.state(progress) != LessonState.done);
    final nextStarted =
        next >= 0 && list[next].state(progress) == LessonState.inProgress;
    final examples = switch (module.id) {
      'organic' => context.l10n.catExamplesOrganic,
      'inorganic' => context.l10n.catExamplesInorganic,
      'hazardous' => context.l10n.catExamplesHazardous,
      _ => '',
    }.split('; ').where((e) => e.isNotEmpty).toList();
    final sim = physicsModules.firstWhere(
      (m) => m.id == relatedSimulation(module.id),
    );
    final simDone = physics?.viewedModuleIds.contains(sim.id.name) ?? false;
    final review = progress?.quizReviews[module.id];
    final best = progress?.quizScores[module.id];
    final attempted = (progress?.categories[module.id]?.quizAttempts ?? 0) > 0;
    final top = MediaQuery.paddingOf(context).top;
    final pct = (value * 100).round();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        L3Hero(
          curveBottom: top + 256,
          radiusY: 300,
          bubble: 170,
          sparkles: [(232, top + 48, 14), (150, top + 18, 9)],
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, top + 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: L3BackButton(),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _HeroTitle(module: module, count: list.length),
                      ),
                    ),
                    _HeroBuddy(moduleId: module.id, pct: pct),
                  ],
                ),
                if (module.level.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: L3Sticker(label: module.level),
                    ),
                  ),
                const SizedBox(height: 18),
                _ModuleTicket(
                  description: module.description,
                  done: done,
                  total: list.length,
                  value: value,
                  button: lessons == null || next < 0
                      ? null
                      : nextStarted
                      ? l10n.lnContinueLessonN(next + 1)
                      : l10n.lnStartLessonN(next + 1),
                  onButton: next < 0
                      ? null
                      : () => _push(LessonPage(lesson: list[next])),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (examples.isNotEmpty) ...[
                Text(
                  l10n.lnWhatGoesIn(module.id),
                  style: context.text.titleLarge,
                ),
                const SizedBox(height: 10),
                _Tags(examples: examples),
                const SizedBox(height: 32),
              ],
              L3SectionTitle(
                title: l10n.lnLessons,
                action: lessons == null
                    ? null
                    : l10n.lnLessonCount(list.length),
              ),
              const SizedBox(height: 14),
              if (lessons == null)
                const LearnSkeleton(height: 233)
              else if (list.isEmpty)
                LearnHintCard(text: l10n.lnNothingModule)
              else
                _LessonGrid(
                  lessons: list,
                  progress: progress,
                  onOpen: (l) => _push(LessonPage(lesson: l)),
                ),
              const SizedBox(height: 32),
              L3SectionTitle(title: l10n.lnSimulation),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ContentPopCard(
                    kind: PopKind.simulation,
                    large: true,
                    tag: l10n.lnSimulation,
                    title: sim.title,
                    meta:
                        '${sim.tag.split(' · ').first} · '
                        '${l10n.lnMinutes(sim.durationMinutes)}',
                    cover: LearnIllustration(
                      LearnArt.simulation(sim.id),
                      fit: BoxFit.cover,
                    ),
                    progress: simDone ? 1 : 0,
                    sticker: popSticker(0, done: simDone),
                    onTap: () => openSimulation(context, ref, sim),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sim.description,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FormulaChip(formula: sim.formula),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              L3SectionTitle(
                title: l10n.lqTitle,
                squiggle: 64,
                action: review == null ? null : l10n.navHistory,
                onAction: review == null
                    ? null
                    : () => _push(QuizReviewPage(review: review)),
              ),
              const SizedBox(height: 14),
              if (widget.quizSet case final q?)
                _QuizTicket(
                  title: q.title,
                  meta: [
                    l10n.lqQuestions(q.questionCount),
                    if (best != null) l10n.lqBestScore(best),
                  ].join(' · '),
                  button: attempted ? l10n.lnOpen : l10n.lnStart,
                  onTap: () => _push(QuizPage(moduleId: module.id)),
                )
              else
                LearnHintCard(text: l10n.lnNoQuizPublished),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({required this.module, required this.count});
  final ElearningModule module;
  final int count;

  @override
  Widget build(BuildContext context) {
    final on = context.elio.onPrimary;
    final meta = captionStyle(
      context,
      on,
    ).copyWith(fontSize: 14, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        L3TitleBlock(
          overline: [
            if (module.order > 0) l10n.lnModuleN(module.order),
            binLabel(module.id),
          ].join(' · '),
          title: module.title,
          overlineColor: on,
          titleColor: on,
          squiggleColor: on,
          squiggle: 120,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          children: [
            if (module.durationMinutes > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: on),
                  const SizedBox(width: 3),
                  Text(l10n.lnMinutes(module.durationMinutes), style: meta),
                ],
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined, size: 16, color: on),
                const SizedBox(width: 3),
                Text(
                  l10n.lnLessonCount(count == 0 ? module.lessonCount : count),
                  style: meta,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Bin buddy pops out of the header (spring/pop, −6°), then the sticker
/// bounces in (spring/bounce, +10°).
class _HeroBuddy extends StatelessWidget {
  const _HeroBuddy({required this.moduleId, required this.pct});
  final String moduleId;
  final int pct;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 118,
    height: 130,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          top: 12,
          child: ElioPopIn(
            curve: ElioMotion.pop,
            scale: 0.6,
            child: Transform.rotate(
              angle: -6 * _deg,
              child: SvgPicture.asset(
                moduleBuddy(moduleId),
                width: 104,
                height: 124,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        Positioned(
          right: -6,
          top: -4,
          child: ElioPopIn(
            delay: const Duration(milliseconds: 200),
            curve: ElioMotion.bounce,
            scale: 0,
            rise: 0,
            child: L3RoundSticker(label: '$pct%', angle: 10, big: true),
          ),
        ),
      ],
    ),
  );
}

/// Module ticket: description, notched tear line, progress, Continue.
class _ModuleTicket extends StatelessWidget {
  const _ModuleTicket({
    required this.description,
    required this.done,
    required this.total,
    required this.value,
    required this.button,
    required this.onButton,
  });
  final String description;
  final int done, total;
  final double value;
  final String? button;
  final VoidCallback? onButton;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final pct = (value * 100).round();
    return Container(
      decoration: ShapeDecoration(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: p.borderSubtle),
        ),
        shadows: l3Shadow,
      ),
      padding: const EdgeInsets.fromLTRB(19, 19, 19, 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: context.text.bodySmall?.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(height: 24, child: _TearLine()),
          const SizedBox(height: 4),
          Semantics(
            label: '${l10n.lnModuleProgressDone(done, total)}, $pct%',
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.lnModuleProgressDone(done, total),
                    style: context.text.labelLarge,
                  ),
                ),
                ElioCountUp(
                  value: pct,
                  duration: ElioMotion.slow,
                  builder: (context, v) => Text(
                    '$v%',
                    style: context.text.labelLarge?.copyWith(
                      color: p.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElioAfterFirstFrame(
            builder: (context, ready) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ready ? value : 0),
              duration: ElioMotion.slow,
              curve: ElioMotion.standard,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  color: p.primary,
                  backgroundColor: p.background,
                ),
              ),
            ),
          ),
          if (button != null) ...[
            const SizedBox(height: 12),
            L3Button(label: button!, onPressed: onButton),
          ],
        ],
      ),
    );
  }
}

/// Dashed tear line with a bg-coloured notch at each edge.
class _TearLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _DashPainter(p.borderMedium)),
        ),
        for (final left in [true, false])
          Positioned(
            left: left ? -31 : null,
            right: left ? null : -31,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: p.background,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (double x = 0; x < s.width; x += 9) {
      canvas.drawLine(
        Offset(x, s.height / 2),
        Offset(math.min(x + 5, s.width), s.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => o.color != color;
}

/// Tilted tag stickers in chip tones; they drop in one by one (rule 7).
class _Tags extends StatelessWidget {
  const _Tags({required this.examples});
  final List<String> examples;

  static const _angles = [-3.0, 2.0, -2.0, 3.0, -3.0];
  static const _tones = [LearnTone.success, LearnTone.warning, LearnTone.info];

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Wrap(
      spacing: 8,
      runSpacing: 14,
      children: [
        for (final (i, e) in examples.indexed)
          ElioPopIn(
            index: i,
            child: Transform.rotate(
              angle: _angles[i % _angles.length] * _deg,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: ShapeDecoration(
                  color: toneBg(p, _tones[i % 3]),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  e,
                  style: context.text.labelLarge?.copyWith(
                    color: toneFg(p, _tones[i % 3]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Two-column grid of small pop cards; rows pop in 60 ms apart (max 6).
class _LessonGrid extends StatelessWidget {
  const _LessonGrid({
    required this.lessons,
    required this.progress,
    required this.onOpen,
  });
  final List<LearnLesson> lessons;
  final LearningProgress? progress;
  final ValueChanged<LearnLesson> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = (box.maxWidth - 14) / 2;
      return Wrap(
        spacing: 14,
        runSpacing: 22,
        children: [
          for (final (i, l) in lessons.indexed)
            SizedBox(
              width: w,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: ElioPopIn(
                  index: i ~/ 2,
                  stagger: const Duration(milliseconds: 60),
                  curve: ElioMotion.pop,
                  scale: 0.6,
                  child: ContentPopCard(
                    kind: l.isVideo ? PopKind.video : PopKind.guide,
                    tag: l.isVideo ? l10n.lnVideo : l10n.lnGuide,
                    title: l.title,
                    meta: [
                      l.isVideo ? l.lengthLabel : l10n.lnPartN(i + 1),
                      if (l.state(progress) == LessonState.done)
                        l10n.lnDone
                      else if (l.progress(progress) > 0)
                        l10n.lnPctWatched((l.progress(progress) * 100).round()),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    cover: LearnThumbnail(
                      url: l.imageUrl,
                      fallbackAsset: l.fallbackArt,
                    ),
                    progress: l.progress(progress),
                    sticker: popSticker(
                      l.progress(progress),
                      done: l.state(progress) == LessonState.done,
                    ),
                    onTap: () => onOpen(l),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Quiz ticket: leaf card in the info tint with the Thinking robot buddy.
class _QuizTicket extends StatelessWidget {
  const _QuizTicket({
    required this.title,
    required this.meta,
    required this.button,
    required this.onTap,
  });
  final String title, meta, button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      decoration: ShapeDecoration(
        color: toneBg(p, LearnTone.info),
        shape: const RoundedRectangleBorder(borderRadius: leafL),
      ),
      padding: const EdgeInsets.fromLTRB(21, 14, 14, 14),
      child: Row(
        children: [
          Transform.rotate(
            angle: -6 * _deg,
            child: const RobotBuddy(mood: RobotMood.thinking, height: 64),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleLarge),
                Text(meta, style: captionStyle(context)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: L3Button(
              label: button,
              onPressed: onTap,
              height: 48,
              chevron: false,
            ),
          ),
        ],
      ),
    );
  }
}
