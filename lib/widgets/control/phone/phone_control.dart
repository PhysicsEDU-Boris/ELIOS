// R3 Control layout for phones in landscape (Figma 393:2358, decision 0174).
// UI only: every handler comes from ControlScreen and still goes through
// MotionGate (0026). Colours come from the active ElioPalette.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/control_session.dart';
import '../../../theme/elio_tokens.dart';
import '../../control_layout.dart' show HomeButton;
import '../../elio_top_bar.dart' show ElioAvatar;
import '../../waste_quiz_popup.dart' show QuizButton;
import '../r2_controls.dart';
import '../../learn/learn_ui.dart' show LearnTheme;

/// Phones in landscape: the shortest side is under 600 dp. Tablets and the Mac keep R2.
bool isPhoneLandscape(BuildContext context) {
  final s = MediaQuery.sizeOf(context);
  return s.shortestSide < 600 && s.width > s.height;
}

/// Everything the phone layout shows and calls. Nothing here talks to the robot.
class PhoneControlLayout extends StatelessWidget {
  const PhoneControlLayout({
    super.key,
    required this.link,
    required this.stopped,
    required this.stopReason,
    required this.skeleton,
    required this.driveLabel,
    required this.armLabel,
    required this.speed,
    required this.onSpeed,
    required this.onDirection,
    required this.onRelease,
    required this.frame,
    required this.fps,
    required this.scanQuizOn,
    required this.onScanQuiz,
    required this.voiceOn,
    required this.onVoice,
    required this.onHome,
    required this.onPickUp,
    required this.onReleaseGripper,
    required this.gripper,
    required this.onGripper,
    required this.height,
    required this.onHeight,
    required this.reach,
    required this.onReach,
    required this.onPower,
    required this.onConnect,
    required this.onStop,
    required this.onGo,
    required this.missionDone,
    required this.trophies,
    required this.quizBadge,
    this.quizWaiting = false,
    required this.onQuiz,
    required this.onHistory,
    required this.onAvatar,
    required this.onBack,
    required this.onGuide,
    this.photoUrl,
    this.overlays = const [],
    this.onLock,
    this.lockBox,
    this.lockLabel,
    this.driveKey,
    this.stopKey,
    this.actionKey,
    this.quizKey,
  });

  final ControlLink link;
  final bool stopped;
  final String? stopReason;
  final bool skeleton;
  final (String, Color) driveLabel, armLabel;
  final double speed;
  final ValueChanged<double> onSpeed;
  final ValueChanged<DriveDir> onDirection;
  final VoidCallback onRelease;
  final Uint8List? frame;
  final double fps;
  final bool scanQuizOn, voiceOn;
  final ValueChanged<bool> onScanQuiz, onVoice;
  final VoidCallback onHome, onPickUp, onReleaseGripper;
  final double gripper, height, reach;
  final ValueChanged<double> onGripper, onHeight, onReach;
  final VoidCallback onPower, onConnect, onStop, onGo;
  final int missionDone, trophies;

  /// Null hides the Quiz button (no quiz).
  final int? quizBadge;

  /// The question is still being prepared: the Quiz button shows Waiting.
  final bool quizWaiting;
  final VoidCallback onQuiz, onHistory, onAvatar, onBack, onGuide;
  final String? photoUrl;

  /// Where the Guide's spotlight points (steps 1-4).
  final GlobalKey? driveKey, stopKey, actionKey, quizKey;

  /// The quiz popup and the guide, over everything. They keep STOP reachable themselves.
  final List<Widget> overlays;

  /// LOCK (0180): the AI boxes the item in the current frame; null greys the key out.
  final VoidCallback? onLock;

  /// The AI's box for the open LOCK scan, as fractions (0..1) of the frame, and its item name.
  final Rect? lockBox;
  final String? lockLabel;

