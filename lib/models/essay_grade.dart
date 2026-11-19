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
    this.why = '',
    this.keyIdea = '',
    this.tips = const [],
    this.alt,
  });

  /// Optional teaching texts of the grading reply (decision 0227): the general
  /// explanation, the key idea and the steps to full marks. Empty when the
  /// reply has none; the review then hides that section.
  final String why, keyIdea;
  final List<String> tips;

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

  /// A short optional string field; '' when missing, not a string or too long.
  static String _text(Object? v, int cap) =>
      v is String && v.trim().length <= cap ? v.trim() : '';

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
        RubricRow(
          criterion: label,
          maxScore: max,
          awardedScore: value,
          // One-line hint per criterion, e.g. "accuracyHint".
          comment: _text(decoded['${key}Hint'], 200),
        ),
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
    final tips = decoded['tips'];
    return EssayGrade(
      score: total,
      feedback: feedback.trim(),
      improvement: improvement.trim(),
      rubricRows: scores,
      why: _text(decoded['why'], 1800),
      keyIdea: _text(decoded['keyIdea'], 600),
      tips: tips is List && tips.length <= 5
          ? [
              for (final t in tips)
                if (_text(t, 240).isNotEmpty) _text(t, 240),
            ]
          : const [],
      alt: alt != null && alt.score == total ? alt : null,
    );
  }
}
