import 'dart:convert';

/// Progress for a single waste category.
class CategoryProgress {
  final String categoryId;

  /// Whether the user has opened the lesson detail screen.
  final bool lessonViewed;

  /// Best quiz score achieved across all attempts.
  final int quizBestScore;

  /// Total number of quiz attempts.
  final int quizAttempts;

  /// Total number of questions in the quiz (set on first attempt).
  final int totalQuestions;

  /// When the category was last interacted with.
  final DateTime? lastAccessed;

  const CategoryProgress({
    required this.categoryId,
    this.lessonViewed = false,
    this.quizBestScore = 0,
    this.quizAttempts = 0,
    this.totalQuestions = 0,
    this.lastAccessed,
  });

  static const double _lessonViewWeight = 0.4;
  static const double _quizScoreWeight = 0.6;

  /// 0.0 – 1.0 composite score:
  ///   [_lessonViewWeight] for viewing the lesson,
  ///   [_quizScoreWeight] × (bestScore / totalQuestions) for the quiz.
  double get progressPercentage {
    if (totalQuestions == 0) return lessonViewed ? _lessonViewWeight : 0.0;
    final quizFraction = quizBestScore / totalQuestions;
    final lessonFraction = lessonViewed ? _lessonViewWeight : 0.0;
    return (lessonFraction + quizFraction * _quizScoreWeight).clamp(0.0, 1.0);
  }

  CategoryProgress copyWith({
    bool? lessonViewed,
    int? quizBestScore,
    int? quizAttempts,
    int? totalQuestions,
    DateTime? lastAccessed,
  }) {
    return CategoryProgress(
      categoryId: categoryId,
      lessonViewed: lessonViewed ?? this.lessonViewed,
      quizBestScore: quizBestScore ?? this.quizBestScore,
      quizAttempts: quizAttempts ?? this.quizAttempts,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      lastAccessed: lastAccessed ?? this.lastAccessed,
    );
  }

  Map<String, dynamic> toMap() => {
    'categoryId': categoryId,
    'lessonViewed': lessonViewed,
    'quizBestScore': quizBestScore,
    'quizAttempts': quizAttempts,
    'totalQuestions': totalQuestions,
    'lastAccessed': lastAccessed?.toIso8601String(),
  };

  factory CategoryProgress.fromMap(Map<String, dynamic> map) {
    final rawLastAccessed = map['lastAccessed'];
    return CategoryProgress(
      categoryId: (map['categoryId'] as String?) ?? '',
      lessonViewed: (map['lessonViewed'] as bool?) ?? false,
      quizBestScore: (map['quizBestScore'] as int?) ?? 0,
      quizAttempts: (map['quizAttempts'] as int?) ?? 0,
      totalQuestions: (map['totalQuestions'] as int?) ?? 0,
      lastAccessed: rawLastAccessed is String
          ? DateTime.tryParse(rawLastAccessed)
          : null,
    );
  }
}

class QuizReviewAnswer {
  final String questionId;
  final String question;
  final String? imageUrl;
  final List<String> options;
  final int correctIndex;
  final int? selectedIndex;
  final String explanation;
  final String difficulty;
  final int order;

  const QuizReviewAnswer({
    required this.questionId,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.selectedIndex,
    required this.explanation,
    required this.difficulty,
    required this.order,
    this.imageUrl,
  });

  bool get isCorrect => selectedIndex != null && selectedIndex == correctIndex;

  Map<String, dynamic> toMap() => {
    'questionId': questionId,
    'question': question,
    'imageUrl': imageUrl,
    'options': options,
    'correctIndex': correctIndex,
    'selectedIndex': selectedIndex,
    'explanation': explanation,
    'difficulty': difficulty,
    'order': order,
  };

  factory QuizReviewAnswer.fromMap(Map<String, dynamic> map) {
    return QuizReviewAnswer(
      questionId: (map['questionId'] ?? '').toString(),
      question: (map['question'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? map['imagePath'] ?? map['imageAsset'])
          ?.toString(),
      options: (map['options'] as List<dynamic>? ?? const [])
          .map((option) => option.toString())
          .toList(),
      correctIndex: LearningProgress._intFromValue(map['correctIndex']),
      selectedIndex: map['selectedIndex'] == null
          ? null
          : LearningProgress._intFromValue(map['selectedIndex']),
      explanation: (map['explanation'] ?? '').toString(),
      difficulty: (map['difficulty'] ?? '').toString(),
      order: LearningProgress._intFromValue(map['order']),
    );
  }
}

class QuizReview {
  final String moduleId;
  final String quizTitle;
  final int score;
  final int totalQuestions;
  final int percent;
  final bool passed;
  final DateTime completedAt;
  final List<QuizReviewAnswer> answers;

