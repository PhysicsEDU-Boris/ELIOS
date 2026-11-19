/// Advanced settings (decision 0232): the robot tuning a teacher can change on the phone.
/// Saved per phone in SharedPreferences. The joystick values apply in the app at once; the arm
/// values travel to the MaixCAM2 as a CONFIG command, which the firmware does not apply yet.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'joystick_math.dart';

/// The five arm joints in the order the table shows them: base, Arm A, Arm B, pitch, yaw.
const armAxisCount = 5;

/// Most trim a servo takes; past this, move the horn one tooth (robotic_hand_sim TRIM_MAX).
const maxTrimDeg = 15.0;

@immutable
class RobotSettings {
  const RobotSettings({
    this.trims = const [0, 0, 0, 0, 0],
    this.inverted = const [false, false, false, false, false],
    this.gripClosedOffset = 0,
    this.gripInverted = false,
    this.deadzone = 0.08,
    this.quadraticShare = 0.7,
    this.turnGain = 0.6,
    this.slewUp = 2.0,
    this.slewDown = 6.0,
    this.minDriveOutput = 0,
    this.baseRate = 40,
    this.baseLimit = 90,
    this.flipTurn = false,
    this.flipBase = false,
    this.teacherPin,
  });

  final List<double> trims;
  final List<bool> inverted;
  final double gripClosedOffset;
  final bool gripInverted;
  final double deadzone, quadraticShare, turnGain, slewUp, slewDown, minDriveOutput;
  final double baseRate, baseLimit;
  final bool flipTurn, flipBase;

  /// Four digits; null until a teacher sets one.
  final String? teacherPin;

  JoystickConfig get joystick => JoystickConfig(
    deadzone: deadzone,
    quadraticShare: quadraticShare,
    turnGain: turnGain,
    slewUp: slewUp,
    slewDown: slewDown,
    minDriveOutput: minDriveOutput,
    armMaxRateDegPerSec: baseRate,
    armBaseMinDeg: -baseLimit,
    armBaseMaxDeg: baseLimit,
    driveTurnSign: flipTurn ? -1 : 1,
    armDirection: flipBase ? -1 : 1,
  );

  RobotSettings copyWith({
    List<double>? trims,
    List<bool>? inverted,
    double? gripClosedOffset,
    bool? gripInverted,
    double? deadzone,
    double? quadraticShare,
    double? turnGain,
    double? slewUp,
    double? slewDown,
    double? minDriveOutput,
    double? baseRate,
    double? baseLimit,
    bool? flipTurn,
    bool? flipBase,
    String? teacherPin,
  }) => RobotSettings(
    trims: trims ?? this.trims,
    inverted: inverted ?? this.inverted,
    gripClosedOffset: gripClosedOffset ?? this.gripClosedOffset,
    gripInverted: gripInverted ?? this.gripInverted,
    deadzone: deadzone ?? this.deadzone,
    quadraticShare: quadraticShare ?? this.quadraticShare,
    turnGain: turnGain ?? this.turnGain,
    slewUp: slewUp ?? this.slewUp,
    slewDown: slewDown ?? this.slewDown,
    minDriveOutput: minDriveOutput ?? this.minDriveOutput,
    baseRate: baseRate ?? this.baseRate,
    baseLimit: baseLimit ?? this.baseLimit,
    flipTurn: flipTurn ?? this.flipTurn,
    flipBase: flipBase ?? this.flipBase,
    teacherPin: teacherPin ?? this.teacherPin,
  );

  /// Everything but the PIN: what Copy settings shares and CONFIG sends.
  Map<String, Object?> toMap() => {
    'trims': trims,
    'inverted': inverted,
    'gripClosedOffset': gripClosedOffset,
    'gripInverted': gripInverted,
    'deadzone': deadzone,
    'quadraticShare': quadraticShare,
    'turnGain': turnGain,
    'slewUp': slewUp,
    'slewDown': slewDown,
    'minDriveOutput': minDriveOutput,
    'baseRate': baseRate,
    'baseLimit': baseLimit,
    'flipTurn': flipTurn,
    'flipBase': flipBase,
  };

  /// Unknown, missing or out-of-range values fall back to the default (pasted text is untrusted).
  factory RobotSettings.fromMap(Map<String, Object?> m, {String? pin}) {
    const d = RobotSettings();
    double n(String k, double fallback, double lo, double hi) {
      final v = m[k];
      return v is num && v.isFinite && v >= lo && v <= hi ? v.toDouble() : fallback;
    }

    bool b(String k, bool fallback) => m[k] is bool ? m[k] as bool : fallback;
    List<T> list<T>(String k, List<T> fallback, T? Function(Object?) read) {
      final v = m[k];
      if (v is! List || v.length != armAxisCount) return fallback;
      final out = [for (final e in v) read(e)];
      return out.contains(null) ? fallback : out.cast<T>();
    }

    return RobotSettings(
      trims: list<double>('trims', d.trims, (e) => e is num && e.abs() <= maxTrimDeg ? e.toDouble() : null),
      inverted: list<bool>('inverted', d.inverted, (e) => e is bool ? e : null),
      gripClosedOffset: n('gripClosedOffset', d.gripClosedOffset, -maxTrimDeg, maxTrimDeg),
      gripInverted: b('gripInverted', d.gripInverted),
      deadzone: n('deadzone', d.deadzone, 0, 0.3),
      quadraticShare: n('quadraticShare', d.quadraticShare, 0, 1),
      turnGain: n('turnGain', d.turnGain, 0.2, 1),
      slewUp: n('slewUp', d.slewUp, 0.5, 6),
      slewDown: n('slewDown', d.slewDown, 1, 12),
      minDriveOutput: n('minDriveOutput', d.minDriveOutput, 0, 0.5),
      baseRate: n('baseRate', d.baseRate, 5, 40),
      baseLimit: n('baseLimit', d.baseLimit, 30, 90),
      flipTurn: b('flipTurn', d.flipTurn),
      flipBase: b('flipBase', d.flipBase),
      teacherPin: pin,
    );
  }

  /// Gripper servo for the app's width 0..100: open 180, closed 75 plus the offset (0230).
  double gripServo(double width) {
    final closed = 75 + gripClosedOffset;
    return 180 - (180 - closed) * width.clamp(0, 100) / 100;
  }

  @override
  bool operator ==(Object other) =>
      other is RobotSettings && jsonEncode(toMap()) == jsonEncode(other.toMap()) && teacherPin == other.teacherPin;

  @override
  int get hashCode => Object.hash(jsonEncode(toMap()), teacherPin);
}

final robotSettingsProvider = NotifierProvider<RobotSettingsNotifier, RobotSettings>(RobotSettingsNotifier.new);

class RobotSettingsNotifier extends Notifier<RobotSettings> {
  static const _key = 'robot_settings_v1';
  bool _touched = false;

  @override
  RobotSettings build() {
    _load();
    return const RobotSettings();
  }

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || _touched) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      state = RobotSettings.fromMap(m, pin: m['pin'] is String ? m['pin'] as String : null);
    } catch (e) {
      debugPrint('RobotSettings load failed: $e');
    }
  }

  void save(RobotSettings s) {
    _touched = true;
    state = s;
    final raw = jsonEncode({...s.toMap(), 'pin': s.teacherPin});
    SharedPreferences.getInstance().then((p) => p.setString(_key, raw)).catchError((Object e) {
      debugPrint('RobotSettings save failed: $e');
      return false;
    });
  }
}
