import 'package:elio/l10n/l10n.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../models/physics_module.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/heat/heat_state.dart';
import '../../../../../physics/heat/heat_notifier.dart';
import '../../../../../physics/shared/porosity_notifier.dart';
import 'painters/heat_painter.dart';
import 'widgets/sim_module_header.dart';
import 'widgets/formula_box.dart';
import 'widgets/sim_canvas_frame.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/calc_box.dart';
import 'widgets/threshold_banner.dart';
import 'widgets/deep_explain_card.dart';
import 'widgets/simulation_page_scaffold.dart';

class HeatSimulationPage extends ConsumerStatefulWidget {
  const HeatSimulationPage({super.key});

  @override
  ConsumerState<HeatSimulationPage> createState() => _HeatSimulationPageState();
}

class _HeatSimulationPageState extends ConsumerState<HeatSimulationPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(heatProvider);
    final porosity = ref.watch(porosityProvider);
    final notifier = ref.read(heatProvider.notifier);

    final q = state.heatJoules;
    final t = state.finalTemp;
    final phase = state.phase;

    // Cross-module requirement:
    // When porosityPercent < 25 && finalTemp > 55, show "anaerob — risiko metana"
    final isAnaerobic = porosity.isAnaerobic && t > 55.0;

    return SimulationPageScaffold(
      module: PhysicsModuleId.heat,
      appBarTitle: l10n.simHeat1,
      header: SimModuleHeader(
        tag: l10n.simHeat2,
        title: l10n.simHeat3,
        subtitle: l10n.simHeat16,
      ),
      formulaBox: FormulaBox(
        title: l10n.simHeat4,
        formulaText: TextSpan(
          children: [
            const TextSpan(text: 'Q = m·c·ΔT = '),
            TextSpan(
              text: fmtNum(q, 0),
              style: TextStyle(color: context.elio.secondaryText),
            ),
            const TextSpan(text: ' J'),
          ],
        ),
        subtitle: l10n.simHeat5,
      ),
      simulationContent: [
        const SizedBox(height: 16),
        SimCanvasFrame(
          noteText: l10n.simHeat6,
          canvas: _HeatCanvas(temp: t),
        ),
        const SizedBox(height: 16),

        // Sliders
        LabeledSlider(
          label: l10n.simDensity7,
          valueLabel: '${fmtNum(state.massKg, 1)} kg',
          value: state.massKg,
          min: 1.0,
          max: 5.0,
          onChanged: (v) => notifier.setMass(v),
        ),
        const SizedBox(height: 14),
        LabeledSlider(
          label: l10n.simHeat7,
          valueLabel: '${fmtNum(state.deltaT, 1)} °C',
          value: state.deltaT,
          min: 5.0,
          max: 40.0,
          onChanged: (v) => notifier.setDeltaT(v),
        ),
        const SizedBox(height: 14),
        // Include porosity slider for testing the cross-module link visually
        LabeledSlider(
          label: l10n.simHeat8,
          valueLabel: '${fmtNum(porosity.porosityPercent, 0)} %',
          value: porosity.porosityPercent,
          min: 10.0,
          max: 80.0,
          onChanged: (v) => ref.read(porosityProvider.notifier).setPorosity(v),
        ),
        const SizedBox(height: 16),

        CalcBox(
          headerTitle: l10n.simHeat9,
          formulaExpression: l10n.simHeatFinal(
            fmtNum(state.deltaT, 1),
            fmtNum(t, 1),
          ),
          statusIcon: _getPhaseIcon(phase),
          statusColor: _getPhaseColor(phase),
          statusText: _getPhaseName(phase),
        ),

        ThresholdBanner(visible: isAnaerobic, text: l10n.simHeat17),
        ThresholdBanner(
          visible: phase == CompostPhase.thermophilic && !isAnaerobic,
          text: l10n.simHeat10,
        ),
        ThresholdBanner(
          visible: phase == CompostPhase.overheated && !isAnaerobic,
          text: l10n.simHeat18,
        ),
      ],
      deepExplainCard: DeepExplainCard(
        title: l10n.simHeat11,
        bodyText: l10n.simHeat12,
        bulletPoints: [
          l10n.simHeat19,
          l10n.simHeat20,
          l10n.simHeat21,
          l10n.simHeat22,
          l10n.simHeat23,
        ],
      ),
    );
  }

  IconData _getPhaseIcon(CompostPhase phase) {
    switch (phase) {
      case CompostPhase.mesophilic:
        return Icons.eco_rounded;
      case CompostPhase.thermophilic:
        return Icons.local_fire_department_rounded;
      case CompostPhase.overheated:
        return Icons.warning_rounded;
    }
  }

  Color _getPhaseColor(CompostPhase phase) {
    switch (phase) {
      case CompostPhase.mesophilic:
        return context.elio.primaryText;
      case CompostPhase.thermophilic:
        return Colors.orange;
      case CompostPhase.overheated:
        return context.elio.secondaryText;
    }
  }

  String _getPhaseName(CompostPhase phase) {
    switch (phase) {
      case CompostPhase.mesophilic:
        return l10n.simHeat13;
      case CompostPhase.thermophilic:
        return l10n.simHeat14;
      case CompostPhase.overheated:
        return l10n.simHeat15;
    }
  }
}