  const QuizReview({
    required this.moduleId,
    required this.quizTitle,
    required this.score,
    required this.totalQuestions,
    required this.percent,
    required this.passed,
    required this.completedAt,
    required this.answers,
  });

  Map<String, dynamic> toMap() => {
    'moduleId': moduleId,
    'quizTitle': quizTitle,
    'score': score,
    'totalQuestions': totalQuestions,
    'percent': percent,
    'passed': passed,
    'completedAt': completedAt.toIso8601String(),
    'answers': answers.map((answer) => answer.toMap()).toList(),
  };

  factory QuizReview.fromMap(Map<String, dynamic> map) {
    return QuizReview(
      moduleId: (map['moduleId'] ?? '').toString(),
      quizTitle: (map['quizTitle'] ?? '').toString(),
      score: LearningProgress._intFromValue(map['score']),
      totalQuestions: LearningProgress._intFromValue(map['totalQuestions']),
      percent: LearningProgress._intFromValue(map['percent']),
      passed: map['passed'] == true,
      completedAt:
          LearningProgress._parseDateTime(map['completedAt']) ?? DateTime.now(),
      answers: (map['answers'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (answer) =>
                QuizReviewAnswer.fromMap(Map<String, dynamic>.from(answer)),
          )
          .toList(),
    );
  }
}

/// Aggregated learning progress for one user.
class LearningProgress {
  static const int fallbackTotalVideoLessons = 10;
  static const int fallbackTotalGuideLessons = 4;
  static const int fallbackTotalQuizModules = 3;

  final String userId;

  /// Keyed by [WasteCategory.id].
  final Map<String, CategoryProgress> categories;

  final Set<String> completedVideoIds;
  final Set<String> completedGuideIds;
  final Map<String, int> quizScores;
  final Map<String, int> videoWatchProgress;
  final Map<String, int> guideReadProgress;
  final Map<String, DateTime> videoLastAccessed;
  final Map<String, DateTime> guideLastAccessed;
  final Map<String, DateTime> quizLastAccessed;
  final Map<String, QuizReview> quizReviews;
  final Set<String> completedQuizModules;
  final int totalWatchSeconds;
  final int totalReadMinutes;
  final DateTime? lastUpdated;

  LearningProgress({
    required this.userId,
    this.categories = const {},
    this.completedVideoIds = const <String>{},
    this.completedGuideIds = const <String>{},
    this.quizScores = const <String, int>{},
    this.videoWatchProgress = const <String, int>{},
    this.guideReadProgress = const <String, int>{},
    Map<String, DateTime>? videoLastAccessed,
    Map<String, DateTime>? guideLastAccessed,
    Map<String, DateTime>? quizLastAccessed,
    this.quizReviews = const <String, QuizReview>{},
    this.completedQuizModules = const <String>{},
    this.totalWatchSeconds = 0,
    this.totalReadMinutes = 0,
    this.lastUpdated,
  }) : videoLastAccessed = Map.unmodifiable(
         videoLastAccessed ?? const <String, DateTime>{},
       ),
       guideLastAccessed = Map.unmodifiable(
         guideLastAccessed ?? const <String, DateTime>{},
       ),
       quizLastAccessed = Map.unmodifiable(
         quizLastAccessed ?? const <String, DateTime>{},
       );

  /// Average progress across all tracked categories (0.0 – 1.0).
  double get overallProgress {
    if (categories.isEmpty) return 0.0;
    final total = categories.values.fold<double>(
      0.0,
      (sum, c) => sum + c.progressPercentage,
    );
    return total / categories.length;
  }

  int get completedLessonsCount =>
      completedVideoIds.length + completedGuideIds.length;

  int get totalLessonsCount =>
      fallbackTotalVideoLessons + fallbackTotalGuideLessons;

  int get completedModulesCount => completedQuizModules.length;

  int get totalModulesCount => fallbackTotalQuizModules;

