import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/app_preferences_provider.dart';

/// Phone-test log (decision 0040): a plain text file the tester can share from
/// the settings screen. Every call is a no-op unless the app is a tester build.
class TesterLog with WidgetsBindingObserver {
  TesterLog._();
  static final instance = TesterLog._();

  static const _maxBytes = 1024 * 1024;

  File? _file;
  final _recent = <String>[];

  @visibleForTesting
  bool enabled = testerBuild;

  String? get path => _file?.path;

  /// Opens the log in the app's external files dir (reachable with `adb pull`).
  Future<void> init({Directory? dir}) async {
    if (!enabled) return;
    try {
      dir ??= await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/elio_tester.log');
      if (file.existsSync() && file.lengthSync() > _maxBytes) file.renameSync('${file.path}.old');
      _file = file;
      WidgetsBinding.instance.addObserver(this);
      log('session', 'start ${DateTime.now().toIso8601String()}');
    } catch (e) {
      debugPrint('TesterLog init failed: $e');
    }
  }

  void log(String tag, String msg) {
    if (!enabled) return;
    final line = '${DateTime.now().toIso8601String()} [$tag] $msg';
    _recent.add(line);
    if (_recent.length > 300) _recent.removeAt(0);
    debugPrint(line);
    try {
      _file?.writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {
      // Logging must never break the app.
    }
  }

  String read() {
    try {
      return _file?.readAsStringSync() ?? _recent.join('\n');
    } catch (_) {
      return _recent.join('\n');
    }
  }

  void clear() {
    _recent.clear();
    try {
      _file?.writeAsStringSync('');
    } catch (_) {}
  }

  @override
  void didHaveMemoryPressure() => log('mem', 'system memory pressure warning');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => log('app', 'lifecycle ${state.name}');
}
