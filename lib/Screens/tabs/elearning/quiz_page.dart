import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/quiz_question.dart';
import '../../../models/quiz_set.dart';
import '../../../providers/learning_progress_provider.dart';
import '../../../services/elearning_content_service.dart';
import '../../../widgets/elio_learning_app_bar.dart';

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

  bool get _quizIsActive => _activeQuizSet != null;

  Future<void> _startQuiz(QuizSet quizSet) async {
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Quiz?'),
        content: const Text(
          'Once you start, you cannot switch tabs until you finish or exit '
          'the quiz. Make sure you have time to complete it.',
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
      if (index == question.correctIndex) _score++;
    });
  }

  void _nextQuestion() {
    if (!_answered) return;
    if (_currentQuestionIndex >= _questions.length - 1) {
      setState(() => _isFinished = true);
      final moduleId = _activeQuizSet?.moduleId;
      if (moduleId != null) {
        unawaited(
          ref
              .read(learningProgressProvider.notifier)
              .updateProgress(moduleId, _score, _questions.length),
        );
      }
      return;
    }

    setState(() {
      _currentQuestionIndex++;
      _selectedOptionIndex = null;
      _answered = false;
    });
  }

  void _retryQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _score = 0;
      _selectedOptionIndex = null;
      _answered = false;
      _isFinished = false;
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
    });
    widget.onQuizActiveChanged?.call(false);
  }

  Future<bool> _confirmLeaveQuiz() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave quiz?'),
            content: const Text(
              'Your current quiz progress will be lost if you leave.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave Quiz'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _requestBackToQuizSets() async {
    if (!await _confirmLeaveQuiz() || !mounted) return;
    _backToQuizSets();
  }

  Future<void> _handlePopAttempt(bool didPop) async {
    if (didPop || !_quizIsActive) return;
    if (!await _confirmLeaveQuiz() || !mounted) return;

    _backToQuizSets();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
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
        onTryAgain: _retryQuiz,
        onBack: _backToQuizSets,
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
              _QuizSetGrid(quizSets: snapshot.data!, onStartQuiz: _startQuiz),
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
  final ValueChanged<QuizSet> onStartQuiz;

  const _QuizSetGrid({required this.quizSets, required this.onStartQuiz});

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
                child: _QuizSetCard(
                  quizSet: quizSet,
                  onTap: () => onStartQuiz(quizSet),
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
  final VoidCallback onTap;

  const _QuizSetCard({required this.quizSet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _moduleColor(quizSet.moduleId);
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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(foregroundColor: _primary),
              child: const Text('Start Quiz'),
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
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Quiz sets'),
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
  final VoidCallback onTryAgain;
  final VoidCallback onBack;

  const _QuizResult({
    super.key,
    required this.quizSet,
    required this.score,
    required this.total,
    required this.onTryAgain,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: Icons.workspace_premium_outlined,
      title: quizSet.title,
      message: 'You scored $score out of $total.',
      actionLabel: 'Try Again',
      onAction: onTryAgain,
      secondaryActionLabel: 'Back to Quizzes',
      onSecondaryAction: onBack,
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
          if (secondaryActionLabel != null && onSecondaryAction != null)
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionLabel!),
            ),
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
