import 'dart:ui' show Offset, Rect;

import 'websocket_service.dart' show Detection;

/// LOCK's box for the camera tracker (0182): [box] as fractions of the [width] x [height] frame
/// the AI saw, sent as top-left pixels. Firmware without tracking ignores it.
Map<String, Object?> trackStartCommand(Rect box, int width, int height, String label) => {
  'cmd': 'track_start',
  'box': [
    (box.left * width).round(),
    (box.top * height).round(),
    (box.width * width).round(),
    (box.height * height).round(),
  ],
  'label': label,
};

const trackStopCommand = <String, Object?>{'cmd': 'track_stop'};

/// The tracked box (the one detection with a `track_id`) as fractions of the frame, or null.
Rect? trackedBox(List<Detection> detections, double width, double height) {
  if (width <= 0 || height <= 0) return null;
  for (final d in detections) {
    if (d.trackId == null) continue;
    return Rect.fromCenter(center: Offset(d.x / width, d.y / height), width: d.w / width, height: d.h / height);
  }
  return null;
}

/// The live scan's own lock and quiz skip the tracked box: LOCK opens no quiz (0181).
List<Detection> untracked(List<Detection> detections) => [
  for (final d in detections)
    if (d.trackId == null) d,
];
