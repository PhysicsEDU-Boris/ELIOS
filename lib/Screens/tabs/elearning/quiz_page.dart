import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/quiz_question.dart';
import '../../../models/quiz_set.dart';
import '../../../models/learning_progress.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../services/elearning_content_service.dart';
import '../../../widgets/learn/learn_ui.dart';
import 'learn_content.dart';
import 'quiz_review_page.dart';
import 'package:elio/l10n/l10n.dart';

/// Quiz list, question and result (L1 v2). [moduleId] narrows the list to
/// one module's quiz (module page "Quiz").
class QuizPage extends StatelessWidget {
  const QuizPage({super.key, this.moduleId, this.onQuizActiveChanged});

  final String? moduleId;
  final ValueChanged<bool>? onQuizActiveChanged;

  @override
  Widget build(BuildContext context) {
    return LearnPageScaffold(
      title: l10n.lqTitle,
      centerTitle: false,
      body: QuizContent(
        selectedModuleId: moduleId,
        onQuizActiveChanged: onQuizActiveChanged,
      ),
    );
  }
}

class QuizContent extends ConsumerStatefulWidget {
  final String? selectedModuleId;
  final VoidCallback? onClearFilter;
  final ValueChanged<bool>? onQuizActiveChanged;

  const QuizContent({
    super.key,
    this.selectedModuleId,
    this.onClearFilter,
    this.onQuizActiveChanged,
  });

  @override
  ConsumerState<QuizContent> createState() => _QuizContentState();
}

class _QuizContentState extends ConsumerState<QuizContent> {
  ElearningContentService get _service =>
      ref.read(elearningContentServiceProvider);
  QuizSet? _activeQuizSet;
  List<QuizQuestion> _questions = const [];
  int _currentQuestionIndex = 0;
  int _score = 0;
  int? _selectedOptionIndex;
  bool _answered = false;
  bool _isFinished = false;
  bool _isLoadingQuestions = false;
  Object? _questionLoadError;
  final Map<String, int> _selectedAnswersByQuestionId = {};
  QuizReview? _latestReview;

  bool get _quizIsActive => _activeQuizSet != null && !_isFinished;

  bool _hasAttemptedQuiz(QuizSet quizSet) {
    final progress = ref.read(learningProgressProvider).valueOrNull;
    final attempts = progress?.categories[quizSet.moduleId]?.quizAttempts ?? 0;
    return attempts > 0;
  }

  bool _hasCompletedQuiz(QuizSet quizSet) {
    final progress = ref.read(learningProgressProvider).valueOrNull;
    return progress?.completedQuizModules.contains(quizSet.moduleId) ?? false;
  }

  int? _quizScorePercent(QuizSet quizSet) {
    final progress = ref.read(learningProgressProvider).valueOrNull;
    return progress?.quizScores[quizSet.moduleId];
  }

