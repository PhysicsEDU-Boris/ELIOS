/// When the camera searches for the arm's AprilTags (0182, 0183): while R1 grips, and for
/// [manualFor] after a manual PICK UP or HOME. The search costs ~50 ms a frame, so it is off
/// otherwise. Pure Dart: time and the send come from the caller.
class ArmTagSwitch {
  ArmTagSwitch({this.manualFor = const Duration(seconds: 5)});

  final Duration manualFor;
  DateTime? _manualUntil;
  bool? _sent;

  /// PICK UP or HOME was pressed at [now].
  void press(DateTime now) => _manualUntil = now.add(manualFor);

  /// The camera starts with tags off after a (re)connect: say again what we want.
  void linkUp() => _sent = null;

  bool wanted(DateTime now, {bool r1Grips = false}) =>
      r1Grips || (_manualUntil != null && now.isBefore(_manualUntil!));

  /// Sends `{"cmd":"arm_tags","on":...}` through [send] when what we want changed. Call it on every
  /// camera frame (and R1 tick), with or without R1.
  void sync(DateTime now, {required bool connected, bool r1Grips = false, required void Function(Map<String, Object?>) send}) {
    final want = wanted(now, r1Grips: r1Grips);
    if (want == _sent || !connected) return;
    send({'cmd': 'arm_tags', 'on': want});
    _sent = want;
  }
}
