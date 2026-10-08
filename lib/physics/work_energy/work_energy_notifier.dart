import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'work_energy_state.dart';

class WorkEnergyNotifier extends Notifier<WorkEnergyState> {
  @override
  WorkEnergyState build() => const WorkEnergyState();

  void setHeight(double v) =>
      state = state.copyWith(heightM: v.clamp(0.2, 1.5));

  void setMass(double v) =>
      state = state.copyWith(massKg: v.clamp(0.5, 5.0));
}

final workEnergyProvider =
    NotifierProvider<WorkEnergyNotifier, WorkEnergyState>(WorkEnergyNotifier.new);
