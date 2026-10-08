import '../shared_constants.dart';

class WorkEnergyState {
  final double heightM;
  final double massKg;
  static const g = 10.0;

  const WorkEnergyState({this.heightM = 0.8, this.massKg = 1.5});

  double get workJoules => massKg * g * heightM;
  
  double get batteryPercentRemaining =>
      (100 - (workJoules / kBatteryCapacityJ) * 100).clamp(0, 100);

  // Miskonsepsi distractor test (m*h instead of m*g*h)
  double get distractorMTimeH => massKg * heightM;

  WorkEnergyState copyWith({double? heightM, double? massKg}) {
    return WorkEnergyState(
      heightM: heightM ?? this.heightM,
      massKg: massKg ?? this.massKg,
    );
  }
}
