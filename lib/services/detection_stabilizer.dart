/// Turns a noisy per-frame detection stream into one "lock" per object:
/// the same object must stay in view for [DetectionStabilizer.lockTime]
/// before it counts, and a locked object can't lock again until it is
/// re-armed. Pure logic: no timers, no camera, no Gemma. See
/// docs/decisions/0007-stabilizer.md.
library;

/// One detection, as the stabilizer sees it. [x], [y] are the box centre and
/// [w], [h] its size, in image pixels (the same layout as `Detection` in
/// websocket_service.dart).
///
/// [trackId], when the source has one, is the object's identity and is used
/// instead of box overlap. A source without boxes (the phone camera, judged
/// by image similarity) plugs in the same way: it gives each object a stable
/// [trackId]. That source is not part of M1.
class TrackedDetection {
  const TrackedDetection({
    required this.label,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.score = 0.0,
    this.trackId,
  });

  final String label;
  final double x, y, w, h;
  final double score;
  final int? trackId;

  @override
  String toString() => 'TrackedDetection($label ${score.toStringAsFixed(2)} '
      'x=$x y=$y w=$w h=$h${trackId == null ? '' : ' id=$trackId'})';
}

/// Emitted once per object, when it has been held for the lock time.
class StabilizerLock {
  const StabilizerLock(this.detection, this.at);

  final TrackedDetection detection;
  final DateTime at;
}

/// Intersection over union of two centre-format boxes (0 when either is empty).
double intersectionOverUnion(TrackedDetection a, TrackedDetection b) {
  final w = _overlap(a.x - a.w / 2, a.x + a.w / 2, b.x - b.w / 2, b.x + b.w / 2);
  final h = _overlap(a.y - a.h / 2, a.y + a.h / 2, b.y - b.h / 2, b.y + b.h / 2);
  final inter = w * h;
  final union = a.w * a.h + b.w * b.h - inter;
  return union <= 0 ? 0 : inter / union;
}

double _overlap(double a0, double a1, double b0, double b1) {
  final d = (a1 < b1 ? a1 : b1) - (a0 > b0 ? a0 : b0);
  return d > 0 ? d : 0;
}

