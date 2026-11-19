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
import 'package:elio/l10n/l10n.dart';

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
      appBarTitle: l10n.simWorkEnergy1,
      header: SimModuleHeader(
        tag: l10n.simWorkEnergy2,
        title: l10n.simWorkEnergy3,
        subtitle: l10n.simWorkEnergy4,
      ),
      formulaBox: FormulaBox(
        title: l10n.simWorkEnergy5,
        formulaText: TextSpan(
          children: [
            const TextSpan(text: 'W = m·g·h = '),
            TextSpan(
              text: fmtNum(workJ, 1),
              style: TextStyle(color: context.elio.secondaryText),
            ),
            const TextSpan(text: ' J'),
          ],
        ),
        subtitle: l10n.simWorkEnergy6,
      ),
      simulationContent: [
        const SizedBox(height: 16),
        SimCanvasFrame(
          noteText: l10n.simWorkEnergy7,
          canvas: _WorkEnergyCanvas(state: state),
        ),
        const SizedBox(height: 16),

        // Sliders
        LabeledSlider(
          label: l10n.simWorkEnergy8,
          valueLabel: '${fmtNum(state.massKg, 1)} kg',
          value: state.massKg,
          min: 0.5,
          max: 5.0,
          onChanged: (v) => notifier.setMass(v),
        ),
        const SizedBox(height: 14),
        LabeledSlider(
          label: l10n.simWorkEnergy9,
          valueLabel: '${fmtNum(state.heightM, 2)} m',
          value: state.heightM,
          min: 0.2,
          max: 1.5,
          onChanged: (v) => notifier.setHeight(v),
        ),
        const SizedBox(height: 16),

        CalcBox(
          headerTitle: l10n.simWorkEnergy10,
          formulaExpression:
              'W = ${fmtNum(state.massKg, 1)} × 10 × ${fmtNum(state.heightM, 1)} = ${fmtNum(workJ, 1)} J',
          statusIcon: Icons.battery_charging_full_rounded,
          statusColor: context.elio.primaryText,
          statusText: l10n.simWorkBatteryLeft(fmtNum(batPct, 3)),
        ),
      ],
      deepExplainCard: DeepExplainCard(
        title: l10n.simWorkEnergy11,
        bodyText: l10n.simWorkEnergy12,
        bulletPoints: [
          l10n.simWorkEnergy13,
          l10n.simWorkEnergy14,
          l10n.simWorkOrganic(fmtNum(kTypicalOrganicLoadKg, 1)),
          l10n.simWorkBattery(fmtNum(kBatteryCapacityJ)),
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.l10n.simWork,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.elio.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: LinearProgressIndicator(
                            value:
                                state.workJoules /
                                75.0, // max work is 5*10*1.5 = 75J
                            backgroundColor: context.elio.borderSubtle,
                            color: context.elio.primaryText,
                            minHeight: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fmtNum(state.workJoules, 1)} J',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.elio.primaryText,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        context.l10n.simBattery,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.elio.textSecondary,
                        ),
                      ),
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
                      Text(
                        '${fmtNum(state.batteryPercentRemaining, 3)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: context.elio.primaryText,
                        ),
                      ),
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
