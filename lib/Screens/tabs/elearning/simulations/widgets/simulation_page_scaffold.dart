import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../models/physics_module.dart';
import '../../../../../providers/physics_progress_provider.dart';
import '../../../../../theme/elio_motion.dart';
import '../../../../../widgets/learn/learn_l3.dart';
import '../../../../../widgets/learn/learn_ui.dart';
import '../../learn_content.dart';
import 'package:elio/l10n/l10n.dart';

const _deg = math.pi / 180;

/// Learn L3 simulation layout (Figma 706:29938 / 707:30679, card 20g):
/// curved header with the art as a tilted polaroid, title block, stat
/// bubbles, then Materi / Rumus / Simulasi tabs in a leaf lab card.
class SimulationPageScaffold extends StatefulWidget {
  final String appBarTitle;
  final Widget header;
  final Widget? formulaBox;
  final Widget? deepExplainCard;
  final List<Widget> simulationContent;

  /// Drives the art and the Rumus / Durasi / Status stats.
  final PhysicsModuleId? module;

  /// Live canvas shown in the polaroid instead of the static art.
  final Widget? heroCanvas;

  /// Bumped by the page on a correct answer: the Done sticker bounces.
  final int doneSignal;

  const SimulationPageScaffold({
    super.key,
    required this.appBarTitle,
    required this.header,
    this.formulaBox,
    this.deepExplainCard,
    required this.simulationContent,
    this.module,
    this.heroCanvas,
    this.doneSignal = 0,
  });

  @override
  State<SimulationPageScaffold> createState() => _SimulationPageScaffoldState();
}

class _SimulationPageScaffoldState extends State<SimulationPageScaffold> {
  late String _tab = l10n.lnSimulations;
  int _dir = 1;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final tabs = <(String, Widget)>[
      if (widget.deepExplainCard case final w?) (l10n.lnTabTheory, w),
      if (widget.formulaBox case final w?) (l10n.lnTabFormula, w),
      (
        l10n.lnSimulations,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.simulationContent,
        ),
      ),
    ];
    final current = tabs.firstWhere(
      (t) => t.$1 == _tab,
      orElse: () => tabs.last,
    );
    final index = tabs.indexOf(current);
    final top = MediaQuery.paddingOf(context).top;
    final reduced = ElioMotion.reduced(context);

    return Scaffold(
      backgroundColor: p.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          L3Hero(
            curveBottom: top + 186,
            sparkles: [(300, top + 52, 14), (40, top + 56, 9)],
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, top + 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const L3BackButton(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.lnSimulation,
                          style: context.text.titleLarge?.copyWith(
                            color: p.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (widget.module case final id?)
                    _ArtPolaroid(
                      module: id,
                      canvas: widget.heroCanvas,
                      doneSignal: widget.doneSignal,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.header,
                if (widget.module case final id?) ...[
                  const SizedBox(height: 24),
                  _SimStats(module: id),
                ],
                const SizedBox(height: 24),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (i, t) in tabs.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        LearnTabPill(
                          label: t.$1,
                          selected: i == index,
                          onTap: () => setState(() {
                            _dir = i >= index ? 1 : -1;
                            _tab = t.$1;
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Tabs slide with the swipe direction (base 220).
                AnimatedSwitcher(
                  duration: reduced ? ElioMotion.fast : ElioMotion.base,
                  switchInCurve: ElioMotion.emphasized,
                  switchOutCurve: ElioMotion.exit,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, a) {
                    final incoming = child.key == ValueKey(current.$1);
                    final dx = (incoming ? 1 : -1) * _dir * 0.08;
                    return FadeTransition(
                      opacity: a,
                      child: reduced
                          ? child
                          : SlideTransition(
                              position: Tween(
                                begin: Offset(dx, 0),
                                end: Offset.zero,
                              ).animate(a),
                              child: child,
                            ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(current.$1),
                    // Materi is already a collapsible card; the others sit in
                    // the leaf lab card.
                    child: current.$1 == l10n.lnTabTheory
                        ? current.$2
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(19),
                            decoration: ShapeDecoration(
                              color: p.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: leafL,
                                side: BorderSide(color: p.borderSubtle),
                              ),
                            ),
                            child: current.$2,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The simulation art as a polaroid tilted +2° with the Done sticker (+8°),
/// which bounces in again on [doneSignal].
class _ArtPolaroid extends ConsumerWidget {
  const _ArtPolaroid({
    required this.module,
    required this.canvas,
    required this.doneSignal,
  });
  final PhysicsModuleId module;
  final Widget? canvas;
  final int doneSignal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final done =
        ref
            .watch(physicsProgressProvider)
            .valueOrNull
            ?.viewedModuleIds
            .contains(module.name) ??
        false;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Transform.rotate(
            angle: 2 * _deg,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.borderSubtle),
                boxShadow: l3Shadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: AspectRatio(
                  aspectRatio: 318 / 194,
                  child: ColoredBox(
                    color: p.surfaceRaised,
                    child:
                        canvas ??
                        LearnIllustration(
                          LearnArt.simulation(module),
                          fit: BoxFit.cover,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (done)
          Positioned(
            right: 4,
            top: -12,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(doneSignal),
              tween: Tween(begin: doneSignal == 0 ? 1 : 0, end: 1),
              duration: ElioMotion.celebrate,
              curve: ElioMotion.bounce,
              builder: (context, s, child) =>
                  Transform.scale(scale: s, child: child),
              child: L3Sticker(
                label: l10n.lnDone,
                icon: Icons.check_rounded,
                angle: 8,
                border: true,
              ),
            ),
          ),
      ],
    );
  }
}

class _SimStats extends ConsumerWidget {
  const _SimStats({required this.module});

  final PhysicsModuleId module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = physicsModules.firstWhere((m) => m.id == module);
    final done =
        ref
            .watch(physicsProgressProvider)
            .valueOrNull
            ?.viewedModuleIds
            .contains(module.name) ??
        false;
    return L3StatBubbles(
      stats: [
        L3Stat(
          icon: Icons.functions_rounded,
          value: info.formula,
          label: l10n.lnTabFormula,
          tone: LearnTone.info,
        ),
        L3Stat(
          icon: Icons.schedule_rounded,
          value: l10n.lnMinutes(info.durationMinutes),
          label: l10n.lnDuration,
          tone: LearnTone.warning,
        ),
        L3Stat(
          icon: done ? Icons.check_rounded : Icons.radio_button_unchecked,
          value: done ? l10n.lnDone : l10n.lnNew,
          label: l10n.lnStatus,
          tone: LearnTone.success,
        ),
      ],
    );
  }
}