class _HeatCanvas extends StatefulWidget {
  final double temp;

  const _HeatCanvas({required this.temp});

  @override
  State<_HeatCanvas> createState() => _HeatCanvasState();
}

class _HeatCanvasState extends State<_HeatCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _secondaryAnimation;
  final List<Particle> _particles = [];
  final Random _rnd = Random();

  // Logical bounds of compost pile
  final double width = 240.0;
  final double height = 160.0; // from 180 down to 20

  @override
  void initState() {
    super.initState();
    // Initialize 20 particles inside the compost bounds
    for (int i = 0; i < 20; i++) {
      _particles.add(
        Particle(
          position: Offset(
            50 + _rnd.nextDouble() * 140,
            180 - _rnd.nextDouble() * 100,
          ),
          velocity: Offset(
            (_rnd.nextDouble() - 0.5) * 2,
            (_rnd.nextDouble() - 0.5) * 2,
          ),
        ),
      );
    }

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_tick)
          ..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to secondary animation to pause when pushed over (pause-when-offscreen)
    _secondaryAnimation?.removeListener(_onRouteAnimation);
    _secondaryAnimation = ModalRoute.of(context)?.secondaryAnimation;
    _secondaryAnimation?.addListener(_onRouteAnimation);
  }

  void _onRouteAnimation() {
    if (_secondaryAnimation != null) {
      if (_secondaryAnimation!.status == AnimationStatus.forward ||
          _secondaryAnimation!.status == AnimationStatus.completed) {
        _controller.stop();
      } else if (_secondaryAnimation!.status == AnimationStatus.reverse ||
          _secondaryAnimation!.status == AnimationStatus.dismissed) {
        if (!mounted) return;
        _controller.repeat();
      }
    }
  }

  void _tick() {
    if (!mounted) return;

    // Speed scales with temp
    final speed = widget.temp / 20.0;

    for (var p in _particles) {
      p.position += p.velocity * speed;

      // Bounce off walls (rough triangle bounds approx)
      if (p.position.dy > 175) {
        p.position = Offset(p.position.dx, 175);
        p.velocity = Offset(p.velocity.dx, -p.velocity.dy.abs());
      }
      if (p.position.dx < 40) {
        p.position = Offset(40, p.position.dy);
        p.velocity = Offset(p.velocity.dx.abs(), p.velocity.dy);
      }
      if (p.position.dx > 200) {
        p.position = Offset(200, p.position.dy);
        p.velocity = Offset(-p.velocity.dx.abs(), p.velocity.dy);
      }
      if (p.position.dy < 40) {
        p.position = Offset(p.position.dx, 40);
        p.velocity = Offset(p.velocity.dx, p.velocity.dy.abs());
      }
    }
    // We call setState implicitly by returning in a CustomPaint that depends on particles?
    // Actually, CustomPainter needs to be rebuilt if state changes.
    // We can just call setState.
    setState(() {});
  }

  @override
  void dispose() {
    _secondaryAnimation?.removeListener(_onRouteAnimation);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Compost Pile
        Expanded(
          flex: 3,
          child: AspectRatio(
            aspectRatio: 240 / 200,
            child: CustomPaint(
              painter: HeatCompostPainter(
                particles: _particles,
                temp: widget.temp,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        // Thermometer
        Expanded(
          flex: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: CustomPaint(
              painter: ThermometerPainter(temp: widget.temp),
              size: const Size(40, 180),
            ),
          ),
        ),
      ],
    );
  }
}
