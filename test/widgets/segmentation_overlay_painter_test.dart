import 'package:elio/services/websocket_service.dart';
import 'package:elio/widgets/segmentation_overlay_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// MaixCAM2 boxes are centre (x, y) + size. The camera panel shows the frame
// with BoxFit.cover, so a 640x480 frame in a 400x230 panel is scaled by
// max(400/640, 230/480) = 0.625 to 400x300 and cropped 35 px top and bottom.
Future<void> _pump(WidgetTester tester, List<Detection> detections) async {
  await tester.pumpWidget(Center(
    child: SizedBox(
      width: 400,
      height: 230,
      child: CustomPaint(
        painter: SegmentationOverlayPainter(detections: detections, imageSize: const Size(640, 480)),
      ),
    ),
  ));
}

void main() {
  testWidgets('a centre box maps through BoxFit.cover scaling', (tester) async {
    await _pump(tester, const [Detection(x: 320, y: 240, w: 100, h: 50, label: 'Plastic', score: 0.9)]);

    // Image rect 270..370 x 215..265 -> x * 0.625, y * 0.625 - 35.
    expect(find.byType(CustomPaint).last, paints..rect(rect: const Rect.fromLTRB(168.75, 99.375, 231.25, 130.625)));
  });

  testWidgets('a box at the frame edge keeps its centre (partly cropped by cover)', (tester) async {
    await _pump(tester, const [
      Detection(x: 320, y: 240, w: 100, h: 50, label: 'Plastic', score: 0.9),
      Detection(x: 40, y: 400, w: 80, h: 60, label: 'Paper', score: 0.8),
    ]);

    // Second box: image rect 0..80 x 370..430 -> 0..50 x 196.25..233.75; it
    // runs past the 230 px panel bottom, as the cropped video does.
    expect(
      find.byType(CustomPaint).last,
      paints
        ..rect(rect: const Rect.fromLTRB(168.75, 99.375, 231.25, 130.625))
        ..rect(rect: const Rect.fromLTRB(0, 196.25, 50, 233.75)),
    );
  });

  testWidgets('x, y are not read as the top-left corner', (tester) async {
    await _pump(tester, const [Detection(x: 320, y: 240, w: 100, h: 50, label: 'Plastic', score: 0.9)]);

    // The old top-left reading put the box at 200..262.5 x 115..146.25.
    expect(find.byType(CustomPaint).last, isNot(paints..rect(rect: const Rect.fromLTRB(200, 115, 262.5, 146.25))));
  });
}
