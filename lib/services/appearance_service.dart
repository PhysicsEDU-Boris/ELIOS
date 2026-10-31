import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tells Android about the in-app dark mode so the next cold start's launch
/// screen and the launcher icon match it (decision 0160). No-op elsewhere.
abstract final class AppearanceService {
  static const _channel = MethodChannel('elio/appearance');

  static Future<void> setDark(bool dark) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setDark', dark);
    } catch (e) {
      debugPrint('AppearanceService.setDark failed: $e');
    }
  }
}
