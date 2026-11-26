/// When the camera searches for the arm's AprilTags (0182, 0183): only while R1 grips or a bin run
/// plays. Never for a manual PICK UP or HOME (owner, 26 Nov: the search costs ~50 ms a frame and
/// those moves don't use it). Pure Dart: time and the send come from the caller.
class ArmTagSwitch {
  bool? _sent;

  /// The camera starts with tags off after a (re)connect: say again what we want.
  void linkUp() => _sent = null;

  bool wanted(DateTime now, {bool r1Grips = false}) => r1Grips;

  /// Sends `{"cmd":"arm_tags","on":...}` through [send] when what we want changed. Call it on every
  /// camera frame (and R1 tick), with or without R1.
  void sync(DateTime now, {required bool connected, bool r1Grips = false, required void Function(Map<String, Object?>) send}) {
    final want = wanted(now, r1Grips: r1Grips);
    if (want == _sent || !connected) return;
    send({'cmd': 'arm_tags', 'on': want});
    _sent = want;
  }
}
