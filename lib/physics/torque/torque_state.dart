import 'dart:math' as math;

enum MotorStatus { safe, warning, critical }

class TorqueState {
  final double armLength; // r, meters
  final double load; // F, newtons
  final double angleDeg; // θ, degrees

  static const double maxSafeTorque = 8.0; // N·m — critical threshold
  static const double warningTorque = 5.0; // N·m — warning threshold
  
  static const double minArmLength = 0.2;
  static const double maxArmLength = 1.0;
  static const double minLoad = 1.0;
  static const double maxLoad = 20.0;
  static const double minAngleDeg = 0.0;
  static const double maxAngleDeg = 90.0;

  const TorqueState({
    this.armLength = 0.5,
    this.load = 4.0,
    this.angleDeg = 90.0,
  });

  double get torque {
    final rad = angleDeg * math.pi / 180;
    return armLength * load * math.sin(rad);
  }

  MotorStatus get motorStatus {
    final tau = torque;
    if (tau > maxSafeTorque) return MotorStatus.critical;
    if (tau > warningTorque) return MotorStatus.warning;
    return MotorStatus.safe;
  }

  double get distractorNoSinTheta => armLength * load;

  TorqueState copyWith({
    double? armLength,
    double? load,
    double? angleDeg,
  }) {
    return TorqueState(
      armLength: armLength ?? this.armLength,
      load: load ?? this.load,
      angleDeg: angleDeg ?? this.angleDeg,
    );
  }
}
