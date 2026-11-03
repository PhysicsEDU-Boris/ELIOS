import 'package:flutter/material.dart';
import '../services/ai_quiz_service.dart';
import 'quiz_explanation.dart';
import 'trophy_rules.dart';

/// Categories displayed in the Scan History filter chips and item badges.
enum ScanCategory {
  b3(
    id: 'b3',
    filterLabel: 'B3',
    badgeLabel: 'B3 · Hazardous',
    bg: Color(0xFFFDEDEC),
    fg: Color(0xFFE74C3C),
  ),
  recyclable(
    id: 'recyclable',
    filterLabel: 'Recyclable',
    badgeLabel: 'Recyclable',
    bg: Color(0xFFE8F8F5),
    fg: Color(0xFF16A085),
  ),
  organic(
    id: 'organic',
    filterLabel: 'Organic',
    badgeLabel: 'Organic',
    bg: Color(0xFFFEF9E7),
    fg: Color(0xFFF39C12),
  ),
  residu(
    id: 'residu',
    filterLabel: 'Residu',
    badgeLabel: 'Residu',
    bg: Color(0xFFF2F4F4),
    fg: Color(0xFF7F8C8D),
  );

  const ScanCategory({
    required this.id,
    required this.filterLabel,
    required this.badgeLabel,
    required this.bg,
    required this.fg,
  });

  final String id;
  final String filterLabel;
  final String badgeLabel;
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
        explanation: explanation ?? this.explanation,
      );

  Map<String, dynamic> toJson() => {
        'question': question,
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
      yourAnswer: json['yourAnswer'] as String? ?? '',
      rightAnswer: json['rightAnswer'] as String? ?? '',
      isCorrect: json['isCorrect'] as bool? ?? false,
      trophies: (json['trophies'] as num?)?.toInt(),
      isEssay: json['isEssay'] as bool? ?? false,
      essayScore: (json['essayScore'] as num?)?.toInt(),
      explanation: explanationJson != null ? QuizExplanation.fromJson(explanationJson) : null,
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
    this.schemaVersion = 3, // v3: explanations may carry quote and bankId (0175)
  }) : trophies = trophies ?? trophiesFor(questions);

  int get correctCount => questions.where((q) => q.isCorrect).length;
  int get totalQuestions => questions.isNotEmpty ? questions.length : difficulty.questionCount;
  QuizGrade get grade => gradeFor(trophies: trophies, totalQuestions: totalQuestions);

  String get difficultyLabel => switch (difficulty) {
        QuizDifficulty.easy => 'Easy · 1Q',
        QuizDifficulty.medium => 'Medium · 2Q',
        QuizDifficulty.hard => 'Hard · 3Q',
      };

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
    final questionsList = (json['questions'] as List<dynamic>? ?? [])
        .map((q) => RecordQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
    final diffName = json['difficulty'] as String? ?? 'medium';
    final difficulty = QuizDifficulty.values.firstWhere(
      (d) => d.name == diffName,
      orElse: () => QuizDifficulty.medium,
    );

    return ScanRecord(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
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
