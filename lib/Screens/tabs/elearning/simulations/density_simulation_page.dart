import 'dart:math' as math;

import 'package:elio/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../services/elio_feedback.dart';
import '../../../../theme/elio_motion.dart';
import '../../../../theme/elio_tokens.dart';
import '../../../../widgets/learn/learn_l3.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../models/physics_module.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/shared_constants.dart';
import '../../../../../physics/density/density_state.dart';
import '../../../../../physics/density/density_notifier.dart';
import 'painters/density_painter.dart';
import 'widgets/sim_module_header.dart';
import 'widgets/formula_box.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/calc_box.dart';
import 'widgets/threshold_banner.dart';
import 'widgets/deep_explain_card.dart';
import 'widgets/simulation_page_scaffold.dart';

class DensitySimulationPage extends ConsumerStatefulWidget {
  const DensitySimulationPage({super.key});

  @override
  ConsumerState<DensitySimulationPage> createState() =>
      _DensitySimulationPageState();
}

class _DensitySimulationPageState extends ConsumerState<DensitySimulationPage> {
  WasteCategory? _picked;
  int _wrong = 0;
  int _done = 0;

  /// Right bin: chime, success, and the Done sticker bounces. Wrong: knock,
  /// error, and the bubble shakes (card 20g).
  void _onBinTapped(WasteCategory binType, WasteCategory currentClass) {
    setState(() => _picked = binType);
    if (binType == currentClass) {
      _done++;
      elioFeedback(ElioSfx.chime, ElioHaptics.success);
    } else {
      _wrong++;
      elioFeedback(ElioSfx.knock, ElioHaptics.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(densityProvider);
    final rho = state.density;
    final classification = state.classification;
    // ρ entering a new material band: one tick (not every pixel).
    ref.listen(densityProvider.select((s) => s.classification), (a, b) {
      if (a != b) elioFeedback(ElioSfx.tick, ElioHaptics.select);
    });
    final formula = TextSpan(
      children: [
        const TextSpan(text: 'ρ = m / V = '),
        TextSpan(
          text: fmtNum(rho, 2),
          style: TextStyle(color: context.elio.secondaryText),
        ),
        const TextSpan(text: ' g/cm³'),
      ],
    );

    return SimulationPageScaffold(
      module: PhysicsModuleId.density,
      heroCanvas: _DensityCanvas(state: state),
      doneSignal: _done,
      appBarTitle: l10n.simDensity1,
      header: SimModuleHeader(
        tag: l10n.simDensity2,
        title: l10n.simDensity1,
        subtitle: l10n.simDensity3,
      ),
      formulaBox: FormulaBox(
        title: l10n.simDensity4,
        formulaText: formula,
        subtitle: l10n.simDensity5,
      ),
      simulationContent: [
        Text(
          l10n.simDensity4,
          style: context.text.labelSmall?.copyWith(
            color: context.elio.primaryText,
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          formula,
          style: ElioTokens.code.copyWith(
            fontSize: 20,
            color: context.elio.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Column(
          children: [
            LabeledSlider(
              label: l10n.simDensity7,
              valueLabel: '${fmtNum(state.massGrams, 0)} g',
              value: state.massGrams,
              min: 100.0,
              max: 2000.0,
              onChanged: (v) => ref.read(densityProvider.notifier).setMass(v),
            ),
            const SizedBox(height: 14),
            LabeledSlider(
              label: 'Volume (V)',
              valueLabel: '${fmtNum(state.volumeCm3, 0)} cm³',
              value: state.volumeCm3,
              min: 100.0,
              max: 1000.0,
              onChanged: (v) => ref.read(densityProvider.notifier).setVolume(v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CalcBox(
          headerTitle: l10n.simDensity8,
          formulaExpression:
              'ρ = ${fmtNum(state.massGrams, 0)} / ${fmtNum(state.volumeCm3, 0)} = ${fmtNum(rho, 2)} g/cm³',
          statusIcon: classification == WasteCategory.outOfRange
              ? Icons.help_outline_rounded
              : Icons.check_circle_rounded,
          statusColor: classification == WasteCategory.outOfRange
              ? context.elio.secondaryText
              : context.elio.primaryText,
          statusText: classification == WasteCategory.outOfRange
              ? l10n.simDensity9
              : l10n.simDensityMaterial(_getCategoryName(classification)),
        ),
        ThresholdBanner(
          visible: classification == WasteCategory.outOfRange,
          text: l10n.simDensity10,
        ),
        const SizedBox(height: 16),

        Text(l10n.simDensity11, style: context.text.labelLarge),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final (type, label, angle) in [
              (WasteCategory.plastic, l10n.simDensity12, -4.0),
              (WasteCategory.glass, l10n.simDensity13, 0.0),
              (WasteCategory.metal, l10n.simDensity14, 4.0),
            ])
              _BinChoice(
                label: label,
                angle: angle,
                picked: _picked == type && type == classification,
                shake: _picked == type && type != classification
                    ? _wrong
                    : null,
                onTap: () => _onBinTapped(type, classification),
              ),
          ],
        ),
      ],
      deepExplainCard: DeepExplainCard(
        title: l10n.simDensity15,
        bodyText: l10n.simDensity16,
        bulletPoints: [
          l10n.simDensity17,
          l10n.simDensity23,
          l10n.simDensity24,
          l10n.simDensity18,
          l10n.simDensityLoad(fmtNum(kTypicalOrganicLoadKg, 1)),
        ],
      ),
    );
  }

  String _getCategoryName(WasteCategory category) {
    switch (category) {
      case WasteCategory.plastic:
        return l10n.simDensity19;
      case WasteCategory.glass:
        return l10n.simDensity20;
      case WasteCategory.metal:
        return l10n.simDensity21;
      default:
        return l10n.simDensity22;
    }
  }
}

class _DensityCanvas extends StatelessWidget {
  final DensityState state;

  const _DensityCanvas({required this.state});

  @override
  Widget build(BuildContext context) => FittedBox(
    // The painter's own 340 × 300 frame, fitted into the hero polaroid.
    child: SizedBox(
      width: 340,
      height: 300,
      child: CustomPaint(
        painter: DensityPainter(
          activeVolumeCm3: state.volumeCm3,
          activeDensity: state.density,
          refVolumeCm3: 500,
          refDensity: 2.5, // Kaca
        ),
      ),
    ),
  );
}

class _BinChoice extends StatelessWidget {
  const _BinChoice({
    required this.label,
    required this.angle,
    required this.picked,
    required this.shake,
    required this.onTap,
  });
  final String label;
  final double angle;
  final bool picked;
  final int? shake;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final fg = picked ? p.primaryText : p.textPrimary;
    return Semantics(
      button: true,
      selected: picked,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: ElioShake(
          trigger: shake,
          distance: 4,
          child: SizedBox(
            width: 84,
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey(picked),
                  tween: Tween(begin: picked ? 1.08 : 1, end: 1),
                  duration: ElioMotion.slow,
                  curve: ElioMotion.pop,
                  builder: (context, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: Transform.rotate(
                    angle: picked ? 0 : angle * math.pi / 180,
                    child: AnimatedContainer(
                      duration: ElioMotion.base,
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: picked
                            ? toneBg(p, LearnTone.success)
                            : p.background,
                        border: Border.all(
                          color: picked ? p.primaryText : p.borderSubtle,
                          width: picked ? 2.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: SvgPicture.asset(
                          'assets/illustrations/learn/icon_bin_anorganik.svg',
                          colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: context.text.labelLarge?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
