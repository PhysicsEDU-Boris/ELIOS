import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learning_progress.dart';
import '../services/progress_service.dart';
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

  /// Record a completed quiz attempt for [categoryId].
  ///
  /// [score]          — number of correct answers
  /// [totalQuestions] — total questions in the quiz
  Future<void> updateProgress(
    String categoryId,
    int score,
    int totalQuestions,
  ) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final existing =
        current.categories[categoryId] ??
        CategoryProgress(categoryId: categoryId);

    final newBest = score > existing.quizBestScore
        ? score
        : existing.quizBestScore;

    final updated = current.copyWith(
      categories: {
        ...current.categories,
        categoryId: existing.copyWith(
          quizBestScore: newBest,
          quizAttempts: existing.quizAttempts + 1,
          totalQuestions: totalQuestions,
          lessonViewed: true, // taking quiz counts as viewing the lesson
          lastAccessed: DateTime.now(),
        ),
      },
      lastUpdated: DateTime.now(),
    );

    state = AsyncData(updated);
    await _persist(updated);
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
