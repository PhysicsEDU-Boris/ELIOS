import 'package:flutter/material.dart';
import '../../../../widgets/learn/learn_ui.dart';
import '../../../../models/physics_module.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../physics/shared/porosity_notifier.dart';
import '../../../../../physics/deep_dive/hooke_spring_state.dart';
import '../../../../../physics/deep_dive/nir_reflectance_state.dart';
import '../../../../../physics/deep_dive/vapor_pressure_state.dart';
import '../../../../../physics/deep_dive/incinerator_state.dart';
import '../../../../../physics/deep_dive/radiation_shielding_state.dart';
import 'widgets/sim_module_header.dart';
import 'widgets/labeled_slider.dart';
import 'widgets/simulation_page_scaffold.dart';
import 'painters/inorganic_painters.dart';
import 'painters/b3_painters.dart';
import 'package:elio/l10n/l10n.dart';

class DeepDiveSimulationPage extends ConsumerStatefulWidget {
  const DeepDiveSimulationPage({super.key});

  @override
  ConsumerState<DeepDiveSimulationPage> createState() =>
      _DeepDiveSimulationPageState();
}

class _DeepDiveSimulationPageState
    extends ConsumerState<DeepDiveSimulationPage> {
  bool _organicExpanded = false;
  bool _inorganicExpanded = false;
  bool _b3Expanded = false;

  @override
  Widget build(BuildContext context) {
    return SimulationPageScaffold(
      module: PhysicsModuleId.deepDive,
      appBarTitle: l10n.simDeepDive1,
      header: SimModuleHeader(
        tag: 'WASTE PHYSICS · DEEP-DIVE',
        title: l10n.simDeepDive2,
        subtitle: l10n.simDeepDive3,
      ),
      simulationContent: [
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _organicExpanded
                  ? Color(0xFF10B981)
                  : context.elio.borderSubtle,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              backgroundColor: context.elio.surface,
              collapsedBackgroundColor: context.elio.surface,
              initiallyExpanded: false,
              title: Text(
                context.l10n.deepOrganicCard,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.elio.textPrimary,
                ),
              ),
              iconColor: const Color(0xFF10B981),
              collapsedIconColor: context.elio.textSecondary,
              onExpansionChanged: (v) => setState(() => _organicExpanded = v),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const _OrganicDeepDiveContent(),
                ),
              ],
            ),
          ),
        ),

        // Inorganic Card
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _inorganicExpanded
                  ? Color(0xFF3B82F6)
                  : context.elio.borderSubtle,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              backgroundColor: context.elio.surface,
              collapsedBackgroundColor: context.elio.surface,
              initiallyExpanded: false,
              title: Text(
                context.l10n.deepInorganicCard,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.elio.textPrimary,
                ),
              ),
              iconColor: const Color(0xFF3B82F6),
              collapsedIconColor: context.elio.textSecondary,
              onExpansionChanged: (v) => setState(() => _inorganicExpanded = v),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const _InorganicDeepDiveContent(),
                ),
              ],
            ),
          ),
        ),

        // B3 Card
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _b3Expanded
                  ? Color(0xFFEF4444)
                  : context.elio.borderSubtle,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              backgroundColor: context.elio.surface,
              collapsedBackgroundColor: context.elio.surface,
              initiallyExpanded: false,
              title: Text(
                context.l10n.deepB3Card,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.elio.textPrimary,
                ),
              ),
              iconColor: const Color(0xFFEF4444),
              collapsedIconColor: context.elio.textSecondary,
              onExpansionChanged: (v) => setState(() => _b3Expanded = v),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const _B3DeepDiveContent(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrganicDeepDiveContent extends ConsumerWidget {
  const _OrganicDeepDiveContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final porosityState = ref.watch(porosityProvider);
    final notifier = ref.read(porosityProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Slider
        LabeledSlider(
          label: l10n.simDeepDive4,
          valueLabel: '${fmtNum(porosityState.porosityPercent, 0)}%',
          value: porosityState.porosityPercent,
          min: 10.0,
          max: 80.0,
          onChanged: notifier.setPorosity,
        ),
        const SizedBox(height: 16),

        // Indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: porosityState.isAnaerobic
                ? context.elio.errorText.withValues(alpha: 0.1)
                : context.elio.primaryText.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: porosityState.isAnaerobic
                  ? context.elio.errorText
                  : context.elio.primaryText,
            ),
          ),
          child: Row(
            children: [
              Icon(
                porosityState.isAnaerobic
                    ? Icons.warning_rounded
                    : Icons.check_circle_rounded,
                color: porosityState.isAnaerobic
                    ? context.elio.errorText
                    : context.elio.primaryText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  porosityState.isAnaerobic
                      ? l10n.simDeepDive5
                      : l10n.simDeepDive6,
                  style: TextStyle(
                    color: porosityState.isAnaerobic
                        ? context.elio.errorText
                        : context.elio.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Physics details
        Text(
          context.l10n.deepCoreConcept,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.elio.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.simDeepDive7,
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),

        Text(
          context.l10n.deepKeyPhysics,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.elio.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${l10n.simDeepDive24}${l10n.simDeepDive25}${l10n.simDeepDive26}',
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),

        // Why can't it be sorted like inorganic/B3?
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: context.elio.textPrimary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    context.l10n.deepWhyDifferent,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.elio.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                l10n.simDeepDive8,
                style: TextStyle(color: context.elio.textPrimary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InorganicDeepDiveContent extends ConsumerStatefulWidget {
  const _InorganicDeepDiveContent();

  @override
  ConsumerState<_InorganicDeepDiveContent> createState() =>
      _InorganicDeepDiveContentState();
}

class _InorganicDeepDiveContentState
    extends ConsumerState<_InorganicDeepDiveContent>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _animationValue = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (mounted) {
        setState(() {
          _animationValue = (elapsed.inMilliseconds % 2000) / 2000.0;
        });
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hookeState = ref.watch(hookeSpringProvider);
    final hookeNotifier = ref.read(hookeSpringProvider.notifier);

    final nirState = ref.watch(nirReflectanceProvider);
    final nirNotifier = ref.read(nirReflectanceProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.deepHardnessTest,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.elio.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.simDeepDive9,
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.elio.surface,
            border: Border.all(color: context.elio.borderSubtle),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: HookeSpringPainter(
              compressionCm: hookeState.compressionCm,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LabeledSlider(
          label: l10n.simDeepDive10,
          valueLabel: '${fmtNum(hookeState.compressionCm, 1)} cm',
          value: hookeState.compressionCm,
          min: 2.0,
          max: 20.0,
          onChanged: hookeNotifier.setCompression,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.deepReactionForce(fmtNum(hookeState.forceN, 1)),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.elio.primaryText,
          ),
        ),
        const Divider(height: 32),

        Text(
          context.l10n.deepNir,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.elio.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.simDeepDive27,
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        // ⚠ CATATAN AKURASI WAJIB (UI COPY)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.elio.secondaryText.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.elio.secondaryText),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_rounded,
                color: context.elio.secondaryText,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.simDeepDive11,
                  style: TextStyle(
                    color: context.elio.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: PlasticType.values.map((type) {
            final isSelected = nirState.selectedPlastic == type;
            final label = type == PlasticType.pet
                ? 'PET'
                : (type == PlasticType.hdpe ? 'HDPE' : 'PP');
            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (v) => nirNotifier.setPlastic(type),
              selectedColor: context.elio.primaryText.withValues(alpha: 0.1),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.elio.surface,
            border: Border.all(color: context.elio.borderSubtle),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: NirCurvePainter(peakNm: nirState.peakWavelengthNm),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.deepSpectrumPeak(fmtNum(nirState.peakWavelengthNm, 0)),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.elio.primaryText,
          ),
        ),
        const Divider(height: 32),

        Text(
          context.l10n.deepEddy,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.elio.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.simDeepDive12,
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.elio.surface,
            border: Border.all(color: context.elio.borderSubtle),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: EddyCurrentPainter(animationValue: _animationValue),
          ),
        ),
        const SizedBox(height: 24),

        // Why can't it be sorted like organic/B3?
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: context.elio.textPrimary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    context.l10n.deepWhyDifferent,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.elio.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                l10n.simDeepDive13,
                style: TextStyle(color: context.elio.textPrimary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _B3DeepDiveContent extends ConsumerWidget {
  const _B3DeepDiveContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaporState = ref.watch(vaporPressureProvider);
    final vaporNotifier = ref.read(vaporPressureProvider.notifier);

    final incinState = ref.watch(incineratorProvider);
    final incinNotifier = ref.read(incineratorProvider.notifier);

    final radState = ref.watch(radiationShieldingProvider);
    final radNotifier = ref.read(radiationShieldingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.deepVaporPressure,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.elio.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.simDeepDive14,
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        // ⚠ CATATAN AKURASI WAJIB (UI COPY)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.elio.secondaryText.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.elio.secondaryText),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_rounded,
                color: context.elio.secondaryText,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.simDeepDive15,
                  style: TextStyle(
                    color: context.elio.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.elio.surface,
            border: Border.all(color: context.elio.borderSubtle),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: VaporPressurePainter(
              temperatureC: vaporState.temperatureC,
              relativePressure: vaporState.relativePressure,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LabeledSlider(
          label: l10n.simDeepDive16,
          valueLabel: '${fmtNum(vaporState.temperatureC, 1)} °C',
          value: vaporState.temperatureC,
          min: 0.0,
          max: 100.0,
          onChanged: vaporNotifier.setTemperature,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.deepRelativeVapor(
            fmtNum(vaporState.relativePressure, 4),
          ),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.elio.errorText,
          ),
        ),
        const Divider(height: 32),

        Text(
          context.l10n.deepIncinerator,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.elio.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.simDeepDive28,
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.elio.surface,
            border: Border.all(color: context.elio.borderSubtle),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: IncineratorPainter(
              temperatureC: incinState.temperatureC,
              isDestroyed: incinState.bondsDestroyed,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LabeledSlider(
          label: l10n.simDeepDive17,
          valueLabel: '${fmtNum(incinState.temperatureC, 0)} °C',
          value: incinState.temperatureC,
          min: 200.0,
          max: 1200.0,
          onChanged: incinNotifier.setTemperature,
        ),
        const SizedBox(height: 8),
        Text(
          incinState.bondsDestroyed ? l10n.simDeepDive18 : l10n.simDeepDive29,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: incinState.bondsDestroyed
                ? context.elio.primaryText
                : context.elio.errorText,
          ),
        ),
        const Divider(height: 32),

        Text(
          context.l10n.deepRadiationShield,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: context.elio.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.simDeepDive19,
          style: TextStyle(color: context.elio.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        // ⚠ CATATAN AKURASI WAJIB (UI COPY)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.elio.secondaryText.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.elio.secondaryText),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_rounded,
                color: context.elio.secondaryText,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.simDeepDive20,
                  style: TextStyle(
                    color: context.elio.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: RadiationType.values.map((type) {
            final isSelected = radState.selectedType == type;
            final label = type == RadiationType.alpha
                ? l10n.simDeepDive21
                : (type == RadiationType.beta ? 'Beta (β)' : 'Gamma (γ)');
            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (v) => radNotifier.setType(type),
              selectedColor: context.elio.primaryText.withValues(alpha: 0.1),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.elio.surface,
            border: Border.all(color: context.elio.borderSubtle),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: RadiationPainter(
              thicknessCm: radState.thicknessCm,
              transmittedPercent: radState.transmittedIntensityPercent,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LabeledSlider(
          label: l10n.simDeepDive22,
          valueLabel: '${fmtNum(radState.thicknessCm, 1)} cm',
          value: radState.thicknessCm,
          min: 0.0,
          max: 20.0,
          onChanged: radNotifier.setThickness,
        ),
        const SizedBox(height: 24),

        // Why can't it be sorted like organic/inorganic?
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: context.elio.textPrimary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    context.l10n.deepWhyDifferent,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.elio.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                l10n.simDeepDive23,
                style: TextStyle(color: context.elio.textPrimary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
