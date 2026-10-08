class KinematicsState {
  final double distanceM;
  final double velocityMs;
  final double robotX;
  final double elapsedS;
  final bool isRunning;

  const KinematicsState({
    this.distanceM = 10.0,
    this.velocityMs = 0.5,
    this.robotX = 0.0,
    this.elapsedS = 0.0,
    this.isRunning = false,
  });

  double get predictedTimeS => distanceM / velocityMs;

  KinematicsState copyWith({
    double? distanceM,
    double? velocityMs,
    double? robotX,
    double? elapsedS,
    bool? isRunning,
  }) {
    return KinematicsState(
      distanceM: distanceM ?? this.distanceM,
      velocityMs: velocityMs ?? this.velocityMs,
      robotX: robotX ?? this.robotX,
      elapsedS: elapsedS ?? this.elapsedS,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  // Returns the new state after a tick of `dt` seconds
  KinematicsState tick(double dt) {
    if (!isRunning) return this;

    double newX = robotX + (velocityMs * dt);
    double newElapsedS = elapsedS + dt;
    bool newIsRunning = true;

    // Clamp at distanceM (overshoot check)
    if (newX >= distanceM) {
      newX = distanceM;
      newElapsedS = distanceM / velocityMs; // Exact time to reach end
      newIsRunning = false; // Auto-stop at target
    }

    return copyWith(
      robotX: newX,
      elapsedS: newElapsedS,
      isRunning: newIsRunning,
    );
  }
}
