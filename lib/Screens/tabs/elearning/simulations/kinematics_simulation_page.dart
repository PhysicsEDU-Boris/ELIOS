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
  ConsumerState<KinematicsSimulationPage> createState() =>
      _KinematicsSimulationPageState();
}

class _KinematicsSimulationPageState
    extends ConsumerState<KinematicsSimulationPage>
    with SingleTickerProviderStateMixin {
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
      if (_secondaryAnimation!.status == AnimationStatus.forward ||
          _secondaryAnimation!.status == AnimationStatus.completed) {
        _ticker.muted = true; // Pause when pushed over
      } else if (_secondaryAnimation!.status == AnimationStatus.reverse ||
          _secondaryAnimation!.status == AnimationStatus.dismissed) {
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
      appBarTitle: l10n.simKinematics1,
      header: SimModuleHeader(
        tag: l10n.simKinematics2,
        title: l10n.simKinematics3,
        subtitle: l10n.simKinematics4,
      ),
      formulaBox: FormulaBox(
        title: l10n.simKinematics5,
        formulaText: TextSpan(
          children: [
            const TextSpan(text: 't = s / v = '),
            TextSpan(
              text: fmtNum(state.predictedTimeS, 1),
              style: TextStyle(color: context.elio.secondaryText),
            ),
            const TextSpan(text: ' s'),
          ],
        ),
        subtitle: l10n.simKinematics6,
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
                    Icon(
                      Icons.timer_rounded,
                      color: context.elio.primaryText,
                      size: 24,
                    ),
                    Text(
                      context.l10n.simLiveTimer,
                      style: TextStyle(
                        color: context.elio.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${fmtNum(state.elapsedS, 2)} s',
                      style: TextStyle(
                        color: context.elio.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
          noteText: l10n.simKinematics16,
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
          label: l10n.simKinematics7,
          valueLabel: '${fmtNum(state.distanceM, 1)} m',
          value: state.distanceM,
          min: 2.0,
          max: 20.0,
          onChanged: (v) => notifier.setDistance(v),
        ),
        const SizedBox(height: 14),
        LabeledSlider(
          label: l10n.simKinematics8,
          valueLabel: '${fmtNum(state.velocityMs, 2)} m/s',
          value: state.velocityMs,
          min: 0.1,
          max: 1.0,
          onChanged: (v) => notifier.setVelocity(v),
        ),
        const SizedBox(height: 16),

        CalcBox(
          headerTitle: l10n.simKinematics9,
          formulaExpression: l10n.simKinArrival(
            fmtNum(state.distanceM, 1),
            fmtNum(state.velocityMs, 2),
            fmtNum(state.predictedTimeS, 1),
          ),
          statusIcon: Icons.route_rounded,
          statusColor: context.elio.primaryText,
          statusText: l10n.simKinematics10,
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
              title: Text(
                context.l10n.simBonusUam,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.elio.textPrimary,
                ),
              ),
              iconColor: context.elio.primaryText,
              collapsedIconColor: context.elio.textSecondary,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: context.elio.primaryText
                      .withValues(alpha: 0.1)
                      .withValues(alpha: 0.3),
                  child: Text(
                    l10n.simKinematics11,
                    style: TextStyle(
                      color: context.elio.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      deepExplainCard: DeepExplainCard(
        title: l10n.simKinematics12,
        bodyText: l10n.simKinematics13,
        bulletPoints: [
          l10n.simKinematics17,
          l10n.simKinematics18,
          l10n.simKinematics14,
          l10n.simKinematics15,
        ],
      ),
    );
  }
}
