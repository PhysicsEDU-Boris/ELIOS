import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../models/physics_module.dart';
import '../../../../../providers/physics_progress_provider.dart';
import '../../../../../widgets/learn/learn_ui.dart';
import '../../learn_content.dart';
import 'package:elio/l10n/l10n.dart';

/// L1 v2 simulation layout (Figma 310:5964): summary card with canvas,
/// meta, title and stats, then Materi / Rumus / Simulasi tabs holding the
/// page's existing sections.
class SimulationPageScaffold extends StatefulWidget {
  final String appBarTitle;
  final Widget header;
  final Widget? formulaBox;
  final Widget? deepExplainCard;
  final List<Widget> simulationContent;

  /// Drives the canvas and the Rumus / Durasi / Status stats.
  final PhysicsModuleId? module;

  const SimulationPageScaffold({
    super.key,
    required this.appBarTitle,
    required this.header,
    this.formulaBox,
    this.deepExplainCard,
    required this.simulationContent,
    this.module,
  });

  @override
  State<SimulationPageScaffold> createState() => _SimulationPageScaffoldState();
}

class _SimulationPageScaffoldState extends State<SimulationPageScaffold> {
  late String _tab = l10n.lnSimulations;

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, IconData, Widget)>[
      if (widget.deepExplainCard case final w?) (l10n.lnTabTheory, Icons.menu_book_outlined, w),
      if (widget.formulaBox case final w?) (l10n.lnTabFormula, Icons.functions_rounded, w),
      (
        l10n.lnSimulations,
        Icons.science_outlined,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widget.simulationContent,
        ),
      ),
    ];
    final current = tabs.firstWhere((t) => t.$1 == _tab, orElse: () => tabs.last);

    return LearnPageScaffold(
      title: l10n.lnSimulations,
      body: LearnListView(
        children: [
          LearnCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.module case final id?) ...[
                  LearnCover(
                    aspectRatio: 16 / 10,
                    child: LearnIllustration(LearnArt.simulation(id), fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 12),
                ],
                widget.header,
                if (widget.module case final id?) ...[
                  const SizedBox(height: 16),
                  _SimStats(module: id),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          LearnSegmented(
            labels: [for (final t in tabs) t.$1],
            icons: [for (final t in tabs) t.$2],
            selected: tabs.indexOf(current),
            onSelected: (i) => setState(() => _tab = tabs[i].$1),
          ),
          const SizedBox(height: 16),
          // Materi is already a collapsible card; the others get one.
          if (current.$1 == 'Materi') current.$3 else LearnCard(child: current.$3),
        ],
      ),
    );
  }
}

class _SimStats extends ConsumerWidget {
  const _SimStats({required this.module});

  final PhysicsModuleId module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final info = physicsModules.firstWhere((m) => m.id == module);
    final done =
        ref.watch(physicsProgressProvider).valueOrNull?.viewedModuleIds.contains(module.name) ??
        false;
    Widget stat(IconData icon, String value, String label, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LearnMeta(icon: icon, label: value, color: color),
          Text(label, style: context.text.labelMedium?.copyWith(color: p.textSecondary)),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stat(Icons.functions_rounded, info.formula, l10n.lnTabFormula, p.primaryText),
        stat(Icons.schedule_rounded, l10n.lnMinutes(info.durationMinutes), l10n.lnDuration, p.tertiaryText),
        stat(
          done ? Icons.check_rounded : Icons.radio_button_unchecked,
          done ? l10n.lnDone : l10n.lnNew,
          l10n.lnStatus,
          done ? p.primaryText : p.textSecondary,
        ),
      ],
    );
  }
}