  Future<void> _startQuiz(QuizSet quizSet) async {
    if (_hasAttemptedQuiz(quizSet)) {
      final completed = _hasCompletedQuiz(quizSet);
      final score = _quizScorePercent(quizSet);
      final scoreText = score == null
          ? ''
          : completed
          ? l10n.lqCompletedBest(score)
          : l10n.lqBest(score);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.lqUsedAttempt(scoreText))));
      return;
    }

    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.quizStartTitle),
        content: Text(l10n.lqOnceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.quizNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.quizStart),
          ),
        ],
      ),
    );

    if (shouldStart != true || !mounted) return;

    setState(() {
      _activeQuizSet = quizSet;
      _questions = const [];
      _currentQuestionIndex = 0;
      _score = 0;
      _selectedOptionIndex = null;
      _answered = false;
      _isFinished = false;
      _isLoadingQuestions = true;
      _questionLoadError = null;
      _selectedAnswersByQuestionId.clear();
      _latestReview = null;
    });
    widget.onQuizActiveChanged?.call(true);

    try {
      final questions = await _service.fetchQuizQuestions(quizSet.moduleId);
      if (!mounted || _activeQuizSet != quizSet) return;
      setState(() {
        _questions = questions;
        _isLoadingQuestions = false;
      });
    } catch (error) {
      if (!mounted || _activeQuizSet != quizSet) return;
      setState(() {
        _questionLoadError = error;
        _isLoadingQuestions = false;
      });
    }
  }

  void _selectAnswer(int index) {
    if (_answered || _questions.isEmpty) return;
    final question = _questions[_currentQuestionIndex];

    setState(() {
      _selectedOptionIndex = index;
      _answered = true;
      _selectedAnswersByQuestionId[question.id] = index;
      if (index == question.correctIndex) _score++;
    });
  }

  void _nextQuestion() {
    if (!_answered) return;
    if (_currentQuestionIndex >= _questions.length - 1) {
      final quizSet = _activeQuizSet;
      if (quizSet == null) return;
      final review = _buildQuizReview(
        quizSet: quizSet,
        questions: _questions,
        score: _score,
      );

      setState(() {
        _isFinished = true;
        _latestReview = review;
      });
      widget.onQuizActiveChanged?.call(false);
      unawaited(
        ref
            .read(learningProgressProvider.notifier)
            .updateProgress(
              quizSet.moduleId,
              _score,
              _questions.length,
              quizReview: review,
            ),
      );
      return;
    }

    setState(() {
      _currentQuestionIndex++;
      _selectedOptionIndex = null;
      _answered = false;
    });
  }

  void _backToQuizSets() {
    setState(() {
      _activeQuizSet = null;
      _questions = const [];
      _currentQuestionIndex = 0;
      _score = 0;
      _selectedOptionIndex = null;
      _answered = false;
      _isFinished = false;
      _isLoadingQuestions = false;
      _questionLoadError = null;
      _selectedAnswersByQuestionId.clear();
      _latestReview = null;
    });
    widget.onQuizActiveChanged?.call(false);
  }

  QuizReview _buildQuizReview({
    required QuizSet quizSet,
    required List<QuizQuestion> questions,
    required int score,
  }) {
    final total = questions.length;
    final percent = total <= 0 ? 0 : ((score / total) * 100).round();

    return QuizReview(
      moduleId: quizSet.moduleId,
      quizTitle: quizSet.title,
      score: score,
      totalQuestions: total,
      percent: percent,
      passed: percent >= 70,
      completedAt: DateTime.now(),
      answers: [
        for (final question in questions)
          QuizReviewAnswer(
            questionId: question.id,
            question: question.question,
            imageUrl: question.imageUrl,
            options: question.options,
            correctIndex: question.correctIndex,
            selectedIndex: _selectedAnswersByQuestionId[question.id],
            explanation: question.explanation,
            difficulty: question.difficulty,
            order: question.order,
          ),
      ],
    );
  }

  void _openQuizReview(QuizReview review) {
    Navigator.of(
      context,
    ).push(learnRoute<void>(QuizReviewPage(review: review)));
  }

  Future<void> _showFinishQuizRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.quizFinishFirst),
        content: Text(l10n.lqFinishBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.quizContinue),
          ),
        ],
      ),
    );
  }

  Future<void> _requestBackToQuizSets() async {
    await _showFinishQuizRequiredDialog();
  }

  Future<void> _handlePopAttempt(bool didPop) async {
    if (didPop || !_quizIsActive) return;
    await _showFinishQuizRequiredDialog();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_quizIsActive,
      onPopInvokedWithResult: (didPop, result) => _handlePopAttempt(didPop),
      child: AnimatedSwitcher(
        duration: context.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final quizSet = _activeQuizSet;
    if (quizSet == null) return _buildQuizSetList();

    if (_isLoadingQuestions) {
      return Center(
        key: ValueKey('loading-quiz'),
        child: LearnSpinner(label: l10n.lqLoading),
      );
    }

    if (_questionLoadError != null) {
      return LearnListView(
        key: ValueKey('quiz-error-${quizSet.id}'),
        children: [
          _CenteredMessage(
            icon: Icons.cloud_off_outlined,
            title: l10n.lqLoadFailed,
            message: l10n.lqCheckFirestore,
            actionLabel: l10n.lqBackToQuizzes,
            onAction: _backToQuizSets,
          ),
        ],
      );
    }

    if (_questions.isEmpty) {
      return LearnListView(
        key: ValueKey('empty-${quizSet.id}'),
        children: [
          _CenteredMessage(
            icon: Icons.quiz_outlined,
            title: l10n.lqNotAvailable,
            actionLabel: l10n.lqBackToQuizzes,
            onAction: _backToQuizSets,
          ),
        ],
      );
    }

    if (_isFinished) {
      return _QuizResult(
        key: ValueKey('result-${quizSet.id}'),
        quizSet: quizSet,
        score: _score,
        total: _questions.length,
        review: _latestReview,
        onBack: _backToQuizSets,
        onReview: _openQuizReview,
      );
    }

    return _QuizQuestionView(
      key: ValueKey('question-${quizSet.id}-$_currentQuestionIndex'),
      quizSet: quizSet,
      question: _questions[_currentQuestionIndex],
      questionIndex: _currentQuestionIndex,
      totalQuestions: _questions.length,
      selectedOptionIndex: _selectedOptionIndex,
      answered: _answered,
      onSelectAnswer: _selectAnswer,
      onNext: _nextQuestion,
      onBack: _requestBackToQuizSets,
    );
  }

  Widget _buildQuizSetList() {
    final progress = ref.watch(learningProgressProvider).valueOrNull;
    final p = context.elio;

    return StreamBuilder<List<QuizSet>>(
      key: ValueKey('quiz-sets-${widget.selectedModuleId ?? 'all'}'),
      stream: _service.watchQuizSets(moduleId: widget.selectedModuleId),
      builder: (context, snapshot) {
        return LearnListView(
          children: [
            Text(
              context.l10n.quizKnowledgeChallenge,
              style: context.text.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.lqIntro,
              style: context.text.bodySmall?.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              _CenteredMessage(
                icon: Icons.cloud_off_outlined,
                title: l10n.lqSetsFailed,
              )
            else if (!snapshot.hasData)
              const Column(
                children: [
                  LearnSkeleton(height: 88),
                  SizedBox(height: 12),
                  LearnSkeleton(height: 88),
                ],
              )
            else if (snapshot.data!.isEmpty)
              _CenteredMessage(
                icon: Icons.quiz_outlined,
                title: l10n.lqNoPublished,
              )
            else
              for (final quizSet in snapshot.data!) ...[
                _QuizSetCard.fromProgress(
                  quizSet: quizSet,
                  progress: progress,
                  onStart: () => _startQuiz(quizSet),
                  onReview: _openQuizReview,
                ),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

class _QuizSetCard extends StatelessWidget {
  final QuizSet quizSet;
  final bool attempted;
  final bool completed;
  final int? scorePercent;
  final QuizReview? review;
  final VoidCallback? onTap;
  final VoidCallback? onReview;

  const _QuizSetCard({
    required this.quizSet,
    required this.attempted,
    required this.completed,
    required this.scorePercent,
    required this.review,
    required this.onTap,
    required this.onReview,
  });

  factory _QuizSetCard.fromProgress({
    required QuizSet quizSet,
    required LearningProgress? progress,
    required VoidCallback onStart,
    required ValueChanged<QuizReview> onReview,
  }) {
    final attempted =
        (progress?.categories[quizSet.moduleId]?.quizAttempts ?? 0) > 0;
    final review = progress?.quizReviews[quizSet.moduleId];
    return _QuizSetCard(
      quizSet: quizSet,
      attempted: attempted,
      completed:
          progress?.completedQuizModules.contains(quizSet.moduleId) ?? false,
      scorePercent: progress?.quizScores[quizSet.moduleId],
      review: review,
      onTap: attempted ? null : onStart,
      onReview: review == null ? null : () => onReview(review),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasReview = review != null;
    final statusText = attempted
        ? [
            completed ? l10n.lqCompleted : l10n.lqAttemptUsed,
            if (scorePercent != null) l10n.lqBestScore(scorePercent!),
            if (!hasReview) l10n.lqReviewNew,
          ].join(' · ')
        : [
            l10n.lqQuestions(quizSet.questionCount),
            if (quizSet.level.isNotEmpty) quizSet.level,
            l10n.lqOneAttempt,
          ].join(' · ');
    final buttonLabel = !attempted
        ? l10n.quizStart
        : hasReview
        ? l10n.lqReview
        : completed
        ? l10n.lqDone
        : l10n.lqUsed;
    return QuizCard(
      title: quizSet.title,
      subtitle: statusText,
      buttonLabel: buttonLabel,
      onPressed: !attempted ? onTap : onReview,
    );
  }
}

class _QuizQuestionView extends StatelessWidget {
  final QuizSet quizSet;
  final QuizQuestion question;
  final int questionIndex;
  final int totalQuestions;
  final int? selectedOptionIndex;
  final bool answered;
  final ValueChanged<int> onSelectAnswer;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _QuizQuestionView({
    super.key,
    required this.quizSet,
    required this.question,
    required this.questionIndex,
    required this.totalQuestions,
    required this.selectedOptionIndex,
    required this.answered,
    required this.onSelectAnswer,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final correctIndex = question.correctIndex;
    final hasValidCorrectIndex =
        correctIndex >= 0 && correctIndex < question.options.length;
    final selectedIsCorrect =
        hasValidCorrectIndex && selectedOptionIndex == correctIndex;

    return Column(
      children: [
        Expanded(
          child: LearnListView(
            children: [
              QuizProgressHeader(
                counter: l10n.lqCounter(questionIndex + 1, totalQuestions),
                level: question.difficulty.isEmpty
                    ? quizSet.level
                    : question.difficulty,
                value: (questionIndex + 1) / totalQuestions,
              ),
              const SizedBox(height: 16),
              LearnCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (question.imageUrl.trim().isNotEmpty) ...[
                      _QuizQuestionImage(imageUrl: question.imageUrl),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      question.question,
                      style: context.text.bodyLarge?.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < question.options.length; index++) ...[
                QuizAnswerOption(
                  index: index,
                  label: question.options[index],
                  selected: selectedOptionIndex == index,
                  isCorrect: hasValidCorrectIndex && index == correctIndex,
                  answered: answered,
                  onTap: () => onSelectAnswer(index),
                ),
                const SizedBox(height: 12),
              ],
              if (answered)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    selectedIsCorrect
                        ? (question.explanation.isEmpty
                              ? l10n.qzCorrect
                              : l10n.lqCorrectExpl(question.explanation))
                        : (question.explanation.isEmpty
                              ? l10n.lqNotQuite
                              : l10n.lqNotQuiteExpl(question.explanation)),
                    style: context.text.titleSmall?.copyWith(
                      color: selectedIsCorrect ? p.primaryText : p.errorText,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: Text(context.l10n.quizFinishToExit),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: answered ? onNext : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  questionIndex == totalQuestions - 1
                      ? l10n.lqViewResults
                      : l10n.qzNextQuestion,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizQuestionImage extends StatelessWidget {
  final String imageUrl;

  const _QuizQuestionImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(learnRadiusM),
      child: SizedBox(
        width: double.infinity,
        height: 200,
        child: ColoredBox(
          color: p.surfaceRaised,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, _) => const SizedBox.expand(),
            errorWidget: (_, _, _) => Center(
              child: Text(
                l10n.lqImageUnavailable,
                style: context.text.labelMedium?.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizResult extends StatelessWidget {
  final QuizSet quizSet;
  final int score;
  final int total;
  final QuizReview? review;
  final VoidCallback onBack;
  final ValueChanged<QuizReview> onReview;

  const _QuizResult({
    super.key,
    required this.quizSet,
    required this.score,
    required this.total,
    required this.review,
    required this.onBack,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return LearnListView(
      children: [
        LearnStateView(
          asset: LearnArt.mascot,
          title: quizSet.title,
          message: l10n.lqScored(score, total),
          primaryLabel: l10n.lqBackLower,
          onPrimary: onBack,
          secondaryLabel: review == null ? null : l10n.lqReviewAnswers,
          onSecondary: review == null ? null : () => onReview(review!),
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return LearnCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, color: p.primaryText, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleSmall,
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: p.textSecondary),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
