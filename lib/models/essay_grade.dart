import 'dart:convert';

import 'quiz_explanation.dart';

/// A validated AI essay result. Rows are present only when the whole rubric
/// is complete and its sum matches [score].
class EssayGrade {
  const EssayGrade({
    required this.score,
    this.feedback = '',
    this.improvement = '',
    this.rubricRows = const [],
    this.alt,
  });

  /// The same grade's feedback in the other app language (bilingual reply,
  /// decision 0185); only kept when its total matches [score].
  final EssayGrade? alt;

  final int score;
  final String feedback;
  final String improvement;
  final List<RubricRow> rubricRows;

  static const _criteria = <(String, String, int)>[
    ('accuracy', 'Accuracy', 4),
    ('keyTerms', 'Key terms', 3),
    ('completeness', 'Completeness', 2),
    ('clarity', 'Clarity', 1),
  ];

  /// Parses the strict JSON contract. A valid total survives a missing or
  /// malformed rubric as score-only; an inconsistent rubric invalidates it.
  static EssayGrade? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final text = raw
        .trim()
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '');
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final total = decoded['total'];
    if (total is! int || total < 0 || total > 10) {
      return null;
    }

    final scores = <RubricRow>[];
    for (final (key, label, max) in _criteria) {
      final value = decoded[key];
      if (value is! int || value < 0 || value > max) {
        return EssayGrade(score: total);
      }
      scores.add(
        RubricRow(criterion: label, maxScore: max, awardedScore: value),
      );
    }
    if (scores.fold<int>(0, (sum, row) => sum + row.awardedScore) != total) {
      return null;
    }

    final feedback = decoded['feedback'];
    final improvement = decoded['improvement'];
    if (feedback is! String ||
        feedback.trim().isEmpty ||
        improvement is! String ||
        improvement.trim().isEmpty) {
      return EssayGrade(score: total);
    }
    final altRaw = decoded['alt'];
    final alt = altRaw is Map ? parse(jsonEncode(altRaw)) : null;
    return EssayGrade(
      score: total,
      feedback: feedback.trim(),
      improvement: improvement.trim(),
      rubricRows: scores,
      alt: alt != null && alt.score == total ? alt : null,
    );
  }
}
