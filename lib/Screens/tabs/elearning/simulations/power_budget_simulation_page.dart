import 'package:flutter/material.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../models/physics_module.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/power_budget/power_budget_notifier.dart';
import 'widgets/sim_module_header.dart';
import 'widgets/formula_box.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/calc_box.dart';
import 'widgets/deep_explain_card.dart';
import 'widgets/simulation_page_scaffold.dart';

class PowerBudgetSimulationPage extends ConsumerWidget {
  const PowerBudgetSimulationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(powerBudgetProvider);
    final notifier = ref.read(powerBudgetProvider.notifier);

    // Handle estimatedRuntimeS == null (infinity)
    final runtimeStr = state.estimatedRuntimeS == null 
        ? '∞' 
        : '${state.estimatedRuntimeS!.toStringAsFixed(0)} s';

    return SimulationPageScaffold(
      module: PhysicsModuleId.power,
      appBarTitle: 'Daya & Anggaran Baterai',
      header: const SimModuleHeader(
        tag: 'MODUL G · MATERI',
        title: 'Daya & Anggaran Baterai',
        subtitle: 'Berapa lama baterai bertahan? Bergantung pada komponen yang dihidupkan.',
      ),
      formulaBox: FormulaBox(
        title: 'RUMUS DAYA & ENERGI',
        formulaText: TextSpan(
          children: [
            const TextSpan(text: 'E = P_total · t = '),
            TextSpan(
              text: '${state.energyJoules.toStringAsFixed(0)} J',
              style: TextStyle(color: context.elio.secondaryText),
            ),
          ],
        ),
        subtitle: 'P_total = ${state.totalPowerW.toStringAsFixed(0)} Watt · t = waktu (detik)',
      ),
      simulationContent: [
        const SizedBox(height: 16),
                  
                  // Scenario Presets
                  Text(
                    'Preset Skenario:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.elio.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Mode Sortir'),
                        backgroundColor: (state.cameraOn && state.armOn && !state.driveOn) ? context.elio.primaryText.withValues(alpha: 0.1) : context.elio.surface,
                        side: BorderSide(color: (state.cameraOn && state.armOn && !state.driveOn) ? context.elio.primaryText : context.elio.borderSubtle),
                        onPressed: () => notifier.applyScenarioSortir(),
                      ),
                      ActionChip(
                        label: const Text('Mode Jelajah'),
                        backgroundColor: (state.cameraOn && state.driveOn && !state.armOn) ? context.elio.primaryText.withValues(alpha: 0.1) : context.elio.surface,
                        side: BorderSide(color: (state.cameraOn && state.driveOn && !state.armOn) ? context.elio.primaryText : context.elio.borderSubtle),
                        onPressed: () => notifier.applyScenarioJelajah(),
                      ),
                      ActionChip(
                        label: const Text('Idle'),
                        backgroundColor: (state.cameraOn && !state.driveOn && !state.armOn) ? context.elio.primaryText.withValues(alpha: 0.1) : context.elio.surface,
                        side: BorderSide(color: (state.cameraOn && !state.driveOn && !state.armOn) ? context.elio.primaryText : context.elio.borderSubtle),
                        onPressed: () => notifier.applyScenarioIdle(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Component Toggles
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: context.elio.borderSubtle),
                    ),
                    color: context.elio.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Kamera (10W)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            value: state.cameraOn,
                            onChanged: notifier.toggleCamera,
                            activeThumbColor: context.elio.primary,
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Motor Penggerak (36W)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            value: state.driveOn,
                            onChanged: notifier.toggleDrive,
                            activeThumbColor: context.elio.primary,
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Motor Lengan (18W)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            value: state.armOn,
                            onChanged: notifier.toggleArm,
                            activeThumbColor: context.elio.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Sliders
                  LabeledSlider(
                    label: 'Waktu Penggunaan (t)',
                    valueLabel: '${state.timeS.toStringAsFixed(0)} s',
                    value: state.timeS,
                    min: 0.0,
                    max: 3600.0,
                    onChanged: (v) => notifier.setTime(v),
                  ),
                  const SizedBox(height: 16),

                  // Battery Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.elio.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.elio.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Sisa Baterai', style: TextStyle(color: context.elio.textSecondary, fontSize: 12)),
                            Text('${state.remainingPercent.toStringAsFixed(1)}%', style: TextStyle(color: context.elio.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: state.remainingPercent / 100.0,
                          backgroundColor: context.elio.borderSubtle,
                          color: state.remainingPercent > 20 ? context.elio.primaryText : context.elio.errorText,
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  CalcBox(
                    headerTitle: 'PREDIKSI KETAHANAN BATERAI',
                    formulaExpression: 't_estimasi = 50000 J / ${state.totalPowerW.toStringAsFixed(0)} W = $runtimeStr',
                    statusIcon: Icons.access_time_filled_rounded,
                    statusColor: context.elio.primaryText,
                    statusText: 'Bertahan selama $runtimeStr',
                  ),
      ],
      deepExplainCard: const DeepExplainCard(
                    title: 'Modul G — Daya & Anggaran Baterai',
                    bodyText: 'Setiap komponen ELIO yang menyala — kamera, motor penggerak, motor lengan — menarik daya listrik dari baterai yang sama. Modul ini mengajarkan cara menghitung berapa lama baterai akan bertahan tergantung kombinasi komponen mana saja yang sedang aktif, sebuah keputusan yang benar-benar diambil oleh sistem kendali ELIO secara real-time untuk menghemat daya.\n\nPerilaku hemat daya nyata ELIO meniru logika ini secara langsung: motor penggerak dimatikan saat sedang menyortir (karena robot diam di tempat), dan kamera dimatikan saat sedang berpindah tempat jika tidak sedang menganalisis objek — setiap watt yang tidak perlu menyala berarti detik operasi tambahan sebelum baterai perlu diisi ulang.',
                    bulletPoints: [
                      'P = V · I (Daya = Tegangan × Arus). Disini daya (P) sudah ditentukan per komponen.',
                      'E = P · t (Energi = Daya total × waktu).',
                      'Total Kapasitas = 50.000 Joule. t_estimasi = 50.000 / P_total.',
                      'Kamera 10W, Motor Penggerak 36W, Motor Lengan 18W.',
                      'Jika P_total = 0, waktu bertahan secara matematis tak hingga (∞).'
                    ],
                  ),
    );
  }
}
