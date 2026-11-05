import 'package:elio/l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../../../../../widgets/learn/learn_ui.dart';

class SimCanvasFrame extends StatelessWidget {
  final Widget canvas;
  final String noteText;
  final bool showRiskBadge;
  final String? riskBadgeText;

  const SimCanvasFrame({
    super.key,
    required this.canvas,
    required this.noteText,
    this.showRiskBadge = false,
    this.riskBadgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: context.elio.surfaceRaised,
        shape: learnShape(
          learnRadiusM,
          BorderSide(color: context.elio.borderSubtle),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          canvas,
          Positioned(
            top: 10,
            left: 10,
            right: 110,
            child: _SimNote(text: noteText),
          ),
          if (showRiskBadge)
            Positioned(
              top: 10,
              right: 10,
              child: _RiskBadge(text: riskBadgeText ?? l10n.simSimCanvasFrame1),
            ),
        ],
      ),
    );
  }
}

class _SimNote extends StatelessWidget {
  final String text;
  const _SimNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.elio.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.labelMedium?.copyWith(
          color: context.elio.textSecondary,
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String text;
  const _RiskBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.elio.error,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: context.text.labelMedium?.copyWith(color: context.elio.onError),
      ),
    );
  }
}
