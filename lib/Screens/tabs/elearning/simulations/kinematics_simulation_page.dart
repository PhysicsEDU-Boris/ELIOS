import 'package:flutter/material.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../models/physics_module.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/kinematics/kinematics_notifier.dart';
import 'painters/kinematics_painter.dart';
import 'widgets/sim_module_header.dart';
import 'widgets/formula_box.dart';
import 'widgets/sim_canvas_frame.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/calc_box.dart';
import 'widgets/deep_explain_card.dart';
import 'widgets/simulation_page_scaffold.dart';
import 'package:elio/l10n/l10n.dart';

class KinematicsSimulationPage extends ConsumerStatefulWidget {
  const KinematicsSimulationPage({super.key});

  @override
  ConsumerState<KinematicsSimulationPage> createState() => _KinematicsSimulationPageState();
}

class _KinematicsSimulationPageState extends ConsumerState<KinematicsSimulationPage> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Animation<double>? _secondaryAnimation;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    // Ticker only runs when needed, driven by state.isRunning, but we can just leave it started 
    // and early-return if !isRunning.
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _secondaryAnimation?.removeListener(_onRouteAnimation);
    _secondaryAnimation = ModalRoute.of(context)?.secondaryAnimation;
    _secondaryAnimation?.addListener(_onRouteAnimation);
  }

  void _onRouteAnimation() {
    if (_secondaryAnimation != null) {
      if (_secondaryAnimation!.status == AnimationStatus.forward || _secondaryAnimation!.status == AnimationStatus.completed) {
        _ticker.muted = true; // Pause when pushed over
      } else if (_secondaryAnimation!.status == AnimationStatus.reverse || _secondaryAnimation!.status == AnimationStatus.dismissed) {
        _ticker.muted = false; // Resume when on top
      }
    }
  }

  Duration _lastElapsed = Duration.zero;

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    
    // Calculate delta time
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    if (dt <= 0) return;

    final state = ref.read(kinematicsProvider);
    if (state.isRunning && !_ticker.muted) {
      ref.read(kinematicsProvider.notifier).tick(dt);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _secondaryAnimation?.removeListener(_onRouteAnimation);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kinematicsProvider);
    final notifier = ref.read(kinematicsProvider.notifier);

    return SimulationPageScaffold(
      module: PhysicsModuleId.kinematics,
      appBarTitle: 'Kinematika',
      header: const SimModuleHeader(
        tag: 'MODUL E · MATERI',
        title: 'Kinematika (GLB & GLBB)',
        subtitle: 'Berapa lama ELIO mencapai target? Hubungkan jarak, kecepatan, dan waktu.',
      ),
      formulaBox: FormulaBox(
        title: 'RUMUS WAKTU (GLB)',
        formulaText: TextSpan(
          children: [
            const TextSpan(text: 't = s / v = '),
            TextSpan(
              text: state.predictedTimeS.toStringAsFixed(1),
              style: TextStyle(color: context.elio.secondaryText),
            ),
            const TextSpan(text: ' s'),
          ],
        ),
        subtitle: 't = waktu · s = jarak tempuh · v = kecepatan konstan',
      ),
      simulationContent: [
        const SizedBox(height: 16),
                  
                  // Live Timer HUD
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: context.elio.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.elio.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(Icons.timer_rounded, color: context.elio.primaryText, size: 24),
                              Text(context.l10n.simLiveTimer, style: TextStyle(color: context.elio.textSecondary, fontSize: 14)),
                              Text('${state.elapsedS.toStringAsFixed(2)} s', style: TextStyle(color: context.elio.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: state.isRunning ? null : () => notifier.run(),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(context.l10n.simRun),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.elio.primary,
                            foregroundColor: context.elio.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SimCanvasFrame(
                    noteText: 'Visualisasi pergerakan GLB (Gerak Lurus Beraturan)',
                    canvas: AspectRatio(
                      aspectRatio: 340 / 100,
                      child: CustomPaint(
                        painter: KinematicsPainter(
                          robotX: state.robotX,
                          distanceM: state.distanceM,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Sliders
                  LabeledSlider(
                    label: 'Jarak Target (s)',
                    valueLabel: '${state.distanceM.toStringAsFixed(1)} m',
                    value: state.distanceM,
                    min: 2.0,
                    max: 20.0,
                    onChanged: (v) => notifier.setDistance(v),
                  ),
                  const SizedBox(height: 14),
                  LabeledSlider(
                    label: 'Kecepatan (v)',
                    valueLabel: '${state.velocityMs.toStringAsFixed(2)} m/s',
                    value: state.velocityMs,
                    min: 0.1,
                    max: 1.0,
                    onChanged: (v) => notifier.setVelocity(v),
                  ),
                  const SizedBox(height: 16),

                  CalcBox(
                    headerTitle: 'HASIL PREDIKSI',
                    formulaExpression: 'Waktu Tiba = ${state.distanceM.toStringAsFixed(1)} / ${state.velocityMs.toStringAsFixed(2)} = ${state.predictedTimeS.toStringAsFixed(1)} detik',
                    statusIcon: Icons.route_rounded,
                    statusColor: context.elio.primaryText,
                    statusText: 'Estimasi Waktu Sampai (ETA)',
                  ),
                  
                  const SizedBox(height: 16),
                  // Bonus GLBB Toggle
                  Card(
                    color: context.elio.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: context.elio.borderSubtle),
                    ),
                    elevation: 0,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(context.l10n.simBonusUam, style: TextStyle(fontWeight: FontWeight.bold, color: context.elio.textPrimary)),
                        iconColor: context.elio.primaryText,
                        collapsedIconColor: context.elio.textSecondary,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: context.elio.primaryText.withValues(alpha: 0.1).withValues(alpha: 0.3),
                            child: Text(
                              'GLBB (Gerak Lurus Berubah Beraturan) melibatkan akselerasi (a). Di dunia nyata, ELIO tidak langsung melesat ke kecepatan penuh — motor butuh waktu (meski kurang dari 1 detik) untuk berakselerasi dari diam hingga kecepatan konstan.\n\nRumus GLBB: s = v₀·t + ½·a·t²\n\nKarena akselerasi ELIO sangat cepat, jarak berakselerasi sangat kecil dan sering diabaikan dalam navigasi ruangan biasa. Namun, jika ada halangan dadakan, modul rem darurat ELIO akan menggunakan deselerasi (akselerasi negatif) yang dihitung dengan rumus GLBB yang sama.',
                              style: TextStyle(color: context.elio.textSecondary, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ],
      deepExplainCard: const DeepExplainCard(
                    title: 'Modul E — Kinematika',
                    bodyText: 'Saat ELIO disuruh menuju titik kumpul sampah, sistem navigasinya (Local Planner) harus tahu seberapa jauh jaraknya dan berapa lama waktu yang dibutuhkan untuk tiba di sana dengan kecepatan tertentu. Ini adalah implementasi murni dari Kinematika Dasar — ilmu fisika yang mempelajari gerak benda tanpa peduli apa penyebab geraknya (gaya/massa).\n\nModul ini memodelkan pergerakan ELIO sebagai Gerak Lurus Beraturan (GLB).',
                    bulletPoints: [
                      'GLB: Kecepatan tetap (v), tidak ada akselerasi (a = 0).',
                      'v = s / t, sehingga t = s / v (waktu = jarak dibagi kecepatan).',
                      'Bonus GLBB: Di dunia nyata motor ELIO butuh waktu berakselerasi (s = v₀·t + ½·a·t²). Namun karena akselerasi ELIO sangat singkat, GLB cukup akurat untuk menghitung ETA.',
                      'Miskonsepsi sering terjadi saat menghitung t: mengalikan s dan v (s·v) alih-alih membaginya (s/v). Satuan s·v adalah m²/s, yang tidak punya makna logis. Cek selalu satuan akhir (m / (m/s) = s).'
                    ],
                  ),
    );
  }
}
