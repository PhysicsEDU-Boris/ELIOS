import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../services/ai_quiz_service.dart';
import 'quiz_explanation.dart';
import 'trophy_rules.dart';

/// Categories displayed in the Scan History filter chips and item badges.
enum ScanCategory {
  b3(
    id: 'b3',
    bg: Color(0xFFFDEDEC),
    fg: Color(0xFFE74C3C),
  ),
  recyclable(
    id: 'recyclable',
    bg: Color(0xFFE8F8F5),
    fg: Color(0xFF16A085),
  ),
  organic(
    id: 'organic',
    bg: Color(0xFFFEF9E7),
    fg: Color(0xFFF39C12),
  ),
  residu(
    id: 'residu',
    bg: Color(0xFFF2F4F4),
    fg: Color(0xFF7F8C8D),
  );

  const ScanCategory({
    required this.id,
    required this.bg,
    required this.fg,
  });

  final String id;
  /// Chip/PDF label in the app language ("B3 · Hazardous").
  String get badgeLabel => switch (this) {
    b3 => l10n.h3CatB3Long,
    recyclable => l10n.h3CatRecyclable,
    organic => l10n.h3CatOrganic,
    residu => l10n.h3CatResidu,
  };
  final Color bg;
  final Color fg;

  static ScanCategory fromString(String? raw) {
    if (raw == null) return ScanCategory.recyclable;
    final lower = raw.trim().toLowerCase();
    if (lower == 'b3' || lower == 'hazardous' || lower.contains('limbah') || lower == 'e_waste') {
      return ScanCategory.b3;
    }
    if (lower == 'organic' || lower == 'organik') {
      return ScanCategory.organic;
    }
    if (lower == 'residu' || lower == 'residual') {
      return ScanCategory.residu;
    }
    return ScanCategory.recyclable;
  }
}

/// A question answer result stored inside a [ScanRecord].
class RecordQuestion {
  final String question;
  final String yourAnswer;
  final String rightAnswer;
  final bool isCorrect;
  final int trophies;
  final bool isEssay;
  final int? essayScore;
  final List<String> options;
  final String bankExplanation;
  final Map<String, String> wrongWhy;

  bool get gradingPending => isEssay && essayScore == null;

  /// Optional structured explanation saved alongside the answer (schema v2+).
  /// Null for old records or when explanation generation failed.
  final QuizExplanation? explanation;

  const RecordQuestion({
    required this.question,
    required this.yourAnswer,
    required this.rightAnswer,
    required this.isCorrect,
    int? trophies,
    this.isEssay = false,
    this.essayScore,
    this.options = const [],
    this.bankExplanation = '',
    this.wrongWhy = const {},
    this.explanation,
  }) : trophies = trophies ?? (isCorrect ? 10 : (essayScore ?? 0));

  RecordQuestion copyWith({QuizExplanation? explanation}) => RecordQuestion(
    question: question,
    yourAnswer: yourAnswer,
    rightAnswer: rightAnswer,
    isCorrect: isCorrect,
    trophies: trophies,
    isEssay: isEssay,
    essayScore: essayScore,
    options: options,
    bankExplanation: bankExplanation,
    wrongWhy: wrongWhy,
    explanation: explanation ?? this.explanation,
  );

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'bankExplanation': bankExplanation,
    'wrongWhy': wrongWhy,
    'yourAnswer': yourAnswer,
    'rightAnswer': rightAnswer,
    'isCorrect': isCorrect,
    'trophies': trophies,
    'isEssay': isEssay,
    if (essayScore != null) 'essayScore': essayScore,
    if (explanation != null) 'explanation': explanation!.toJson(),
  };

  factory RecordQuestion.fromJson(Map<String, dynamic> json) {
    final explanationJson = json['explanation'] as Map<String, dynamic>?;
    return RecordQuestion(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List?)?.cast<String>() ?? const [],
      bankExplanation: json['bankExplanation'] as String? ?? '',
      wrongWhy: (json['wrongWhy'] as Map?)?.cast<String, String>() ?? const {},
      yourAnswer: json['yourAnswer'] as String? ?? '',
      rightAnswer: json['rightAnswer'] as String? ?? '',
      isCorrect: json['isCorrect'] as bool? ?? false,
      trophies: (json['trophies'] as num?)?.toInt(),
      isEssay: json['isEssay'] as bool? ?? false,
      essayScore: (json['essayScore'] as num?)?.toInt(),
      explanation: explanationJson != null
          ? QuizExplanation.fromJson(explanationJson)
          : null,
    );
  }
}

