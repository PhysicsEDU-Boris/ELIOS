import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/quiz/physics_quiz_state.dart';
import '../../../../models/physics_module.dart';
import '../../../../services/elio_feedback.dart';
import '../../../../theme/elio_motion.dart';
import '../../../../widgets/learn/learn_l3.dart';
import '../../../../widgets/learn/learn_ui.dart';
import 'package:elio/l10n/l10n.dart';

const _deg = math.pi / 180;

/// Kuis fisika, Learn L3 (Figma 707:29999 / 707:30807, card 20h).
class PhysicsQuizPage extends ConsumerWidget {
  const PhysicsQuizPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(physicsQuizProvider);
    final notifier = ref.read(physicsQuizProvider.notifier);
    final finished = !quizState.results.values.any(
      (r) => r == QuizResult.unanswered,
    );
    final index = finished
        ? quizState.total
        : physicsQuizQuestions.indexWhere(
            (q) => quizState.results[q.moduleId] == QuizResult.unanswered,
          );

    return Scaffold(
      backgroundColor: context.elio.background,
      body: Column(
        children: [
          _QuizHeader(index: index, total: quizState.total),
          Expanded(
            child: finished
                ? _QuizResult(
                    score: quizState.score,
                    total: quizState.total,
                    onRetake: notifier.randomizeAll,
                  )
                : _PhysicsQuestionView(
                    // A key per question resets the view (and slides it in).
                    key: ValueKey(index),
                    question: physicsQuizQuestions[index],
                    questionData: quizState
                        .currentData[physicsQuizQuestions[index].moduleId]!,
                    isLast: index == quizState.total - 1,
                    onNext: (i) => notifier.answer(
                      physicsQuizQuestions[index].moduleId,
                      i,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Green header: Back, title with squiggle, counter, tilted level sticker
/// and one segment per question (current is wider, filled with surface).
class _QuizHeader extends StatelessWidget {
  const _QuizHeader({required this.index, required this.total});
  final int index, total;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final top = MediaQuery.paddingOf(context).top;
    final done = index >= total;
    return L3Hero(
      curveBottom: top + 106,
      radiusY: 250,
      bubble: 140,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, top + 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const L3BackButton(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done ? l10n.pqResultsTitle : l10n.pqTitle,
                        style: context.text.titleLarge?.copyWith(
                          color: p.onPrimary,
                        ),
                      ),
                      LearnSquiggle(width: 96, color: p.onPrimary),
                      if (!done)
                        Text(
                          l10n.pqCounter(index + 1, total),
                          style: captionStyle(context, p.onPrimary),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: L3Sticker(
                    label: l10n.pqAdvanced,
                    angle: -5,
                    color: p.errorText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label: done ? null : l10n.pqCounter(index + 1, total),
              child: Row(
                children: [
                  for (var i = 0; i < total; i++)
                    Expanded(
                      flex: i == index ? 64 : 42,
                      child: AnimatedContainer(
                        duration: ElioMotion.slow,
                        curve: ElioMotion.soft,
                        height: 8,
                        margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                        decoration: BoxDecoration(
                          color: i <= index ? p.surface : p.primaryHover,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhysicsQuestionView extends StatefulWidget {
  const _PhysicsQuestionView({
    super.key,
    required this.question,
    required this.questionData,
    required this.isLast,
    required this.onNext,
  });
  final PhysicsQuizQuestion question;
  final Map<String, num> questionData;
  final bool isLast;
  final ValueChanged<int> onNext;

  @override
  State<_PhysicsQuestionView> createState() => _PhysicsQuestionViewState();
}

class _PhysicsQuestionViewState extends State<_PhysicsQuestionView> {
  int? _selected;
  bool _checked = false;
  late final List<String> _options = widget.question.options(
    widget.questionData,
  );

  bool get _right => _selected == widget.question.correctIndex;

  void _pick(int i) {
    if (_checked) return;
    setState(() => _selected = i);
    elioFeedback(ElioSfx.tick, ElioHaptics.select);
  }

  void _check() {
    setState(() => _checked = true);
    _right
        ? elioFeedback(ElioSfx.chime, ElioHaptics.success)
        : elioFeedback(ElioSfx.knock, ElioHaptics.error);
  }

  String _overline() {
    final id = PhysicsModuleId.values
        .where((m) => m.name == widget.question.moduleId)
        .firstOrNull;
    final m = physicsModules.where((m) => m.id == id).firstOrNull;
    return m?.title ?? l10n.pqTitle;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final mood = !_checked
        ? RobotMood.thinking
        : _right
        ? RobotMood.excited
        : RobotMood.sad;
    // Each question slides in from the right (base 220, emphasized).
    return ElioSlideIn(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 200),
                      padding: const EdgeInsets.fromLTRB(21, 19, 21, 56),
                      decoration: ShapeDecoration(
                        color: p.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: leafL,
                          side: BorderSide(color: p.borderSubtle),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _overline().toUpperCase(),
                            style: context.text.labelSmall?.copyWith(
                              color: p.primaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.question.prompt(widget.questionData),
                            style: context.text.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: -20,
                      child: ElioPopIn(
                        curve: ElioMotion.pop,
                        scale: 0.4,
                        delay: ElioMotion.fast,
                        child: Transform.rotate(
                          angle: -8 * _deg,
                          child: RobotBuddy(mood: mood, height: 80),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < _options.length; i++) ...[
                  QuizAnswerOption(
                    index: i,
                    label: _options[i],
                    selected: _selected == i,
                    isCorrect: i == widget.question.correctIndex,
                    answered: _checked,
                    minHeight: 64,
                    onTap: () => _pick(i),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_checked) ...[
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _right ? l10n.qzCorrect : l10n.pqWrong,
                      style: context.text.titleSmall?.copyWith(
                        color: _right ? p.primaryText : p.errorText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: ShapeDecoration(
                      color: p.surfaceRaised,
                      shape: const RoundedRectangleBorder(borderRadius: leafS),
                    ),
                    child: Text(
                      widget.question.workedSolution(widget.questionData),
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  L3Button(
                    // Check plays its own chime / knock.
                    feedback: _checked,
                    label: !_checked
                        ? l10n.lnCheckAnswer
                        : widget.isLast
                        ? l10n.pqSeeResults
                        : l10n.pqNext,
                    onPressed: _selected == null
                        ? null
                        : _checked
                        ? () => widget.onNext(_selected!)
                        : _check,
                  ),
                  const SizedBox(height: 10),
                  AnimatedOpacity(
                    duration: ElioMotion.fast,
                    opacity: _selected == null ? 1 : 0,
                    child: Text(
                      l10n.lnPickToContinue,
                      style: captionStyle(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slides its child in from the right once (base 220, emphasized).
class ElioSlideIn extends StatelessWidget {
  const ElioSlideIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ElioMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: ElioMotion.base,
      curve: ElioMotion.emphasized,
      builder: (context, t, child) => Opacity(
        opacity: 1 - t,
        child: FractionalTranslation(
          translation: Offset(0.25 * t, 0),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Results: the buddy is Excited and the score counts up; S9 + celebrate.
class _QuizResult extends StatefulWidget {
  const _QuizResult({
    required this.score,
    required this.total,
    required this.onRetake,
  });
  final int score;
  final int total;
  final VoidCallback onRetake;

  @override
  State<_QuizResult> createState() => _QuizResultState();
}

class _QuizResultState extends State<_QuizResult> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => elioFeedback(ElioSfx.sparkle, ElioHaptics.celebrate),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    children: [
      const Center(
        child: ElioPopIn(
          curve: ElioMotion.pop,
          scale: 0.4,
          child: RobotBuddy(mood: RobotMood.excited, height: 120),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        l10n.pqDone,
        textAlign: TextAlign.center,
        style: context.text.displaySmall,
      ),
      const SizedBox(height: 8),
      ElioCountUp(
        value: widget.score,
        builder: (context, v) => Text(
          l10n.pqScore(v, widget.total),
          textAlign: TextAlign.center,
          style: context.text.titleLarge?.copyWith(
            color: context.elio.primaryText,
          ),
        ),
      ),
      const SizedBox(height: 32),
      L3Button(label: l10n.gradeTryAgain, onPressed: widget.onRetake),
      const SizedBox(height: 12),
      L3Button(
        label: l10n.pqBackMenu,
        secondary: true,
        chevron: false,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ],
  );
}
