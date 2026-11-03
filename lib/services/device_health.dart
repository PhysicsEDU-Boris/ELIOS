import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only platform helpers (MainActivity.kt) for the tester build.
class DeviceHealth {
  DeviceHealth._();
  static const _channel = MethodChannel('elio/device_health');

  static Future<void> shareText(String text) async {
    try {
      await _channel.invokeMethod<void>('shareText', text);
    } catch (e) {
      debugPrint('shareText failed: $e');
    }
  }
}
