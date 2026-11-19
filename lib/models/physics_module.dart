import 'package:flutter/material.dart';
import 'package:elio/l10n/l10n.dart';

enum PhysicsLevel { beginner, intermediate, advanced, all }

enum PhysicsModuleId {
  density,
  heat,
  torque,
  workEnergy,
  kinematics,
  pwm,
  power,
  deepDive,
  quiz,
}

class PhysicsModule {
  final PhysicsModuleId id;
  final String formula;
  final PhysicsLevel physicsLevel;
  final int durationMinutes;
  final Color accent;
  final Color softColor;
  final IconData icon;
  final bool isAvailable;

  const PhysicsModule({
    required this.id,
    required this.formula,
    required PhysicsLevel level,
    required this.durationMinutes,
    required this.accent,
    required this.softColor,
    required this.icon,
    this.isAvailable = false,
  }) : physicsLevel = level;

  String get level => switch (physicsLevel) {
    PhysicsLevel.beginner => l10n.physLevelBeginner,
    PhysicsLevel.intermediate => l10n.physLevelIntermediate,
    PhysicsLevel.advanced => l10n.physLevelAdvanced,
    PhysicsLevel.all => l10n.physLevelAllLevels,
  };

  /// Card texts in the app language (decision 0185).
  (String, String, String) get _texts => switch (id) {
    PhysicsModuleId.density => (
      l10n.physDensityTag,
      l10n.physDensityTitle,
      l10n.physDensityDesc,
    ),
    PhysicsModuleId.heat => (
      l10n.physHeatTag,
      l10n.physHeatTitle,
      l10n.physHeatDesc,
    ),
    PhysicsModuleId.torque => (
      l10n.physTorqueTag,
      l10n.physTorqueTitle,
      l10n.physTorqueDesc,
    ),
    PhysicsModuleId.workEnergy => (
      l10n.physWorkEnergyTag,
      l10n.physWorkEnergyTitle,
      l10n.physWorkEnergyDesc,
    ),
    PhysicsModuleId.kinematics => (
      l10n.physKinematicsTag,
      l10n.physKinematicsTitle,
      l10n.physKinematicsDesc,
    ),
    PhysicsModuleId.pwm => (
      l10n.physPwmTag,
      l10n.physPwmTitle,
      l10n.physPwmDesc,
    ),
    PhysicsModuleId.power => (
      l10n.physPowerTag,
      l10n.physPowerTitle,
      l10n.physPowerDesc,
    ),
    PhysicsModuleId.deepDive => (
      l10n.physDeepDiveTag,
      l10n.physDeepDiveTitle,
      l10n.physDeepDiveDesc,
    ),
    PhysicsModuleId.quiz => (
      l10n.physQuizTag,
      l10n.physQuizTitle,
      l10n.physQuizDesc,
    ),
  };
  String get tag => _texts.$1;
  String get title => _texts.$2;
  String get description => _texts.$3;
}

/// Hardcoded per your answer — simulations are code anyway, no Firestore
/// round trip needed. Only `torque` is wired to a real page right now;
/// the rest render as "Segera Hadir" (coming soon) cards until built.
const List<PhysicsModule> physicsModules = [
  PhysicsModule(
    id: PhysicsModuleId.density,
    formula: 'ρ = m / V',
    level: PhysicsLevel.beginner,
    durationMinutes: 6,
    accent: Color(0xFF2563EB),
    softColor: Color(0xFFDBEAFE),
    icon: Icons.opacity_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.heat,
    formula: 'Q = m · c · ΔT',
    level: PhysicsLevel.beginner,
    durationMinutes: 7,
    accent: Color(0xFFDC2626),
    softColor: Color(0xFFFEE2E2),
    icon: Icons.local_fire_department_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.torque,
    formula: 'τ = r · F · sin(θ)',
    level: PhysicsLevel.intermediate,
    durationMinutes: 8,
    accent: Color(0xFF00694C),
    softColor: Color(0xFFE6F2EC),
    icon: Icons.settings_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.workEnergy,
    formula: 'W = m · g · h',
    level: PhysicsLevel.intermediate,
    durationMinutes: 6,
    accent: Color(0xFF7C3AED),
    softColor: Color(0xFFEDE9FE),
    icon: Icons.height_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.kinematics,
    formula: 'v = s / t',
    level: PhysicsLevel.beginner,
    durationMinutes: 5,
    accent: Color(0xFF0891B2),
    softColor: Color(0xFFCFFAFE),
    icon: Icons.speed_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.pwm,
    formula: 'V_avg = D · V_max',
    level: PhysicsLevel.intermediate,
    durationMinutes: 7,
    accent: Color(0xFFCA8A04),
    softColor: Color(0xFFFEF9C3),
    icon: Icons.bolt_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.power,
    formula: 'P = V · I',
    level: PhysicsLevel.intermediate,
    durationMinutes: 7,
    accent: Color(0xFF059669),
    softColor: Color(0xFFECFDF5),
    icon: Icons.battery_charging_full_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.deepDive,
    formula: 'O2, Hooke, NIR',
    level: PhysicsLevel.advanced,
    durationMinutes: 10,
    accent: Color(0xFF6366F1),
    softColor: Color(0xFFEEF2FF),
    icon: Icons.science_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.quiz,
    formula: 'Quiz',
    level: PhysicsLevel.all,
    durationMinutes: 10,
    accent: Color(0xFFBE185D),
    softColor: Color(0xFFFCE7F3),
    icon: Icons.quiz_rounded,
    isAvailable: true,
  ),
];
