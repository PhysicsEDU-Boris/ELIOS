import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'kinematics_state.dart';

class KinematicsNotifier extends Notifier<KinematicsState> {
  @override
  KinematicsState build() => const KinematicsState();

  void setDistance(double v) {
    // If currently running, we just update the target distance.
    // If we were already stopped at the end, and we increase distance, we don't auto-run.
    state = state.copyWith(distanceM: v.clamp(2.0, 20.0));
  }

  void setVelocity(double v) {
    state = state.copyWith(velocityMs: v.clamp(0.1, 1.0));
  }

  void run() {
    state = state.copyWith(robotX: 0.0, elapsedS: 0.0, isRunning: true);
  }

  void reset() {
    state = state.copyWith(robotX: 0.0, elapsedS: 0.0, isRunning: false);
  }

  void tick(double dt) {
    state = state.tick(dt);
  }
}

final kinematicsProvider = NotifierProvider<KinematicsNotifier, KinematicsState>(KinematicsNotifier.new);
