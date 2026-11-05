import 'package:elio/l10n/l10n.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../models/physics_module.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/torque/torque_state.dart';
import '../../../../../physics/torque/torque_notifier.dart';
import 'painters/torque_painter.dart';
import 'widgets/sim_module_header.dart';
import 'widgets/formula_box.dart';
import 'widgets/sim_canvas_frame.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/calc_box.dart';
import 'widgets/threshold_banner.dart';
import 'widgets/deep_explain_card.dart';
import 'widgets/simulation_page_scaffold.dart';

class TorqueSimulationPage extends ConsumerStatefulWidget {
  const TorqueSimulationPage({super.key});

  @override
  ConsumerState<TorqueSimulationPage> createState() =>
      _TorqueSimulationPageState();
}

class _TorqueSimulationPageState extends ConsumerState<TorqueSimulationPage> {
  bool _draggingGripper = false;

  void _onDragUpdate(Offset logicalPoint, TorqueState state) {
    final end = torqueArmEnd(state);
    if (!_draggingGripper) {
      if ((logicalPoint - end).distance > 34) return;
      _draggingGripper = true;
    }

    final dx = logicalPoint.dx - torqueShoulder.dx;
    final dy = torqueShoulder.dy - logicalPoint.dy;
    final newR = math.sqrt(dx * dx + dy * dy) / torquePxPerMeter;
    final newTheta = math.atan2(dy, dx) * 180 / math.pi;

    final notifier = ref.read(torqueProvider.notifier);
    notifier.setArmLength(newR);
    notifier.setAngle(newTheta);
  }

  void _endDrag() => _draggingGripper = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(torqueProvider);
    final tau = state.torque;
    final status = state.motorStatus;

    return SimulationPageScaffold(
      module: PhysicsModuleId.torque,
      appBarTitle: l10n.simTorque1,
      header: SimModuleHeader(
        tag: l10n.simTorque2,
        title: l10n.simTorque1,
        subtitle: l10n.simTorque12,
      ),
      formulaBox: FormulaBox(
        title: l10n.simTorque3,
        formulaText: TextSpan(
          children: [
            const TextSpan(text: 'τ = r · F · sin(θ) = '),
            TextSpan(
              text: fmtNum(tau, 2),
              style: TextStyle(color: context.elio.secondaryText),
            ),
            const TextSpan(text: ' N·m'),
          ],
        ),
        subtitle: l10n.simTorque4,
      ),
      simulationContent: [
        const SizedBox(height: 16),
        SimCanvasFrame(
          noteText: l10n.simTorque5,
          showRiskBadge: status == MotorStatus.critical,
          canvas: _TorqueCanvas(
            state: state,
            shake: status == MotorStatus.critical,
            onDragUpdate: (point) => _onDragUpdate(point, state),
            onDragEnd: _endDrag,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            LabeledSlider(
              label: l10n.simTorque6,
              valueLabel: '${fmtNum(state.armLength, 2)} m',
              value: state.armLength,
              min: TorqueState.minArmLength,
              max: TorqueState.maxArmLength,
              onChanged: (v) =>
                  ref.read(torqueProvider.notifier).setArmLength(v),
            ),
            const SizedBox(height: 14),
            LabeledSlider(
              label: l10n.simTorque7,
              valueLabel: '${fmtNum(state.load, 1)} N',
              value: state.load,
              min: TorqueState.minLoad,
              max: TorqueState.maxLoad,
              onChanged: (v) => ref.read(torqueProvider.notifier).setLoad(v),
            ),
            const SizedBox(height: 14),
            LabeledSlider(
              label: l10n.simTorque8,
              valueLabel: '${fmtNum(state.angleDeg, 0)}°',
              value: state.angleDeg,
              min: TorqueState.minAngleDeg,
              max: TorqueState.maxAngleDeg,
              onChanged: (v) => ref.read(torqueProvider.notifier).setAngle(v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CalcBox(
          headerTitle: l10n.simTorque9,
          formulaExpression:
              'τ = ${fmtNum(state.armLength, 2)} × ${fmtNum(state.load, 1)} × sin(${fmtNum(state.angleDeg, 0)}°) = ${fmtNum(tau, 2)} N·m',
          statusIcon: status == MotorStatus.safe
              ? Icons.check_circle_rounded
              : status == MotorStatus.warning
              ? Icons.error_rounded
              : Icons.dangerous_rounded,
          statusColor: status == MotorStatus.safe
              ? context.elio.primaryText
              : status == MotorStatus.warning
              ? context.elio.secondaryText
              : context.elio.errorText,
          statusText: l10n.simTorqueMotorStatus(
            status == MotorStatus.safe
                ? l10n.simTorqueSafe
                : status == MotorStatus.warning
                ? l10n.simTorqueWarning
                : l10n.simTorqueCritical,
          ),
        ),
        ThresholdBanner(
          visible: status == MotorStatus.critical,
          text: l10n.simTorque13,
        ),
        const SizedBox(height: 16),
        // Challenge card was not abstracted but should be rendered directly here
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.elio.surfaceRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.elio.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.simTorque10,
                style: TextStyle(
                  color: context.elio.primaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.simTorqueChallenge(fmtNum(0.5, 1)),
                style: TextStyle(
                  color: context.elio.textSecondary,
                  fontSize: 12.5,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
      deepExplainCard: DeepExplainCard(
        title: l10n.simTorque11,
        bodyText: l10n.simTorqueBody,
        bulletPoints: [l10n.simTorque14, l10n.simTorque15, l10n.simTorque16],
      ),
    );
  }
}

class _TorqueCanvas extends StatelessWidget {
  final TorqueState state;
  final bool shake;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  const _TorqueCanvas({
    required this.state,
    required this.shake,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = torqueLogicalSize.width / constraints.maxWidth;
        Offset toLogical(Offset local) => local * scale;

        return AspectRatio(
          aspectRatio: torqueLogicalSize.width / torqueLogicalSize.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => onDragUpdate(toLogical(d.localPosition)),
            onPanUpdate: (d) => onDragUpdate(toLogical(d.localPosition)),
            onPanEnd: (_) => onDragEnd(),
            child: CustomPaint(
              painter: TorquePainter(state: state, shake: shake),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}
