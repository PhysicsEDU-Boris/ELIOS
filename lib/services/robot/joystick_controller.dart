/// Turns the Control sticks into smooth drive and arm-base commands every tick (task J1,
/// decision 0231). Sends only through the callbacks, which go through the MotionGate (0026).
library;

import 'dart:async';

import 'joystick_math.dart';

class JoystickController {
  JoystickController({
    required this.sendDrive,
    required this.sendArmBase,
    required this.driveLocked,
    required this.armLocked,
    required this.baseServo,
    JoystickConfig config = const JoystickConfig(),
  })  : _config = config,
        _driveV = SlewLimiter(up: config.slewUp, down: config.slewDown),
        _driveW = SlewLimiter(up: config.slewUp, down: config.slewDown),
        _arm = SlewLimiter(up: config.slewUp, down: config.slewDown),
        _base = ArmBaseIntegrator(config);

  /// Left and right wheel, each in [-1, 1].
  final void Function(double left, double right) sendDrive;

  /// The base servo value, 0..180.
  final void Function(int servo) sendArmBase;

  /// STOPPED, no link, or R1's drive lock (0021): the drive output is a hard 0.
  final bool Function() driveLocked;

  /// STOPPED, no link, R1 sorting or a hand in view: the base stick is ignored.
  final bool Function() armLocked;

  /// The base servo value the app last commanded, by anyone.
  final double Function() baseServo;

  JoystickConfig _config;
  SlewLimiter _driveV, _driveW, _arm;
  ArmBaseIntegrator _base;

  JoystickConfig get config => _config;

  /// Advanced settings changed (0232): new constants from the next tick, keeping the current
  /// outputs and base angle so nothing jumps.
  set config(JoystickConfig c) {
    SlewLimiter keep(SlewLimiter s) => SlewLimiter(up: c.slewUp, down: c.slewDown)..reset(s.value);
    _driveV = keep(_driveV);
    _driveW = keep(_driveW);
    _arm = keep(_arm);
    _base = ArmBaseIntegrator(c, initialDeg: _base.angleDeg)..syncTo(_base.angleDeg);
    _config = c;
  }

  double _dx = 0, _dy = 0, _ax = 0;
  bool _wasDriving = false, _wasArmMoving = false;
  int _lastTick = 0;
  Timer? _timer;

  // ponytail: no stick timeout; a held, still finger sends no events, so a timeout would stop the
  // robot under a steady push. Release, widget dispose, background, STOP and link loss zero it instead.

  /// Screen deltas: x right, y down, each in [-1, 1]. (0, 0) on release.
  void setDriveStick(double x, double y) {
    final (cx, cy) = clampToUnitCircle(x, y);
    _dx = cx;
    _dy = cy;
  }

  /// x in [-1, 1], positive towards servo 180. 0 on release.
  void setArmStick(double x) => _ax = x.clamp(-1.0, 1.0).toDouble();

  void start() {
    _lastTick = 0;
    _timer?.cancel();
    // Timer.tick counts the periods that passed, so a late callback gets a longer dt (up to maxDt).
    _timer = Timer.periodic(Duration(milliseconds: config.tickMs), (t) {
      final dt = ((t.tick - _lastTick) * config.tickMs / 1000.0).clamp(0.0, config.maxDtSeconds).toDouble();
      _lastTick = t.tick;
      tick(dt);
    });
  }

  /// The app went to the background: sticks and ramps to 0 (the gate stops the wheels).
  void letGo() {
    _dx = _dy = _ax = 0;
    _driveV.reset();
    _driveW.reset();
    _arm.reset();
    _wasDriving = _wasArmMoving = false;
  }

  /// Leaving the screen: no more ticks. The caller's MotionGate.dispose sends the final motor 0,0.
  void stop() {
    _timer?.cancel();
    _timer = null;
    letGo();
  }

  /// One update; public so tests can run it with a fixed dt.
  void tick(double dt) {
    if (driveLocked()) {
      _driveV.reset();
      _driveW.reset();
      if (_wasDriving) sendDrive(0, 0);
      _wasDriving = false;
    } else {
      final v = _driveV.step(shapeAxis(-_dy, config), dt); // screen up = forward
      final w = _driveW.step(shapeAxis(_dx, config), dt);
      final out = mixDrive(v, w, config);
      final active = out.left != 0.0 || out.right != 0.0;
      if (active || _wasDriving) sendDrive(out.left, out.right);
      _wasDriving = active;
    }

    if (armLocked()) {
      _arm.reset();
      _wasArmMoving = false;
      return;
    }
    final fraction = _arm.step(shapeAxis(_ax, config), dt);
    final moving = fraction != 0.0;
    // Someone else moved the base (HOME, a debug slider): start from their angle, not ours.
    if (moving && !_wasArmMoving && baseServo().round() != _base.servo) {
      _base.syncTo(baseServo() - config.armBaseCenterServo);
    }
    if (moving) {
      sendArmBase(_base.update(fraction, dt));
    } else if (_wasArmMoving) {
      sendArmBase(_base.servo); // one hold command at the stopped angle
    }
    _wasArmMoving = moving;
  }
}