/// Single-target stabilizer: it follows one object at a time (see [update]).
class DetectionStabilizer {
  DetectionStabilizer({
    this.lockTime = const Duration(milliseconds: 1000),
    this.iouThreshold = 0.65,
    this.dropoutTolerance = const Duration(milliseconds: 600),
    this.rearmAfter = const Duration(milliseconds: 1500),
    this.maxFrameGap = const Duration(milliseconds: 1500),
    this.ignoredLabels = const {},
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// How long the same object must be seen before it locks.
  final Duration lockTime;

  /// Minimum box overlap between consecutive frames to count as the same
  /// object, when no [TrackedDetection.trackId] is available.
  final double iouThreshold;

  /// How long the object may be missing before the lock timer starts over
  /// (a longer absence resets it). Absence is measured from the first frame
  /// that arrived without the object; time in which no frames arrive at all
  /// does not count, so the result doesn't depend on the frame rate.
  final Duration dropoutTolerance;

  /// A locked object re-arms after being missing this long (measured like
  /// [dropoutTolerance]). A new label on it locks only after holding for
  /// [lockTime], which then replaces the lock.
  final Duration rearmAfter;

  /// If no frame arrives for longer than this (for example analysis was
  /// paused), the unlocked candidate and its timer are dropped. A locked
  /// object stays locked, and the pause doesn't count as its absence.
  final Duration maxFrameGap;

  /// Labels removed before tracking (compared after trimming, exact match),
  /// e.g. the hand holding the item. They can never be tracked or locked.
  final Set<String> ignoredLabels;

  final DateTime Function() _clock;

  DateTime? _lastFrameAt;

  TrackedDetection? _candidate;
  DateTime? _candidateSince;
  DateTime? _candidateMissingSince;

  TrackedDetection? _locked;
  DateTime? _lockedMissingSince;

  /// An object is being timed but hasn't locked yet.
  bool get hasCandidate => _candidate != null;

  /// An object is locked: it can't lock again until it re-arms.
  bool get isLocked => _locked != null;

  /// Feeds one frame's detections, timed by the injected clock. Returns a
  /// lock when the tracked object has just been held for [lockTime],
  /// otherwise null.
  ///
  /// Which box is tracked: the current candidate if it is still in view,
  /// else the most confident box (ties: the larger one). While a locked
  /// object stays in view, other objects wait until it leaves.
  ///
  /// A frame timed earlier than the previous one is ignored.
  StabilizerLock? update(List<TrackedDetection> detections) {
    final now = _clock();
    final last = _lastFrameAt;
    if (last != null && now.isBefore(last)) return null;
    if (last != null && now.difference(last) > maxFrameGap) {
      _candidate = null;
      _lockedMissingSince = null;
    }
    _lastFrameAt = now;

    final seen = [
      for (final d in detections)
        if (d.label.trim().isNotEmpty && !ignoredLabels.contains(d.label.trim())) d,
    ];

    // The locked object: still in view, back after a long absence (re-armed), or missing.
    final locked = _locked;
    if (locked != null) {
      final match = _find(seen, locked);
      final missing = _lockedMissingSince;
      if (match == null) {
        if (now.difference(_lockedMissingSince ??= now) >= rearmAfter) _locked = null;
      } else {
        _locked = missing != null && now.difference(missing) >= rearmAfter ? null : match;
        _lockedMissingSince = null;
      }
    }

    // The candidate: a short absence keeps its timer, a longer one drops it.
    // In view means the same object, whatever its label (a new label is
    // handled below as a new candidate).
    final cand = _candidate;
    if (cand != null) {
      final inView = seen.any((d) => _sameObject(cand, d));
      final missing = _candidateMissingSince;
      if (!inView) {
        if (now.difference(_candidateMissingSince ??= now) > dropoutTolerance) _candidate = null;
      } else if (missing != null && now.difference(missing) > dropoutTolerance) {
        _candidate = null;
      } else {
        _candidateMissingSince = null;
      }
    }
    // Missing but still inside the dropout window: wait for it, don't switch.
    if (_candidate != null && _candidateMissingSince != null) return null;

    final target = _pick(seen);
    if (target == null) return null;

    // The locked object with its locked label: still blocked. A new label on
    // it must hold for lockTime like any candidate, so a flicker back to the
    // locked label drops that candidate instead of re-arming.
    final stillLocked = _locked;
    if (stillLocked != null && _sameObject(stillLocked, target) && target.label == stillLocked.label) {
      _candidate = null;
      return null;
    }

    final current = _candidate;
    if (current == null || !_sameObject(current, target) || current.label != target.label) {
      _candidate = target;
      _candidateSince = now;
      _candidateMissingSince = null;
      return null;
    }

    _candidate = target;
    return now.difference(_candidateSince!) >= lockTime ? _lock(target, now) : null;
  }

  StabilizerLock _lock(TrackedDetection d, DateTime now) {
    _candidate = null;
    _locked = d;
    _lockedMissingSince = null;
    return StabilizerLock(d, now);
  }

  TrackedDetection? _find(List<TrackedDetection> seen, TrackedDetection ref) {
    for (final d in seen) {
      if (_sameObject(ref, d) && d.label == ref.label) return d;
    }
    return null;
  }

  TrackedDetection? _pick(List<TrackedDetection> seen) {
    if (seen.isEmpty) return null;
    for (final anchor in [_candidate, _locked]) {
      if (anchor == null) continue;
      for (final d in seen) {
        if (_sameObject(anchor, d)) return d;
      }
    }
    var best = seen.first;
    for (final d in seen.skip(1)) {
      if (d.score > best.score || (d.score == best.score && d.w * d.h > best.w * best.h)) best = d;
    }
    return best;
  }

  /// Track ids decide when both sides have one; otherwise box overlap does.
  bool _sameObject(TrackedDetection a, TrackedDetection b) {
    if (a.trackId != null && b.trackId != null) return a.trackId == b.trackId;
    return intersectionOverUnion(a, b) >= iouThreshold;
  }
}
