import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Local debug artifacts only; writes never hold the model slot or UI open.
class ScanDiagnostics {
  ScanDiagnostics({Future<Directory> Function()? directory})
    : id = 'scan-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      _directory = directory ?? getApplicationSupportDirectory;

  static int _sequence = 0;
  final String id;
  final Future<Directory> Function() _directory;
  final Stopwatch clock = Stopwatch()..start();
  Future<void> _writes = Future.value();

  Future<void> get flushed => _writes;

  void event(String event, [Map<String, Object?> data = const {}]) {
    if (!kDebugMode) return;
    String line;
    try {
      line = jsonEncode({
        'sessionId': id,
        'event': event,
        'at': DateTime.now().toUtc().toIso8601String(),
        'lockElapsedMs': clock.elapsedMilliseconds,
        ...data,
      });
    } catch (error) {
      debugPrint('[M2c] $id $event diagnostic encoding failed: $error');
      return;
    }
    debugPrint('[M2c] $line');
    _write(
      (dir) => File(
        '${dir.path}/$id.jsonl',
      ).writeAsString('$line\n', mode: FileMode.append),
    );
  }

  void image(Uint8List bytes) {
    if (!kDebugMode) return;
    _write((dir) async {
      final file = File('${dir.path}/$id-identify.jpg');
      await file.writeAsBytes(bytes);
      debugPrint('[M2c] $id exact vision input: ${file.path}');
    });
  }

  void _write(Future<void> Function(Directory) write) {
    _writes = _writes
        .then((_) async {
          final root = await _directory();
          final dir = await Directory(
            '${root.path}/m2c-diagnostics',
          ).create(recursive: true);
          await write(dir);
        })
        .catchError((Object error) {
          debugPrint('[M2c] $id diagnostic write failed: $error');
        });
  }
}