  int get completedLearningItemsCount =>
      completedLessonsCount + completedQuizModules.length;

  int get totalLearningItemsCount =>
      totalLessonsCount + fallbackTotalQuizModules;

  int totalLessonsCountFor({
    required int totalVideos,
    required int totalGuides,
  }) {
    return totalVideos + totalGuides;
  }

  int totalLearningItemsCountFor({
    required int totalVideos,
    required int totalGuides,
    required int totalQuizModules,
  }) {
    return totalVideos + totalGuides + totalQuizModules;
  }

  int get savedWatchSeconds =>
      videoWatchProgress.values.fold(0, (sum, seconds) => sum + seconds);

  LearningProgress copyWith({
    String? userId,
    Map<String, CategoryProgress>? categories,
    Set<String>? completedVideoIds,
    Set<String>? completedGuideIds,
    Map<String, int>? quizScores,
    Map<String, int>? videoWatchProgress,
    Map<String, int>? guideReadProgress,
    Map<String, DateTime>? videoLastAccessed,
    Map<String, DateTime>? guideLastAccessed,
    Map<String, DateTime>? quizLastAccessed,
    Map<String, QuizReview>? quizReviews,
    Set<String>? completedQuizModules,
    int? totalWatchSeconds,
    int? totalReadMinutes,
    DateTime? lastUpdated,
  }) {
    return LearningProgress(
      userId: userId ?? this.userId,
      categories: categories ?? this.categories,
      completedVideoIds: completedVideoIds ?? this.completedVideoIds,
      completedGuideIds: completedGuideIds ?? this.completedGuideIds,
      quizScores: quizScores ?? this.quizScores,
      videoWatchProgress: videoWatchProgress ?? this.videoWatchProgress,
      guideReadProgress: guideReadProgress ?? this.guideReadProgress,
      videoLastAccessed: videoLastAccessed ?? this.videoLastAccessed,
      guideLastAccessed: guideLastAccessed ?? this.guideLastAccessed,
      quizLastAccessed: quizLastAccessed ?? this.quizLastAccessed,
      quizReviews: quizReviews ?? this.quizReviews,
      completedQuizModules: completedQuizModules ?? this.completedQuizModules,
      totalWatchSeconds: totalWatchSeconds ?? this.totalWatchSeconds,
      totalReadMinutes: totalReadMinutes ?? this.totalReadMinutes,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'categories': {for (final e in categories.entries) e.key: e.value.toMap()},
    'completedVideoIds': completedVideoIds.toList(),
    'completedGuideIds': completedGuideIds.toList(),
    'quizScores': quizScores,
    'videoWatchProgress': videoWatchProgress,
    'guideReadProgress': guideReadProgress,
    'videoLastAccessed': videoLastAccessed.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    ),
    'guideLastAccessed': guideLastAccessed.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    ),
    'quizLastAccessed': quizLastAccessed.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    ),
    'quizReviews': quizReviews.map(
      (key, value) => MapEntry(key, value.toMap()),
    ),
    'completedQuizModules': completedQuizModules.toList(),
    'totalWatchSeconds': totalWatchSeconds,
    'totalReadMinutes': totalReadMinutes,
    'lastUpdated': lastUpdated?.toIso8601String(),
  };

