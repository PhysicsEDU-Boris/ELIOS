import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/heat/heat_state.dart';
import '../../../../../physics/heat/heat_notifier.dart';
import '../../../../../physics/shared/porosity_notifier.dart';
import '../../../../../theme/elio_learning_colors.dart';
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
      appBarTitle: 'Kalor & Termodinamika',
      header: const SimModuleHeader(
        tag: 'MODUL B · MATERI',
        title: 'Kalor & Termodinamika Pengomposan',
        subtitle: 'Kalor dari aktivitas mikroba mengubah suhu tumpukan kompos. Pantau fasenya.',
      ),
      formulaBox: FormulaBox(
        title: 'RUMUS KALOR (Q)',
        formulaText: TextSpan(
          children: [
            const TextSpan(text: 'Q = m·c·ΔT = '),
            TextSpan(
              text: q.toStringAsFixed(0),
              style: const TextStyle(color: elioWarning),
            ),
            const TextSpan(text: ' J'),
          ],
        ),
        subtitle: 'm = massa · c = 4000 J/kg°C · ΔT = perubahan suhu',
      ),
      simulationContent: [
        const SizedBox(height: 16),
                  SimCanvasFrame(
                    noteText: 'Partikel mewakili aktivitas mikroba',
                    canvas: _HeatCanvas(temp: t),
                  ),
                  const SizedBox(height: 16),
                  
                  // Sliders
                  LabeledSlider(
                    label: 'Massa (m)',
                    valueLabel: '${state.massKg.toStringAsFixed(1)} kg',
                    value: state.massKg,
                    min: 1.0,
                    max: 5.0,
                    onChanged: (v) => notifier.setMass(v),
                  ),
                  const SizedBox(height: 14),
                  LabeledSlider(
                    label: 'Perubahan Suhu (ΔT)',
                    valueLabel: '${state.deltaT.toStringAsFixed(1)} °C',
                    value: state.deltaT,
                    min: 5.0,
                    max: 40.0,
                    onChanged: (v) => notifier.setDeltaT(v),
                  ),
                  const SizedBox(height: 14),
                  // Include porosity slider for testing the cross-module link visually
                  LabeledSlider(
                    label: 'Porositas (Lintas Modul)',
                    valueLabel: '${porosity.porosityPercent.toStringAsFixed(0)} %',
                    value: porosity.porosityPercent,
                    min: 10.0,
                    max: 80.0,
                    onChanged: (v) => ref.read(porosityProvider.notifier).setPorosity(v),
                  ),
                  const SizedBox(height: 16),

                  CalcBox(
                    headerTitle: 'HASIL FASE',
                    formulaExpression: 'Suhu Akhir = 25°C + ${state.deltaT.toStringAsFixed(1)}°C = ${t.toStringAsFixed(1)}°C',
                    statusIcon: _getPhaseIcon(phase),
                    statusColor: _getPhaseColor(phase),
                    statusText: _getPhaseName(phase),
                  ),
                  
                  ThresholdBanner(
                    visible: isAnaerobic,
                    text: 'Peringatan: anaerob — risiko metana. Porositas rendah (<25%) dan suhu tinggi (>55°C).',
                  ),
                  ThresholdBanner(
                    visible: phase == CompostPhase.thermophilic && !isAnaerobic,
                    text: 'Fase Termofilik: Bakteri tahan panas bekerja optimal, patogen mulai mati.',
                  ),
                  ThresholdBanner(
                    visible: phase == CompostPhase.overheated && !isAnaerobic,
                    text: 'Overheated: Terlalu panas! Aktivitas mikroba terhambat.',
                  ),
      ],
      deepExplainCard: const DeepExplainCard(
                    title: 'Modul B — Kalor & Termodinamika Pengomposan',
                    bodyText: 'Saat mikroorganisme di tumpukan kompos memecah sampah organik, mereka melepaskan energi dalam bentuk kalor (heat) — ini disebut proses eksotermik biologis. Suhu tumpukan kompos naik bukan karena api atau listrik, tapi karena aktivitas metabolisme jutaan bakteri dan jamur yang bekerja memecah rantai molekul organik.\n\nModul ini memodelkan berapa banyak kalor yang perlu diserap atau dilepas suatu massa kompos untuk mengalami perubahan suhu tertentu, dan menghubungkannya ke fase biologis nyata dari proses pengomposan.',
                    bulletPoints: [
                      'Q = m · c · ΔT (Kalor = massa × kalor jenis × perubahan suhu).',
                      'Fase Mesofilik (< 55°C): Bakteri suhu-sedang mulai memecah gula & protein sederhana.',
                      'Fase Termofilik (55–60°C): Bakteri tahan-panas mendominasi, fase membunuh patogen & biji gulma.',
                      'Overheated (> 60°C): Aktivitas mikroba mulai terhambat/mati; perlu diaduk untuk melepas panas.',
                      'Hubungan dengan Porositas: Ketika porositas < 25% DAN suhu > 55°C, tumpukan berisiko masuk kondisi anaerobik (oksigen habis). Mikroba anaerob mengambil alih dan menghasilkan gas metana (CH₄) yang berbahaya.'
                    ],
                  ),
    );
  }

  IconData _getPhaseIcon(CompostPhase phase) {
    switch (phase) {
      case CompostPhase.mesophilic: return Icons.eco_rounded;
      case CompostPhase.thermophilic: return Icons.local_fire_department_rounded;
      case CompostPhase.overheated: return Icons.warning_rounded;
    }
  }

  Color _getPhaseColor(CompostPhase phase) {
    switch (phase) {
      case CompostPhase.mesophilic: return elioOk;
      case CompostPhase.thermophilic: return Colors.orange;
      case CompostPhase.overheated: return elioWarning;
    }
  }

  String _getPhaseName(CompostPhase phase) {
    switch (phase) {
      case CompostPhase.mesophilic: return 'Mesofilik (< 55°C)';
      case CompostPhase.thermophilic: return 'Termofilik (55 - 60°C)';
      case CompostPhase.overheated: return 'Terlalu Panas (> 60°C)';
    }
  }
}

class _HeatCanvas extends StatefulWidget {
  final double temp;

  const _HeatCanvas({required this.temp});

  @override
  State<_HeatCanvas> createState() => _HeatCanvasState();
}

class _HeatCanvasState extends State<_HeatCanvas> with SingleTickerProviderStateMixin {
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
      _particles.add(Particle(
        position: Offset(50 + _rnd.nextDouble() * 140, 180 - _rnd.nextDouble() * 100),
        velocity: Offset((_rnd.nextDouble() - 0.5) * 2, (_rnd.nextDouble() - 0.5) * 2),
      ));
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick)..repeat();
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
      if (_secondaryAnimation!.status == AnimationStatus.forward || _secondaryAnimation!.status == AnimationStatus.completed) {
        _controller.stop();
      } else if (_secondaryAnimation!.status == AnimationStatus.reverse || _secondaryAnimation!.status == AnimationStatus.dismissed) {
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
              painter: ThermometerPainter(
                temp: widget.temp,
              ),
              size: const Size(40, 180),
            ),
          ),
        ),
      ],
    );
  }
}
