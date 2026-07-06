import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/quiz_question.dart';
import '../../../models/quiz_set.dart';
import '../../../models/learning_progress.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../services/elearning_content_service.dart';
import '../../../widgets/elio_learning_app_bar.dart';
import 'quiz_review_page.dart';

const _background = Color(0xFFF7FAF6);
const _primary = Color(0xFF004F38);
const _ink = Color(0xFF181D1A);
const _muted = Color(0xFF3F4943);
const _border = Color(0xFFBEC9C2);
const _surface = Color(0xFFEBEFEA);
const _success = Color(0xFF059669);
const _error = Color(0xFFBA1A1A);

class QuizPage extends StatelessWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: const ElioLearningAppBar(
        title: 'Quiz',
        showBack: true,
        backgroundColor: _background,
      ),
      body: const QuizContent(),
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
  final ElearningContentService _service = ElearningContentService();
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
          ? ' Completed with best score $score%.'
          : ' Best score $score%.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You have already used your one quiz attempt.$scoreText',
          ),
        ),
      );
      return;
    }

    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Quiz?'),
        content: const Text(
          'This quiz can only be attempted once. Once you start, you must '
          'finish it before leaving.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
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
            imagePath: question.imagePath,
            imageAsset: question.imageAsset,
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => QuizReviewPage(review: review),
      ),
    );
  }

  Future<void> _showFinishQuizRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish quiz first'),
        content: const Text(
          'This quiz has only one attempt. Please finish all questions before '
          'leaving.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Quiz'),
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
      child: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _buildContent(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final quizSet = _activeQuizSet;
    if (quizSet == null) return _buildQuizSetList();

    if (_isLoadingQuestions) {
      return const _CenteredMessage(
        key: ValueKey('loading-quiz'),
        icon: Icons.hourglass_top_rounded,
        title: 'Loading quiz questions...',
      );
    }

    if (_questionLoadError != null) {
      return _CenteredMessage(
        key: ValueKey('quiz-error-${quizSet.id}'),
        icon: Icons.cloud_off_outlined,
        title: 'Quiz questions could not be loaded.',
        message: 'Check the Firestore connection and try again.',
        actionLabel: 'Back to Quizzes',
        onAction: _backToQuizSets,
      );
    }

    if (_questions.isEmpty) {
      return _CenteredMessage(
        key: ValueKey('empty-${quizSet.id}'),
        icon: Icons.quiz_outlined,
        title: 'Quiz questions are not available yet.',
        actionLabel: 'Back to Quizzes',
        onAction: _backToQuizSets,
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

    return StreamBuilder<List<QuizSet>>(
      key: ValueKey('quiz-sets-${widget.selectedModuleId ?? 'all'}'),
      stream: _service.watchQuizSets(moduleId: widget.selectedModuleId),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Knowledge\nChallenge',
              style: GoogleFonts.inter(
                color: _ink,
                fontSize: 42,
                height: 1.08,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.7,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Test your understanding of waste management and how ELIO '
              'classifies materials.',
              style: GoogleFonts.inter(
                color: _muted,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            if (widget.selectedModuleId != null) ...[
              const SizedBox(height: 18),
              _FilterBanner(
                moduleId: widget.selectedModuleId!,
                onClear: widget.onClearFilter,
              ),
            ],
            const SizedBox(height: 28),
            if (snapshot.hasError)
              const _CenteredMessage(
                icon: Icons.cloud_off_outlined,
                title: 'Quiz sets could not be loaded.',
              )
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.data!.isEmpty)
              const _CenteredMessage(
                icon: Icons.quiz_outlined,
                title: 'No published quizzes are available.',
              )
            else
              _QuizSetGrid(
                quizSets: snapshot.data!,
                progress: progress,
                onStartQuiz: _startQuiz,
                onReviewQuiz: _openQuizReview,
              ),
          ],
        );
      },
    );
  }
}

class _FilterBanner extends StatelessWidget {
  final String moduleId;
  final VoidCallback? onClear;

