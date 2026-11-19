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
import 'package:elio/l10n/l10n.dart';

class PowerBudgetSimulationPage extends ConsumerWidget {
  const PowerBudgetSimulationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(powerBudgetProvider);
    final notifier = ref.read(powerBudgetProvider.notifier);

    // Handle estimatedRuntimeS == null (infinity)
    final runtimeStr = state.estimatedRuntimeS == null
        ? '∞'
        : '${fmtNum(state.estimatedRuntimeS!)} s';

    return SimulationPageScaffold(
      module: PhysicsModuleId.power,
      appBarTitle: l10n.simPowerBudget1,
      header: SimModuleHeader(
        tag: l10n.simPowerBudget2,
        title: l10n.simPowerBudget1,
        subtitle: l10n.simPowerBudget13,
      ),
      formulaBox: FormulaBox(
        title: l10n.simPowerBudget3,
        formulaText: TextSpan(
          children: [
            const TextSpan(text: 'E = P_total · t = '),
            TextSpan(
              text: '${fmtNum(state.energyJoules, 0)} J',
              style: TextStyle(color: context.elio.secondaryText),
            ),
          ],
        ),
        subtitle: l10n.simPowerLegend(fmtNum(state.totalPowerW)),
      ),
      simulationContent: [
        const SizedBox(height: 16),

        // Scenario Presets
        Text(
          l10n.simPowerBudget4,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: context.elio.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: Text(context.l10n.simSortMode),
              backgroundColor: (state.cameraOn && state.armOn && !state.driveOn)
                  ? context.elio.primaryText.withValues(alpha: 0.1)
                  : context.elio.surface,
              side: BorderSide(
                color: (state.cameraOn && state.armOn && !state.driveOn)
                    ? context.elio.primaryText
                    : context.elio.borderSubtle,
              ),
              onPressed: () => notifier.applyScenarioSortir(),
            ),
            ActionChip(
              label: Text(context.l10n.simExploreMode),
              backgroundColor: (state.cameraOn && state.driveOn && !state.armOn)
                  ? context.elio.primaryText.withValues(alpha: 0.1)
                  : context.elio.surface,
              side: BorderSide(
                color: (state.cameraOn && state.driveOn && !state.armOn)
                    ? context.elio.primaryText
                    : context.elio.borderSubtle,
              ),
              onPressed: () => notifier.applyScenarioJelajah(),
            ),
            ActionChip(
              label: Text(context.l10n.simIdle),
              backgroundColor:
                  (state.cameraOn && !state.driveOn && !state.armOn)
                  ? context.elio.primaryText.withValues(alpha: 0.1)
                  : context.elio.surface,
              side: BorderSide(
                color: (state.cameraOn && !state.driveOn && !state.armOn)
                    ? context.elio.primaryText
                    : context.elio.borderSubtle,
              ),
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
                  title: Text(
                    context.l10n.simCamera,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  value: state.cameraOn,
                  onChanged: notifier.toggleCamera,
                  activeThumbColor: context.elio.primary,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(
                    context.l10n.simDriveMotor,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  value: state.driveOn,
                  onChanged: notifier.toggleDrive,
                  activeThumbColor: context.elio.primary,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(
                    context.l10n.simArmMotor,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
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
          label: l10n.simPowerBudget5,
          valueLabel: '${fmtNum(state.timeS, 0)} s',
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
                  Text(
                    context.l10n.simBatteryLeft,
                    style: TextStyle(
                      color: context.elio.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${fmtNum(state.remainingPercent, 1)}%',
                    style: TextStyle(
                      color: context.elio.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: state.remainingPercent / 100.0,
                backgroundColor: context.elio.borderSubtle,
                color: state.remainingPercent > 20
                    ? context.elio.primaryText
                    : context.elio.errorText,
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        CalcBox(
          headerTitle: l10n.simPowerBudget6,
          formulaExpression: l10n.simPowerEstimate(
            fmtNum(state.totalPowerW),
            runtimeStr,
          ),
          statusIcon: Icons.access_time_filled_rounded,
          statusColor: context.elio.primaryText,
          statusText: l10n.simPowerLasts(runtimeStr),
        ),
      ],
      deepExplainCard: DeepExplainCard(
        title: l10n.simPowerBudget7,
        bodyText: l10n.simPowerBudget8,
        bulletPoints: [
          l10n.simPowerBudget9,
          l10n.simPowerBudget10,
          l10n.simPowerBudget11,
          l10n.simPowerBudget12,
          l10n.simPowerBudget14,
        ],
      ),
    );
  }
}
