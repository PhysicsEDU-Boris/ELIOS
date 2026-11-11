// ELIOS 3 page title (Figma "Scan hub" 629:90675): Display title, green
// squiggle, secondary subtitle. It scrolls with the page; there is no top bar.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/elio_tokens.dart';
import 'learn/learn_ui.dart';

class ElioPageTitle extends StatelessWidget {
  const ElioPageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Shows a round back button before the title (pushed pages).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        style: ElioTokens.body.copyWith(
          fontSize: onBack == null ? 36 : 28,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: onBack == null ? -0.72 : -0.28,
          color: p.textPrimary,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (onBack != null) ...[
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(48),
                  backgroundColor: p.surface,
                  side: BorderSide(color: p.borderSubtle),
                ),
                icon: Icon(Icons.arrow_back_rounded, color: p.textPrimary),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: heading),
            ?trailing,
          ],
        ),
        if (onBack == null)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 2),
            child: ExcludeSemantics(
              child: SvgPicture.asset(
                'assets/illustrations/scan/squiggle.svg',
                width: 72,
                height: 10,
                colorFilter: ColorFilter.mode(p.primary, BlendMode.srcIn),
              ),
            ),
          ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              subtitle!,
              style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
            ),
          ),
      ],
    );
  }
}
