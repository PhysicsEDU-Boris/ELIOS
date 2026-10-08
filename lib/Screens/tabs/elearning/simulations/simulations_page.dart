import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/physics_module.dart';
import '../../../../widgets/elio_learning_app_bar.dart';
import '../../../../theme/elio_learning_colors.dart';
import 'torque_simulation_page.dart';
import 'density_simulation_page.dart';
import 'heat_simulation_page.dart';
import 'work_energy_simulation_page.dart';
import 'kinematics_simulation_page.dart';
import 'pwm_simulation_page.dart';
import 'power_budget_simulation_page.dart';
import 'deep_dive_simulation_page.dart';
import '../quiz/physics_quiz_page.dart';
import 'widgets/meta_chip.dart';
import '../../../../providers/physics_progress_provider.dart';
import '../../../../models/physics_progress.dart';

/// Standalone route (used if you ever want to deep-link straight to this
/// page). Inside the Learn tab, use `SimulationsContent` instead — see
/// `simulations_page.dart` integration note.
class SimulationsPage extends StatelessWidget {
  const SimulationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: elioBackground,
      appBar: const ElioLearningAppBar(title: 'Simulasi', showBack: true),
      body: const SimulationsContent(),
    );
  }
}

class SimulationsContent extends ConsumerWidget {
  const SimulationsContent({super.key});

  void _openModule(BuildContext context, WidgetRef ref, PhysicsModule module) {
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
          MaterialPageRoute<void>(builder: (_) => const TorqueSimulationPage()),
        );
        break;
      case PhysicsModuleId.density:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DensitySimulationPage()),
        );
        break;
      case PhysicsModuleId.heat:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const HeatSimulationPage()),
        );
        break;
      case PhysicsModuleId.workEnergy:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const WorkEnergySimulationPage()),
        );
        break;
      case PhysicsModuleId.kinematics:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const KinematicsSimulationPage()),
        );
        break;
      case PhysicsModuleId.pwm:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PwmSimulationPage()),
        );
        break;
      case PhysicsModuleId.power:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PowerBudgetSimulationPage()),
        );
        break;
      case PhysicsModuleId.deepDive:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DeepDiveSimulationPage()),
        );
        break;
      case PhysicsModuleId.quiz:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PhysicsQuizPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressState = ref.watch(physicsProgressProvider);
    final progress = progressState.valueOrNull;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simulasi Fisika\nRobot ELIO',
                  style: GoogleFonts.inter(
                    color: elioInk,
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Geser slider dan sentuh diagram untuk melihat rumus '
                  'fisika bekerja secara langsung pada setiap sistem ELIO.',
                  style: GoogleFonts.inter(
                    color: elioMuted,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 20),
                  _PhysicsProgressOverviewCard(progress: progress),
                ],
                const SizedBox(height: 26),
                for (final module in physicsModules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SimulationCard(
                      module: module,
                      isCompleted: progress?.viewedModuleIds.contains(module.id.name) ?? false,
                      onTap: () => _openModule(context, ref, module),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SimulationCard extends StatelessWidget {
  final PhysicsModule module;
  final bool isCompleted;
  final VoidCallback onTap;

  const _SimulationCard({required this.module, this.isCompleted = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: elioBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: module.softColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(module.icon, color: module.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          module.tag,
                          style: GoogleFonts.inter(
                            color: module.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        if (!module.isAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: elioBorder,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Segera Hadir',
                              style: GoogleFonts.inter(
                                color: elioMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else ...[
                          const SizedBox(width: 8),
                          if (isCompleted) ...[
                            const _StatusBadge(label: 'Selesai', color: elioOk),
                          ] else ...[
                            const _StatusBadge(label: 'Tersedia', color: elioPrimary),
                          ]
                        ]
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      module.title,
                      style: GoogleFonts.inter(
                        color: elioInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      module.description,
                      style: GoogleFonts.inter(
                        color: elioMuted,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        MetaChip(
                          icon: Icons.functions_rounded,
                          label: module.formula,
                        ),
                        MetaChip(
                          icon: Icons.schedule_rounded,
                          label: '${module.durationMinutes} min',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                module.isAvailable
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: elioMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PhysicsProgressOverviewCard extends StatelessWidget {
  final PhysicsProgress progress;

  const _PhysicsProgressOverviewCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    // We calculate progress based on viewed modules
    final activeModules = progress.viewedModuleIds.length;
    final totalModules = physicsModules.length;
    final percent = totalModules == 0 ? 0 : ((activeModules / totalModules) * 100).round();
    final value = percent / 100.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF123524).withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: elioPrimary,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progres Simulasi',
                        style: GoogleFonts.inter(
                          color: elioInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        activeModules == 0
                            ? 'Mulai modul untuk melacak progres'
                            : '$activeModules dari $totalModules modul selesai',
                        style: GoogleFonts.inter(
                          color: elioMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$percent%',
                  style: GoogleFonts.inter(
                    color: elioPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 9,
                backgroundColor: const Color(0xFFE8EFEB),
                valueColor: const AlwaysStoppedAnimation(elioPrimary),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              '$percent% Overall Completion',
              style: GoogleFonts.inter(
                color: elioMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
