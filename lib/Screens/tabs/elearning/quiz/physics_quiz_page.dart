import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/quiz/physics_quiz_state.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../learn_content.dart';

class PhysicsQuizPage extends ConsumerWidget {
  const PhysicsQuizPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(physicsQuizProvider);
    final notifier = ref.read(physicsQuizProvider.notifier);

    // If all questions are answered, show result card
    final isFinished = !quizState.results.values.any((r) => r == QuizResult.unanswered);

    if (isFinished) {
      return LearnPageScaffold(
        title: 'Hasil Kuis Fisika',
        centerTitle: false,
        body: LearnListView(
          children: [
            _QuizResult(
              score: quizState.score,
              total: quizState.total,
              onRetake: () => notifier.randomizeAll(),
            ),
          ],
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

    // A key per question index resets the stateful view for each question.
    return LearnPageScaffold(
      title: 'Kuis fisika',
      centerTitle: false,
      body: _PhysicsQuestionView(
        key: ValueKey(currentQuestionIndex),
        question: question,
        questionData: questionData,
        questionIndex: currentQuestionIndex,
        totalQuestions: quizState.total,
        onNext: (selectedIndex) {
          notifier.answer(question.moduleId, selectedIndex);
        },
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
    final p = context.elio;
    final answered = _selectedIndex != null;
    final selectedIsCorrect = _selectedIndex == widget.question.correctIndex;
    final isLast = widget.questionIndex == widget.totalQuestions - 1;

    return Column(
      children: [
        Expanded(
          child: LearnListView(
            children: [
              QuizProgressHeader(
                counter: 'Pertanyaan ${widget.questionIndex + 1} / ${widget.totalQuestions}',
                level: 'Fisika lanjutan',
                value: (widget.questionIndex + 1) / widget.totalQuestions,
              ),
              const SizedBox(height: 16),
              LearnCard(
                child: Text(
                  widget.question.prompt(widget.questionData),
                  style: context.text.bodyLarge?.copyWith(fontSize: 18),
                ),
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < _options.length; i++) ...[
                QuizAnswerOption(
                  index: i,
                  label: _options[i],
                  selected: _selectedIndex == i,
                  isCorrect: i == widget.question.correctIndex,
                  answered: answered,
                  onTap: () => setState(() => _selectedIndex = i),
                ),
                const SizedBox(height: 12),
              ],
              if (answered) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    selectedIsCorrect ? 'Benar!' : 'Kurang Tepat.',
                    style: context.text.titleSmall?.copyWith(
                      color: selectedIsCorrect ? p.primaryText : p.errorText,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                LearnCard(
                  color: p.surfaceRaised,
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: answered ? () => widget.onNext(_selectedIndex!) : null,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(isLast ? 'Lihat Hasil' : 'Pertanyaan selanjutnya'),
              ),
            ),
          ),
        ),
      ],
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
    return LearnStateView(
      asset: LearnArt.mascot,
      title: 'Kuis Fisika Selesai',
      message: 'Skor Anda: $score / $total',
      primaryLabel: 'Coba Lagi',
      onPrimary: onRetake,
      secondaryLabel: 'Kembali ke Menu',
      onSecondary: () => Navigator.of(context).pop(),
    );
  }
}
