import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'power_budget_state.dart';

class PowerBudgetNotifier extends Notifier<PowerBudgetState> {
  @override
  PowerBudgetState build() => const PowerBudgetState();

  void toggleCamera(bool v) => state = state.copyWith(cameraOn: v);
  void toggleDrive(bool v) => state = state.copyWith(driveOn: v);
  void toggleArm(bool v) => state = state.copyWith(armOn: v);

  void setTime(double v) => state = state.copyWith(timeS: v.clamp(0.0, 3600.0));

  void applyScenarioSortir() {
    state = state.copyWith(cameraOn: true, driveOn: false, armOn: true);
  }

  void applyScenarioJelajah() {
    state = state.copyWith(cameraOn: true, driveOn: true, armOn: false);
  }

  void applyScenarioIdle() {
    state = state.copyWith(cameraOn: true, driveOn: false, armOn: false);
  }
}

final powerBudgetProvider = NotifierProvider<PowerBudgetNotifier, PowerBudgetState>(PowerBudgetNotifier.new);
