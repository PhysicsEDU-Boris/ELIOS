import 'dart:math' as math;
import 'dart:ui';

import 'package:elio/services/robot/floor_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const img = Size(640, 360);
  final th = 15 * math.pi / 180;
  final n = [0.05, math.cos(th), math.sin(th)];
  final len = math.sqrt(n.fold(0.0, (s, v) => s + v * v));
  final truth = FloorCamera(normal: [for (final v in n) v / len], heightMm: 92);

  test('a floor tag seen by a tilted, rolled camera gives back its floor', () {
    // An 80 mm tag 25 cm ahead, 2 cm right, turned 30 degrees.
    const yaw = 30 * math.pi / 180;
    final corners = [
      for (final (x, y) in const [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)])
        truth.project(
          25 + 4 * (x * math.cos(yaw) - y * math.sin(yaw)),
          2 + 4 * (x * math.sin(yaw) + y * math.cos(yaw)),
          img,
        )!,
    ];
    // Either winding: the detector's corner order may run either way round.
    for (final order in [corners, corners.reversed.toList()]) {
      final got = FloorCamera.fromTag(order, 80, img)!;
      expect(got.heightMm, closeTo(92, 0.01));
      for (var i = 0; i < 3; i++) {
        expect(got.normal[i], closeTo(truth.normal[i], 1e-6));
      }
      expect(got.tiltDeg, closeTo(truth.tiltDeg, 1e-4));
    }
  });

  test('locate is the inverse of project', () {
    final px = truth.project(24, -3, img)!;
    final (d, l) = truth.locate(px, img)!;
    expect(d, closeTo(24, 1e-9));
    expect(l, closeTo(-3, 1e-9));
  });

  test('the level camera: floor lines below the centre row, nothing above the horizon', () {
    final at20 = FloorCamera.nominal.project(20, 0, img)!;
    expect(at20.dy, greaterThan(180));
    expect(FloorCamera.nominal.project(60, 0, img)!.dy, lessThan(at20.dy));
    expect(FloorCamera.nominal.locate(const Offset(320, 100), img), isNull);
    expect(FloorCamera.nominal.tiltDeg, 0);
    expect(FloorCamera.nominal.project(20, 5, img)!.dx, greaterThan(320)); // positive = right (0022)
  });

  test('bad corners and bad saved values are refused', () {
    expect(FloorCamera.fromTag(const [Offset(1, 1), Offset(1, 1), Offset(1, 1), Offset(1, 1)], 80, img), isNull);
    expect(FloorCamera.fromJson({'normal': [0, 1], 'height_mm': 86}), isNull);
    expect(FloorCamera.fromJson({'normal': [0, 1, 0], 'height_mm': -1}), isNull);
    final back = FloorCamera.fromJson(truth.toJson())!;
    expect(back.heightMm, 92);
  });
}
