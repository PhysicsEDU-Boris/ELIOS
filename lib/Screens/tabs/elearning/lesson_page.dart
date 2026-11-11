import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/elearning_module.dart';
import '../../../models/guide_lesson.dart';
import '../../../models/quiz_set.dart';
import '../../../models/video_lesson.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../services/elearning_content_service.dart';
import '../../../services/elio_feedback.dart';
import '../../../theme/elio_motion.dart';
import '../../../widgets/learn/learn_l3.dart';
import '../../../widgets/learn/learn_ui.dart';
import 'guides_page.dart';
import 'learn_content.dart';
import 'learn_hub_v3.dart';
import 'module_page.dart';
import 'quiz_page.dart';
import 'video_lessons_page.dart';
import 'package:elio/l10n/l10n.dart';

const _deg = math.pi / 180;

/// Lesson page, Learn L3 (Figma 705:29794 / 707:30456, card 20f). The
/// polaroid player and the bottom button open the existing YouTube player or
/// PDF viewer.
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
  late int _tab = _lesson.isVideo ? 0 : 1;
  bool _playing = false;
  double? _lastValue;

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

  Future<void> _open(LearnLesson lesson) async {
    // Play: the button shrinks into the video and the polaroid straightens.
    setState(() => _playing = true);
    await Future<void>.delayed(ElioMotion.base);
    if (!mounted) return;
    await (lesson.isVideo
        ? openVideoLesson(context, ref, lesson.video!)
        : openGuideLesson(context: context, ref: ref, lesson: lesson.guide!));
    if (mounted) setState(() => _playing = false);
  }

  /// The video reaching the end chimes once (S4 + H-success).
  void _watchEnd(double value) {
    final last = _lastValue;
    _lastValue = value;
    if (last != null && last < 1 && value >= 1) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => elioFeedback(ElioSfx.chime, ElioHaptics.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    final lesson = _lesson;
    final value = lesson.progress(progress);
    _watchEnd(value);
    final pct = (value * 100).round();
    final state = lesson.state(progress);
    final buttonLabel = switch (state) {
      LessonState.start => lesson.isVideo ? l10n.lnPlayVideo : l10n.lnOpenGuide,
      LessonState.inProgress =>
        lesson.isVideo ? l10n.lnContinueVideo(pct) : l10n.lnContinueGuide(pct),
      LessonState.done => lesson.isVideo ? l10n.lnWatchAgain : l10n.lnReadAgain,
    };
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: p.background,
      bottomNavigationBar: _BottomAction(
        label: buttonLabel,
        onPressed: () => _open(lesson),
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
                final module = modulesSnap.data
                    ?.where((m) => m.id == lesson.moduleId)
                    .firstOrNull;
                final position = siblings.indexWhere(
                  (l) => l.id == lesson.id && l.isVideo == lesson.isVideo,
                );
                final quizzes = quizSnap.data ?? const <QuizSet>[];
                final guides = siblings.where((l) => !l.isVideo).toList();
                final videos = siblings.where((l) => l.isVideo).toList();
                final shown = _tab == 0 ? videos : guides;

                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    L3Hero(
                      curveBottom: top + 186,
                      sparkles: const [],
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, top + 4, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const L3BackButton(),
                                const SizedBox(width: 12),
                                if (position >= 0)
                                  Text(
                                    l10n.lnLessonNofM(
                                      position + 1,
                                      siblings.length,
                                    ),
                                    style: context.text.labelLarge?.copyWith(
                                      color: p.onPrimary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _Player(
                              key: ValueKey(lesson.id),
                              lesson: lesson,
                              value: value,
                              playing: _playing,
                              label: buttonLabel,
                              onPlay: () => _open(lesson),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          L3TitleBlock(
                            overline: [
                              lesson.isVideo ? l10n.lnVideo : l10n.lnGuide,
                              if (module != null && module.order > 0)
                                l10n.lnModuleN(module.order),
                              if (lesson.isVideo &&
                                  lesson.video!.level.isNotEmpty)
                                lesson.video!.level,
                            ].join(' · '),
                            title: lesson.title,
                          ),
                          const SizedBox(height: 24),
                          L3StatBubbles(
                            key: ValueKey('stats-${lesson.id}'),
                            stats: [
                              L3Stat(
                                icon: Icons.schedule_rounded,
                                value: lesson.lengthLabel.isEmpty
                                    ? '–'
                                    : lesson.lengthLabel,
                                label: lesson.isVideo
                                    ? l10n.lnDuration
                                    : l10n.lnReading,
                                tone: LearnTone.info,
                              ),
                              L3Stat(
                                icon: Icons.menu_book_outlined,
                                value: position < 0
                                    ? '–'
                                    : l10n.lnPositionOf(
                                        position + 1,
                                        siblings.length,
                                      ),
                                label: l10n.lnLesson,
                                tone: LearnTone.warning,
                              ),
                              L3Stat(
                                icon: Icons.check_rounded,
                                value: '#%',
                                count: pct,
                                label: lesson.isVideo
                                    ? l10n.lnWatched
                                    : l10n.lnRead,
                                tone: LearnTone.success,
                              ),
                            ],
                          ),
                          if (module != null) ...[
                            const SizedBox(height: 24),
                            _ModuleRow(
                              module: module,
                              value: moduleProgress(
                                module.id,
                                siblings,
                                progress,
                              ),
                            ),
                          ],
                          if (lesson.description.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(l10n.lnAbout, style: context.text.titleLarge),
                            const SizedBox(height: 6),
                            Text(
                              lesson.description,
                              style: context.text.bodyMedium?.copyWith(
                                color: p.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final (i, (label, n)) in [
                                  (l10n.lnVideos, videos.length),
                                  (l10n.lnGuides, guides.length),
                                  (l10n.lnQuizShort, quizzes.length),
                                ].indexed) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  LearnTabPill(
                                    label: label,
                                    count: n,
                                    selected: _tab == i,
                                    onTap: () => setState(() => _tab = i),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (!loaded)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: LearnSpinner()),
                            )
                          else if (_tab == 2)
                            quizzes.isEmpty
                                ? LearnHintCard(text: l10n.lnNoQuizModule)
                                : Column(
                                    children: [
                                      for (final q in quizzes)
                                        _PlaylistRow(
                                          title: q.title,
                                          meta: context.l10n.learnQuestionCount(
                                            q.questionCount,
                                          ),
                                          thumb: const LearnIllustration(
                                            LearnArt.quizThumb,
                                            fit: BoxFit.cover,
                                          ),
                                          state: _RowState.open,
                                          icon: Icons.chevron_right_rounded,
                                          onTap: () =>
                                              Navigator.of(context).push(
                                                learnRoute<void>(
                                                  QuizPage(
                                                    moduleId: q.moduleId,
                                                  ),
                                                ),
                                              ),
                                        ),
                                    ],
                                  )
                          else if (shown.isEmpty)
                            LearnHintCard(text: l10n.lnNothingModule)
                          else
                            Column(
                              children: [
                                for (final l in shown)
                                  _PlaylistRow(
                                    key: ValueKey('${l.isVideo}-${l.id}'),
                                    title: l.title,
                                    meta: [
                                      if (l.lengthLabel.isNotEmpty)
                                        l.lengthLabel,
                                      if (l.isVideo &&
                                          l.video!.level.isNotEmpty)
                                        l.video!.level,
                                      if (l.id == lesson.id) l10n.lnPlaying,
                                    ].join(' · '),
                                    thumb: LearnThumbnail(
                                      url: l.imageUrl,
                                      fallbackAsset: l.fallbackArt,
                                    ),
                                    state: l.id == lesson.id
                                        ? _RowState.current
                                        : l.state(progress) == LessonState.done
                                        ? _RowState.done
                                        : _RowState.open,
                                    icon: l.isVideo
                                        ? Icons.play_arrow_rounded
                                        : Icons.description_outlined,
                                    onTap: l.id == lesson.id
                                        ? null
                                        : () => setState(() => _lesson = l),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
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

/// Polaroid player: settles −6° → −2° on enter (spring/soft) while the
/// percentage sticker pops; Play straightens it to 0° (base 220).
class _Player extends StatelessWidget {
  const _Player({
    super.key,
    required this.lesson,
    required this.value,
    required this.playing,
    required this.label,
    required this.onPlay,
  });
  final LearnLesson lesson;
  final double value;
  final bool playing;
  final String label;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final reduced = ElioMotion.reduced(context);
    final frame = Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.borderSubtle),
        boxShadow: l3Shadow,
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: AspectRatio(
              aspectRatio: 334 / 188,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LearnThumbnail(
                    url: lesson.imageUrl,
                    fallbackAsset: lesson.fallbackArt,
                  ),
                  Center(
                    child: AnimatedScale(
                      scale: playing ? 0 : 1,
                      duration: ElioMotion.fast,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: p.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          lesson.isVideo
                              ? Icons.play_arrow_rounded
                              : Icons.description_outlined,
                          size: 34,
                          color: p.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (lesson.isVideo && lesson.lengthLabel.isNotEmpty)
                    Positioned(
                      right: 10,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.textPrimary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          lesson.lengthLabel,
                          style: context.text.labelLarge?.copyWith(
                            color: p.background,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 4,
              color: p.primary,
              backgroundColor: p.borderMedium,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPlay,
      child: GestureDetector(
        onTap: () {
          elioFeedback(ElioSfx.pop, ElioHaptics.light);
          onPlay();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: reduced ? -2 : -6, end: playing ? 0 : -2),
                duration: playing ? ElioMotion.base : ElioMotion.expressive,
                curve: playing ? ElioMotion.standard : ElioMotion.soft,
                builder: (context, a, child) =>
                    Transform.rotate(angle: a * _deg, child: child),
                child: frame,
              ),
            ),
            Positioned(
              right: -10,
              top: 8,
              child: ElioPopIn(
                curve: ElioMotion.pop,
                scale: 0,
                rise: 0,
                delay: const Duration(milliseconds: 120),
                child: L3RoundSticker(
                  label: popSticker(value),
                  size: 60,
                  big: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module, required this.value});
  final ElearningModule module;
  final double value;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    void open() => Navigator.of(
      context,
    ).push(learnRoute<void>(ModulePage(module: module)));
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: p.borderSubtle),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 13, 16, 13),
          child: Row(
            children: [
              Transform.rotate(
                angle: -6 * _deg,
                child: SvgPicture.asset(
                  moduleBuddy(module.id),
                  width: 42,
                  height: 50,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge,
                    ),
                    Text(
                      [
                        if (module.order > 0) l10n.lnModuleN(module.order),
                        if (module.level.isNotEmpty) module.level,
                        '${(value * 100).round()}%',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: captionStyle(context),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: p.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right_rounded, color: p.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RowState { done, current, open }

/// Playlist row (leaf 22/8/22/8). The current row tints and its dot pulses
/// once (spring/pop); Done rows tick in.
class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    super.key,
    required this.title,
    required this.meta,
    required this.thumb,
    required this.state,
    required this.icon,
    required this.onTap,
  });
  final String title, meta;
  final Widget thumb;
  final _RowState state;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final current = state == _RowState.current;
    final shape = RoundedRectangleBorder(
      borderRadius: leafS,
      side: current
          ? BorderSide(color: toneBorder(p, LearnTone.success), width: 2)
          : BorderSide(color: p.borderSubtle),
    );
    final dot = switch (state) {
      _RowState.done => (
        toneBg(p, LearnTone.success),
        p.primaryText,
        Icons.check_rounded,
      ),
      _RowState.current => (p.primary, p.onPrimary, icon),
      _RowState.open => (p.background, p.textPrimary, icon),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: onTap != null,
        selected: current,
        label: '$title, $meta',
        excludeSemantics: true,
        onTap: onTap,
        child: AnimatedContainer(
          duration: ElioMotion.base,
          decoration: ShapeDecoration(
            color: current ? toneBg(p, LearnTone.success) : p.surface,
            shape: shape,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: shape,
              onTap: onTap == null
                  ? null
                  : () {
                      elioFeedback(ElioSfx.pop, ElioHaptics.light);
                      onTap!();
                    },
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(width: 72, height: 48, child: thumb),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelLarge,
                          ),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: captionStyle(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TweenAnimationBuilder<double>(
                      key: ValueKey(state),
                      tween: Tween(
                        begin: state == _RowState.open ? 1 : 0.6,
                        end: 1,
                      ),
                      duration: ElioMotion.slow,
                      curve: ElioMotion.pop,
                      builder: (context, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: dot.$1,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(dot.$3, size: 16, color: dot.$2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom action bar (surface, top corners 28); slides up on enter.
class _BottomAction extends StatelessWidget {
  const _BottomAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ElioPopIn(
      rise: 96,
      scale: 1,
      duration: ElioMotion.base,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: l3Shadow,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: SafeArea(
          top: false,
          child: L3Button(label: label, onPressed: onPressed),
        ),
      ),
    );
  }
}
