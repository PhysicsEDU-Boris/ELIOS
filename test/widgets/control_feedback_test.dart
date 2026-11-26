// Control inputs buzz and click when pressed (decision 0188); the click is the
// S1 tick from the one audio service since ELIOS 3 (0201).
import 'package:elio/models/control_session.dart';
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/widgets/control/r2_controls.dart';
import 'package:elio/widgets/control_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

var _day = DateTime(2030);

void main() {
  late List<String> calls;
  setUp(() {
    calls = [];
    // A fresh day per test: the throttle remembers the last sound.
    var now = _day = _day.add(const Duration(days: 1));
    ElioSound.instance
      ..sink = ((s, _) => calls.add('ElioSound:${s.name}'))
      ..isSilent = (() async => false)
      // Each press is a new moment, so the 120 ms throttle never hides one.
      ..clock = (() => now = now.add(const Duration(seconds: 1)));
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (c) async {
          if (c.method == 'HapticFeedback.vibrate' ||
              c.method == 'SystemSound.play') {
            calls.add('${c.method}:${c.arguments}');
          }
          return null;
        });
  });
  tearDown(() {
    ElioSound.instance
      ..sink = null
      ..clock = DateTime.now;
  });
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Future<void> pump(WidgetTester t, Widget w) => t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 240, height: 200, child: w)),
      ),
    ),
  );

  const feel = [
    'HapticFeedback.vibrate:HapticFeedbackType.selectionClick',
    'ElioSound:tick',
  ];

  testWidgets('button tap', (t) async {
    var taps = 0;
    await pump(
      t,
      TransportKey(icon: Icons.add, label: 'GO', onTap: () => taps++),
    );
    await t.tap(find.byType(TransportKey));
    await t.pump();
    expect(taps, 1);
    await t.pump();
    expect(calls, feel);
  });

  testWidgets('disabled button stays silent', (t) async {
    await pump(
      t,
      const TransportKey(icon: Icons.add, label: 'GO', onTap: null),
    );
    await t.tap(find.byType(TransportKey));
    await t.pump();
    expect(calls, isEmpty);
  });

  testWidgets('toggle', (t) async {
    bool? got;
    await pump(
      t,
      RockerToggle(label: 'Voice', value: false, onChanged: (v) => got = v),
    );
    await t.tap(find.byType(Switch));
    expect(got, true);
    await t.pump();
    expect(calls, feel);
  });

  testWidgets('slider: once per drag, not per step', (t) async {
    await pump(t, ControlFader(value: 0.2, onChanged: (_) {}));
    await t.drag(find.byType(Slider), const Offset(80, 0));
    await t.pump();
    expect(calls, feel);
  });

  testWidgets('slider: the thumb follows the finger while the owner\'s value lags (0240)', (t) async {
    final sent = <double>[];
    // The arm faders feed back a throttled / refused commanded value: here it never changes.
    await pump(t, SizedBox(width: 300, child: ControlFader(value: 0.2, onChanged: sent.add)));
    double thumb() => t.widget<Slider>(find.byType(Slider)).value;
    final g = await t.startGesture(t.getCenter(find.byType(Slider)));
    await g.moveBy(const Offset(60, 0));
    await t.pump();
    expect(thumb(), sent.last, reason: 'under the finger, not stuck at the owner value');
    expect(thumb(), isNot(0.2));
    await g.up();
    await t.pump();
    expect(thumb(), 0.2, reason: 'released: back to what the owner says the arm has');
  });

  testWidgets('joystick: once per new direction', (t) async {
    final dirs = <DriveDir>[];
    await pump(
      t,
      DriveJoystick(enabled: true, onDirection: dirs.add, onRelease: () {}),
    );
    final g = await t.startGesture(t.getCenter(find.byType(DriveJoystick)));
    await g.moveBy(const Offset(0, -60));
    await g.moveBy(const Offset(0, -5)); // same direction: no second buzz
    await g.up();
    expect(dirs, hasLength(1));
    await t.pump();
    expect(calls, feel);
  });

  testWidgets('emergency stop', (t) async {
    await pump(t, EmergencyStopButton(onStop: () {}));
    await t.tap(
      find.descendant(
        of: find.byType(EmergencyStopButton),
        matching: find.byType(InkWell),
      ),
    );
    await t.pump();
    await t.pump();
    expect(calls, feel);
  });
}
