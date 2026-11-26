/// Advanced settings (decision 0232, Figma "R3 / Light / Advanced settings — 1..6"): the teacher's
/// robot tuning page, opened from "Advanced" beside Guide on the phone Control screen. Like
/// robotic_hand_sim's Joints tab (0241): no PIN, no Save; every change is stored and sent to the
/// robot as it is made (at most 10 CONFIG a second while a slider is dragged).
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../services/robot/arm_pose.dart' show armAxes;
import '../services/robot/arm_profile.dart';
import '../services/robot/fader_throttle.dart';
import '../services/robot/motion_gate.dart' show heartbeatInterval, stopRepeatInterval, stopRepeats;
import '../services/robot/r1_constants.dart' show armTimeout, nudgeMaxPwm, waitCap;
import '../services/robot/robot_settings.dart';
import '../widgets/learn/learn_ui.dart' show LearnTheme;
import '../widgets/history_ui.dart' show HistoryTone, historyTint;
import '../widgets/learn/learn_l3.dart' show LearnSquiggle;

class AdvancedSettingsScreen extends ConsumerStatefulWidget {
  const AdvancedSettingsScreen({super.key, required this.linkUp, required this.address, required this.onSend});

  final bool linkUp;
  final String address;

  /// Sends the CONFIG command; false when nothing could be sent (no link, STOPPED).
  final bool Function(Map<String, Object?> config) onSend;

  @override
  ConsumerState<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

/// Home, range and speed per joint, from robotic_hand_sim 75ab797 (decision 0230). Read only.
const _axes = [
  ('Stepper NEMA17 · TMC2208', '90°', '−90…270°', '40°/s'),
  ('Servo PCA 1 + 2', '90°', '40…140°', '30°/s'),
  ('Servo PCA 3', '180°', '0…180°', '30°/s'),
  ('Servo PCA 8', '0°', '0…180°', '45°/s'),
  ('Servo PCA 11', '90°', '0…180°', '45°/s'),
];

class _AdvancedSettingsScreenState extends ConsumerState<AdvancedSettingsScreen> {
  late RobotSettings _draft = ref.read(robotSettingsProvider);
  int _section = 0;

  RobotSettings get _saved => ref.read(robotSettingsProvider);
  final _live = FaderThrottle();
  late final RobotSettingsNotifier _store;
  late RobotSettings _applied;
  bool _toldNotSent = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(robotSettingsProvider.notifier); // dispose may still store the last step (no ref there)
    _applied = _draft;
  }

  /// Every change applies at once (0241, the sim's Joints tab): stored on the phone and sent as CONFIG.
  void _edit(RobotSettings Function(RobotSettings) f) {
    setState(() => _draft = f(_draft));
    _live(_apply);
  }

  void _apply() {
    if (_draft == _applied) return;
    _applied = _draft;
    _store.save(_draft);
    // No link or STOPPED: the gate sends it on the next connection or GO; say so once per visit.
    if (!widget.onSend(_draft.toMap()) && !_toldNotSent && mounted) {
      _toldNotSent = true;
      _toast(l10n.advSavedLocal);
    }
  }

  @override
  void dispose() {
    _live.cancel();
    final last = _draft, send = widget.onSend; // the last drag step still waiting in the throttle
    if (last != _applied) {
      Future.microtask(() {
        _store.save(last);
        send(last.toMap());
      });
    }
    super.dispose();
  }

