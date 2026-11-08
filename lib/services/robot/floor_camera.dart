import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// Floor AprilTag for the floor calibration (decision 0192): tag36h11 id 2, black-square edge in mm.
const floorTagId = 2;
const floorTagMm = 80.0;

// MaixCAM2 intrinsics from the 0183 ChArUco solve at 640x360
// (docs/test-results/0183/maixcam2_intrinsics_640x360.json; distortion is negligible).
const _fx = 374.23, _cx = 303.88, _cy = 183.0, _w0 = 640.0, _h0 = 360.0;

/// Where the floor is, seen from the MaixCAM2 lens (decision 0192). Camera frame in mm: x right,
/// y down, z along the optical axis. The floor is the plane `normal · X = heightMm`.
/// `dist_cm` / `lateral_cm` (0022) are measured from the floor point below the lens, along the
/// optical axis projected on the floor, and sideways (positive = right in the image).
class FloorCamera {
  const FloorCamera({required this.normal, required this.heightMm});

  /// Unit vector from the lens towards the floor.
  final List<double> normal;
  final double heightMm;

  /// Decision 0022's level camera, 86.2 mm up. Only for drawing before a calibration.
  static const nominal = FloorCamera(normal: [0, 1, 0], heightMm: 86.2);

  /// How far the optical axis points down, in degrees.
  double get tiltDeg => math.asin(normal[2].clamp(-1.0, 1.0)) * 180 / math.pi;

  List<double> get _foot => _scale(normal, heightMm);
  List<double> get _forward => _unit(_sub(const [0, 0, 1], _scale(normal, normal[2])));
  List<double> get _lateral => _cross(normal, _forward);

  /// The floor point under image pixel [px] as (distCm, lateralCm); null above the horizon.
  (double, double)? locate(Offset px, Size image) {
    final k = _k(image);
    final ray = [(px.dx - k.cx) / k.f, (px.dy - k.cy) / k.f, 1.0];
    final den = _dot(normal, ray);
    if (den <= 1e-6) return null;
    final p = _sub(_scale(ray, heightMm / den), _foot);
    return (_dot(p, _forward) / 10, _dot(p, _lateral) / 10);
  }

  /// The image pixel of the floor point [distCm] ahead and [lateralCm] right; null behind the lens.
  Offset? project(double distCm, double lateralCm, Size image) {
    final p = _add(_foot, _add(_scale(_forward, distCm * 10), _scale(_lateral, lateralCm * 10)));
    if (p[2] <= 1) return null;
    final k = _k(image);
    return Offset(k.cx + k.f * p[0] / p[2], k.cy + k.f * p[1] / p[2]);
  }

  /// The floor from one flat floor tag: its 4 image corners in order around the tag, and its
  /// black-square edge. Null when the corners don't give a sane floor (a bad detection).
  static FloorCamera? fromTag(List<Offset> corners, double sideMm, Size image) {
    if (corners.length != 4) return null;
    final k = _k(image);
    final s = sideMm / 2;
    const square = [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)];
    // Homography tag plane (mm) -> normalised image coordinates, h33 = 1 (4-point DLT).
    final a = <List<double>>[];
    for (var i = 0; i < 4; i++) {
      final (x, y) = (square[i].$1 * s, square[i].$2 * s);
      final u = (corners[i].dx - k.cx) / k.f, v = (corners[i].dy - k.cy) / k.f;
      a.add([x, y, 1, 0, 0, 0, -u * x, -u * y, u]);
      a.add([0, 0, 0, x, y, 1, -v * x, -v * y, v]);
    }
    final h = _solve(a);
    if (h == null) return null;
    final b1 = [h[0], h[3], h[6]], b2 = [h[1], h[4], h[7]], b3 = [h[2], h[5], 1.0];
    final lambda = 2 / (_norm(b1) + _norm(b2));
    final t = _scale(b3, lambda);
    var n = _unit(_cross(b1, b2));
    var d = _dot(n, t);
    if (d < 0) (n, d) = (_scale(n, -1), -d);
    // ponytail: a sanity range for this robot's lens height; widen it if the camera is moved.
    if (!d.isFinite || d < 20 || d > 500) return null;
    return FloorCamera(normal: n, heightMm: d);
  }

  Map<String, Object> toJson() => {'normal': normal, 'height_mm': heightMm};

  static FloorCamera? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final n = raw['normal'], h = raw['height_mm'];
    if (n is! List || n.length != 3 || n.any((v) => v is! num) || h is! num || h <= 0) return null;
    return FloorCamera(normal: _unit([for (final v in n) (v as num).toDouble()]), heightMm: h.toDouble());
  }

  static const _key = 'floor_camera_v1';

  static Future<FloorCamera?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      return raw == null ? null : fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('FloorCamera load failed: $e');
      return null;
    }
  }

  Future<void> save() async => (await SharedPreferences.getInstance()).setString(_key, jsonEncode(toJson()));
}

/// The 0183 intrinsics scaled to [image]. ponytail: assumes the same field of view across the
/// width at every stream size; a mode that crops the sensor differently needs its own solve.
({double f, double cx, double cy}) _k(Size image) {
  final s = image.width / _w0;
  return (f: _fx * s, cx: _cx * s, cy: image.height / 2 + (_cy - _h0 / 2) * s);
}

/// Gaussian elimination with partial pivoting on an n x (n+1) augmented matrix.
List<double>? _solve(List<List<double>> a) {
  final n = a.length;
  for (var c = 0; c < n; c++) {
    var p = c;
    for (var r = c + 1; r < n; r++) {
      if (a[r][c].abs() > a[p][c].abs()) p = r;
    }
    if (a[p][c].abs() < 1e-12) return null;
    final row = a[c];
    a[c] = a[p];
    a[p] = row;
    for (var r = 0; r < n; r++) {
      if (r == c) continue;
      final f = a[r][c] / a[c][c];
      for (var j = c; j <= n; j++) {
        a[r][j] -= f * a[c][j];
      }
    }
  }
  return [for (var i = 0; i < n; i++) a[i][n] / a[i][i]];
}

double _dot(List<double> a, List<double> b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
double _norm(List<double> a) => math.sqrt(_dot(a, a));
List<double> _scale(List<double> a, double s) => [a[0] * s, a[1] * s, a[2] * s];
List<double> _add(List<double> a, List<double> b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
List<double> _sub(List<double> a, List<double> b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
List<double> _unit(List<double> a) => _scale(a, 1 / _norm(a));
List<double> _cross(List<double> a, List<double> b) =>
    [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
