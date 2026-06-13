import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/learning_progress.dart';

/// Handles persistence of [LearningProgress]:
///   • Firestore for authenticated users
///   • SharedPreferences for anonymous/guest users
class ProgressService {
  static const _prefKey = 'elio_learning_progress';
  static const _usersCollection = 'users';
  static const _progressSubcollection = 'learning_progress';
  static const _learningDocId = 'main';

  final FirebaseFirestore _firestore;
  bool _lastLoadUsedFallback = false;

  ProgressService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  bool get lastLoadUsedFallback => _lastLoadUsedFallback;

  void markLoadFallback() {
    _lastLoadUsedFallback = true;
  }

  // ---------------------------------------------------------------------------
  // Firestore
  // ---------------------------------------------------------------------------

  Future<LearningProgress> loadFromFirestore(String userId) async {
    debugPrint('Loading progress from Firestore for signed-in user');
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .collection(_progressSubcollection)
          .doc(_learningDocId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return loadFromLocal(userId);
      }

      final progress = LearningProgress.fromMap(
        doc.data()!,
      ).copyWith(userId: userId);
      try {
        await saveToLocal(progress);
      } catch (error) {
        debugPrint('Could not cache Firestore progress locally: $error');
      }
      return progress;
    } on FirebaseException catch (error) {
      _lastLoadUsedFallback = true;
      debugPrint(
        'Firestore progress unavailable, using empty/local progress: '
        '${error.code} ${error.message ?? ''}',
      );
      return loadFromLocal(userId);
    }
  }

  Future<void> saveToFirestore(LearningProgress progress) async {
    debugPrint('Saving learning progress to Firestore');
    await _firestore
        .collection(_usersCollection)
        .doc(progress.userId)
        .collection(_progressSubcollection)
        .doc(_learningDocId)
        .set({
          ...progress.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    debugPrint('Learning progress saved successfully');
  }

  Future<void> clearFromFirestore(String userId) async {
    await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_progressSubcollection)
        .doc(_learningDocId)
        .delete();
  }

  // ---------------------------------------------------------------------------
  // SharedPreferences (guest / offline)
  // ---------------------------------------------------------------------------

  Future<LearningProgress> loadFromLocal(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(_prefKeyFor(userId)) ?? prefs.getString(_prefKey);
      if (raw == null) return LearningProgress.empty(userId);

      final progress = LearningProgress.fromJson(raw);
      if (progress.userId != userId) {
        return LearningProgress.empty(userId);
      }
      return progress;
    } catch (error) {
      debugPrint('Local progress unavailable, using empty progress: $error');
      return LearningProgress.empty(userId);
    }
  }

  Future<void> saveToLocal(LearningProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyFor(progress.userId), progress.toJson());
  }

  Future<void> clearLocal(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyFor(userId));
  }

  // ---------------------------------------------------------------------------
  // Unified API — caller picks backend via [isGuest]
  // ---------------------------------------------------------------------------

  Future<LearningProgress> load(String userId, {required bool isGuest}) async {
    _lastLoadUsedFallback = false;
    if (isGuest) {
      debugPrint('Loading guest progress from local storage');
      return loadFromLocal(userId);
    }
    return loadFromFirestore(userId);
  }

  Future<bool> save(LearningProgress progress, {required bool isGuest}) async {
    if (isGuest) {
      debugPrint('Saving guest progress locally');
      await saveToLocal(progress);
      return true;
    }

    try {
      await saveToLocal(progress);
    } catch (error) {
      debugPrint('Could not cache progress locally: $error');
    }

    try {
      await saveToFirestore(progress);
      return true;
    } on FirebaseException catch (error) {
      _lastLoadUsedFallback = true;
      debugPrint(
        'Learning progress save failed: '
        '${error.code} ${error.message ?? ''}',
      );
      return false;
    } catch (error) {
      _lastLoadUsedFallback = true;
      debugPrint('Learning progress save failed: $error');
      return false;
    }
  }

  Future<void> clear(String userId, {required bool isGuest}) {
    return isGuest ? clearLocal(userId) : _clearAuthenticated(userId);
  }

  Future<void> _clearAuthenticated(String userId) async {
    await clearLocal(userId);
    try {
      await clearFromFirestore(userId);
    } on FirebaseException catch (error) {
      _lastLoadUsedFallback = true;
      debugPrint(
        'Firestore progress clear unavailable; local progress was cleared: '
        '${error.code} ${error.message ?? ''}',
      );
    }
  }

  String _prefKeyFor(String userId) => '${_prefKey}_$userId';
}
