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

/// The tracked detection (the one with a `track_id`), or null.
Detection? trackedDetection(List<Detection> detections) {
  for (final d in detections) {
    if (d.trackId != null) return d;
  }
  return null;
}

/// The tracked box as fractions of the frame, or null.
Rect? trackedBox(List<Detection> detections, double width, double height) {
  final d = trackedDetection(detections);
  if (d == null || width <= 0 || height <= 0) return null;
  return Rect.fromCenter(center: Offset(d.x / width, d.y / height), width: d.w / width, height: d.h / height);
}

/// The live scan's own lock and quiz skip the tracked box: LOCK opens no quiz (0181).
List<Detection> untracked(List<Detection> detections) => [
  for (final d in detections)
    if (d.trackId == null) d,
];

/// How long the green box outlives the last tracked box: after that the camera has lost the item.
const trackLostAfter = Duration(milliseconds: 1500);

/// The box drawn for a LOCK: the AI's box until the camera tracks it, then the tracked box, and
/// none once the camera has lost it (robot test 4 Nov: a stale box stayed on screen for 20 s).
Rect? lockOverlayBox({Rect? aiBox, Rect? trackBox, DateTime? trackSeenAt, required DateTime now}) {
  if (trackSeenAt == null) return aiBox;
  return now.difference(trackSeenAt) < trackLostAfter ? trackBox : null;
}

// ── Refine (0182): a fresh AI box once the item settles after a move, turn or re-find ──────────
// The tracker keeps the LOCK shape (a pack laid flat kept its upright box), so when the camera says
// the item just settled (`held` false -> true) the app asks the AI once for a tight box around it
// and restarts tracking from that box.

/// At most one refine per this long (each is one AI call, ~2-3 s).
const refineEvery = Duration(seconds: 3);

/// No settled box for this long (lost, or only odd boxes: a pack laid flat is not recognised and
/// never settles, robot test 4 Nov): the AI looks for the item in the whole frame instead.
const unsettledRefineAfter = Duration(seconds: 2);

/// The locked item has no settled box on this detection frame: the tracked box is moving
/// (`held` false), or missing although the camera tracked it before. Old firmware (no tracking,
/// or no `held`) is never unsettled, so it never triggers a refine.
bool unsettled(Detection? tracked, {required bool seenTracking}) =>
    tracked == null ? seenTracking : tracked.held == false;

/// The area sent to the AI: the tracked box with half its size added on every side, in the frame.
Rect refineArea(Rect tracked) => Rect.fromLTRB(
  (tracked.left - tracked.width / 2).clamp(0.0, 1.0),
  (tracked.top - tracked.height / 2).clamp(0.0, 1.0),
  (tracked.right + tracked.width / 2).clamp(0.0, 1.0),
  (tracked.bottom + tracked.height / 2).clamp(0.0, 1.0),
);

/// The part of the frame `cropToBox` (detection_crop.dart) cuts for [area]: it adds 5 % margins.
Rect cropArea(Rect area) => Rect.fromLTRB(
  (area.left - area.width * .05).clamp(0.0, 1.0),
  (area.top - area.height * .05).clamp(0.0, 1.0),
  (area.right + area.width * .05).clamp(0.0, 1.0),
  (area.bottom + area.height * .05).clamp(0.0, 1.0),
);

/// [inner] (fractions of the [crop] photo) as fractions of the whole frame.
Rect fromCrop(Rect crop, Rect inner) => Rect.fromLTRB(
  crop.left + inner.left * crop.width,
  crop.top + inner.top * crop.height,
  crop.left + inner.right * crop.width,
  crop.top + inner.bottom * crop.height,
);

/// The item is still where it was when the refine was asked: its box now overlaps the box then
/// by more than half (IoU), so a late AI answer does not snap the box back to an old place.
bool stillThere(Rect? now, Rect then) {
  if (now == null) return false;
  final i = now.intersect(then);
  if (i.width <= 0 || i.height <= 0) return false;
  final inter = i.width * i.height;
  return inter / (now.width * now.height + then.width * then.height - inter) > .5;
}
