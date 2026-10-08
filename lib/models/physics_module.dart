import 'package:flutter/material.dart';

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
  final String tag;
  final String title;
  final String description;
  final String formula;
  final String level;
  final int durationMinutes;
  final Color accent;
  final Color softColor;
  final IconData icon;
  final bool isAvailable;

  const PhysicsModule({
    required this.id,
    required this.tag,
    required this.title,
    required this.description,
    required this.formula,
    required this.level,
    required this.durationMinutes,
    required this.accent,
    required this.softColor,
    required this.icon,
    this.isAvailable = false,
  });
}

/// Hardcoded per your answer — simulations are code anyway, no Firestore
/// round trip needed. Only `torque` is wired to a real page right now;
/// the rest render as "Segera Hadir" (coming soon) cards until built.
const List<PhysicsModule> physicsModules = [
  PhysicsModule(
    id: PhysicsModuleId.density,
    tag: 'Modul A · Lingkungan',
    title: 'Massa Jenis Sampah',
    description:
        'ELIO mengklasifikasi sampah anorganik berdasarkan densitas.',
    formula: 'ρ = m / V',
    level: 'Pemula',
    durationMinutes: 6,
    accent: Color(0xFF2563EB),
    softColor: Color(0xFFDBEAFE),
    icon: Icons.opacity_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.heat,
    tag: 'Modul B · Lingkungan',
    title: 'Panas & Termodinamika Kompos',
    description: 'Dekomposisi mikroba menghasilkan panas seiring waktu.',
    formula: 'Q = m · c · ΔT',
    level: 'Pemula',
    durationMinutes: 7,
    accent: Color(0xFFDC2626),
    softColor: Color(0xFFFEE2E2),
    icon: Icons.local_fire_department_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.torque,
    tag: 'Modul C · Mekanika',
    title: 'Torsi Bahu Robot',
    description: 'Sendi bahu ELIO menahan torsi saat lengan menjulur.',
    formula: 'τ = r · F · sin(θ)',
    level: 'Menengah',
    durationMinutes: 8,
    accent: Color(0xFF00694C),
    softColor: Color(0xFFE6F2EC),
    icon: Icons.settings_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.workEnergy,
    tag: 'Modul D · Mekanika',
    title: 'Usaha & Energi Potensial',
    description: 'Mengangkat beban membutuhkan usaha yang terukur.',
    formula: 'W = m · g · h',
    level: 'Menengah',
    durationMinutes: 6,
    accent: Color(0xFF7C3AED),
    softColor: Color(0xFFEDE9FE),
    icon: Icons.height_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.kinematics,
    tag: 'Modul E · Kinematika',
    title: 'Kecepatan Gerak ELIO',
    description: 'Gerak lurus beraturan menuju tumpukan sampah.',
    formula: 'v = s / t',
    level: 'Pemula',
    durationMinutes: 5,
    accent: Color(0xFF0891B2),
    softColor: Color(0xFFCFFAFE),
    icon: Icons.speed_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.pwm,
    tag: 'Modul F · Elektronika',
    title: 'PWM & Tegangan Motor',
    description: 'Duty cycle mengatur tegangan rata-rata motor roda.',
    formula: 'V_avg = D · V_max',
    level: 'Menengah',
    durationMinutes: 7,
    accent: Color(0xFFCA8A04),
    softColor: Color(0xFFFEF9C3),
    icon: Icons.bolt_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.power,
    tag: 'Modul G · Daya',
    title: 'Daya & Baterai ELIO',
    description: 'Manajemen konsumsi daya komponen robot.',
    formula: 'P = V · I',
    level: 'Menengah',
    durationMinutes: 7,
    accent: Color(0xFF059669),
    softColor: Color(0xFFECFDF5),
    icon: Icons.battery_charging_full_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.deepDive,
    tag: 'Deep-Dive · Waste Physics',
    title: 'Kartu Deep-Dive Sampah',
    description: 'Eksplorasi mendalam: Organik, Inorganik, dan B3.',
    formula: 'O2, Hooke, NIR',
    level: 'Lanjutan',
    durationMinutes: 10,
    accent: Color(0xFF6366F1),
    softColor: Color(0xFFEEF2FF),
    icon: Icons.science_rounded,
    isAvailable: true,
  ),
  PhysicsModule(
    id: PhysicsModuleId.quiz,
    tag: 'Evaluasi',
    title: 'Uji Pemahaman (Kuis)',
    description: 'Uji pengetahuan Anda tentang fisika di balik robot ELIO.',
    formula: 'Quiz',
    level: 'Semua Level',
    durationMinutes: 10,
    accent: Color(0xFFBE185D),
    softColor: Color(0xFFFCE7F3),
    icon: Icons.quiz_rounded,
    isAvailable: true,
  ),
];
