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
  ConsumerState<TorqueSimulationPage> createState() => _TorqueSimulationPageState();
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
      appBarTitle: 'Torsi Bahu Robot',
      header: const SimModuleHeader(
        tag: 'MODUL C · MEKANIKA',
        title: 'Torsi Bahu Robot',
        subtitle: 'Saat ELIO menjulurkan lengan, sendi bahu menahan torsi yang lebih besar.',
      ),
      formulaBox: FormulaBox(
                    title: 'RUMUS TORSI',
                    formulaText: TextSpan(
                      children: [
                        const TextSpan(text: 'τ = r · F · sin(θ) = '),
                        TextSpan(
                          text: tau.toStringAsFixed(2),
                          style: TextStyle(color: context.elio.secondaryText),
                        ),
                        const TextSpan(text: ' N·m'),
                      ],
                    ),
        subtitle: 'r = panjang lengan · F = beban · θ = sudut',
      ),
      simulationContent: [
        const SizedBox(height: 16),
                  SimCanvasFrame(
                    noteText: 'Seret gagang lengan untuk mengubah r & θ',
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
                        label: 'Panjang lengan (r)',
                        valueLabel: '${state.armLength.toStringAsFixed(2)} m',
                        value: state.armLength,
                        min: TorqueState.minArmLength,
                        max: TorqueState.maxArmLength,
                        onChanged: (v) => ref.read(torqueProvider.notifier).setArmLength(v),
                      ),
                      const SizedBox(height: 14),
                      LabeledSlider(
                        label: 'Beban (F)',
                        valueLabel: '${state.load.toStringAsFixed(1)} N',
                        value: state.load,
                        min: TorqueState.minLoad,
                        max: TorqueState.maxLoad,
                        onChanged: (v) => ref.read(torqueProvider.notifier).setLoad(v),
                      ),
                      const SizedBox(height: 14),
                      LabeledSlider(
                        label: 'Sudut (θ)',
                        valueLabel: '${state.angleDeg.toStringAsFixed(0)}°',
                        value: state.angleDeg,
                        min: TorqueState.minAngleDeg,
                        max: TorqueState.maxAngleDeg,
                        onChanged: (v) => ref.read(torqueProvider.notifier).setAngle(v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CalcBox(
                    headerTitle: 'TORSI INSTAN',
                    formulaExpression: 'τ = ${state.armLength.toStringAsFixed(2)} × ${state.load.toStringAsFixed(1)} × sin(${state.angleDeg.toStringAsFixed(0)}°) = ${tau.toStringAsFixed(2)} N·m',
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
                    statusText: 'Motor: ${status == MotorStatus.safe ? 'AMAN' : status == MotorStatus.warning ? 'PERHATIAN' : 'KRITIS'} · batas aman 8 N·m',
                  ),
                  ThresholdBanner(
                    visible: status == MotorStatus.critical,
                    text: 'Torsi melebihi 8 N·m — Robot bisa terguling!',
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
                          'TANTANGAN',
                          style: TextStyle(
                            color: context.elio.primaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cari berat maksimum yang dapat diangkat ELIO saat r = 0.5 m dan '
                          'θ = 90° dengan batas torsi 8 N·m.\nJawaban: F = τ/(r·sinθ) = '
                          '8 / 0.5 = 16 N',
                          style: TextStyle(color: context.elio.textSecondary, fontSize: 12.5, height: 1.55),
                        ),
                      ],
                    ),
                  ),
      ],
      deepExplainCard: const DeepExplainCard(
                    title: 'Penjelasan Materi: Torsi (Momen Gaya)',
                    bodyText: 'Torsi (τ) adalah ukuran efektivitas gaya dalam memutar benda '
                        'terhadap suatu titik poros. Torsi bergantung pada lengan '
                        'momen dan sudut antara lengan dengan arah gaya.',
                    bulletPoints: [
                      'θ = 90°: torsi maksimum — lengan tegak lurus dengan gaya.',
                      'θ = 0° atau 180°: torsi nol — gaya sejajar lengan.',
                      'r besar: torsi lebih besar, tapi robot lebih sulit stabil.'
                    ],
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
