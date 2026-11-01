import 'package:flutter/material.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../models/physics_module.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/shared_constants.dart';
import '../../../../../physics/density/density_state.dart';
import '../../../../../physics/density/density_notifier.dart';
import 'painters/density_painter.dart';
import 'widgets/sim_module_header.dart';
import 'widgets/formula_box.dart';
import 'widgets/sim_canvas_frame.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/calc_box.dart';
import 'widgets/threshold_banner.dart';
import 'widgets/deep_explain_card.dart';
import 'widgets/simulation_page_scaffold.dart';

class DensitySimulationPage extends ConsumerStatefulWidget {
  const DensitySimulationPage({super.key});

  @override
  ConsumerState<DensitySimulationPage> createState() => _DensitySimulationPageState();
}

class _DensitySimulationPageState extends ConsumerState<DensitySimulationPage> {
  // Logic for tap-to-sort shake rejection
  WasteCategory? _shakingBin;

  void _onBinTapped(WasteCategory binType, WasteCategory currentClass) {
    if (binType != currentClass) {
      setState(() => _shakingBin = binType);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _shakingBin = null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(densityProvider);
    final rho = state.density;
    final classification = state.classification;

    return SimulationPageScaffold(
      module: PhysicsModuleId.density,
      appBarTitle: 'Densitas & Klasifikasi',
      header: const SimModuleHeader(
        tag: 'MODUL A · MATERI',
        title: 'Densitas & Klasifikasi',
        subtitle: 'Benda dengan massa jenis berbeda diklasifikasikan ke kategori yang sesuai.',
      ),
      formulaBox: FormulaBox(
        title: 'RUMUS DENSITAS',
        formulaText: TextSpan(
          children: [
            const TextSpan(text: 'ρ = m / V = '),
            TextSpan(
              text: rho.toStringAsFixed(2),
              style: const TextStyle(color: Color(0xFFFFE08A)),
            ),
            const TextSpan(text: ' g/cm³'),
          ],
        ),
        subtitle: 'm = massa · V = volume',
      ),
      simulationContent: [
                  const SizedBox(height: 16),
                  SimCanvasFrame(
                    noteText: 'Ubah slider untuk melihat benda berubah',
                    canvas: _DensityCanvas(state: state),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      LabeledSlider(
                        label: 'Massa (m)',
                        valueLabel: '${state.massGrams.toStringAsFixed(0)} g',
                        value: state.massGrams,
                        min: 100.0,
                        max: 2000.0,
                        onChanged: (v) => ref.read(densityProvider.notifier).setMass(v),
                      ),
                      const SizedBox(height: 14),
                      LabeledSlider(
                        label: 'Volume (V)',
                        valueLabel: '${state.volumeCm3.toStringAsFixed(0)} cm³',
                        value: state.volumeCm3,
                        min: 100.0,
                        max: 1000.0,
                        onChanged: (v) => ref.read(densityProvider.notifier).setVolume(v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CalcBox(
                    headerTitle: 'HASIL KLASIFIKASI',
                    formulaExpression: 'ρ = ${state.massGrams.toStringAsFixed(0)} / ${state.volumeCm3.toStringAsFixed(0)} = ${rho.toStringAsFixed(2)} g/cm³',
                    statusIcon: classification == WasteCategory.outOfRange
                        ? Icons.help_outline_rounded
                        : Icons.check_circle_rounded,
                    statusColor: classification == WasteCategory.outOfRange
                        ? context.elio.secondaryText
                        : context.elio.primaryText,
                    statusText: classification == WasteCategory.outOfRange
                        ? 'Material tidak dikenal'
                        : 'Material: ${_getCategoryName(classification)}',
                  ),
                  ThresholdBanner(
                    visible: classification == WasteCategory.outOfRange,
                    text: 'Densitas di luar rentang database (bukan plastik, kaca, atau logam yang dikenal).',
                  ),
                  const SizedBox(height: 16),
                  
                  // Bins
                  Text(
                    'Pilih Tong Sampah:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.elio.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BinWidget(
                        type: WasteCategory.plastic,
                        label: 'Plastik',
                        isHighlighted: classification == WasteCategory.plastic,
                        isShaking: _shakingBin == WasteCategory.plastic,
                        onTap: () => _onBinTapped(WasteCategory.plastic, classification),
                      ),
                      _BinWidget(
                        type: WasteCategory.glass,
                        label: 'Kaca',
                        isHighlighted: classification == WasteCategory.glass,
                        isShaking: _shakingBin == WasteCategory.glass,
                        onTap: () => _onBinTapped(WasteCategory.glass, classification),
                      ),
                      _BinWidget(
                        type: WasteCategory.metal,
                        label: 'Logam',
                        isHighlighted: classification == WasteCategory.metal,
                        isShaking: _shakingBin == WasteCategory.metal,
                        onTap: () => _onBinTapped(WasteCategory.metal, classification),
                      ),
                    ],
                  ),
      ],
      deepExplainCard: const DeepExplainCard(
                    title: 'Modul A — Densitas & Klasifikasi Sampah',
                    bodyText: 'Densitas (massa jenis) adalah ukuran seberapa "padat" materi tersusun di dalam suatu benda. Dua benda bisa punya ukuran (volume) yang sama tapi berat yang jauh berbeda — itu karena partikel penyusunnya dikemas dengan kerapatan berbeda. Besi terasa berat digenggam bukan karena besi "lebih banyak," tapi karena atom-atomnya lebih rapat per satuan ruang dibanding, katakanlah, plastik.\n\nKonsep ini penting untuk ELIO karena densitas adalah salah satu sinyal paling murah dan paling cepat untuk menebak jenis material — jauh lebih murah dibanding, misalnya, menganalisis spektrum inframerah tiap benda.',
                    bulletPoints: [
                      'ρ = m / V (Densitas = massa / volume). Air murni punya ρ = 1.0 g/cm³ sebagai titik referensi.',
                      'Rentang: Plastik (0.9–1.4), Kaca (2.4–2.6), Logam (≥ 2.7).',
                      'Plastik dengan ρ < 1.0 (HDPE, PP) mengapung di air. Plastik dengan ρ > 1.0 (PET, PVC) tenggelam. Ini teknik pemilahan flotasi sungguhan di industri!',
                      'Miskonsepsi sering menukar posisi m dan V menjadi V/m, mengubah hasil drastis. Densitas adalah massa per volume.',
                      'Beban tipikal organik ELIO adalah $kTypicalOrganicLoadKg kg. Karena organik jauh lebih padat dari plastik, mengangkat volume organik yang sama membutuhkan usaha energi lebih besar (Lihat Modul D).'
                    ],
                  ),
    );
  }

  String _getCategoryName(WasteCategory category) {
    switch (category) {
      case WasteCategory.plastic: return 'Plastik (0.9 - 1.4 g/cm³)';
      case WasteCategory.glass: return 'Kaca (2.4 - 2.6 g/cm³)';
      case WasteCategory.metal: return 'Logam (≥ 2.7 g/cm³)';
      default: return 'Tidak diketahui';
    }
  }
}

class _DensityCanvas extends StatelessWidget {
  final DensityState state;

  const _DensityCanvas({required this.state});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AspectRatio(
          aspectRatio: 340 / 300,
          child: CustomPaint(
            painter: DensityPainter(
              activeVolumeCm3: state.volumeCm3,
              activeDensity: state.density,
              refVolumeCm3: 500,
              refDensity: 2.5, // Kaca
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _BinWidget extends StatefulWidget {
  final WasteCategory type;
  final String label;
  final bool isHighlighted;
  final bool isShaking;
  final VoidCallback onTap;

  const _BinWidget({
    required this.type,
    required this.label,
    required this.isHighlighted,
    required this.isShaking,
    required this.onTap,
  });

  @override
  State<_BinWidget> createState() => _BinWidgetState();
}

class _BinWidgetState extends State<_BinWidget> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(-0.2, 0)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.2, 0), end: const Offset(0.2, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.2, 0), end: const Offset(-0.2, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.2, 0), end: Offset.zero), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));
  }

  @override
  void didUpdateWidget(_BinWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShaking && !oldWidget.isShaking) {
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SlideTransition(
        position: _shakeAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 80,
          height: 100,
          decoration: BoxDecoration(
            color: widget.isHighlighted ? context.elio.primaryText.withValues(alpha: 0.1) : context.elio.surface,
            border: Border.all(
              color: widget.isHighlighted ? context.elio.primaryText : context.elio.borderSubtle,
              width: widget.isHighlighted ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delete_outline,
                size: 32,
                color: widget.isHighlighted ? context.elio.primaryText : context.elio.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: widget.isHighlighted ? context.elio.primaryText : context.elio.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