  /// GO replaces STOP only with a live link: offline always shows STOP (Figma 397:2604).
  bool get _showGo => stopped && link == ControlLink.connected;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    if (skeleton) return _skeletonView(context);
    return ColoredBox(
      color: p.background,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                SizedBox(height: 44, child: _topBar(context)),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 232, child: _driveCard(context)),
                      const SizedBox(width: 8),
                      Expanded(child: _centre(context)),
                      const SizedBox(width: 8),
                      SizedBox(width: 196, child: _armCard(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...overlays,
        ],
      ),
    );
  }

  /// Loading (Figma 397:3314): the same grid as flat placeholders; the real STOP stays on top.
  Widget _skeletonView(BuildContext context) {
    final p = context.elio;
    Widget block(double? w, double h, [double r = 12]) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(r),
      ),
    );
    Widget card(double? w, Widget child) => SizedBox(
      width: w,
      child: PhoneCard(child: child),
    );
    return ColoredBox(
      color: p.background,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      block(44, 44, 22),
                      const SizedBox(width: 8),
                      block(166, 30, 15),
                      const SizedBox(width: 8),
                      block(98, 44, 22),
                      const Spacer(),
                      block(120, 30, 15),
                      const SizedBox(width: 8),
                      block(124, 44, 22),
                      const SizedBox(width: 8),
                      block(120, 44, 22),
                      const SizedBox(width: 8),
                      block(38, 38, 19),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      card(
                        232,
                        Column(
                          children: [
                            Row(
                              children: [
                                block(14, 14, 7),
                                const SizedBox(width: 6),
                                block(36, 10, 5),
                                const Spacer(),
                                block(78, 22, 11),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: block(null, 0, 999),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            block(null, 40),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (var i = 0; i < 4; i++) ...[
                                  if (i > 0) const SizedBox(width: 6),
                                  Expanded(child: block(null, 28, 14)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                block(90, 24, 12),
                                const SizedBox(width: 6),
                                block(60, 24, 12),
                                const SizedBox(width: 6),
                                block(60, 24, 12),
                                const Spacer(),
                                block(80, 24, 12),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Container(
                                key: const ValueKey('phone_video'),
                                decoration: BoxDecoration(
                                  color: p.surfaceRaised,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: p.borderSubtle),
                                  boxShadow: [
                                    BoxShadow(
                                      color: p.borderMedium,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 28,
                                    color: p.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            PhoneCard(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  block(48, 60, 24),
                                  const SizedBox(width: 12),
                                  block(48, 60, 24),
                                  const SizedBox(width: 12),
                                  block(48, 60, 24),
                                  const SizedBox(width: 12),
                                  Expanded(child: block(null, 44)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      card(
                        196,
                        Column(
                          children: [
                            Row(
                              children: [
                                block(14, 14, 7),
                                const SizedBox(width: 6),
                                block(30, 10, 5),
                                const Spacer(),
                                block(70, 22, 11),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  block(48, 0, 18),
                                  const SizedBox(width: 8),
                                  block(48, 0, 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        block(44, 44, 22),
                                        const SizedBox(height: 6),
                                        block(44, 14, 7),
                                        const SizedBox(height: 18),
                                        KeyedSubtree(
                                          key: stopKey,
                                          child: PhoneGlowButton(
                                            key: const ValueKey('phone_stop'),
                                            kind: GlowKind.stop,
                                            size: 76,
                                            onTap: onStop,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...overlays,
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    // Narrow phones (800 dp and under): a smaller title and a plain mission count.
    final narrow = MediaQuery.sizeOf(context).width < 860;
    return Row(
      children: [
        PhonePill(
          key: const ValueKey('phone_back'),
          semantic: 'Exit',
          onTap: onBack,
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: context.elio.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Robot Control',
          maxLines: 1,
          style: TextStyle(
            color: context.elio.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        _GuideButton(onTap: onGuide),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _showGo && !skeleton
                ? const _StoppedPill(key: ValueKey('phone_stopped_pill'))
                : _MissionChip(done: missionDone, compact: narrow),
          ),
        ),
        const SizedBox(width: 8),
        if (quizBadge != null) ...[
          KeyedSubtree(
            key: quizKey,
            child: QuizButton(key: const ValueKey('phone_quiz'), waiting: quizWaiting, count: quizBadge!, onTap: onQuiz),
          ),
          const SizedBox(width: 8),
        ],
        PhonePill(
          key: const ValueKey('phone_history'),
          semantic: 'History',
          onTap: onHistory,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                size: 18,
                color: context.elio.textPrimary,
              ),
              const SizedBox(width: 6),
              TrophyCount(count: trophies),
            ],
          ),
        ),
        const SizedBox(width: 4),
        ElioAvatar(photoUrl: photoUrl, onTap: onAvatar),
      ],
    );
  }

  /// Faded (not blocked) while STOPPED: touches still reach the gate, which drops them.
  Widget _fade(Widget child) => Opacity(
    opacity: stopped && link == ControlLink.connected ? 0.45 : 1,
    child: child,
  );

  Widget _driveCard(BuildContext context) {
    final p = context.elio;
    return PhoneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            icon: Icons.speed_rounded,
            title: 'DRIVE',
            status: driveLabel,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: KeyedSubtree(
              key: driveKey,
              child: _fade(
                DriveJoystick(
                  enabled: true,
                  onDirection: onDirection,
                  onRelease: onRelease,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _fade(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: ControlCaps('SPEED (PWM)')),
                    Text(
                      '${speed.round()}%',
                      style: TextStyle(
                        color: p.primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 36,
                  child: ControlFader(
                    value: speed,
                    max: 100,
                    semanticLabel: 'Speed',
                    onChanged: onSpeed,
                  ),
                ),
                const SizedBox(height: 4),
                GearChips(speed: speed, onSelect: onSpeed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _centre(BuildContext context) {
    final p = context.elio;
    final live = link == ControlLink.connected && frame != null;
    final liveText = live
        ? (stopped ? 'LIVE · scan paused' : 'LIVE · ${fps.round()} fps')
        : 'No video';
    final (connText, connColor) = switch (link) {
      ControlLink.connected => ('Connected', p.primary),
      ControlLink.waiting => ('Connecting...', p.secondaryText),
      ControlLink.disconnected => ('Offline', p.borderStrong),
    };
    return Column(
      children: [
        SizedBox(
          height: 30,
          child: skeleton
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    _InfoChip(
                      dot: live ? p.error : p.borderStrong,
                      text: liveText,
                    ),
                    const SizedBox(width: 6),
                    _IconToggle(
                      icon: Icons.center_focus_strong_outlined,
                      label: 'Scan quiz',
                      value: scanQuizOn,
                      onChanged: onScanQuiz,
                    ),
                    const SizedBox(width: 6),
                    _IconToggle(
                      icon: Icons.volume_up_outlined,
                      label: 'Voice',
                      value: voiceOn,
                      onChanged: onVoice,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _InfoChip(dot: connColor, text: connText),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 6),
        Expanded(child: _video(context)),
        const SizedBox(height: 6),
        _actionBar(context),
      ],
    );
  }

  /// The live frame and nothing on top of it (R3): no bands, tag, reticle or quiz button.
  Widget _video(BuildContext context) {
    final p = context.elio;
    Widget body;
    if (skeleton) {
      body = const SizedBox.expand();
    } else if (link == ControlLink.disconnected) {
      body = _OfflinePanel(onConnect: onConnect);
    } else if (link == ControlLink.waiting) {
      body = Center(
        child: Text(
          'Connecting...',
          style: TextStyle(color: p.textSecondary, fontSize: 14),
        ),
      );
    } else if (frame != null) {
      body = SizedBox.expand(
        child: Image.memory(frame!, fit: BoxFit.cover, gaplessPlayback: true),
      );
      if (lockBox != null) body = Stack(children: [body, Positioned.fill(child: _lockOverlay())]);
    } else {
      body = Center(
        child: Text(
          'Connected. Waiting for camera frames...',
          style: TextStyle(color: p.textSecondary, fontSize: 13),
        ),
      );
    }
    return Container(
      key: const ValueKey('phone_video'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.borderSubtle),
        boxShadow: [
          BoxShadow(color: p.borderMedium, offset: const Offset(0, 3)),
        ],
      ),
      child: body,
    );
  }

  /// The AI's box over the video. The square camera frame is shown with BoxFit.cover, so the box
  /// is scaled by the larger side and shifted by the cropped margin.
  // ponytail: assumes a square frame (MaixCAM2 streams the model's 640x640); pass the frame size if that changes.
  Widget _lockOverlay() => LayoutBuilder(builder: (context, c) {
    final side = c.maxWidth > c.maxHeight ? c.maxWidth : c.maxHeight;
    final dx = (c.maxWidth - side) / 2, dy = (c.maxHeight - side) / 2;
    final b = lockBox!;
    return Stack(children: [
      Positioned(
        key: const ValueKey('phone_lock_box'),
        left: dx + b.left * side,
        top: dy + b.top * side,
        width: b.width * side,
        height: b.height * side,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFF22C55E), width: 3)),
          child: lockLabel == null
              ? null
              : Align(
                  alignment: Alignment.topLeft,
                  child: ColoredBox(
                    color: const Color(0xFF22C55E),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      child: Text(lockLabel!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
        ),
      ),
    ]);
  });

  Widget _actionBar(BuildContext context) {
    final p = context.elio;
    return KeyedSubtree(
      key: actionKey,
      child: PhoneCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: skeleton
            ? const SizedBox(height: 60, child: _SkeletonBlocks())
            : _fade(
                Row(
                  children: [
                    HomeButton(onConfirmed: onHome, size: 48),
                    const SizedBox(width: 12),
                    TransportKey(
                      icon: Icons.back_hand_outlined,
                      label: 'PICK UP',
                      primary: true,
                      size: 48,
                      onTap: onPickUp,
                    ),
                    const SizedBox(width: 12),
                    TransportKey(
                      icon: Icons.front_hand_outlined,
                      label: 'RELEASE',
                      size: 48,
                      onTap: onReleaseGripper,
                    ),
                    const SizedBox(width: 12),
                    TransportKey(
                      key: const ValueKey('phone_lock'),
                      icon: Icons.center_focus_strong,
                      label: 'LOCK',
                      size: 48,
                      onTap: onLock,
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1.5, height: 52, color: p.borderSubtle),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Expanded(child: ControlCaps('GRIPPER')),
                              Text(
                                '${gripper.round()}%',
                                style: TextStyle(
                                  color: p.primaryText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 36,
                            child: ControlFader(
                              value: gripper,
                              max: 100,
                              semanticLabel: 'Gripper',
                              onChanged: onGripper,
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

  Widget _armCard(BuildContext context) {
    final p = context.elio;
    final on = link == ControlLink.connected;
    Widget fader(String label, double value, ValueChanged<double> onChanged) =>
        SizedBox(
          width: 48,
          child: Column(
            children: [
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  color: p.primaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ControlFader(
                  vertical: true,
                  value: value,
                  semanticLabel: label,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(height: 4),
              ControlCaps(label),
            ],
          ),
        );
    return PhoneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            icon: Icons.precision_manufacturing_outlined,
            title: 'ARM',
            status: armLabel,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _fade(
                  fader('HEIGHT', (height / 180).clamp(0.0, 1.0), onHeight),
                ),
                const SizedBox(width: 8),
                _fade(fader('REACH', (reach / 180).clamp(0.0, 1.0), onReach)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: on || link == ControlLink.waiting
                            ? 'Putuskan robot'
                            : 'Hubungkan robot',
                        child: PhoneGlowButton(
                          key: const ValueKey('robot_power'),
                          kind: on ? GlowKind.powerOn : GlowKind.powerOff,
                          size: 44,
                          onTap: onPower,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        on
                            ? 'Online'
                            : (link == ControlLink.waiting
                                  ? 'Connecting...'
                                  : 'Offline'),
                        maxLines: 1,
                        style: TextStyle(
                          color: on ? p.primaryText : p.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      KeyedSubtree(
                        key: stopKey,
                        child: _showGo
                            ? PhoneGlowButton(
                                key: const ValueKey('phone_go'),
                                kind: GlowKind.go,
                                size: 76,
                                onTap: onGo,
                              )
                            : PhoneGlowButton(
                                key: const ValueKey('phone_stop'),
                                kind: GlowKind.stop,
                                size: 76,
                                onTap: onStop,
                              ),
                      ),
                    ],
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

/// A card with the R2 shape: 20 dp radius, 4 dp bottom lip.
class PhoneCard extends StatelessWidget {
  const PhoneCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 12),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.borderSubtle),
        boxShadow: [
          BoxShadow(color: p.borderMedium, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

/// A rounded white pill button with the 3 dp lip.
class PhonePill extends StatelessWidget {
  const PhonePill({
    super.key,
    required this.child,
    required this.onTap,
    required this.padding,
    this.semantic,
    this.green = false,
  });
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsets padding;
  final String? semantic;
  final bool green;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      button: true,
      label: semantic,
      excludeSemantics: semantic != null,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: green ? p.primary : p.borderSubtle,
            width: green ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: p.borderMedium, offset: const Offset(0, 3)),
          ],
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _GuideButton extends StatelessWidget {
  const _GuideButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return PhonePill(
      key: const ValueKey('phone_guide'),
      green: true,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
            child: ExcludeSemantics(
              child: SvgPicture.asset(
                'assets/illustrations/control/elio_robot.svg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Guide',
            style: TextStyle(
              color: p.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionChip extends StatelessWidget {
  const _MissionChip({required this.done, this.compact = false});
  final int done;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: p.borderSubtle),
        boxShadow: [
          BoxShadow(color: p.borderMedium, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, size: 16, color: p.primaryText),
            const SizedBox(width: 6),
            if (!compact)
              for (var i = 0; i < missionTarget; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Container(
                  width: 14,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < done ? p.primary : p.borderMedium,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            const SizedBox(width: 6),
            Text(
              '${done.clamp(0, missionTarget)}/$missionTarget',
              style: TextStyle(
                color: p.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoppedPill extends StatelessWidget {
  const _StoppedPill({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.isDark
            ? p.error.withValues(alpha: 0.18)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: p.error),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: p.error, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Robot stopped · scanning paused',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.errorText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrophyCount extends StatelessWidget {
  const TrophyCount({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: ElioTokens.answerYellow, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              size: 14,
              color: ElioTokens.answerYellow,
            ),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: TextStyle(
                color: p.secondaryText,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.status,
  });
  final IconData icon;
  final String title;
  final (String, Color) status;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: context.elio.primaryText),
      const SizedBox(width: 6),
      ControlCaps(title),
      const Spacer(),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ControlStatusChip(label: status.$1, color: status.$2),
        ),
      ),
    ],
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.dot, required this.text});
  final Color dot;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: p.borderSubtle),
        boxShadow: [
          BoxShadow(color: p.borderMedium, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact switch with an icon (Figma Phone/Icon toggle). The label is the semantics label.
class _IconToggle extends StatelessWidget {
  const _IconToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: GestureDetector(
        key: ValueKey('toggle_$label'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: p.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: p.textPrimary),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 34,
                  height: 20,
                  padding: const EdgeInsets.all(2),
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: value ? p.primary : p.borderMedium,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: p.surface,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflinePanel extends StatelessWidget {
  const _OfflinePanel({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            controlArt('elio_disconnected', height: 84),
            const SizedBox(height: 6),
            Text(
              'Robot offline',
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Turn on the robot and join the ELIOS Wi-Fi.',
              style: TextStyle(color: p.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            PhonePill(
              key: const ValueKey('phone_connect'),
              semantic: 'Connect',
              green: true,
              onTap: onConnect,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.power_settings_new_rounded,
                    size: 16,
                    color: p.primaryText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connect',
                    style: TextStyle(
                      color: p.primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The loading skeleton (Figma 397:3314): flat raised blocks. STOP is never part of it.
class _SkeletonBlocks extends StatelessWidget {
  const _SkeletonBlocks();

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    Widget bar(double h, [double? w]) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar(14, 80),
        const SizedBox(height: 12),
        Expanded(child: bar(0)),
        const SizedBox(height: 12),
        bar(28),
      ],
    );
  }
}

enum GlowKind { powerOn, powerOff, stop, go }

/// Glow button (Figma 393:2479): power 44 dp, STOP and GO 76 dp.
class PhoneGlowButton extends StatelessWidget {
  const PhoneGlowButton({
    super.key,
    required this.kind,
    required this.size,
    required this.onTap,
  });
  final GlowKind kind;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final (fill, rim, ring, glow) = switch (kind) {
      GlowKind.stop => (
        p.error,
        p.destructiveActive,
        p.onError,
        ElioGlow.destructiveHover,
      ),
      GlowKind.go => (p.primary, p.primaryActive, Colors.white, ElioGlow.large),
      GlowKind.powerOn => (
        p.primary,
        p.primaryActive,
        Colors.white,
        ElioGlow.medium,
      ),
      GlowKind.powerOff => (
        p.surface,
        p.borderMedium,
        p.surface,
        const <BoxShadow>[],
      ),
    };
    final power = kind == GlowKind.powerOn || kind == GlowKind.powerOff;
    final label = switch (kind) {
      GlowKind.stop => 'Berhenti darurat',
      GlowKind.go => 'GO',
      _ => 'Power',
    };
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: rim, offset: Offset(0, size * 0.05)),
            ...glow,
          ],
        ),
        child: Material(
          color: fill,
          shape: CircleBorder(
            side: BorderSide(color: ring, width: power ? 3 : size * 0.07),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: power
                  ? Icon(
                      Icons.power_settings_new_rounded,
                      size: size * 0.45,
                      color: kind == GlowKind.powerOn
                          ? p.onPrimary
                          : p.textSecondary,
                    )
                  : FittedBox(
                      child: Padding(
                        padding: EdgeInsets.all(size * 0.16),
                        child: Text(
                          kind == GlowKind.stop ? 'STOP' : 'GO',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: kind == GlowKind.stop
                                ? p.onError
                                : p.onPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
