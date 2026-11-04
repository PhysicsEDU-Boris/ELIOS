import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../Screens/scan_history_screen.dart';
import '../services/scan_record_store.dart';
import '../theme/elio_tokens.dart';
import 'control/r2_controls.dart';
import 'learn/learn_ui.dart' show LearnTheme;
import 'package:elio/l10n/l10n.dart';

/// The R2 gamified Control screen layout (Figma 358:2358, decision 0173; the
/// STOP rules of 0026 hold at every size).
///
/// - Wide (from [wideMinWidth] and [wideMinHeight]): the Figma grid. Drive
///   card, camera + action bar, arm card; mission, "This drive", ELIO tip and
///   toggles below.
/// - Landscape (from [landscapeMinWidth]): the same three columns, the bottom
///   cards collapsed into one [compactStrip] row (cards again from
///   [cardsMinHeight]).
/// - Portrait: stacked and scrolling, STOP pinned bottom right.
///
/// STOP is never scaled below 64 dp, covered or dimmed; the quiz lays over
/// everything below the STOPPED strip and has its own STOP in its header.
class ControlLayout extends StatelessWidget {
  const ControlLayout({
    super.key,
    required this.exitButton,
    required this.historyButton,
    this.debugScanButton,
    this.debugBuild = kDebugMode,
    this.avatar,
    this.stoppedPill,
    required this.driveStatus,
    required this.joystick,
    this.driveHint,
    required this.speed,
    required this.camera,
    required this.actions,
    required this.armStatus,
    required this.armHeight,
    required this.armReach,
    required this.power,
    required this.stopButton,
    this.armTip,
    required this.bottomCards,
    required this.compactStrip,
    required this.quiz,
    this.stoppedBanner,
  });

  final Widget exitButton;
  final Widget historyButton;

  /// Shown only in debug builds ([debugBuild]).
  final Widget? debugScanButton;
  final bool debugBuild;
  final Widget? avatar;

  /// `Robot STOPPED · <why>` in the top bar.
  final Widget? stoppedPill;
  final Widget driveStatus;
  final Widget joystick;
  final Widget? driveHint;

  /// Speed fader with its gear chips.
  final Widget speed;
  final Widget camera;

  /// HOME, PICK UP, RELEASE and the gripper fader.
  final Widget actions;
  final Widget armStatus;
  final Widget armHeight;
  final Widget armReach;
  final Widget power;
  final Widget stopButton;
  final Widget? armTip;

  /// Mission, "This drive", ELIO tip, toggles.
  final List<Widget> bottomCards;
  final Widget compactStrip;
  final Widget quiz;
  final Widget? stoppedBanner;

