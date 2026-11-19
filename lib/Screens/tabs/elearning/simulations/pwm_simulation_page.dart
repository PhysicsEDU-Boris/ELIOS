import 'package:flutter/material.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../models/physics_module.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/pwm/pwm_notifier.dart';
import 'painters/pwm_painter.dart';
import 'widgets/sim_module_header.dart';
import 'widgets/formula_box.dart';
import 'widgets/sim_canvas_frame.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/calc_box.dart';
import 'widgets/deep_explain_card.dart';
import 'widgets/simulation_page_scaffold.dart';
import 'package:elio/l10n/l10n.dart';

class PwmSimulationPage extends ConsumerStatefulWidget {
  const PwmSimulationPage({super.key});

  @override
  ConsumerState<PwmSimulationPage> createState() => _PwmSimulationPageState();
}

class _PwmSimulationPageState extends ConsumerState<PwmSimulationPage>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0.0;
  double _wheelAngle = 0.0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    if (dt <= 0) return;

    final state = ref.read(pwmProvider);

    setState(() {
      _time += dt;
      // Convert RPM to radians per second: (RPM / 60) * 2π
      final rps = state.approxRpm / 60.0;
      final radsPerSec = rps * 2 * 3.14159;
      _wheelAngle += radsPerSec * dt;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pwmProvider);
    final notifier = ref.read(pwmProvider.notifier);

    return SimulationPageScaffold(
      module: PhysicsModuleId.pwm,
      appBarTitle: l10n.simPwm1,
      header: SimModuleHeader(
        tag: l10n.simPwm2,
        title: l10n.simPwm3,
        subtitle: l10n.simPwm12,
      ),
      formulaBox: FormulaBox(
        title: l10n.simPwm4,
        formulaText: TextSpan(
          children: [
            const TextSpan(text: 'V_avg = D · V_max = '),
            TextSpan(
              text: '${fmtNum(state.averageVoltage, 1)} V',
              style: TextStyle(color: context.elio.secondaryText),
            ),
          ],
        ),
        subtitle: 'D = Duty Cycle · V_max = 12.0V',
      ),
      simulationContent: [
        const SizedBox(height: 16),

        SimCanvasFrame(
          noteText: l10n.simPwm5,
          canvas: AspectRatio(
            aspectRatio: 340 / 100,
            child: CustomPaint(
              painter: PwmWavePainter(
                dutyPercent: state.dutyPercent,
                time: _time,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Wheel and RPM Readout
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.elio.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.elio.borderSubtle),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(
                  painter: PwmWheelPainter(angle: _wheelAngle),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.simMotorSpeed,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: context.elio.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fmtNum(state.approxRpm, 0)} RPM',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.elio.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // REQUIRED LABEL: DO NOT REMOVE
                    Text(
                      context.l10n.simLinearEstimate,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.elio.secondaryText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Sliders
        LabeledSlider(
          label: 'Duty Cycle (D)',
          valueLabel: '${fmtNum(state.dutyPercent, 0)}%',
          value: state.dutyPercent,
          min: 0.0,
          max: 100.0,
          onChanged: (v) => notifier.setDuty(v),
        ),
        const SizedBox(height: 16),

        CalcBox(
          headerTitle: l10n.simPwm6,
          formulaExpression:
              'V_avg = ${fmtNum(state.dutyPercent / 100.0, 2)} × ${fmtNum(12, 1)} = ${fmtNum(state.averageVoltage, 1)} Volt',
          statusIcon: Icons.bolt_rounded,
          statusColor: context.elio.primaryText,
          statusText: l10n.simPwmMotorGets(fmtNum(state.averageVoltage, 1)),
        ),
      ],
      deepExplainCard: DeepExplainCard(
        title: l10n.simPwm7,
        bodyText: l10n.simPwm13,
        bulletPoints: [
          l10n.simPwm8,
          l10n.simPwm9,
          l10n.simPwm14,
          l10n.simPwm10,
          l10n.simPwm11,
        ],
      ),
    );
  }
}
