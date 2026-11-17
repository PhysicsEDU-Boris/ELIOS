// ELIOS 3 sound and haptics (Figma section 13, decision 0201): the one audio
// service for UI and robot feedback sounds S1-S10, and the haptic map.
// Profile → Sound effects mutes every sound, Master volume scales it, the
// phone's silent mode mutes it, at most one sound per 120 ms, never looped.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The palette. Assets are made by tools/sounds/make_sounds.py.
enum ElioSfx {
  tick('s1_leaf_tick'), // selection, tabs, segments, robot control presses
  pop('s2_seed_pop'), // button release, cards, menus
  toggleOn('s3_toggle_on'),
  toggleOff('s3_toggle_off'),
  chime('s4_bloom_chime'), // correct, step done
  knock('s5_soft_knock'), // wrong, locked, failed
  blip('s6_robot_blip'), // robot connected, Open control, Use ELIOS
  shutter('s7_shutter'),
  recStart('s8_rec_start'),
  recStop('s8_rec_stop'),
  sparkle('s9_trophy_sparkle'), // trophies, medal, level up
  sparkleShort('s9_short'), // clover, contribution approved
  air('s10_air'); // sheets; off by default

  const ElioSfx(this.file);
  final String file;
  String get asset => 'sounds/$file.wav';
}

class ElioSound {
  ElioSound._();
  static final instance = ElioSound._();

  /// Mirrors Profile → Sound effects and Master volume (kept current by
  /// AppPreferencesNotifier; applied immediately).
  bool enabled = true;
  double volume = 0.75;

  /// Quiz mute: silences [quizFeedback] cues only (app sounds stay on).
  bool quizMuted = false;

  /// S10 is off by default (Figma).
  bool airEnabled = false;

  static const minGap = Duration(milliseconds: 120);
  DateTime _last = DateTime(0);

  /// Test seams.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;
  @visibleForTesting
  Future<bool> Function() isSilent = _platformSilent;
  @visibleForTesting
  void Function(ElioSfx sfx, double volume)? sink;

  final _pools = <ElioSfx, Future<AudioPool>>{};
  bool _contextSet = false;

  /// Plays [sfx] at Master volume. False when muted, throttled or silent.
  Future<bool> play(ElioSfx sfx, {double gain = 1}) async {
    if (!enabled || volume <= 0) return _skip(sfx, 'off or volume 0');
    if (sfx == ElioSfx.air && !airEnabled) return false;
    final now = clock();
    final since = now.difference(_last);
    // A clock set back (time zone, manual change) must not mute sounds.
    if (!since.isNegative && since < minGap) return false;
    _last = now;
    if (await isSilent()) return _skip(sfx, 'phone on silent/vibrate');
    final v = (volume * gain).clamp(0.0, 1.0);
    final s = sink;
    if (s != null) {
      s(sfx, v);
      return true;
    }
    try {
      await _ensureContext();
      final pool = await (_pools[sfx] ??= AudioPool.createFromAsset(
        path: sfx.asset,
        maxPlayers: 2,
      ));
      await pool.start(volume: v);
      // Debug builds log each sound so phone checks can read it over adb.
      if (kDebugMode) debugPrint('[ElioSound] ${sfx.name} played');
      return true;
    } catch (e) {
      debugPrint('[ElioSound] ${sfx.name} failed: $e');
      return false;
    }
  }

  bool _skip(ElioSfx sfx, String why) {
    if (kDebugMode) debugPrint('[ElioSound] ${sfx.name} skipped: $why');
    return false;
  }

  /// UI sounds mix with music and the quiz voice instead of pausing them.
  Future<void> _ensureContext() async {
    if (_contextSet) return;
    _contextSet = true;
    await AudioPlayer.global.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
  }

  static const _channel = MethodChannel('elio/device_health');
  static DateTime _silentAt = DateTime(0);
  static bool _silent = false;

  /// Android ringer silent / vibrate (cached for a second). Other platforms
  /// cannot be asked, so they count as not silent.
  static Future<bool> _platformSilent() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    final now = DateTime.now();
    if (now.difference(_silentAt) < const Duration(seconds: 1)) return _silent;
    try {
      _silent = await _channel.invokeMethod<bool>('isSilent') ?? false;
    } catch (_) {
      _silent = false;
    }
    _silentAt = now;
    return _silent;
  }
}

/// The haptic map (H-select … H-celebrate). Only for user-caused events and
/// their results; never on scroll, load or background sync.
abstract final class ElioHaptics {
  static void select() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();

  /// Two short pulses (correct, connected, contribution approved).
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.mediumImpact();
  }

  /// 15 ms · 60 ms gap · 15 ms (locked, bin label not in view).
  static Future<void> warning() async {
    await HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
  }

  /// Wrong answer, failure.
  static void error() => HapticFeedback.heavyImpact();

  /// Success, then 3 ticks 80 ms apart (level up, medal, clover).
  static Future<void> celebrate() async {
    await success();
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.selectionClick();
    }
  }
}

/// Sound + haptic in one call, for the common pairs.
/// Runs [cue] once the route of [context] has finished entering (at once
/// when it has no transition): the entry sound lands with the page, not on
/// top of the tap that opened it. No timers.
void elioOnRouteEntered(BuildContext context, VoidCallback cue) {
  final a = ModalRoute.of(context)?.animation;
  if (a == null || a.isCompleted) return cue();
  void listener(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    a.removeStatusListener(listener);
    cue();
  }

  a.addStatusListener(listener);
}

/// A quiet entry cue: [sfx] at half gain with [haptic].
void elioEntryCue(ElioSfx sfx, void Function() haptic) {
  haptic();
  unawaited(ElioSound.instance.play(sfx, gain: 0.5));
}

/// [elioFeedback] for the quiz and explanation pages: the haptic always, the
/// sound unless the quiz is muted.
void quizFeedback(ElioSfx sfx, void Function() haptic) {
  haptic();
  if (!ElioSound.instance.quizMuted) unawaited(ElioSound.instance.play(sfx));
}

void elioFeedback(ElioSfx sfx, void Function() haptic) {
  haptic();
  unawaited(ElioSound.instance.play(sfx));
}
