import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/learning_progress.dart';
import '../../../widgets/elio_learning_app_bar.dart';

const _background = Color(0xFFF7FAF6);
const _primary = Color(0xFF004F38);
const _ink = Color(0xFF181D1A);
const _muted = Color(0xFF3F4943);
const _border = Color(0xFFBEC9C2);
const _success = Color(0xFF059669);
const _error = Color(0xFFBA1A1A);

class QuizReviewPage extends StatelessWidget {
  final QuizReview review;

  const QuizReviewPage({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: const ElioLearningAppBar(
        title: 'Quiz Review',
        showBack: true,
        backgroundColor: _background,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QuizReviewHeader(review: review),
                  const SizedBox(height: 18),
                  for (var index = 0; index < review.answers.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _QuizReviewAnswerCard(
                        answer: review.answers[index],
                        questionNumber: index + 1,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizReviewHeader extends StatelessWidget {
  final QuizReview review;

  const _QuizReviewHeader({required this.review});

  @override
  Widget build(BuildContext context) {
    final statusColor = review.passed ? _success : _error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review.quizTitle,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuizReviewMetric(
                label: 'Score',
                value: '${review.score}/${review.totalQuestions}',
              ),
              _QuizReviewMetric(label: 'Percent', value: '${review.percent}%'),
              _QuizReviewMetric(
                label: review.passed ? 'Passed' : 'Attempt used',
                value: _reviewDateLabel(review.completedAt),
                color: statusColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuizReviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _QuizReviewMetric({
    required this.label,
    required this.value,
    this.color = _primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizReviewAnswerCard extends StatelessWidget {
  final QuizReviewAnswer answer;
  final int questionNumber;

  const _QuizReviewAnswerCard({
    required this.answer,
    required this.questionNumber,
  });

  @override
  Widget build(BuildContext context) {
    final unanswered = answer.selectedIndex == null;
    final color = unanswered
        ? _muted
        : answer.isCorrect
        ? _success
        : _error;
    final icon = unanswered
        ? Icons.warning_amber_rounded
        : answer.isCorrect
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;

    return Container(
      width: double.infinity,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Question $questionNumber',
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            answer.question,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _QuizReviewAnswerLine(
            label: 'Your answer',
            value: _answerText(answer, answer.selectedIndex),
            color: color,
          ),
          const SizedBox(height: 8),
          _QuizReviewAnswerLine(
            label: 'Correct answer',
            value: _answerText(answer, answer.correctIndex),
            color: _success,
          ),
          if (answer.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Explanation',
              style: GoogleFonts.inter(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              answer.explanation,
              style: GoogleFonts.inter(color: _ink, fontSize: 13, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizReviewAnswerLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _QuizReviewAnswerLine({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _answerText(QuizReviewAnswer answer, int? index) {
  if (index == null) return 'Not answered';
  if (index < 0 || index >= answer.options.length) return 'Unknown answer';
  return answer.options[index];
}

String _reviewDateLabel(DateTime date) {
  final local = date.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
