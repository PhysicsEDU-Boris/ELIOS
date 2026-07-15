import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../physics/quiz/physics_quiz_state.dart';
import '../../../../widgets/elio_learning_app_bar.dart';
import '../../../../../theme/elio_learning_colors.dart';

const _primary = Color(0xFF004F38);
const _ink = Color(0xFF181D1A);
const _muted = Color(0xFF3F4943);
const _border = Color(0xFFBEC9C2);
const _surface = Color(0xFFEBEFEA);
const _success = Color(0xFF059669);
const _error = Color(0xFFBA1A1A);

class PhysicsQuizPage extends ConsumerWidget {
  const PhysicsQuizPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(physicsQuizProvider);
    final notifier = ref.read(physicsQuizProvider.notifier);

    // If all questions are answered, show result card
    final isFinished = !quizState.results.values.any((r) => r == QuizResult.unanswered);

    if (isFinished) {
      return Scaffold(
        backgroundColor: elioBackground,
        appBar: const ElioLearningAppBar(title: 'Hasil Kuis Fisika', showBack: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _QuizResult(
              score: quizState.score,
              total: quizState.total,
              onRetake: () => notifier.randomizeAll(),
            ),
          ),
        ),
      );
    }

    // Find first unanswered question
    int currentQuestionIndex = 0;
    for (int i = 0; i < physicsQuizQuestions.length; i++) {
      if (quizState.results[physicsQuizQuestions[i].moduleId] == QuizResult.unanswered) {
        currentQuestionIndex = i;
        break;
      }
    }

    final question = physicsQuizQuestions[currentQuestionIndex];
    final questionData = quizState.currentData[question.moduleId]!;
    
    // We use a unique key based on the question index so the stateful widget resets for each question
    return Scaffold(
      backgroundColor: elioBackground,
      appBar: const ElioLearningAppBar(title: 'Kuis Fisika', showBack: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: _PhysicsQuestionView(
                key: ValueKey(currentQuestionIndex),
                question: question,
                questionData: questionData,
                questionIndex: currentQuestionIndex,
                totalQuestions: quizState.total,
                onNext: (selectedIndex) {
                  notifier.answer(question.moduleId, selectedIndex);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhysicsQuestionView extends StatefulWidget {
  final PhysicsQuizQuestion question;
  final Map<String, num> questionData;
  final int questionIndex;
  final int totalQuestions;
  final ValueChanged<int> onNext;

  const _PhysicsQuestionView({
    super.key,
    required this.question,
    required this.questionData,
    required this.questionIndex,
    required this.totalQuestions,
    required this.onNext,
  });

  @override
  State<_PhysicsQuestionView> createState() => _PhysicsQuestionViewState();
}

class _PhysicsQuestionViewState extends State<_PhysicsQuestionView> {
  int? _selectedIndex;
  late final List<String> _options;

  @override
  void initState() {
    super.initState();
    _options = widget.question.options(widget.questionData);
  }

  @override
  Widget build(BuildContext context) {
    final answered = _selectedIndex != null;
    final selectedIsCorrect = _selectedIndex == widget.question.correctIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pertanyaan ${widget.questionIndex + 1} / ${widget.totalQuestions}',
              style: GoogleFonts.inter(
                color: _muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const _DifficultyChip(label: 'Fisika Lanjutan', color: _primary),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          widget.question.prompt(widget.questionData),
          style: GoogleFonts.inter(
            color: _ink,
            fontSize: 18,
            height: 1.4,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 32),
        for (int i = 0; i < _options.length; i++) ...[
          _AnswerOption(
            index: i,
            label: _options[i],
            selected: _selectedIndex == i,
            isCorrect: i == widget.question.correctIndex,
            answered: answered,
            onTap: () {
              setState(() {
                _selectedIndex = i;
              });
            },
          ),
          if (i != _options.length - 1) const SizedBox(height: 10),
        ],
        if (answered) ...[
          const SizedBox(height: 18),
          Text(
            selectedIsCorrect ? 'Benar!' : 'Kurang Tepat.',
            style: GoogleFonts.inter(
              color: selectedIsCorrect ? _success : _error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.question.workedSolution(widget.questionData),
              style: GoogleFonts.inter(
                color: _ink,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: answered ? () => widget.onNext(_selectedIndex!) : null,
            style: FilledButton.styleFrom(backgroundColor: _primary),
            child: Text(
              widget.questionIndex == widget.totalQuestions - 1
                  ? 'Lihat Hasil'
                  : 'Pertanyaan Selanjutnya',
            ),
          ),
        ),
      ],
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
  final int score;
  final int total;
  final VoidCallback onRetake;

  const _QuizResult({
    required this.score,
    required this.total,
    required this.onRetake,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_outlined, color: _primary, size: 42),
          const SizedBox(height: 14),
          Text(
            'Kuis Fisika Selesai',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Skor Anda: $score / $total',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRetake,
            style: FilledButton.styleFrom(backgroundColor: _primary),
            child: const Text('Coba Lagi'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(foregroundColor: _primary),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Kembali ke Menu'),
          ),
        ],
      ),
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
