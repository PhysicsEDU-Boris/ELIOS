import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/waste_category.dart';

const _background = Color(0xFFF7FAF6);
const _primary = Color(0xFF004F38);
const _ink = Color(0xFF181D1A);
const _muted = Color(0xFF3F4943);
const _border = Color(0xFFBEC9C2);
const _surface = Color(0xFFEBEFEA);
const _success = Color(0xFF059669);
const _error = Color(0xFFBA1A1A);

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  WasteCategory? _selectedCategory;
  int _currentQuestionIndex = 0;
  int _score = 0;
  int? _selectedOptionIndex;
  bool _answered = false;
  bool _isFinished = false;

  void _startQuiz(WasteCategory category) {
    if (category.quiz.isEmpty) return;

    setState(() {
      _selectedCategory = category;
      _currentQuestionIndex = 0;
      _score = 0;
      _selectedOptionIndex = null;
      _answered = false;
      _isFinished = false;
    });
  }

  void _selectAnswer(int index) {
    final category = _selectedCategory;
    if (category == null || _answered || category.quiz.isEmpty) return;

    final question = category.quiz[_currentQuestionIndex];
    setState(() {
      _selectedOptionIndex = index;
      _answered = true;
      if (index == question.correctIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    final category = _selectedCategory;
    if (category == null || !_answered) return;

    if (_currentQuestionIndex >= category.quiz.length - 1) {
      setState(() {
        _isFinished = true;
        // TODO: Persist quiz score to learningProgressProvider in Phase 5.
      });
      return;
    }

    setState(() {
      _currentQuestionIndex++;
      _selectedOptionIndex = null;
      _answered = false;
    });
  }

  void _resetQuiz() {
    final category = _selectedCategory;
    if (category != null) {
      _startQuiz(category);
    }
  }

  void _backToCategories() {
    setState(() {
      _selectedCategory = null;
      _currentQuestionIndex = 0;
      _score = 0;
      _selectedOptionIndex = null;
      _answered = false;
      _isFinished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _QuizTopBar(),
                        const SizedBox(height: 28),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _buildContent(),
                        ),
                      ],
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
    final category = _selectedCategory;
    if (category == null) {
      return _QuizCategoryView(
        key: const ValueKey('quiz-categories'),
        categories: wasteCategories,
        onStartQuiz: _startQuiz,
      );
    }

    if (category.quiz.isEmpty) {
      return _QuizEmptyState(
        key: ValueKey('empty-${category.id}'),
        title: 'Quiz questions are not available yet.',
        message:
            'We are preparing questions for ${category.title}. Check back soon.',
        onBack: _backToCategories,
      );
    }

    if (_isFinished) {
      return _QuizResultView(
        key: ValueKey('result-${category.id}'),
        category: category,
        score: _score,
        onTryAgain: _resetQuiz,
        onBackToCategories: _backToCategories,
      );
    }

    return _QuizQuestionView(
      key: ValueKey('question-${category.id}-$_currentQuestionIndex'),
      category: category,
      questionIndex: _currentQuestionIndex,
      selectedOptionIndex: _selectedOptionIndex,
      answered: _answered,
      onSelectAnswer: _selectAnswer,
      onNext: _nextQuestion,
      onBackToCategories: _backToCategories,
    );
  }
}

class _QuizTopBar extends StatelessWidget {
  const _QuizTopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            color: _primary,
            tooltip: 'Back to learning hub',
          ),
          const Spacer(),
          Text(
            'ELIO',
            style: GoogleFonts.inter(
              color: _primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const Spacer(),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _primary.withValues(alpha: 0.12)),
            ),
            child: const Icon(Icons.quiz_outlined, color: _primary, size: 20),
          ),
        ],
      ),
    );
  }
}

class _QuizCategoryView extends StatelessWidget {
  final List<WasteCategory> categories;
  final ValueChanged<WasteCategory> onStartQuiz;

  const _QuizCategoryView({
    super.key,
    required this.categories,
    required this.onStartQuiz,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _QuizFilterChips(),
        const SizedBox(height: 34),
        const _QuizHeader(),
        const SizedBox(height: 28),
        const _QuizProgressCallout(),
        const SizedBox(height: 34),
        Text(
          'Choose a challenge',
          style: GoogleFonts.inter(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Pick a topic and test what you know.',
          style: GoogleFonts.inter(color: _muted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 18),
        if (categories.isEmpty)
          const _QuizEmptyState(
            title: 'No quizzes available yet.',
            message: 'New environmental learning challenges will appear here.',
          )
        else
          _QuizCategoryGrid(categories: categories, onStartQuiz: onStartQuiz),
      ],
    );
  }
}

class _QuizFilterChips extends StatelessWidget {
  const _QuizFilterChips();