  void _toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<bool> _confirm(String title, String body, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.advKeepEditing)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          // Curved green header (L2 v3): one wide ellipse and two light bubbles.
          Positioned(
            left: -300,
            top: -336,
            child: ClipOval(child: Container(width: 1500, height: 420, color: p.primary)),
          ),
          Positioned(right: -60, top: -110, child: _Circle(size: 170, color: p.primaryHover)),
          Positioned(left: -14, top: 40, child: _Circle(size: 44, color: p.primaryHover)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                children: [
                  _topBar(context),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 176, child: _rail(context)),
                        const SizedBox(width: 8),
                        Expanded(child: _card(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final p = context.elio;
    final onGreen = p.onPrimary;
    return Row(
      children: [
        _RoundButton(
          key: const ValueKey('adv_back'),
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.advTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: onGreen, fontSize: 19, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Spacer(),
        _StatusStrip(linkUp: widget.linkUp, address: widget.address),
      ],
    );
  }

  static const _icons = [
    Icons.precision_manufacturing_outlined,
    Icons.back_hand_outlined,
    Icons.sports_esports_outlined,
    Icons.wifi_rounded,
    Icons.shield_outlined,
    Icons.inventory_2_outlined,
    Icons.speed_rounded,
  ];
  static const _tones = [
    HistoryTone.success,
    HistoryTone.warning,
    HistoryTone.info,
    HistoryTone.info,
    HistoryTone.error,
    HistoryTone.success,
    HistoryTone.info,
  ];

  List<String> get _titles => [
    l10n.advSecAxes,
    l10n.advSecGripper,
    l10n.advSecDrive,
    l10n.advSecLink,
    l10n.advSecSafety,
    l10n.advSecBackup,
    l10n.advSecSpeed,
  ];

  /// Rail order. Section ids (and their adv_tab_ keys) stay put; Speed & ramps (6, 0240) sits under the axes.
  static const _order = [0, 6, 1, 2, 3, 4, 5];

  Widget _rail(BuildContext context) {
    final p = context.elio;
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        for (final i in _order)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _RailItem(
              key: ValueKey('adv_tab_$i'),
              icon: _icons[i],
              label: _titles[i],
              bubble: i == _section ? p.primary : historyTint(p, _tones[i]).bg,
              selected: i == _section,
              onTap: () => setState(() => _section = i),
            ),
          ),
      ],
    );
  }

