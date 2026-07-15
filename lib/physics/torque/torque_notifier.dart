import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'torque_state.dart';

class TorqueNotifier extends Notifier<TorqueState> {
  @override
  TorqueState build() => const TorqueState();

  void setArmLength(double value) {
    state = state.copyWith(armLength: _clamp(value, TorqueState.minArmLength, TorqueState.maxArmLength));
  }

  void setLoad(double value) {
    state = state.copyWith(load: _clamp(value, TorqueState.minLoad, TorqueState.maxLoad));
  }

  void setAngle(double value) {
    state = state.copyWith(angleDeg: _clamp(value, TorqueState.minAngleDeg, TorqueState.maxAngleDeg));
  }

  double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

final torqueProvider = NotifierProvider<TorqueNotifier, TorqueState>(TorqueNotifier.new);