  static const _labels = ['Quiz', 'All Categories', 'Guides', 'Video Lessons'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? _primary : const Color(0xFFE6E9E8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              _labels[index],
              style: GoogleFonts.inter(
                color: selected ? Colors.white : _muted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuizHeader extends StatelessWidget {
  const _QuizHeader();

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: 18),
        Text(
          'Test your understanding of waste management, environmental '
          'sustainability, and how ELIO classifies materials.',
          style: GoogleFonts.inter(
            color: _muted,
            fontSize: 16,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _QuizProgressCallout extends StatelessWidget {
  const _QuizProgressCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track your learning\nprogress',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Build environmental literacy through quick, interactive '
                  'quizzes.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: Color(0xFF91E5C1),
              size: 38,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizCategoryGrid extends StatelessWidget {
  final List<WasteCategory> categories;
  final ValueChanged<WasteCategory> onStartQuiz;

  const _QuizCategoryGrid({
    required this.categories,
    required this.onStartQuiz,
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
            for (final category in categories)
              SizedBox(
                width: itemWidth,
                child: _QuizCategoryCard(
                  category: category,
                  metadata: _QuizMetadata.forCategory(category),
                  onTap: () => onStartQuiz(category),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuizCategoryCard extends StatelessWidget {
  final WasteCategory category;
  final _QuizMetadata metadata;
  final VoidCallback onTap;

  const _QuizCategoryCard({
    required this.category,
    required this.metadata,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final available = category.quiz.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123524).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: metadata.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 23),
                ),
              ),
              const Spacer(),
              _QuizDifficultyChip(
                label: metadata.difficulty,
                color: metadata.accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            metadata.title,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 17,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            category.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: _muted, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, size: 17, color: _muted),
              const SizedBox(width: 6),
              Text(
                available
                    ? '${category.quiz.length} questions'
                    : 'Questions coming soon',
                style: GoogleFonts.inter(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: available ? onTap : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                disabledForegroundColor: _muted,
                side: BorderSide(
                  color: available ? _primary : _border.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(available ? 'Start Quiz' : 'Not Available Yet'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizDifficultyChip extends StatelessWidget {
  final String label;
  final Color color;

  const _QuizDifficultyChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _QuizQuestionView extends StatelessWidget {
  final WasteCategory category;
  final int questionIndex;
  final int? selectedOptionIndex;
  final bool answered;
  final ValueChanged<int> onSelectAnswer;
  final VoidCallback onNext;
  final VoidCallback onBackToCategories;

  const _QuizQuestionView({
    super.key,
    required this.category,
    required this.questionIndex,
    required this.selectedOptionIndex,
    required this.answered,
    required this.onSelectAnswer,
    required this.onNext,
    required this.onBackToCategories,
  });

  @override
  Widget build(BuildContext context) {
    final question = category.quiz[questionIndex];
    final metadata = _QuizMetadata.forCategory(category);
    final progress = (questionIndex + 1) / category.quiz.length;
    final selectedIsCorrect = selectedOptionIndex == question.correctIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onBackToCategories,
          style: TextButton.styleFrom(
            foregroundColor: _primary,
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(
            'Quiz categories',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Question ${questionIndex + 1} of ${category.quiz.length}',
                style: GoogleFonts.inter(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _QuizDifficultyChip(
              label: metadata.difficulty,
              color: metadata.accent,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _QuizProgressBar(value: progress),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF123524).withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: metadata.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 21),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      metadata.title,
                      style: GoogleFonts.inter(
                        color: metadata.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                question.question,
                style: GoogleFonts.inter(
                  color: _ink,
                  fontSize: 23,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              for (var index = 0; index < question.options.length; index++) ...[
                _AnswerOption(
                  index: index,
                  label: question.options[index],
                  selected: selectedOptionIndex == index,
                  isCorrect: index == question.correctIndex,
                  answered: answered,
                  onTap: () => onSelectAnswer(index),
                ),
                if (index != question.options.length - 1)
                  const SizedBox(height: 11),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: answered
                    ? Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: _AnswerFeedback(
                          correct: selectedIsCorrect,
                          correctAnswer:
                              question.options[question.correctIndex],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: answered ? onNext : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: _surface,
                    disabledForegroundColor: _muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(
                    questionIndex == category.quiz.length - 1
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

class _QuizProgressBar extends StatelessWidget {
  final double value;

  const _QuizProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 9,
        backgroundColor: _surface,
        valueColor: const AlwaysStoppedAnimation(_primary),
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
    final borderColor = revealCorrect
        ? _success
        : revealWrong
        ? _error
        : selected
        ? _primary
        : _border.withValues(alpha: 0.6);
    final background = revealCorrect
        ? const Color(0xFFECFDF5)
        : revealWrong
        ? const Color(0xFFFFDAD6).withValues(alpha: 0.55)
        : selected
        ? _primary.withValues(alpha: 0.06)
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: revealCorrect
                      ? _success
                      : revealWrong
                      ? _error
                      : selected
                      ? _primary
                      : _surface,
                  shape: BoxShape.circle,
                ),
                child: revealCorrect || revealWrong
                    ? Icon(
                        revealCorrect ? Icons.check_rounded : Icons.close,
                        color: Colors.white,
                        size: 17,
                      )
                    : Text(
                        String.fromCharCode(65 + index),
                        style: GoogleFonts.inter(
                          color: selected ? Colors.white : _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _ink,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerFeedback extends StatelessWidget {
  final bool correct;
  final String correctAnswer;

  const _AnswerFeedback({required this.correct, required this.correctAnswer});

  @override
  Widget build(BuildContext context) {
    final color = correct ? _success : _error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            correct ? Icons.check_circle_outline : Icons.info_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              correct
                  ? 'Correct! Nice work.'
                  : 'Not quite. The correct answer is $correctAnswer.',
              style: GoogleFonts.inter(
                color: color,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizResultView extends StatelessWidget {
  final WasteCategory category;
  final int score;
  final VoidCallback onTryAgain;
  final VoidCallback onBackToCategories;

  const _QuizResultView({
    super.key,
    required this.category,
    required this.score,
    required this.onTryAgain,
    required this.onBackToCategories,
  });

  @override
  Widget build(BuildContext context) {
    final total = category.quiz.length;
    final percentage = total == 0 ? 0 : ((score / total) * 100).round();
    final metadata = _QuizMetadata.forCategory(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Challenge\nComplete',
          style: GoogleFonts.inter(
            color: _ink,
            fontSize: 42,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.7,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'You completed the ${metadata.title}.',
          style: GoogleFonts.inter(
            color: _muted,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF123524).withValues(alpha: 0.07),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 38),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$percentage%',
                style: GoogleFonts.inter(
                  color: _primary,
                  fontSize: 54,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$score of $total correct',
                style: GoogleFonts.inter(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _resultMessage(percentage),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: _muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: onTryAgain,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 19),
                  label: const Text('Try Again'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: onBackToCategories,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('Back to Quiz Categories'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _resultMessage(int percentage) {
    if (percentage == 100) {
      return 'Excellent work. You have a strong understanding of this topic.';
    }
    if (percentage >= 67) {
      return 'Great progress. Review the missed answer and try for a perfect score.';
    }
    return 'Good start. Revisit the learning guide, then take the challenge again.';
  }
}

class _QuizEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onBack;

  const _QuizEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          const Icon(Icons.quiz_outlined, color: _primary, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _muted, fontSize: 13, height: 1.45),
          ),
          if (onBack != null) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(foregroundColor: _primary),
              child: const Text('Back to Quiz Categories'),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizMetadata {
  final String title;
  final String difficulty;
  final Color accent;

  const _QuizMetadata({
    required this.title,
    required this.difficulty,
    required this.accent,
  });

  factory _QuizMetadata.forCategory(WasteCategory category) {
    switch (category.id) {
      case 'organic':
        return const _QuizMetadata(
          title: 'Organic Waste Quiz',
          difficulty: 'BEGINNER',
          accent: _primary,
        );
      case 'inorganic':
        return const _QuizMetadata(
          title: 'Recyclable Waste Quiz',
          difficulty: 'INTERMEDIATE',
          accent: Color(0xFF00647C),
        );
      case 'hazardous':
        return const _QuizMetadata(
          title: 'Hazardous Waste (B3) Quiz',
          difficulty: 'ADVANCED',
          accent: _error,
        );
      default:
        return _QuizMetadata(
          title: '${category.title} Quiz',
          difficulty: 'LEARNING',
          accent: _primary,
        );
    }
  }
}
