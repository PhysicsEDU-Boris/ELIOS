// Modal drawer for phones (Figma spec 279:2399). Not Scaffold.drawer: that one
// opens from the screen edge, settles at 50% / 365 dp/s and has no drag slop of
// its own. Open 250 ms ease-out, close 200 ms ease-in, no animation with
// reduced motion; it follows the finger 1:1 and closes past 40% or 700 dp/s.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:elio/l10n/l10n.dart';

const _openMs = Duration(milliseconds: 250);
const _closeMs = Duration(milliseconds: 200);
const _slop = 8.0;
const _flingDpPerSecond = 700.0;
const _closeBelow = 0.6; // dragged past 40% of the width

class ElioDrawerHost extends StatefulWidget {
  const ElioDrawerHost({
    super.key,
    required this.child,
    required this.drawer,
    this.onClosed,
    this.maxWidth = 304,
  });

  final Widget child;
  final Widget drawer;

  /// Called once the drawer is fully closed; the shell returns focus to the avatar.
  final VoidCallback? onClosed;
  final double maxWidth;

  @override
  State<ElioDrawerHost> createState() => ElioDrawerHostState();
}

class ElioDrawerHostState extends State<ElioDrawerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this)
    ..addListener(() => setState(() {}));
  bool _open = false;
  double _width = 304;

  bool get isOpen => _open;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void open() {
    if (_open) return;
    setState(() => _open = true);
    _settle(1);
  }

  void close() {
    if (!_open) return;
    setState(() => _open = false);
    _settle(0);
  }

  void _settle(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = target;
      _afterSettle(target);
      return;
    }
    _c
        .animateTo(
          target,
          duration: target == 1 ? _openMs : _closeMs,
          curve: target == 1 ? Curves.easeOut : Curves.easeIn,
        )
        .then((_) => _afterSettle(target));
  }

  void _afterSettle(double target) {
    if (mounted && target == 0 && !_open) widget.onClosed?.call();
  }

  void _dragUpdate(DragUpdateDetails d) {
    _c.value = (_c.value + (d.primaryDelta ?? 0) / _width).clamp(0.0, 1.0);
  }

  void _dragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final closing =
        v < -_flingDpPerSecond ||
        (v <= _flingDpPerSecond && _c.value < _closeBelow);
    if (closing) {
      setState(() => _open = false);
      _settle(0);
    } else {
      _settle(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.value;
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: LayoutBuilder(
        builder: (context, box) {
          _width = widget.maxWidth < box.maxWidth * 0.8
              ? widget.maxWidth
              : box.maxWidth * 0.8;
          return Stack(
            children: [
              // The page behind is inert while the drawer is open.
              ExcludeFocus(
                excluding: _open,
                child: ExcludeSemantics(excluding: _open, child: widget.child),
              ),
              if (v > 0)
                Positioned.fill(
                  child: RawGestureDetector(
                    gestures: {
                      _DrawerDrag:
                          GestureRecognizerFactoryWithHandlers<_DrawerDrag>(
                            _DrawerDrag.new,
                            (r) => r
                              ..onStart = ((_) => _c.stop())
                              ..onUpdate = _dragUpdate
                              ..onEnd = _dragEnd,
                          ),
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Semantics(
                            button: true,
                            label: l10n.closeMenu,
                            excludeSemantics: true,
                            onTap: close,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: close,
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: 0.4 * v),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -_width * (1 - v),
                          top: 0,
                          bottom: 0,
                          width: _width,
                          child: Semantics(
                            scopesRoute: true,
                            namesRoute: true,
                            explicitChildNodes: true,
                            label: l10n.navigationMenu,
                            child: CallbackShortcuts(
                              bindings: {
                                const SingleActivator(
                                  LogicalKeyboardKey.escape,
                                ): close,
                              },
                              child: FocusScope(
                                autofocus: true,
                                child: widget.drawer,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Horizontal drag with the spec's direction lock: after 8 dp of travel it is a
/// drawer drag only if |dx| > |dy|; otherwise it steps aside so the menu list
/// keeps its vertical scroll.
class _DrawerDrag extends HorizontalDragGestureRecognizer {
  Offset _from = Offset.zero;
  bool _accepted = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _from = event.position;
    _accepted = false;
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    super.acceptGesture(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (!_accepted && event is PointerMoveEvent) {
      final d = event.position - _from;
      if (d.distance > _slop) {
        if (d.dx.abs() > d.dy.abs()) {
          resolve(GestureDisposition.accepted);
        } else {
          resolvePointer(event.pointer, GestureDisposition.rejected);
          return;
        }
      }
    }
    super.handleEvent(event);
  }
}