  static const wideMinWidth = 1100.0;
  static const wideMinHeight = 680.0;
  static const landscapeMinWidth = 600.0;
  static const cardsMinHeight = 700.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ?stoppedBanner,
        Expanded(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final w = viewport.maxWidth, h = viewport.maxHeight;
              final screenH = MediaQuery.maybeSizeOf(context)?.height ?? h;
              final Widget body;
              var pinStop = false;
              if (w >= wideMinWidth && screenH >= wideMinHeight) {
                body = _wide(context);
              } else if (w >= landscapeMinWidth) {
                body = _landscape(context, w, cards: screenH >= cardsMinHeight);
              } else {
                pinStop = true;
                body = _portrait(context, w);
              }
              return Stack(
                children: [
                  Positioned.fill(child: body),
                  if (pinStop) Positioned(right: 12, bottom: 12, child: stopButton),
                  quiz,
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _topBar(BuildContext context, {required bool title, required bool wrap}) {
    final p = context.elio;
    final right = [if (debugBuild && debugScanButton != null) debugScanButton!, historyButton, ?avatar];
    if (wrap) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [exitButton, ?stoppedPill, ...right],
      );
    }
    return Row(
      children: [
        exitButton,
        const SizedBox(width: 12),
        Expanded(
          child: title
              ? fitDown(Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Robot Control',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Drive close, pick it up, sort it right!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.textSecondary, fontSize: 13),
                    ),
                  ],
                ))
              : const SizedBox.shrink(),
        ),
        if (stoppedPill != null) ...[Flexible(flex: 2, child: stoppedPill!), const SizedBox(width: 8)],
        for (final r in right) ...[r, if (r != right.last) const SizedBox(width: 8)],
      ],
    );
  }

  Widget _cardHeader(IconData icon, String label, Widget status) => Row(
    children: [
      Builder(builder: (context) => Icon(icon, size: 18, color: context.elio.primaryText)),
      const SizedBox(width: 6),
      Expanded(child: ControlCaps(label)),
      Flexible(
        child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: status),
      ),
    ],
  );

  Widget _driveCard({required bool roomy}) => ControlCard(
    padding: EdgeInsets.all(roomy ? 16 : 10),
    child: Column(
      children: [
        _cardHeader(Icons.speed_rounded, 'DRIVE', driveStatus),
        SizedBox(height: roomy ? 8 : 4),
        Expanded(child: joystick),
        if (roomy && driveHint != null) ...[const SizedBox(height: 6), driveHint!],
        SizedBox(height: roomy ? 10 : 4),
        speed,
      ],
    ),
  );

  Widget _armCard({required bool roomy, required bool withStop}) {
    Widget fader(Widget f) => Expanded(child: f);
    final buttons = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        power,
        if (withStop) ...[SizedBox(height: roomy ? 16 : 8), stopButton],
      ],
    );
    return ControlCard(
      padding: EdgeInsets.all(roomy ? 16 : 10),
      child: Column(
        children: [
          _cardHeader(Icons.precision_manufacturing_outlined, 'ARM', armStatus),
          SizedBox(height: roomy ? 8 : 4),
          Expanded(
            child: Row(
              children: [
                fader(armHeight),
                SizedBox(width: roomy ? 12 : 6),
                fader(armReach),
                SizedBox(width: roomy ? 12 : 6),
                // Power and STOP keep their size; only the faders give way.
                SizedBox(width: roomy ? 112 : 84, child: buttons),
              ],
            ),
          ),
          if (roomy && armTip != null) ...[const SizedBox(height: 10), armTip!],
        ],
      ),
    );
  }

  Widget _wide(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        SizedBox(height: 56, child: _topBar(context, title: true, wrap: false)),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 300, child: _driveCard(roomy: true)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: camera),
                    const SizedBox(height: 16),
                    SizedBox(height: 120, child: ControlCard(child: actions)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(width: 340, child: _armCard(roomy: true, withStop: true)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(height: 144, child: _cardsRow(const [300, 0, 0, 240], gap: 20)),
      ],
    ),
  );

  /// Fixed widths (0 = flexible); each card scales down rather than clip.
  Widget _cardsRow(List<double> widths, {required double gap}) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < bottomCards.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        if (widths[i] > 0) SizedBox(width: widths[i], child: bottomCards[i]) else Expanded(child: bottomCards[i]),
      ],
    ],
  );

  Widget _landscape(BuildContext context, double w, {required bool cards}) {
    final driveW = (w * 0.24).clamp(180.0, 280.0);
    final armW = (w * 0.27).clamp(210.0, 320.0);
    final roomy = cards;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          SizedBox(height: 44, child: _topBar(context, title: w >= 900, wrap: false)),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: driveW,
                  child: _driveCard(roomy: roomy),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: camera),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: roomy ? 110 : 76,
                        child: ControlCard(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: actions,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: armW,
                  child: _armCard(roomy: roomy, withStop: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (cards)
            SizedBox(height: 132, child: _cardsRow(const [0, 0, 0, 0], gap: 8))
          else
            SizedBox(height: 48, child: compactStrip),
        ],
      ),
    );
  }

  Widget _portrait(BuildContext context, double w) => SingleChildScrollView(
    // Room under the pinned STOP so nothing ends up behind it.
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12 + EmergencyStopButton.size + 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topBar(context, title: false, wrap: true),
        const SizedBox(height: 12),
        AspectRatio(aspectRatio: 4 / 3, child: camera),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ControlCard(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: actions),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 400, child: _driveCard(roomy: true)),
        const SizedBox(height: 8),
        SizedBox(height: 300, child: _armCard(roomy: true, withStop: false)),
        for (final c in bottomCards) ...[const SizedBox(height: 8), SizedBox(height: 132, child: c)],
      ],
    ),
  );
}