/// A single scan item record with quiz results, photo, and trophies earned.
class ScanRecord {
  final String id;
  final DateTime time;
  final String itemName;
  final ScanCategory category;
  final String? cropPhotoPath;
  final QuizDifficulty difficulty;
  final List<RecordQuestion> questions;
  final int trophies;

  /// Schema version for forward-compat. Version 1 = no explanation field.
  /// Version 2 = explanation added (decision 0031).
  final int schemaVersion;

  ScanRecord({
    required this.id,
    required this.time,
    required this.itemName,
    required this.category,
    this.cropPhotoPath,
    this.difficulty = QuizDifficulty.medium,
    required this.questions,
    int? trophies,
    this.schemaVersion =
        4, // v4: saved AI explanation and question grounding (0184)
  }) : trophies = trophies ?? trophiesFor(questions);

  int get correctCount => questions.where((q) => q.isCorrect).length;
  int get totalQuestions =>
      questions.isNotEmpty ? questions.length : difficulty.questionCount;
  QuizGrade get grade =>
      gradeFor(trophies: trophies, totalQuestions: totalQuestions);

  String get difficultyLabel => l10n.h3DiffChip(
    switch (difficulty) {
      QuizDifficulty.easy => l10n.h3Easy,
      QuizDifficulty.medium => l10n.h3Medium,
      QuizDifficulty.hard => l10n.h3Hard,
    },
    totalQuestions,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'time': time.toIso8601String(),
    'itemName': itemName,
    'category': category.id,
    if (cropPhotoPath != null) 'cropPhotoPath': cropPhotoPath,
    'difficulty': difficulty.name,
    'questions': questions.map((q) => q.toJson()).toList(),
    'trophies': trophies,
  };

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    final legacy = ((json['schemaVersion'] as num?)?.toInt() ?? 1) < 4;
    final questionsList = (json['questions'] as List<dynamic>? ?? []).map((q) {
      final data = Map<String, dynamic>.from(q as Map);
      if (legacy && data['explanation'] is Map && data['isEssay'] != true) {
        final old = Map<String, dynamic>.from(data['explanation'] as Map);
        // Legacy takeaways/comparison rows were local templates, never reviewed text.
        if (old['bankId'] == null && old['groundingStatus'] != 'bankGrounded') {
          data['explanation'] = {...old, 'summary': '', 'correctAnswerReason': '',
            'selectedAnswerFeedback': '', 'conceptExplanation': '',
            'learningTakeaway': '', 'comparisonRows': <dynamic>[],
            'groundingStatus': 'unavailable', 'source': ''};
        } else {
          data['explanation'] = {
            ...old,
            'learningTakeaway': '',
            'comparisonRows': <dynamic>[],
            'source': 'bank',
          };
          if ((data['bankExplanation'] as String? ?? '').isEmpty) {
            data['bankExplanation'] = old['correctAnswerReason'] ?? '';
          }
        }
      }
      return RecordQuestion.fromJson(data);
    }).toList();
    final diffName = json['difficulty'] as String? ?? 'medium';
    final difficulty = QuizDifficulty.values.firstWhere(
      (d) => d.name == diffName,
      orElse: () => QuizDifficulty.medium,
    );

    return ScanRecord(
      schemaVersion: 4,
      id: json['id'] as String? ?? '',
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      itemName: json['itemName'] as String? ?? 'Unknown Item',
      category: ScanCategory.fromString(json['category'] as String?),
      cropPhotoPath: json['cropPhotoPath'] as String?,
      difficulty: difficulty,
      questions: questionsList,
      trophies: (json['trophies'] as num?)?.toInt(),
    );
  }
}
