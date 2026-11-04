// LOCK -> camera tracker (0182): the command the app sends and the box it draws back.
import 'package:elio/services/lock_tracking.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('track_start carries the AI box as top-left pixels of the frame it saw', () {
    final cmd = trackStartCommand(const Rect.fromLTRB(.25, .5, .5, 1), 640, 480, 'kardus');
    expect(cmd, {
      'cmd': 'track_start',
      'box': [160, 240, 160, 240],
      'label': 'kardus',
    });
    expect(trackStopCommand, {'cmd': 'track_stop'});
  });

  test('the tracked detection comes back as fractions; hands and old boxes do not', () {
    const hand = Detection(x: 100, y: 100, w: 50, h: 50, label: 'Human_Hand', score: .9);
    const tracked = Detection(x: 320, y: 240, w: 64, h: 48, label: 'kardus', score: .99, trackId: 2);
    final box = trackedBox([hand, tracked], 640, 480)!;
    expect(box.center, const Offset(.5, .5));
    expect(box.width, closeTo(.1, 1e-9));
    expect(box.height, closeTo(.1, 1e-9));
    expect(trackedBox([hand], 640, 480), isNull);
    expect(trackedBox([tracked], 0, 480), isNull);
  });

  test('the live scan never sees the tracked box, so LOCK opens no quiz by itself', () {
    const hand = Detection(x: 1, y: 1, w: 1, h: 1, label: 'Human_Hand', score: .9);
    const tracked = Detection(x: 1, y: 1, w: 1, h: 1, label: 'kardus', trackId: 1);
    expect(untracked([hand, tracked]), [hand]);
  });

  test('the green box: AI box, then the tracked box, then none once the camera lost it', () {
    const ai = Rect.fromLTRB(.1, .1, .2, .2);
    const tracked = Rect.fromLTRB(.3, .3, .4, .4);
    final t0 = DateTime(2026, 11, 4, 9, 30);
    expect(lockOverlayBox(aiBox: ai, now: t0), ai); // old firmware never tracks
    expect(lockOverlayBox(aiBox: ai, trackBox: tracked, trackSeenAt: t0, now: t0.add(const Duration(seconds: 1))), tracked);
    expect(lockOverlayBox(aiBox: ai, trackBox: tracked, trackSeenAt: t0, now: t0.add(trackLostAfter)), isNull);
  });
}