  factory LearningProgress.fromMap(Map<String, dynamic> map) {
    final rawCats = map['categories'];
    final cats = <String, CategoryProgress>{};
    if (rawCats is Map) {
      for (final entry in rawCats.entries) {
        if (entry.value is Map<String, dynamic>) {
          cats[entry.key as String] = CategoryProgress.fromMap(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    final rawQuizScores = map['quizScores'];
    final quizScores = rawQuizScores is Map
        ? _parseQuizScores(rawQuizScores)
        : _deriveQuizScores(cats);

    final rawCompletedQuizModules = map['completedQuizModules'];
    final completedQuizModules = rawCompletedQuizModules is List
        ? _stringSetFromList(rawCompletedQuizModules)
        : _deriveCompletedQuizModules(cats);

    final rawVideoWatchProgress = map['videoWatchProgress'];
    final rawGuideReadProgress = map['guideReadProgress'];
    final rawLastUpdated = map['lastUpdated'];
    return LearningProgress(
      userId: (map['userId'] as String?) ?? '',
      categories: cats,
      completedVideoIds: map['completedVideoIds'] is List
          ? _stringSetFromList(map['completedVideoIds'] as List)
          : const <String>{},
      completedGuideIds: map['completedGuideIds'] is List
          ? _stringSetFromList(map['completedGuideIds'] as List)
          : const <String>{},
      quizScores: quizScores,
      videoWatchProgress: rawVideoWatchProgress is Map
          ? _parseStringIntMap(rawVideoWatchProgress)
          : const <String, int>{},
      guideReadProgress: rawGuideReadProgress is Map
          ? _parseStringIntMap(rawGuideReadProgress)
          : const <String, int>{},
      videoLastAccessed: _parseDateTimeMap(map['videoLastAccessed']),
      guideLastAccessed: _parseDateTimeMap(map['guideLastAccessed']),
      quizLastAccessed: _parseDateTimeMap(map['quizLastAccessed']),
      quizReviews: _quizReviewsFromValue(map['quizReviews']),
      completedQuizModules: completedQuizModules,
      totalWatchSeconds: map['totalWatchSeconds'] is num
          ? (map['totalWatchSeconds'] as num).toInt()
          : 0,
      totalReadMinutes: map['totalReadMinutes'] is num
          ? (map['totalReadMinutes'] as num).toInt()
          : 0,
      lastUpdated: rawLastUpdated is String
          ? DateTime.tryParse(rawLastUpdated)
          : null,
    );
  }

  /// Convenience: empty progress for [userId].
  factory LearningProgress.empty(String userId) =>
      LearningProgress(userId: userId);

  // JSON helpers used by SharedPreferences persistence.
  String toJson() => jsonEncode(toMap());

  factory LearningProgress.fromJson(String source) =>
      LearningProgress.fromMap(jsonDecode(source) as Map<String, dynamic>);


  static Set<String> _stringSetFromList(List<dynamic> list) =>
      list.whereType<String>().toSet();

  static Map<String, int> _parseQuizScores(Map<dynamic, dynamic> map) {
    final scores = <String, int>{};
    for (final entry in map.entries) {
      if (entry.key is String && entry.value is num) {
        scores[entry.key as String] = (entry.value as num).toInt();
      }
    }
    return scores;
  }

  static Map<String, int> _parseStringIntMap(Map<dynamic, dynamic> map) {
    final values = <String, int>{};
    for (final entry in map.entries) {
      if (entry.key is String && entry.value is num) {
        final value = (entry.value as num).toInt();
        values[entry.key as String] = value < 0 ? 0 : value;
      }
    }
    return values;
  }

  static Map<String, DateTime> _parseDateTimeMap(dynamic value) {
    if (value is! Map) return const <String, DateTime>{};

    final parsed = <String, DateTime>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || key.trim().isEmpty) continue;

      final date = _parseDateTime(entry.value);
      if (date == null) continue;

      parsed[key] = date;
    }
    return parsed;
  }

  static int _intFromValue(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static Map<String, QuizReview> _quizReviewsFromValue(dynamic value) {
    if (value is! Map) return const <String, QuizReview>{};

    final reviews = <String, QuizReview>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final rawReview = entry.value;

      if (key.trim().isEmpty || rawReview is! Map) continue;

      reviews[key] = QuizReview.fromMap(Map<String, dynamic>.from(rawReview));
    }
    return reviews;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);

    try {
      final converted = (value as dynamic).toDate();
      if (converted is DateTime) return converted;
    } catch (_) {
      return null;
    }

    return null;
  }

  static Map<String, int> _deriveQuizScores(
    Map<String, CategoryProgress> categories,
  ) {
    final scores = <String, int>{};
    for (final entry in categories.entries) {
      final category = entry.value;
      if (category.totalQuestions > 0) {
        scores[entry.key] =
            (category.quizBestScore / category.totalQuestions * 100).round();
      }
    }
    return scores;
  }

  static Set<String> _deriveCompletedQuizModules(
    Map<String, CategoryProgress> categories,
  ) {
    const legacyQuizModuleIds = {'organic', 'inorganic', 'hazardous'};
    return categories.entries
        .where(
          (entry) =>
              legacyQuizModuleIds.contains(entry.key) &&
              entry.value.totalQuestions > 0 &&
              entry.value.quizBestScore / entry.value.totalQuestions >= 0.70,
        )
        .map((entry) => entry.key)
        .toSet();
  }
}
