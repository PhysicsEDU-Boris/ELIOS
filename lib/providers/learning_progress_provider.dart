import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../models/learning_progress.dart';
import '../services/progress_service.dart';
import 'app_notification_provider.dart';
import 'auth_provider.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

final progressServiceProvider = Provider<ProgressService>(
  (_) => ProgressService(),
);

// ---------------------------------------------------------------------------
// Main notifier provider
// ---------------------------------------------------------------------------

final learningProgressProvider =
    AsyncNotifierProvider<LearningProgressNotifier, LearningProgress>(
      LearningProgressNotifier.new,
    );

final progressSyncWarningProvider = Provider<bool>((ref) {
  final progress = ref.watch(learningProgressProvider);
  final service = ref.read(progressServiceProvider);
  return progress.hasError || service.lastLoadUsedFallback;
});

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class LearningProgressNotifier extends AsyncNotifier<LearningProgress> {
  ProgressService get _service => ref.read(progressServiceProvider);

  /// Auto-loads progress for the currently signed-in user.
  /// Re-runs whenever auth state changes.
  @override
  Future<LearningProgress> build() async {
    final user = await ref.watch(authStateProvider.future);
    final isGuest = user == null || user.isAnonymous;
    final userId = user?.uid ?? 'guest';
    return _loadSafely(userId, isGuest: isGuest);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Explicitly (re)load progress for [userId].
  Future<void> loadProgress(String userId) async {
    final user = ref.read(currentUserProvider);
    final isGuest = user == null || user.isAnonymous;
    final effectiveUserId = isGuest ? (user?.uid ?? 'guest') : user.uid;
    state = const AsyncLoading();
    state = AsyncData(await _loadSafely(effectiveUserId, isGuest: isGuest));
  }

  /// Call when a user opens a category detail screen.
  Future<void> markLessonViewed(String categoryId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final existing =
        current.categories[categoryId] ??
        CategoryProgress(categoryId: categoryId);

    if (existing.lessonViewed) return; // already recorded — nothing to do

    final updated = current.copyWith(
      categories: {
        ...current.categories,
        categoryId: existing.copyWith(
          lessonViewed: true,
          lastAccessed: DateTime.now(),
        ),
      },
      lastUpdated: DateTime.now(),
    );

    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> markVideoCompleted(
    String videoId, {
    required String moduleId,
    int watchedSeconds = 0,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.completedVideoIds.contains(videoId)) return;

    final safeWatchedSeconds = watchedSeconds < 0 ? 0 : watchedSeconds;
    final existing =
        current.categories[moduleId] ?? CategoryProgress(categoryId: moduleId);
    final now = DateTime.now();

    final updated = current.copyWith(
      completedVideoIds: {...current.completedVideoIds, videoId},
      videoLastAccessed: {...current.videoLastAccessed, videoId: now},
      totalWatchSeconds: current.totalWatchSeconds + safeWatchedSeconds,
      categories: {
        ...current.categories,
        moduleId: existing.copyWith(lessonViewed: true, lastAccessed: now),
      },
      lastUpdated: now,
    );

    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> updateVideoWatchProgress(
    String videoId, {
    required String moduleId,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    if (videoId.trim().isEmpty || moduleId.trim().isEmpty) return;

    final current = state.valueOrNull;
    if (current == null) return;

    final safeDuration = durationSeconds < 0 ? 0 : durationSeconds;
    final safePosition = safeDuration > 0
        ? positionSeconds.clamp(0, safeDuration).toInt()
        : (positionSeconds < 0 ? 0 : positionSeconds);
    final completionThreshold = safeDuration > 0
        ? math.max(0, safeDuration - 2)
        : 0;
    final shouldComplete =
        safeDuration > 0 && safePosition >= completionThreshold;
    final storedPosition = shouldComplete ? safeDuration : safePosition;
    final previousPosition = current.videoWatchProgress[videoId] ?? 0;
    final nextStoredPosition = shouldComplete
        ? safeDuration
        : math.max(previousPosition, storedPosition);
    final alreadyCompleted = current.completedVideoIds.contains(videoId);
    final nextCompletedVideoIds = shouldComplete || alreadyCompleted
        ? {...current.completedVideoIds, videoId}
        : current.completedVideoIds;

    if (previousPosition == nextStoredPosition &&
        alreadyCompleted == nextCompletedVideoIds.contains(videoId)) {
      return;
    }

    final existing =
        current.categories[moduleId] ?? CategoryProgress(categoryId: moduleId);
    final now = DateTime.now();
    final nextVideoWatchProgress = {
      ...current.videoWatchProgress,
      videoId: nextStoredPosition,
    };
    final totalWatchSeconds = nextVideoWatchProgress.values.fold<int>(
      0,
      (sum, seconds) => sum + seconds,
    );

    final updated = current.copyWith(
      videoWatchProgress: nextVideoWatchProgress,
      videoLastAccessed: {...current.videoLastAccessed, videoId: now},
      completedVideoIds: nextCompletedVideoIds,
      totalWatchSeconds: totalWatchSeconds,
      categories: {
        ...current.categories,
        moduleId: existing.copyWith(
          lessonViewed: shouldComplete || alreadyCompleted
              ? true
              : existing.lessonViewed,
          lastAccessed: now,
        ),
      },
      lastUpdated: now,
    );

    state = AsyncData(updated);
    await _persist(updated);
    if (shouldComplete && !alreadyCompleted) {
      ref
          .read(appNotificationProvider.notifier)
          .push(
            type: AppNotificationType.learning,
            title: 'Video completed',
            message: 'You completed a video lesson.',
            routeHint: 'learning',
          );
    }
  }

  Future<void> markGuideCompleted(
    String guideId, {
    required String moduleId,
    int readMinutes = 0,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.completedGuideIds.contains(guideId)) return;

    final safeReadMinutes = readMinutes < 0 ? 0 : readMinutes;
    final existing =
        current.categories[moduleId] ?? CategoryProgress(categoryId: moduleId);
    final now = DateTime.now();

    final updated = current.copyWith(
      completedGuideIds: {...current.completedGuideIds, guideId},
      guideLastAccessed: {...current.guideLastAccessed, guideId: now},
      totalReadMinutes: current.totalReadMinutes + safeReadMinutes,
      categories: {
        ...current.categories,
        moduleId: existing.copyWith(lessonViewed: true, lastAccessed: now),
      },
      lastUpdated: now,
    );

    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> updateGuideReadProgress(
    String guideId, {
    required String moduleId,
    required int pageReached,
    required int pageCount,
    int readMinutes = 0,
  }) async {
    if (guideId.trim().isEmpty || moduleId.trim().isEmpty) return;

    final current = state.valueOrNull;
    if (current == null) return;

    final safePageCount = pageCount < 0 ? 0 : pageCount;
    final safePageReached = safePageCount > 0
        ? pageReached.clamp(0, safePageCount).toInt()
        : (pageReached < 0 ? 0 : pageReached);
    final previousPageReached = current.guideReadProgress[guideId] ?? 0;
    final nextPageReached = math.max(previousPageReached, safePageReached);
    final shouldComplete =
        safePageCount > 0 && nextPageReached >= safePageCount;
    final alreadyCompleted = current.completedGuideIds.contains(guideId);
    final nextCompletedGuideIds = shouldComplete || alreadyCompleted
        ? {...current.completedGuideIds, guideId}
        : current.completedGuideIds;

    if (previousPageReached == nextPageReached &&
        alreadyCompleted == nextCompletedGuideIds.contains(guideId)) {
      return;
    }

    final safeReadMinutes = readMinutes < 0 ? 0 : readMinutes;
    final existing =
        current.categories[moduleId] ?? CategoryProgress(categoryId: moduleId);
    final now = DateTime.now();
    final nextGuideReadProgress = {
      ...current.guideReadProgress,
      guideId: nextPageReached,
    };

    final updated = current.copyWith(
      guideReadProgress: nextGuideReadProgress,
      guideLastAccessed: {...current.guideLastAccessed, guideId: now},
      completedGuideIds: nextCompletedGuideIds,
      totalReadMinutes:
          current.totalReadMinutes +
          (shouldComplete && !alreadyCompleted ? safeReadMinutes : 0),
      categories: {
        ...current.categories,
        moduleId: existing.copyWith(
          lessonViewed: shouldComplete || alreadyCompleted
              ? true
              : existing.lessonViewed,
          lastAccessed: now,
        ),
      },
      lastUpdated: now,
    );

    state = AsyncData(updated);
    await _persist(updated);
    if (shouldComplete && !alreadyCompleted) {
      ref
          .read(appNotificationProvider.notifier)
          .push(
            type: AppNotificationType.learning,
            title: 'Guide completed',
            message: 'You completed a guide.',
            routeHint: 'learning',
          );
    }
  }

  /// Record a completed quiz attempt for [categoryId].
  ///
  /// [score]          — number of correct answers
  /// [totalQuestions] — total questions in the quiz
  Future<void> updateProgress(
    String categoryId,
    int score,
    int totalQuestions, {
    QuizReview? quizReview,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final existing =
        current.categories[categoryId] ??
        CategoryProgress(categoryId: categoryId);

    final safeTotalQuestions = totalQuestions < 0 ? 0 : totalQuestions;
    final effectiveTotalQuestions = safeTotalQuestions > 0
        ? safeTotalQuestions
        : existing.totalQuestions;
    final safeScore = effectiveTotalQuestions > 0
        ? score.clamp(0, effectiveTotalQuestions).toInt()
        : 0;
    final newBest = safeScore > existing.quizBestScore
        ? safeScore
        : existing.quizBestScore;
    final existingQuizPercent = current.quizScores[categoryId] ?? 0;
    final bestPercent = effectiveTotalQuestions > 0
        ? (newBest / effectiveTotalQuestions * 100)
              .round()
              .clamp(0, 100)
              .toInt()
        : 0;
    final nextQuizScores = effectiveTotalQuestions > 0
        ? {
            ...current.quizScores,
            categoryId: math.max(existingQuizPercent, bestPercent),
          }
        : current.quizScores;
    final passed =
        effectiveTotalQuestions > 0 &&
        newBest / effectiveTotalQuestions >= 0.70;
    final now = DateTime.now();
    final updatedQuizReviews = quizReview == null
        ? current.quizReviews
        : {...current.quizReviews, categoryId: quizReview};

    final updated = current.copyWith(
      categories: {
        ...current.categories,
        categoryId: existing.copyWith(
          quizBestScore: newBest,
          quizAttempts: existing.quizAttempts + 1,
          totalQuestions: effectiveTotalQuestions,
          lessonViewed: true, // taking quiz counts as viewing the lesson
          lastAccessed: now,
        ),
      },
      quizScores: nextQuizScores,
      quizLastAccessed: {...current.quizLastAccessed, categoryId: now},
      quizReviews: updatedQuizReviews,
      completedQuizModules: passed
          ? {...current.completedQuizModules, categoryId}
          : current.completedQuizModules,
      lastUpdated: now,
    );

    state = AsyncData(updated);
    await _persist(updated);
    ref
        .read(appNotificationProvider.notifier)
        .push(
          type: AppNotificationType.quiz,
          title: 'Quiz completed',
          message: 'Your quiz result has been saved.',
          routeHint: 'quiz',
        );
    if (quizReview != null) {
      ref
          .read(appNotificationProvider.notifier)
          .push(
            type: AppNotificationType.quiz,
            title: 'Quiz review available',
            message: 'You can now review your quiz answers.',
            routeHint: 'quizReview',
            metadata: {'moduleId': categoryId},
          );
    }
  }

  /// Clear all progress for the current user.
  Future<void> resetProgress() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final isGuest = ref.read(isGuestProvider);
    await _service.clear(user.uid, isGuest: isGuest);
    state = AsyncData(LearningProgress.empty(user.uid));
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _persist(LearningProgress progress) async {
    final user = ref.read(currentUserProvider);
    final isGuest = user == null || user.isAnonymous;
    final progressToSave = user != null && !user.isAnonymous
        ? progress.copyWith(userId: user.uid)
        : progress;
    try {
      final synced = await _service.save(progressToSave, isGuest: isGuest);

      if (!synced && !isGuest) {
        _service.markLoadFallback();
        ref.invalidate(progressSyncWarningProvider);
        ref
            .read(appNotificationProvider.notifier)
            .push(
              type: AppNotificationType.warning,
              title: 'Progress sync issue',
              message:
                  'Your progress could not be synced. Check your connection.',
            );
      }
    } catch (e, st) {
      debugPrint(
        '[LearningProgressNotifier] persist failed; keeping in-memory '
        'progress: $e',
      );
      debugPrintStack(stackTrace: st);
      if (!isGuest) {
        _service.markLoadFallback();
        ref.invalidate(progressSyncWarningProvider);
        ref
            .read(appNotificationProvider.notifier)
            .push(
              type: AppNotificationType.warning,
              title: 'Progress sync issue',
              message:
                  'Your progress could not be synced. Check your connection.',
            );
      }
    }
  }

  Future<LearningProgress> _loadSafely(
    String userId, {
    required bool isGuest,
  }) async {
    try {
      final progress = await _service.load(userId, isGuest: isGuest);
      return progress;
    } catch (error, stackTrace) {
      debugPrint(
        '[LearningProgressNotifier] load failed, using empty progress: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      if (!isGuest) _service.markLoadFallback();
      return LearningProgress.empty(userId);
    }
  }
}
