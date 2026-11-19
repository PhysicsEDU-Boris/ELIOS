import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:elio/services/detection_crop.dart';
import 'package:elio/services/detection_stabilizer.dart';
import 'package:elio/services/frame_source/frame_source.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/scan_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saved vision input matches submitted crop; timings and JSON share session',
    () async {
      final root = await Directory.systemTemp.createTemp('m2c-test-');
      final directory = Completer<Directory>();
      final diagnostics = ScanDiagnostics(directory: () => directory.future);
      final service = AiQuizService.instance;
      final source = img.Image(width: 80, height: 40);
      img.fillRect(
        source,
        x1: 40,
        y1: 0,
        x2: 79,
        y2: 39,
        color: img.ColorRgb8(255, 0, 0),
      );
      final frame = CapturedFrame(
        bytes: Uint8List.fromList(img.encodePng(source)),
        cleanBytes: Uint8List.fromList(img.encodePng(source)),
        frameId: 1,
        detectionFrameId: 1,
        width: 160,
        height: 80,
        timestamp: DateTime(2026),
      );
      final crop = prepareDetectionCrop((
        frame,
        const TrackedDetection(label: 'E_Waste', x: 140, y: 40, w: 80, h: 80),
      ));
      expect(crop.details, containsPair('decodedWidth', 80));
      expect(crop.details, containsPair('left', 50));
      expect(crop.details, containsPair('right', 80));
      expect(crop.details, containsPair('cropWidth', 30));
      expect(img.decodeJpg(crop.bytes!)!.getPixel(10, 10).r, greaterThan(240));
      Uint8List? supplied;
      service.mockSendExecute =
          (prompt, {imageBytes, isUser = false}) async {
            supplied = imageBytes;
            return '{"item":"ponsel","material":"elektronik","category":"B3"}';
          };
      try {
        // Disk can be slow without delaying identification or occupying the slot.
        final result = await service.identifyItem(
          crop.bytes!,
          diagnostics: diagnostics,
        );
        expect(result.item, 'ponsel');
        directory.complete(root);
        await diagnostics.flushed;
        final saved = await File(
          '${root.path}/m2c-diagnostics/${diagnostics.id}-identify.jpg',
        ).readAsBytes();
        expect(saved, orderedEquals(supplied!));
        expect(saved, orderedEquals(crop.bytes!));
        final events =
            (await File(
                  '${root.path}/m2c-diagnostics/${diagnostics.id}.jsonl',
                ).readAsLines())
                .map((line) => jsonDecode(line) as Map<String, dynamic>)
                .toList();
        expect(events.every((e) => e['sessionId'] == diagnostics.id), isTrue);
        expect(
          events.map((e) => e['event']),
          containsAllInOrder([
            'identify_request',
            'vision_submit',
            'identify_complete',
          ]),
        );
        final completed = events.last;
        expect(completed['rawJson'], contains('ponsel'));
        expect(completed['requestMs'], isA<int>());
      } finally {
        service.mockSendExecute = null;
        await service.cancel();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'diagnostic storage or encoding errors do not escape into scan flow',
    () async {
      final diagnostics = ScanDiagnostics(
        directory: () => Future.error(FileSystemException('unavailable')),
      );
      diagnostics.event('lock');
      diagnostics.image(Uint8List(0));
      diagnostics.event('invalid-box', {'x': double.nan});
      await expectLater(diagnostics.flushed, completes);
    },
  );
}
