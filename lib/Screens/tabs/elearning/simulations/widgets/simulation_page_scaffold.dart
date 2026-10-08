import 'package:flutter/material.dart';
import '../../../../../../theme/elio_learning_colors.dart';
import '../../../../../widgets/elio_learning_app_bar.dart';
import 'collapsible_section.dart';

class SimulationPageScaffold extends StatelessWidget {
  final String appBarTitle;
  final Widget header;
  final Widget? formulaBox;
  final Widget? deepExplainCard;
  final List<Widget> simulationContent;

  const SimulationPageScaffold({
    super.key,
    required this.appBarTitle,
    required this.header,
    this.formulaBox,
    this.deepExplainCard,
    required this.simulationContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: elioBackground,
      appBar: ElioLearningAppBar(title: appBarTitle, showBack: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  if (deepExplainCard != null) ...[
                    const SizedBox(height: 16),
                    deepExplainCard!,
                  ],
                  if (formulaBox != null) ...[
                    const SizedBox(height: 16),
                    CollapsibleSection(
                      title: 'PERSAMAAN FISIKA',
                      iconEmoji: '🧮',
                      initiallyExpanded: true,
                      child: formulaBox!,
                    ),
                  ],
                  const SizedBox(height: 16),
                  CollapsibleSection(
                    title: 'SIMULASI INTERAKTIF',
                    iconEmoji: '⚙️',
                    initiallyExpanded: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: simulationContent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
