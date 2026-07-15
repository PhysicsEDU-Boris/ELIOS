import '../shared_constants.dart';

class PowerBudgetState {
  final bool cameraOn;
  final bool driveOn;
  final bool armOn;
  final double timeS;

  const PowerBudgetState({
    this.cameraOn = false,
    this.driveOn = false,
    this.armOn = false,
    this.timeS = 600.0,
  });

  double get totalPowerW {
    double p = 0;
    if (cameraOn) p += 10.0;
    if (driveOn) p += 36.0;
    if (armOn) p += 18.0;
    return p;
  }

  double get energyJoules => totalPowerW * timeS;

  double get remainingPercent =>
      (100.0 - (energyJoules / kBatteryCapacityJ) * 100.0).clamp(0, 100);

  // null means infinite runtime (when totalPowerW is 0)
  double? get estimatedRuntimeS {
    final p = totalPowerW;
    if (p == 0) return null;
    return kBatteryCapacityJ / p;
  }

  PowerBudgetState copyWith({
    bool? cameraOn,
    bool? driveOn,
    bool? armOn,
    double? timeS,
  }) {
    return PowerBudgetState(
      cameraOn: cameraOn ?? this.cameraOn,
      driveOn: driveOn ?? this.driveOn,
      armOn: armOn ?? this.armOn,
      timeS: timeS ?? this.timeS,
    );
  }
}
