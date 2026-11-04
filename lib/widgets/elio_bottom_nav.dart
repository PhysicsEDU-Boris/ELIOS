// Bottom navigation (Figma page "N3 Bottom nav", component set 270:5746, spec
// 270:8626): Home, Learn, Control (raised round button), Config, History.
// Tab indices are the app's provider indices (Home 0, Learn 1, Config 2,
// History 4); only the on-screen order differs. Control (3) is an action and
// is never selected.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;
import 'package:elio/l10n/l10n.dart';

const _barHeight = 64.0;
const _ringGap = 4.0; // surface-coloured ring round the Control button
const _controlSize = 56.0;
const _raise = 16.0 + _ringGap; // space above the top rule, taken by the circle

class ElioBottomNav extends StatelessWidget {
  const ElioBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
    required this.onControl,
  });

  /// Active tab: Home 0, Learn 1, Config 2, History 4.
  final int currentIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onControl;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    Widget tab(int i, String label, IconData off, IconData on) => _Cell(
      label: label,
      semantics: label,
      selected: currentIndex == i,
      onTap: () => onSelectTab(i),
      icon: Icon(currentIndex == i ? on : off, size: 24),
    );
    return Semantics(
      container: true,
      label: l10n.navMain,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: p.borderMedium),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(minHeight: _barHeight),
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: tab(0, l10n.navHome, Icons.home_outlined, Icons.home)),
              Expanded(
                child: tab(
                  1,
                  l10n.navLearn,
                  Icons.menu_book_outlined,
                  Icons.menu_book,
                ),
              ),
              Expanded(
                child: _Cell(
                  label: l10n.navControl,
                  semantics: l10n.navControlHint,
                  selected: false,
                  onTap: onControl,
                  icon: const SizedBox.shrink(),
                ),
              ),
              Expanded(
                child: tab(2, l10n.navConfig, Icons.wifi_outlined, Icons.wifi),
              ),
              Expanded(
                child: tab(
                  4,
                  l10n.navHistory,
                  Icons.history_rounded,
                  Icons.history_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One 48 dp+ target: 32 dp icon slot above the label, 24x3 stroke on the rule.
class _Cell extends StatefulWidget {
  const _Cell({
    required this.label,
    required this.semantics,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  final String label, semantics;
  final bool selected;
  final VoidCallback onTap;
  final Widget icon;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _focused = false, _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final color = widget.selected ? p.primaryText : p.textSecondary;
    final plain = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semantics,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (f) => setState(() => _focused = f),
        onHighlightChanged: (v) => setState(() => _pressed = v),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(minHeight: _barHeight - 1),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (widget.selected)
                Container(
                  width: 24,
                  height: 3,
                  decoration: ShapeDecoration(
                    color: p.primaryText,
                    shape: const StadiumBorder(),
                  ),
                ),
              if (_focused)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.primaryText, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: p.primary.withValues(alpha: 0.25),
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 32,
                      alignment: Alignment.center,
                      // Pressed: Surface Raised pill behind the icon.
                      decoration: ShapeDecoration(
                        color: _pressed && !plain ? p.surfaceRaised : null,
                        shape: const StadiumBorder(),
                      ),
                      child: IconTheme(
                        data: IconThemeData(color: color),
                        child: widget.icon,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        style: ElioTokens.caption.copyWith(
                          color: color,
                          height: 16 / 12,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The raised Control circle. Put it in `Scaffold.floatingActionButton` with
/// [ElioControlFabLocation]: it then overlaps the page, not the bar's layout
/// box, and the page above the bar is not shortened. The Control cell in the bar
/// carries the semantics.
///
/// With [modelAsset] the robot icon is a 3D model the user can spin by dragging
/// on it; a tap still opens Control. The icon shows until the model has loaded
/// and stays if it fails (the bar never waits on it).
class ElioControlButton extends StatefulWidget {
  const ElioControlButton({super.key, required this.onTap, this.modelAsset});
  final VoidCallback onTap;
  final String? modelAsset;

  @override
  State<ElioControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ElioControlButton> {
  bool _focused = false, _loaded = false, _failed = false;
  Offset? _down;
  Timer? _showTimer;
  DateTime _lastTap = DateTime(0);

  @override
  void initState() {
    super.initState();
    // onLoad is not always delivered by the web view; show the model anyway.
    _showTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  void _tap() {
    final now = DateTime.now();
    if (now.difference(_lastTap) < const Duration(milliseconds: 500)) return;
    _lastTap = now;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final has3d = widget.modelAsset != null && !_failed;
    return ExcludeSemantics(
      child: InkResponse(
        onTap: _tap,
        onFocusChange: (f) => setState(() => _focused = f),
        highlightShape: BoxShape.circle,
        radius: _controlSize / 2 + _ringGap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Container(
          width: _controlSize + 2 * _ringGap,
          height: _controlSize + 2 * _ringGap,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surface,
            shape: BoxShape.circle,
            boxShadow: _focused
                ? [
                    BoxShadow(color: p.primaryText, spreadRadius: 2),
                    BoxShadow(
                      color: p.primary.withValues(alpha: 0.25),
                      spreadRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Container(
            width: _controlSize,
            height: _controlSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // A sphere: light from the top left, darker towards the rim.
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.4),
                radius: 0.95,
                colors: [
                  Color.lerp(p.primary, Colors.white, 0.45)!,
                  p.primary,
                  p.primaryActive,
                ],
                stops: const [0, 0.55, 1],
              ),
              shape: BoxShape.circle,
              // 1.5 px stroke keeps the circle at 3:1 on white.
              border: Border.all(color: p.primaryText, width: 1.5),
              boxShadow: dark ? ElioGlow.control : ElioLightEffects.card,
            ),
            child: !has3d
                ? Icon(Icons.smart_toy, size: 28, color: p.onPrimary)
                : ClipOval(
                    // The web view turns the robot with its own touch handling;
                    // a short still press is read here as a tap.
                    child: Listener(
                      onPointerDown: (e) => _down = e.position,
                      onPointerUp: (e) {
                        final d = _down;
                        _down = null;
                        if (d != null && (e.position - d).distance < 10) {
                          _tap();
                        }
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Flutter3DViewer(
                            src: widget.modelAsset!,
                            progressBarColor: Colors.transparent,
                            onProgress: (v) {
                              if (v >= 1 && mounted) {
                                setState(() => _loaded = true);
                              }
                            },
                            onLoad: (_) {
                              if (mounted) setState(() => _loaded = true);
                            },
                            onError: (_) {
                              if (mounted) setState(() => _failed = true);
                            },
                          ),
                          if (!_loaded)
                            IgnorePointer(
                              child: Icon(
                                Icons.smart_toy,
                                size: 28,
                                color: p.onPrimary,
                              ),
                            ),
                          // Glossy highlight; the touches pass through.
                          IgnorePointer(
                            child: Align(
                              alignment: const Alignment(-0.35, -0.6),
                              child: Container(
                                width: 22,
                                height: 12,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.55),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Centres the circle horizontally, its ring [_raise] above the bar's top rule.
class ElioControlFabLocation extends FloatingActionButtonLocation {
  const ElioControlFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry g) => Offset(
    (g.scaffoldSize.width - g.floatingActionButtonSize.width) / 2,
    g.contentBottom - _raise,
  );
}
