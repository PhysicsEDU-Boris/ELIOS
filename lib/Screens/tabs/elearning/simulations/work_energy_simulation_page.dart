import 'package:flutter/material.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../models/physics_module.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/shared_constants.dart';
import '../../../../../physics/work_energy/work_energy_state.dart';
import '../../../../../physics/work_energy/work_energy_notifier.dart';
import 'painters/work_energy_painter.dart';
import 'widgets/sim_module_header.dart';
import 'widgets/formula_box.dart';
import 'widgets/sim_canvas_frame.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/calc_box.dart';
import 'widgets/deep_explain_card.dart';
import 'widgets/simulation_page_scaffold.dart';

class WorkEnergySimulationPage extends ConsumerWidget {
  const WorkEnergySimulationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workEnergyProvider);
    final notifier = ref.read(workEnergyProvider.notifier);

    final workJ = state.workJoules;
    final batPct = state.batteryPercentRemaining;

    return SimulationPageScaffold(
      module: PhysicsModuleId.workEnergy,
      appBarTitle: 'Usaha & Energi',
      header: const SimModuleHeader(
        tag: 'MODUL D · MATERI',
        title: 'Usaha & Energi Potensial',
        subtitle: 'Setiap gerakan mengangkat beban mengubah energi baterai menjadi energi potensial gravitasi.',
      ),
      formulaBox: FormulaBox(
                    title: 'RUMUS USAHA (W)',
                    formulaText: TextSpan(
                      children: [
                        const TextSpan(text: 'W = m·g·h = '),
                        TextSpan(
                          text: workJ.toStringAsFixed(1),
                          style: TextStyle(color: context.elio.secondaryText),
                        ),
                        const TextSpan(text: ' J'),
                      ],
                    ),
        subtitle: 'm = massa · g = 10 m/s² · h = ketinggian',
      ),
      simulationContent: [
        const SizedBox(height: 16),
                  SimCanvasFrame(
                    noteText: 'Ubah tinggi dan beban untuk melihat dampaknya',
                    canvas: _WorkEnergyCanvas(state: state),
                  ),
                  const SizedBox(height: 16),
                  
                  // Sliders
                  LabeledSlider(
                    label: 'Massa Beban (m)',
                    valueLabel: '${state.massKg.toStringAsFixed(1)} kg',
                    value: state.massKg,
                    min: 0.5,
                    max: 5.0,
                    onChanged: (v) => notifier.setMass(v),
                  ),
                  const SizedBox(height: 14),
                  LabeledSlider(
                    label: 'Ketinggian (h)',
                    valueLabel: '${state.heightM.toStringAsFixed(2)} m',
                    value: state.heightM,
                    min: 0.2,
                    max: 1.5,
                    onChanged: (v) => notifier.setHeight(v),
                  ),
                  const SizedBox(height: 16),

                  CalcBox(
                    headerTitle: 'HASIL PERHITUNGAN',
                    formulaExpression: 'W = ${state.massKg.toStringAsFixed(1)} × 10 × ${state.heightM.toStringAsFixed(1)} = ${workJ.toStringAsFixed(1)} J',
                    statusIcon: Icons.battery_charging_full_rounded,
                    statusColor: context.elio.primaryText,
                    statusText: 'Baterai Tersisa: ${batPct.toStringAsFixed(3)}%',
                  ),
      ],
      deepExplainCard: DeepExplainCard(
                    title: 'Modul D — Usaha & Energi Potensial Gravitasi',
                    bodyText: 'Setiap kali ELIO mengangkat sampah dari nampan ke tempat penampungan yang lebih tinggi, ia melakukan usaha (work) melawan gravitasi. Usaha ini tersimpan sebagai energi potensial gravitasi pada benda yang diangkat — energi yang "siap dilepas" kalau benda itu dijatuhkan kembali.\n\nIni bukan sekadar konsep abstrak: setiap Joule usaha yang dilakukan motor lengan ELIO untuk mengangkat sesuatu berasal dari baterai, sehingga modul ini secara langsung menjelaskan kenapa mengangkat beban berat lebih sering ke ketinggian lebih tinggi = baterai ELIO lebih cepat habis.',
                    bulletPoints: [
                      'W = E_p = m · g · h (Usaha = Energi Potensial = massa × gravitasi × ketinggian).',
                      'g (gravitasi) dibulatkan menjadi 10 m/s² untuk kemudahan hitung.',
                      'Sampah organik cenderung memiliki massa lebih besar per volume dibanding plastik. Untuk beban tipikal organik seberat $kTypicalOrganicLoadKg kg, mengangkatnya ke ketinggian yang sama dengan plastik ringan membutuhkan usaha jauh lebih besar.',
                      'Kapasitas baterai ELIO yang dipakai dalam simulasi ini adalah $kBatteryCapacityJ Joule. %tersisa = 100 - (W / $kBatteryCapacityJ) × 100.'
                    ],
                    // Fixed the math typo in the UI copy (12 J is 99.976% remaining of 50,000 J, not 96.0%)
                  ),
    );
  }
}

class _WorkEnergyCanvas extends StatelessWidget {
  final WorkEnergyState state;

  const _WorkEnergyCanvas({required this.state});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AspectRatio(
          aspectRatio: 340 / 300,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomPaint(
                  painter: WorkEnergyPainter(
                    heightM: state.heightM,
                    massKg: state.massKg,
                  ),
                  size: Size.infinite,
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Usaha (W)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.elio.textSecondary)),
                      const SizedBox(height: 4),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: LinearProgressIndicator(
                            value: state.workJoules / 75.0, // max work is 5*10*1.5 = 75J
                            backgroundColor: context.elio.borderSubtle,
                            color: context.elio.primaryText,
                            minHeight: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${state.workJoules.toStringAsFixed(1)} J', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.elio.primaryText)),
                      
                      const SizedBox(height: 20),
                      
                      Text('Baterai', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.elio.textSecondary)),
                      const SizedBox(height: 4),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: LinearProgressIndicator(
                            value: state.batteryPercentRemaining / 100.0,
                            backgroundColor: context.elio.borderSubtle,
                            color: context.elio.primaryText,
                            minHeight: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${state.batteryPercentRemaining.toStringAsFixed(3)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.elio.primaryText)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
