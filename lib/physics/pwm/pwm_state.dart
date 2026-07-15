class PwmState {
  final double dutyPercent;
  static const double vMax = 12.0;

  const PwmState({this.dutyPercent = 60.0});

  double get averageVoltage => vMax * (dutyPercent / 100.0);

  // Note: This is a linear approximation, not physically exact.
  // Real motor RPM depends non-linearly on load torque, inductance, and back-EMF.
  double get approxRpm => 300.0 * (dutyPercent / 100.0);

  PwmState copyWith({double? dutyPercent}) {
    return PwmState(dutyPercent: dutyPercent ?? this.dutyPercent);
  }
}
