import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/physics_module.dart';
import 'torque_simulation_page.dart';
import 'density_simulation_page.dart';
import 'heat_simulation_page.dart';
import 'work_energy_simulation_page.dart';
import 'kinematics_simulation_page.dart';
import 'pwm_simulation_page.dart';
import 'power_budget_simulation_page.dart';
import 'deep_dive_simulation_page.dart';
import '../quiz/physics_quiz_page.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../providers/physics_progress_provider.dart';

/// Marks [module] viewed and opens its page.
void openSimulation(BuildContext context, WidgetRef ref, PhysicsModule module) {
  if (!module.isAvailable) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${module.title} segera hadir.')));
    return;
  }

  ref.read(physicsProgressProvider.notifier).markModuleViewed(module.id.name);

  switch (module.id) {
    case PhysicsModuleId.torque:
      Navigator.of(context).push(
        learnRoute<void>(const TorqueSimulationPage()),
      );
      break;
    case PhysicsModuleId.density:
      Navigator.of(context).push(
        learnRoute<void>(const DensitySimulationPage()),
      );
      break;
    case PhysicsModuleId.heat:
      Navigator.of(context).push(
        learnRoute<void>(const HeatSimulationPage()),
      );
      break;
    case PhysicsModuleId.workEnergy:
      Navigator.of(context).push(
        learnRoute<void>(const WorkEnergySimulationPage()),
      );
      break;
    case PhysicsModuleId.kinematics:
      Navigator.of(context).push(
        learnRoute<void>(const KinematicsSimulationPage()),
      );
      break;
    case PhysicsModuleId.pwm:
      Navigator.of(context).push(
        learnRoute<void>(const PwmSimulationPage()),
      );
      break;
    case PhysicsModuleId.power:
      Navigator.of(context).push(
        learnRoute<void>(const PowerBudgetSimulationPage()),
      );
      break;
    case PhysicsModuleId.deepDive:
      Navigator.of(context).push(
        learnRoute<void>(const DeepDiveSimulationPage()),
      );
      break;
    case PhysicsModuleId.quiz:
      Navigator.of(context).push(
        learnRoute<void>(const PhysicsQuizPage()),
      );
      break;
  }
}

