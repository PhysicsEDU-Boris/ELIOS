import 'package:flutter/material.dart';

import 'elio_tokens.dart';

/// Draws a glow around [child] on hover and on focus anywhere inside it
/// (glow only on hover, focus and active; never at rest). Pass [error] to
/// swap to the error glow while focused. Wrap a TextField, card or button.
class ElioGlowBox extends StatefulWidget {
  const ElioGlowBox({
    super.key,
    required this.child,
    this.glow,
    this.onFocusGlow,
    this.radius = ElioTokens.radiusSmall,
  });

  final Widget child;

  /// Shown on hover (default [ElioGlow.subtle]).
  final List<BoxShadow>? glow;

  /// Shown on focus (default [ElioGlow.inputFocus]).
  final List<BoxShadow>? onFocusGlow;
  final double radius;

  @override
  State<ElioGlowBox> createState() => _ElioGlowBoxState();
}

class _ElioGlowBoxState extends State<ElioGlowBox> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    // Light mode: focus ring + halo, no glow on hover (hover is a fill change).
    final light = Theme.of(context).brightness == Brightness.light;
    final shadows = _focus
        ? widget.onFocusGlow ?? (light ? ElioLightEffects.focus : ElioGlow.inputFocus)
        : _hover && !light
            ? widget.glow ?? ElioGlow.subtle
            : const <BoxShadow>[];
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => setState(() => _focus = f),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: shadows,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
