import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/physics_progress.dart';
import '../services/progress_service.dart';
import 'auth_provider.dart';

final progressServiceProvider = Provider<ProgressService>((ref) {
  return ProgressService();
});

final physicsProgressProvider = StateNotifierProvider<PhysicsProgressNotifier, AsyncValue<PhysicsProgress>>((ref) {
  return PhysicsProgressNotifier(
    ref.watch(progressServiceProvider),
    ref.watch(currentUserProvider)?.uid,
    ref.watch(isGuestProvider),
  );
});

class PhysicsProgressNotifier extends StateNotifier<AsyncValue<PhysicsProgress>> {
  final ProgressService _service;
  final String? _userId;
  final bool _isGuest;
  Timer? _debounce;

  PhysicsProgressNotifier(this._service, this._userId, this._isGuest)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    if (_userId == null && !_isGuest) {
      state = AsyncValue.data(PhysicsProgress.empty());
      return;
    }
    
    try {
      final progress = await _service.loadPhysics(_userId ?? 'guest', isGuest: _isGuest);
      state = AsyncValue.data(progress);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markModuleViewed(String moduleId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    
    if (current.viewedModuleIds.contains(moduleId)) return;
    
    final newSet = Set<String>.from(current.viewedModuleIds)..add(moduleId);
    _updateState(current.copyWith(viewedModuleIds: newSet));
  }

  Future<void> updateQuizScore(String moduleId, int score) async {
    final current = state.valueOrNull;
    if (current == null) return;
    
    final bestScore = current.quizBestScores[moduleId] ?? 0;
    if (score <= bestScore) return;
    
    final newScores = Map<String, int>.from(current.quizBestScores);
    newScores[moduleId] = score;
    
    _updateState(current.copyWith(quizBestScores: newScores));
  }

  void _updateState(PhysicsProgress newProgress) {
    state = AsyncValue.data(newProgress);
    
    if (_userId == null && !_isGuest) return;
    
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _service.savePhysics(_userId ?? 'guest', newProgress, isGuest: _isGuest);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