/// A pill in the top bar (Exit, History, Debug).
class ControlPill extends StatelessWidget {
  const ControlPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.dashed = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  /// Debug: a quiet outlined pill.
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Material(
      color: dashed ? Colors.transparent : p.surface,
      shape: StadiumBorder(
        side: BorderSide(color: dashed ? p.borderStrong : p.borderMedium, width: dashed ? 1 : 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 4, trailing == null ? 16 : 6, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: dashed ? p.textSecondary : p.textPrimary),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: dashed ? p.textSecondary : p.textPrimary,
                    fontSize: dashed ? 13 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `Robot STOPPED · <why>` (Figma 368:3125): the STOPPED state in the top bar.
class StoppedPill extends StatelessWidget {
  const StoppedPill({super.key, required this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final why = switch (reason) {
      'link_lost' => 'link lost',
      'button' => 'STOP',
      'error' => 'robot error',
      _ => reason ?? '-',
    };
    return DecoratedBox(
      decoration: ShapeDecoration(color: p.error, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: p.onError, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Robot STOPPED · $why',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.onError, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HOME as a transport key, with the 1-second hold-to-confirm (decision 0027).
class HomeButton extends StatefulWidget {
  const HomeButton({
    super.key,
    required this.onConfirmed,
    this.enabled = true,
    this.holdDuration = const Duration(seconds: 1),
    this.size = 60,
  });

  final VoidCallback onConfirmed;
  final bool enabled;
  final Duration holdDuration;
  final double size;

  @override
  State<HomeButton> createState() => _HomeButtonState();
}

class _HomeButtonState extends State<HomeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.holdDuration);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDown() {
    if (!widget.enabled) return;
    _holdTimer?.cancel();
    _controller.forward(from: 0.0);
    _holdTimer = Timer(widget.holdDuration, () {
      widget.onConfirmed();
    });
  }

  void _onUpOrCancel() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!widget.enabled) return;
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tahan 1 detik untuk HOME',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _onDown(),
        onPointerUp: (_) => _onUpOrCancel(),
        onPointerCancel: (_) => _onUpOrCancel(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => TransportKey(
            icon: Icons.home_outlined,
            label: 'HOME',
            size: widget.size,
            progress: _controller.value,
            onTap: widget.enabled ? () {} : null,
          ),
        ),
      ),
    );
  }
}

/// History with the trophy count. Opens the scan history screen.
class HistoryPill extends StatelessWidget {
  const HistoryPill({super.key, this.trophies, this.store, this.onTap});

  final int? trophies;
  final ScanRecordStore? store;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveStore = store ?? ScanRecordStore.instance;
    return AnimatedBuilder(
      animation: effectiveStore,
      builder: (context, _) {
        final total = trophies ?? effectiveStore.totalTrophies;
        final p = context.elio;
        return ControlPill(
          icon: Icons.history_rounded,
          label: 'History',
          onTap:
              onTap ??
              () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (context) => ScanHistoryScreen(store: effectiveStore)));
              },
          trailing: DecoratedBox(
            decoration: ShapeDecoration(color: p.secondaryText.withValues(alpha: 0.15), shape: const StadiumBorder()),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded, size: 14, color: p.secondaryText),
                  const SizedBox(width: 4),
                  Text(
                    '$total',
                    style: TextStyle(color: p.secondaryText, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The emergency stop (Glow button "Stop", 358:2446): red, round, one tap,
/// never smaller than 64 dp, never dimmed. "STOP" never wraps.
class EmergencyStopButton extends StatelessWidget {
  const EmergencyStopButton({super.key, required this.onStop, this.diameter});

  final VoidCallback onStop;

  /// Defaults to [size] (104 on tall screens, 72 when short).
  final double? diameter;

  static const size = 72.0;
  static const minSize = 64.0;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final tall = (MediaQuery.maybeSizeOf(context)?.height ?? 0) >= 700;
    final d = (diameter ?? (tall ? 104.0 : size)).clamp(minSize, 160.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Berhenti darurat',
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: p.destructiveActive, offset: const Offset(0, 4)),
                ...ElioGlow.destructiveHover,
              ],
            ),
            child: Material(
              color: p.error,
              shape: CircleBorder(
                side: BorderSide(color: p.onError, width: d * 0.05),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onStop,
                // Scaled down, never wrapped, in whatever font the device has.
                child: Padding(
                  padding: EdgeInsets.all(d * 0.16),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'STOP',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(color: p.onError, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (d > size) ...[
          const SizedBox(height: 6),
          Text('Space / Esc', style: TextStyle(color: p.textSecondary, fontSize: 12)),
        ],
      ],
    );
  }
}

/// STOPPED: why, and "Lanjutkan", the deliberate second action. A full-width
/// strip above everything else, so it hides nothing.
class StoppedBanner extends StatelessWidget {
  const StoppedBanner({super.key, required this.reason, required this.onResume});

  final String? reason;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final why = switch (reason) {
      'link_lost' => 'koneksi terputus',
      'button' => 'tombol STOP',
      'error' => 'robot error',
      _ => reason ?? '-',
    };
    final isShort = MediaQuery.maybeSizeOf(context)?.height != null && MediaQuery.sizeOf(context).height < 500;
    return Material(
      color: const Color(0xFFD32F2F),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: isShort ? 4 : 6),
        child: Row(
          children: [
            Icon(Icons.pan_tool_rounded, color: Colors.white, size: isShort ? 18 : 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ROBOT DIHENTIKAN ($why). Pemindaian berhenti; kuis yang terbuka tetap bisa dijawab.',
                maxLines: isShort ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: isShort ? 11.5 : 14),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onResume,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.transparent, // the ELIO theme fills outlined buttons
                side: const BorderSide(color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: isShort ? 8 : 16, vertical: isShort ? 4 : 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(context.l10n.commonContinue, style: TextStyle(fontSize: isShort ? 12 : 14)),
            ),
          ],
        ),
      ),
    );
  }
}