  Widget _card(BuildContext context) {
    final p = context.elio;
    final (sub, action) = switch (_section) {
      0 => (l10n.advAxesSub, null),
      1 => (l10n.advGripSub, null),
      2 => (l10n.advDriveSub, null),
      3 => (l10n.advLinkSub, null),
      4 => (l10n.advSafetySub, _Chip(label: l10n.advReadOnly)),
      6 => (
        l10n.advSpeedSub,
        TextButton.icon(
          key: const ValueKey('adv_speed_reset'),
          onPressed: () => _edit((s) => s.copyWith(profile: defaultArmProfile)),
          icon: const Icon(Icons.restart_alt_rounded, size: 16),
          label: Text(l10n.advSpeedReset),
        ),
      ),
      _ => (l10n.advBackupSub, null),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(30),
          bottomLeft: Radius.circular(10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? .3 : .08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titles[_section],
                      style: TextStyle(color: p.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    const LearnSquiggle(width: 90),
                    const SizedBox(height: 4),
                    Text(
                      sub,
                      style: TextStyle(color: p.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey('adv_body_$_section'),
              child: switch (_section) {
                0 => _axesBody(context),
                1 => _gripperBody(context),
                2 => _driveBody(context),
                3 => _linkBody(context),
                4 => _safetyBody(context),
                6 => _speedBody(context),
                _ => _backupBody(context),
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _axesBody(BuildContext context) {
    final p = context.elio;
    final names = [l10n.advAxisBase, l10n.advAxisArmA, l10n.advAxisArmB, l10n.advAxisPitch, l10n.advAxisYaw];
    TextStyle cap = TextStyle(color: p.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1);
    Widget cell(double w, Widget c) => SizedBox(width: w, child: c);
    return Column(
      children: [
        Row(
          children: [
            cell(132, Text(l10n.advColAxis, style: cap)),
            Expanded(child: Text(l10n.advColTrim, style: cap)),
            cell(52, Text(l10n.advColInv, style: cap)),
            cell(44, Text(l10n.advColHome, style: cap)),
            cell(70, Text(l10n.advColRange, style: cap)),
            cell(44, Text(l10n.advColSpeed, style: cap)),
          ],
        ),
        for (var i = 0; i < armAxisCount; i++)
          Container(
            key: ValueKey('adv_axis_$i'),
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.borderSubtle)),
            ),
            child: Row(
              children: [
                cell(
                  132,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        names[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _axes[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.textTertiary, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _Stepper(
                    key: ValueKey('adv_trim_$i'),
                    value: _draft.trims[i],
                    min: -maxTrimDeg,
                    max: maxTrimDeg,
                    step: 0.5,
                    label: '${_draft.trims[i] > 0 ? '+' : ''}${_draft.trims[i].toStringAsFixed(1)}°',
                    onChanged: (v) => _edit((s) => s.copyWith(trims: [...s.trims]..[i] = v)),
                  ),
                ),
                cell(
                  52,
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        key: ValueKey('adv_inv_$i'),
                        value: _draft.inverted[i],
                        onChanged: (v) => _edit((s) => s.copyWith(inverted: [...s.inverted]..[i] = v)),
                      ),
                    ),
                  ),
                ),
                for (final (w, t) in [(44.0, _axes[i].$2), (70.0, _axes[i].$3), (44.0, _axes[i].$4)])
                  cell(
                    w,
                    Text(
                      t,
                      style: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        _Ticket(tone: HistoryTone.warning, title: l10n.advTips, text: l10n.advAxesTip),
      ],
    );
  }

  /// Speed & ramps (0240): robotic_hand_sim's per-joint "max" and Detail (accel / decel), Base first.
  Widget _speedBody(BuildContext context) {
    final p = context.elio;
    final names = {
      'Arm Base': l10n.advAxisBase,
      'Arm A': l10n.advAxisArmA,
      'Arm B': l10n.advAxisArmB,
      'Wrist Pitch': l10n.advAxisPitch,
      'Wrist Yaw': l10n.advAxisYaw,
      'Gripper': l10n.advSecGripper,
    };
    TextStyle cap = TextStyle(color: p.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1);
    TextStyle small = TextStyle(color: p.textSecondary, fontSize: 11, fontWeight: FontWeight.w600);
    String pct(double v) => '${(v * 100).round()} %';

    // One ramp changed: the other gives way so they never overlap (the sim's _edit_profile).
    void set(int i, {double? vmax, double? accel, double? decel}) => _edit((s) {
      final g = s.profile[armAxes[i].name]!;
      final a = accel ?? (decel != null ? math.min(g.accel, 1 - decel) : g.accel);
      final d = decel ?? (accel != null ? math.min(g.decel, 1 - accel) : g.decel);
      return s.copyWith(profile: {...s.profile, armAxes[i].name: cleanAxis(i, vmax ?? g.vmax, a, d)});
    });

    Widget ramp(int i, String id, String label, double v, void Function(double) on) => Expanded(
      child: Row(
        children: [
          SizedBox(width: 78, child: Text(label, style: small)),
          Expanded(
            child: _Stepper(
              key: ValueKey('adv_${id}_$i'),
              value: (v * 100).roundToDouble().clamp(5, 95).toDouble(),
              min: 5,
              max: 95,
              step: 1,
              label: pct(v),
              onChanged: (x) => on(x / 100),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 132, child: Text(l10n.advColAxis, style: cap)),
            Expanded(child: Text(l10n.advColTopSpeed, style: cap)),
            const SizedBox(width: 96),
          ],
        ),
        for (final i in [5, 4, 3, 2, 1, 0])
          Builder(
            builder: (context) {
              final g = _draft.profile[armAxes[i].name]!;
              final seconds = (30 * peakOverMean(g.accel, g.decel) / g.vmax).toStringAsFixed(1);
              return Container(
                key: ValueKey('adv_speed_$i'),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.borderSubtle)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 132,
                                child: Text(
                                  names[armAxes[i].name]!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Expanded(
                                child: _Stepper(
                                  key: ValueKey('adv_vmax_$i'),
                                  value: g.vmax,
                                  min: 1,
                                  max: vmaxCap(i),
                                  step: 1,
                                  label: '${g.vmax.toStringAsFixed(g.vmax % 1 == 0 ? 0 : 1)}°/s',
                                  onChanged: (v) => set(i, vmax: v),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              ramp(i, 'accel', l10n.advSpeedUp, g.accel, (v) => set(i, accel: v)),
                              const SizedBox(width: 12),
                              ramp(i, 'decel', l10n.advSlowDown, g.decel, (v) => set(i, decel: v)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 84,
                      child: Column(
                        children: [
                          CustomPaint(
                            size: const Size(84, 30),
                            painter: _RampGraph(g.accel, g.decel, p.primary, p.borderMedium),
                          ),
                          const SizedBox(height: 2),
                          Text(l10n.advSpeedMove(seconds), style: TextStyle(color: p.textTertiary, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        _Ticket(tone: HistoryTone.info, title: l10n.advTips, text: l10n.advSpeedTip),
      ],
    );
  }

  Widget _gripperBody(BuildContext context) {
    final p = context.elio;
    Widget map(String l, double width) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l,
              style: TextStyle(color: p.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${_draft.gripServo(width).round()}°',
            style: TextStyle(color: p.primaryText, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return _Columns([
      [
        _SliderSetting(
          key: const ValueKey('adv_grip_offset'),
          label: l10n.advGripOffset,
          hint: l10n.advGripOffsetHint,
          value: _draft.gripClosedOffset,
          min: -maxTrimDeg,
          max: maxTrimDeg,
          step: 0.5,
          format: (v) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)}°',
          onChanged: (v) => _edit((s) => s.copyWith(gripClosedOffset: v)),
        ),
        _ToggleSetting(
          key: const ValueKey('adv_grip_inv'),
          label: l10n.advGripInv,
          hint: l10n.advGripInvHint,
          value: _draft.gripInverted,
          onChanged: (v) => _edit((s) => s.copyWith(gripInverted: v)),
        ),
      ],
      [
        _Caps(l10n.advGripMap),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: p.surfaceRaised, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [map(l10n.advGripOpen, 0), map('50 %', 50), map(l10n.advGripClosed, 100)]),
        ),
        _Ticket(tone: HistoryTone.warning, title: l10n.advTips, text: l10n.advGripTip),
      ],
    ]);
  }

  Widget _driveBody(BuildContext context) {
    _SliderSetting s(
      String key,
      String label,
      String hint,
      double v,
      double min,
      double max,
      double step,
      String Function(double) f,
      RobotSettings Function(double) set,
    ) => _SliderSetting(
      key: ValueKey('adv_$key'),
      label: label,
      hint: hint,
      value: v,
      min: min,
      max: max,
      step: step,
      format: f,
      onChanged: (x) => _edit((_) => set(x)),
    );
    String f2(double v) => v.toStringAsFixed(2);
    String ps(double v) => '${v.toStringAsFixed(1)} /s';
    return _Columns([
      [
        _Caps(l10n.advCapResponse),
        s(
          'deadzone',
          l10n.advDeadzone,
          l10n.advDeadzoneHint,
          _draft.deadzone,
          0,
          0.3,
          0.01,
          f2,
          (x) => _draft.copyWith(deadzone: x),
        ),
        s(
          'curve',
          l10n.advCurve,
          l10n.advCurveHint,
          _draft.quadraticShare,
          0,
          1,
          0.05,
          f2,
          (x) => _draft.copyWith(quadraticShare: x),
        ),
        s(
          'turn',
          l10n.advTurnGain,
          l10n.advTurnGainHint,
          _draft.turnGain,
          0.2,
          1,
          0.05,
          f2,
          (x) => _draft.copyWith(turnGain: x),
        ),
      ],
      [
        _Caps(l10n.advCapSmooth),
        s(
          'slew_up',
          l10n.advSlewUp,
          l10n.advSlewUpHint,
          _draft.slewUp,
          0.5,
          6,
          0.5,
          ps,
          (x) => _draft.copyWith(slewUp: x),
        ),
        s(
          'slew_down',
          l10n.advSlewDown,
          l10n.advSlewDownHint,
          _draft.slewDown,
          1,
          12,
          0.5,
          ps,
          (x) => _draft.copyWith(slewDown: x),
        ),
        s(
          'p0',
          l10n.advMinOutput,
          l10n.advMinOutputHint,
          _draft.minDriveOutput,
          0,
          0.5,
          0.01,
          f2,
          (x) => _draft.copyWith(minDriveOutput: x),
        ),
      ],
      [
        _Caps(l10n.advCapBase),
        s(
          'base_rate',
          l10n.advBaseRate,
          l10n.advBaseRateHint,
          _draft.baseRate,
          5,
          40,
          5,
          (v) => '${v.round()}°/s',
          (x) => _draft.copyWith(baseRate: x),
        ),
        s(
          'base_limit',
          l10n.advBaseLimit,
          l10n.advBaseLimitHint,
          _draft.baseLimit,
          30,
          90,
          5,
          (v) => '±${v.round()}°',
          (x) => _draft.copyWith(baseLimit: x),
        ),
        _ToggleSetting(
          key: const ValueKey('adv_flip_turn'),
          label: l10n.advFlipTurn,
          hint: l10n.advFlipTurnHint,
          value: _draft.flipTurn,
          onChanged: (v) => _edit((s) => s.copyWith(flipTurn: v)),
        ),
        _ToggleSetting(
          key: const ValueKey('adv_flip_base'),
          label: l10n.advFlipBase,
          hint: l10n.advFlipBaseHint,
          value: _draft.flipBase,
          onChanged: (v) => _edit((s) => s.copyWith(flipBase: v)),
        ),
      ],
    ]);
  }

  Widget _linkBody(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _InfoRow(l10n.advAddress, widget.address),
      _InfoRow(l10n.advLinkStatus, widget.linkUp ? l10n.advConnected : l10n.advOffline),
      const SizedBox(height: 6),
      _Ticket(tone: HistoryTone.info, title: l10n.advTips, text: l10n.advLinkTip),
    ],
  );

  Widget _safetyBody(BuildContext context) => _Columns([
    [
      _InfoRow(l10n.advArmTimeout, '${armTimeout.inSeconds} s'),
      _InfoRow(l10n.advSortCap, '${waitCap.inSeconds} s'),
      _InfoRow(l10n.advHeartbeat, '${heartbeatInterval.inMilliseconds} ms'),
    ],
    [
      _InfoRow(l10n.advNudge, '$nudgeMaxPwm PWM'),
      _InfoRow(l10n.advStopRepeat, '$stopRepeats× · ${stopRepeatInterval.inMilliseconds} ms'),
      _InfoRow(l10n.advHandPause, '✓'),
    ],
    [_Ticket(tone: HistoryTone.error, title: l10n.advImportant, text: l10n.advSafetyTip)],
  ], lastFull: true);

  Widget _backupBody(BuildContext context) {
    final p = context.elio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(
              key: const ValueKey('adv_export'),
              icon: Icons.copy_rounded,
              label: l10n.advExport,
              fill: p.surface,
              fg: p.textPrimary,
              border: p.borderMedium,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: jsonEncode(_draft.toMap())));
                _toast(l10n.advCopied);
              },
            ),
            _Pill(
              key: const ValueKey('adv_import'),
              icon: Icons.paste_rounded,
              label: l10n.advImport,
              fill: p.surface,
              fg: p.textPrimary,
              border: p.borderMedium,
              onTap: () async {
                final raw = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
                try {
                  final m = jsonDecode(raw ?? '') as Map<String, dynamic>;
                  _edit((_) => RobotSettings.fromMap(m, pin: _saved.teacherPin));
                  _toast(l10n.advImported);
                } catch (_) {
                  _toast(l10n.advImportFailed);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Ticket(
          tone: HistoryTone.error,
          title: l10n.advDanger,
          text: l10n.advResetBody,
          trailing: _Pill(
            key: const ValueKey('adv_reset'),
            label: l10n.advReset,
            fill: p.error,
            fg: p.onError,
            onTap: () async {
              if (await _confirm(l10n.advResetConfirm, l10n.advResetBody, l10n.advReset)) {
                _edit((_) => RobotSettings(teacherPin: _saved.teacherPin));
              }
            },
          ),
        ),
      ],
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

/// Side-by-side columns on a wide card, stacked when narrow. [lastFull]: the last group spans.
class _Columns extends StatelessWidget {
  const _Columns(this.groups, {this.lastFull = false});
  final List<List<Widget>> groups;
  final bool lastFull;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      Widget col(List<Widget> g) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final w in g) Padding(padding: const EdgeInsets.only(bottom: 8), child: w)],
      );
      final row = lastFull ? groups.sublist(0, groups.length - 1) : groups;
      final wide = c.maxWidth / row.length >= 170;
      final top = wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: col(row[i])),
                ],
              ],
            )
          : col([for (final g in row) ...g]);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [top, if (lastFull) col(groups.last)]);
    },
  );
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Material(
      color: p.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: p.textPrimary),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.onTap,
    required this.fill,
    required this.fg,
    this.icon,
    this.border,
  });
  final String label;
  final VoidCallback onTap;
  final Color fill, fg;
  final Color? border;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
    color: fill,
    elevation: 0,
    shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border!, width: 1.5)),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: p.surfaceRaised, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 12, color: p.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: p.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Connected dot + MaixCAM2 address, one white capsule on the green (Figma Settings/Status strip).
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.linkUp, required this.address});
  final bool linkUp;
  final String address;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final tone = historyTint(p, linkUp ? HistoryTone.success : HistoryTone.neutral);
    return Container(
      key: const ValueKey('adv_status'),
      padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: linkUp ? p.primary : p.textTertiary,
                    boxShadow: linkUp ? [BoxShadow(color: p.primary.withValues(alpha: .4), spreadRadius: 3)] : null,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  linkUp ? l10n.advConnected : l10n.advOffline,
                  style: TextStyle(
                    color: linkUp ? p.primaryText : p.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.wifi_rounded, size: 16, color: p.textSecondary),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.advAddress.toUpperCase(),
                style: TextStyle(color: p.textTertiary, fontSize: 9, fontWeight: FontWeight.w700),
              ),
              Text(
                address,
                style: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A rail section: tinted icon bubble and label; the selected one is a white leaf pill.
class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.icon,
    required this.label,
    required this.bubble,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color bubble;
  final bool selected;
  final VoidCallback onTap;

  static const _leaf = BorderRadius.only(
    topLeft: Radius.circular(22),
    bottomRight: Radius.circular(22),
    topRight: Radius.circular(8),
    bottomLeft: Radius.circular(8),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.surface : Colors.transparent,
        borderRadius: _leaf,
        elevation: selected ? 2 : 0,
        shadowColor: Colors.black26,
        child: InkWell(
          borderRadius: _leaf,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 7, 10, 7),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: bubble, shape: BoxShape.circle),
                  child: Icon(icon, size: 18, color: selected ? p.onPrimary : p.textPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? p.textPrimary : p.textSecondary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

class _Caps extends StatelessWidget {
  const _Caps(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(color: context.elio.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

double _snap(double v, double min, double max, double step) =>
    (((v - min) / step).round() * step + min).clamp(min, max).toDouble();

/// − slider + with the value at the end (axis table rows).
class _Stepper extends StatelessWidget {
  const _Stepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.label,
    required this.onChanged,
  });
  final double value, min, max, step;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Row(
      children: [
        _Jog(icon: Icons.remove_rounded, onTap: () => onChanged(_snap(value - step, min, max, step))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 6, overlayShape: SliderComponentShape.noOverlay),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              activeColor: p.primary,
              inactiveColor: p.borderMedium,
              onChanged: (v) => onChanged(_snap(v, min, max, step)),
            ),
          ),
        ),
        _Jog(icon: Icons.add_rounded, onTap: () => onChanged(_snap(value + step, min, max, step))),
        SizedBox(
          width: 48,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: value == 0 ? p.textSecondary : p.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Jog extends StatelessWidget {
  const _Jog({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.surface,
          border: Border.all(color: p.borderMedium, width: 1.5),
        ),
        child: Icon(icon, size: 16, color: p.textPrimary),
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.format,
    required this.onChanged,
  });
  final String label, hint;
  final double value, min, max, step;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              format(value),
              style: TextStyle(color: p.primaryText, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        _Stepper(value: value, min: min, max: max, step: step, label: '', onChanged: onChanged),
        Text(hint, style: TextStyle(color: p.textTertiary, fontSize: 10)),
      ],
    );
  }
}

class _ToggleSetting extends StatelessWidget {
  const _ToggleSetting({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });
  final String label, hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(hint, style: TextStyle(color: p.textTertiary, fontSize: 10)),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: p.field,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.formBorder.withValues(alpha: .5)),
            ),
            child: Text(
              value,
              style: TextStyle(color: p.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// A ticket note (L2 v3): tinted, side notches, icon bubble, dashed tear line, caps title.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.tone, required this.title, required this.text, this.trailing});
  final HistoryTone tone;
  final String title, text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final t = historyTint(p, tone);
    final icon = switch (tone) {
      HistoryTone.error => Icons.warning_amber_rounded,
      HistoryTone.info => Icons.info_outline_rounded,
      _ => Icons.lightbulb_outline_rounded,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            color: Color.alphaBlend(t.bg, p.surface),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
                  child: Icon(icon, size: 17, color: t.fg),
                ),
                const SizedBox(width: 10),
                CustomPaint(size: const Size(2, 30), painter: _Dashes(t.fg.withValues(alpha: .45))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(color: t.fg, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
                      Text(
                        text,
                        style: TextStyle(color: p.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
          ),
          for (final left in [true, false])
            Positioned(
              left: left ? -7 : null,
              right: left ? null : -7,
              top: 0,
              bottom: 0,
              child: Center(child: _Circle(size: 14, color: p.surface)),
            ),
        ],
      ),
    );
  }
}

/// Speed over time of one joint's move (0240, the sim's ProfilePlot): up, cruise, down.
class _RampGraph extends CustomPainter {
  const _RampGraph(this.accel, this.decel, this.color, this.base);
  final double accel, decel;
  final Color color, base;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = Path()
      ..moveTo(0, h)
      ..lineTo(accel * w, 2)
      ..lineTo((1 - decel) * w, 2)
      ..lineTo(w, h);
    canvas.drawPath(Path.from(line)..close(), Paint()..color = color.withValues(alpha: .15));
    canvas.drawLine(
      Offset(0, h),
      Offset(w, h),
      Paint()
        ..color = base
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_RampGraph old) => old.accel != accel || old.decel != decel || old.color != color;
}

class _Dashes extends CustomPainter {
  _Dashes(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (double y = 0; y < s.height; y += 6) {
      canvas.drawLine(Offset(s.width / 2, y), Offset(s.width / 2, math.min(y + 3, s.height)), paint);
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.color != color;
}
