// Decision 0022: optional track_id / dist_cm / lateral_cm per detection and
// arm_tags per frame. Missing or malformed values are null; old firmware works.
import 'package:elio/services/websocket_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const box = {'x': 320, 'y': 240, 'w': 120, 'h': 160, 'label': 'Plastic', 'score': 0.9};

  group('Detection.fromJson', () {
    test('old firmware: no new fields, all null, box unchanged', () {
      final d = Detection.fromJson(box);
      expect([d.trackId, d.distCm, d.lateralCm], [null, null, null]);
      expect([d.x, d.y, d.w, d.h, d.label, d.score], [320, 240, 120, 160, 'Plastic', 0.9]);
    });

    test('each field parses on its own', () {
      expect(Detection.fromJson({...box, 'track_id': 7}).trackId, 7);
      expect(Detection.fromJson({...box, 'dist_cm': 24}).distCm, 24.0);
      expect(Detection.fromJson({...box, 'dist_cm': 24.5}).distCm, 24.5);
      expect(Detection.fromJson({...box, 'lateral_cm': -3.25}).lateralCm, -3.25);
      final d = Detection.fromJson({...box, 'track_id': 7});
      expect([d.distCm, d.lateralCm], [null, null]);
    });

    test('malformed values become null and the box still parses', () {
      for (final bad in <Object?>['7', 7.5, true, null, [], {}]) {
        final d = Detection.fromJson({
          ...box,
          'track_id': bad,
          'dist_cm': bad is num ? 'x' : bad,
          'lateral_cm': bad is num ? 'x' : bad,
        });
        expect([d.trackId, d.distCm, d.lateralCm], [null, null, null], reason: '$bad');
        expect(d.label, 'Plastic');
      }
      expect(Detection.fromJson({...box, 'dist_cm': double.infinity}).distCm, isNull);
      expect(Detection.fromJson({...box, 'lateral_cm': double.nan}).lateralCm, isNull);
    });
  });

  group('ArmTag.listFromJson', () {
    test('missing or not a list: null', () {
      expect(ArmTag.listFromJson(null), isNull);
      expect(ArmTag.listFromJson('id0'), isNull);
      expect(ArmTag.listFromJson({'id': 0, 'dist_mm': 80}), isNull);
    });

    test('valid tags parse; malformed entries are skipped', () {
      final tags = ArmTag.listFromJson([
        {'id': 0, 'dist_mm': 82.5},
        {'id': 1, 'dist_mm': 140},
        {'id': '1', 'dist_mm': 140},
        {'id': 1},
        {'id': 1, 'dist_mm': 'far'},
        7,
      ])!;
      expect([for (final t in tags) (t.id, t.distMm)], [(0, 82.5), (1, 140.0)]);
      expect(ArmTag.listFromJson([]), isEmpty);
    });
  });

  test('arm_moving (decision 0026): a bool, else null (unknown, old firmware)', () {
    expect(armMovingFromJson(true), isTrue);
    expect(armMovingFromJson(false), isFalse);
    for (final bad in <Object?>[null, 'true', 1, 0, [], {}]) {
      expect(armMovingFromJson(bad), isNull, reason: '$bad');
    }
  });
}