  const _FilterBanner({required this.moduleId, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, color: _primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered by: ${_moduleTitle(moduleId)}',
              style: GoogleFonts.inter(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizSetGrid extends StatelessWidget {
  final List<QuizSet> quizSets;
  final LearningProgress? progress;
  final ValueChanged<QuizSet> onStartQuiz;
  final ValueChanged<QuizReview> onReviewQuiz;

  const _QuizSetGrid({
    required this.quizSets,
    required this.progress,
    required this.onStartQuiz,
    required this.onReviewQuiz,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * 16)) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final quizSet in quizSets)
              SizedBox(
                width: itemWidth,
                child: Builder(
                  builder: (context) {
                    final categoryProgress =
                        progress?.categories[quizSet.moduleId];
                    final attempted = (categoryProgress?.quizAttempts ?? 0) > 0;
                    final completed =
                        progress?.completedQuizModules.contains(
                          quizSet.moduleId,
                        ) ??
                        false;
                    final scorePercent = progress?.quizScores[quizSet.moduleId];
                    final review = progress?.quizReviews[quizSet.moduleId];

                    return _QuizSetCard(
                      quizSet: quizSet,
                      attempted: attempted,
                      completed: completed,
                      scorePercent: scorePercent,
                      review: review,
                      onTap: attempted ? null : () => onStartQuiz(quizSet),
                      onReview: review == null
                          ? null
                          : () => onReviewQuiz(review),
                    );
                  },
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    final accent = _moduleColor(quizSet.moduleId);
    final hasReview = review != null;
    final statusText = attempted
        ? [
            completed ? 'Completed' : 'Attempt used',
            if (scorePercent != null) 'Best score $scorePercent%',
            if (!hasReview) 'Review available for new attempts only',
          ].join(' • ')
        : 'One attempt only';
    final buttonLabel = !attempted
        ? 'Start Quiz'
        : hasReview
        ? 'Review Answers'
        : completed
        ? 'Review unavailable'
        : 'Attempt Used';
    final buttonAction = !attempted ? onTap : onReview;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.12),
                foregroundColor: accent,
                child: const Icon(Icons.quiz_outlined),
              ),
              const Spacer(),
              _DifficultyChip(label: quizSet.level, color: accent),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            quizSet.title,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            quizSet.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: _muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          Text(
            '${quizSet.questionCount} questions',
            style: GoogleFonts.inter(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            statusText,
            style: GoogleFonts.inter(
              color: attempted ? accent : _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: buttonAction,
              style: OutlinedButton.styleFrom(foregroundColor: _primary),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
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
    final correctIndex = question.correctIndex;
    final hasValidCorrectIndex =
        correctIndex >= 0 && correctIndex < question.options.length;
    final selectedIsCorrect =
        hasValidCorrectIndex && selectedOptionIndex == correctIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.lock_outline_rounded),
          label: const Text('Finish quiz to exit'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Question ${questionIndex + 1} of $totalQuestions',
                style: GoogleFonts.inter(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _DifficultyChip(
              label: question.difficulty.isEmpty
                  ? quizSet.level
                  : question.difficulty,
              color: _moduleColor(quizSet.moduleId),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (questionIndex + 1) / totalQuestions,
          minHeight: 9,
          backgroundColor: _surface,
          color: _primary,
        ),
        const SizedBox(height: 26),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (question.imageAsset.trim().isNotEmpty) ...[
                _QuizQuestionImage(imageAsset: question.imageAsset),
                const SizedBox(height: 22),
              ],
              Text(
                question.question,
                style: GoogleFonts.inter(
                  color: _ink,
                  fontSize: 22,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 22),
              for (var index = 0; index < question.options.length; index++) ...[
                _AnswerOption(
                  index: index,
                  label: question.options[index],
                  selected: selectedOptionIndex == index,
                  isCorrect: hasValidCorrectIndex && index == correctIndex,
                  answered: answered,
                  onTap: () => onSelectAnswer(index),
                ),
                if (index != question.options.length - 1)
                  const SizedBox(height: 10),
              ],
              if (answered) ...[
                const SizedBox(height: 18),
                Text(
                  selectedIsCorrect
                      ? 'Correct${question.explanation.isEmpty ? '!' : ': ${question.explanation}'}'
                      : 'Not quite${question.explanation.isEmpty ? '.' : ': ${question.explanation}'}',
                  style: GoogleFonts.inter(
                    color: selectedIsCorrect ? _success : _error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: answered ? onNext : null,
                  style: FilledButton.styleFrom(backgroundColor: _primary),
                  child: Text(
                    questionIndex == totalQuestions - 1
                        ? 'View Results'
                        : 'Next Question',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuizQuestionImage extends StatelessWidget {
  final String imageAsset;

  const _QuizQuestionImage({required this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return _QuizImageFrame(
      child: Image.asset(
        imageAsset,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const _QuizImageUnavailable(),
      ),
    );
  }
}

class _QuizImageFrame extends StatelessWidget {
  final Widget child;

  const _QuizImageFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: 200,
        child: ColoredBox(color: _surface, child: child),
      ),
    );
  }
}

class _QuizImageUnavailable extends StatelessWidget {
  const _QuizImageUnavailable();

  @override
  Widget build(BuildContext context) {
    return const _QuizImageFrame(
      child: Center(
        child: Text(
          'Image unavailable',
          style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  final int index;
  final String label;
  final bool selected;
  final bool isCorrect;
  final bool answered;
  final VoidCallback onTap;

  const _AnswerOption({
    required this.index,
    required this.label,
    required this.selected,
    required this.isCorrect,
    required this.answered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final revealCorrect = answered && isCorrect;
    final revealWrong = answered && selected && !isCorrect;
    final color = revealCorrect
        ? _success
        : revealWrong
        ? _error
        : selected
        ? _primary
        : _border;

    return InkWell(
      onTap: answered ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: revealCorrect || revealWrong ? 0.1 : 0.04,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: color,
              foregroundColor: Colors.white,
              child: Text(
                String.fromCharCode(65 + index),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
    return _CenteredMessage(
      icon: Icons.workspace_premium_outlined,
      title: quizSet.title,
      message: 'You scored $score out of $total.',
      actionLabel: 'Back to Quizzes',
      onAction: onBack,
      secondaryActionLabel: 'Review Answers',
      onSecondaryAction: review == null ? null : () => onReview(review!),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String label;
  final Color color;

  const _DifficultyChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label.isEmpty ? 'Quiz' : label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const _CenteredMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _primary, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _muted, height: 1.4),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(backgroundColor: _primary),
              child: Text(actionLabel!),
            ),
          ],
          if (secondaryActionLabel != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onSecondaryAction,
              style: OutlinedButton.styleFrom(foregroundColor: _primary),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(secondaryActionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

String _moduleTitle(String moduleId) {
  switch (moduleId) {
    case 'organic':
      return 'Organic Waste Management';
    case 'inorganic':
      return 'Inorganic / Recyclable Waste Management';
    case 'hazardous':
      return 'Hazardous Waste (B3) Management';
    default:
      return moduleId;
  }
}

Color _moduleColor(String moduleId) {
  switch (moduleId) {
    case 'organic':
      return const Color(0xFF059669);
    case 'inorganic':
      return const Color(0xFF2563EB);
    case 'hazardous':
      return const Color(0xFFDC2626);
    default:
      return _primary;
  }
}
