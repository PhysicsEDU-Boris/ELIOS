import 'dart:async';

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only phone health (MainActivity.kt). Every call returns null off
/// Android or when the platform call fails, so callers treat "unknown" as fine.
class DeviceHealth {
  DeviceHealth._();
  static const _channel = MethodChannel('elio/device_health');
  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// PowerManager thermal status: 0 none, 1 light, 2 moderate, 3 severe, 4 critical, 5 emergency, 6 shutdown.
  static Future<int?> thermalStatus() async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<int>('thermalStatus');
    } catch (_) {
      return null;
    }
  }

  /// App PSS and device free RAM, in MB.
  static Future<({int pssMb, int availMb, int totalMb, bool low})?> memory() async {
    if (!_android) return null;
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('memory');
      if (m == null) return null;
      return (
        pssMb: (m['pssKb'] as int) ~/ 1024,
        availMb: (m['availKb'] as int) ~/ 1024,
        totalMb: (m['totalKb'] as int) ~/ 1024,
        low: m['lowMemory'] as bool,
      );
    } catch (_) {
      return null;
    }
  }

  /// ApplicationExitInfo reason code of the previous process, or null.
  static Future<int?> lastExitReason() async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<int>('lastExitReason');
    } catch (_) {
      return null;
    }
  }

  static Future<void> shareText(String text) async {
    try {
      await _channel.invokeMethod<void>('shareText', text);
    } catch (e) {
      debugPrint('shareText failed: $e');
    }
  }
}

/// ApplicationExitInfo codes that mean the system, not the user, ended the process.
const _systemKills = {2 /* SIGNALED */, 3 /* LOW_MEMORY */, 9 /* EXCESSIVE_RESOURCE_USAGE */, 14 /* FREEZER */};
const _nativeCrash = 5;

enum PreviousRun { clean, systemKilled, nativeCrash }

/// What a leftover "Gemma was active" marker means, given the previous exit
/// reason (null = unknown, e.g. Android < 11: the marker alone counts).
PreviousRun classifyPreviousRun({required bool markerLeft, required int? exitReason}) {
  if (!markerLeft) return PreviousRun.clean;
  if (exitReason == _nativeCrash) return PreviousRun.nativeCrash;
  if (exitReason == null || _systemKills.contains(exitReason)) return PreviousRun.systemKilled;
  return PreviousRun.clean; // the user swiped the app away (USER_REQUESTED) or it exited itself
}

/// Pauses Gemma while the phone is hot. Pauses at SEVERE, resumes at MODERATE
/// or below, so a status hovering at the line doesn't flap.
class ThermalGate {
  ThermalGate({Future<int?> Function()? read, this.onChange}) : _read = read ?? DeviceHealth.thermalStatus;

  static const pauseAt = 3;
  static const resumeAt = 2;
  static const names = ['NONE', 'LIGHT', 'MODERATE', 'SEVERE', 'CRITICAL', 'EMERGENCY', 'SHUTDOWN'];

  final Future<int?> Function() _read;
  final void Function(int status, bool paused)? onChange;

  bool paused = false;
  int? status;

  String get statusName => status == null ? '?' : names[status!.clamp(0, 6)];

  /// Reads the status and returns whether Gemma must stay paused.
  Future<bool> check() async {
    final s = await _read();
    if (s == null) return paused;
    final was = paused;
    if (s >= pauseAt) {
      paused = true;
    } else if (s <= resumeAt) {
      paused = false;
    }
    if (s != status || was != paused) onChange?.call(s, paused);
    status = s;
    return paused;
  }
}
