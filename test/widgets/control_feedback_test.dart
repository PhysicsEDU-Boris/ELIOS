// Control inputs buzz and click when pressed (decision 0188).
import 'package:elio/models/control_session.dart';
import 'package:elio/widgets/control/r2_controls.dart';
import 'package:elio/widgets/control_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> calls;
  setUp(() {
    calls = [];
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (c) async {
        if (c.method == 'HapticFeedback.vibrate' || c.method == 'SystemSound.play') {
          calls.add('${c.method}:${c.arguments}');
        }
        return null;
      },
    );
  });
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  Future<void> pump(WidgetTester t, Widget w) => t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 240, height: 200, child: w)),
      ),
    ),
  );

  const feel = ['HapticFeedback.vibrate:HapticFeedbackType.selectionClick', 'SystemSound.play:SystemSoundType.click'];

  testWidgets('button tap', (t) async {
    var taps = 0;
    await pump(t, TransportKey(icon: Icons.add, label: 'GO', onTap: () => taps++));
    await t.tap(find.byType(TransportKey));
    await t.pump();
    expect(taps, 1);
    expect(calls, feel);
  });

  testWidgets('disabled button stays silent', (t) async {
    await pump(t, const TransportKey(icon: Icons.add, label: 'GO', onTap: null));
    await t.tap(find.byType(TransportKey));
    await t.pump();
    expect(calls, isEmpty);
  });

  testWidgets('toggle', (t) async {
    bool? got;
    await pump(t, RockerToggle(label: 'Voice', value: false, onChanged: (v) => got = v));
    await t.tap(find.byType(Switch));
    expect(got, true);
    expect(calls, feel);
  });

  testWidgets('slider: once per drag, not per step', (t) async {
    await pump(t, ControlFader(value: 0.2, onChanged: (_) {}));
    await t.drag(find.byType(Slider), const Offset(80, 0));
    expect(calls, feel);
  });

  testWidgets('joystick: once per new direction', (t) async {
    final dirs = <DriveDir>[];
    await pump(t, DriveJoystick(enabled: true, onDirection: dirs.add, onRelease: () {}));
    final g = await t.startGesture(t.getCenter(find.byType(DriveJoystick)));
    await g.moveBy(const Offset(0, -60));
    await g.moveBy(const Offset(0, -5)); // same direction: no second buzz
    await g.up();
    expect(dirs, hasLength(1));
    expect(calls, feel);
  });

  testWidgets('emergency stop', (t) async {
    await pump(t, EmergencyStopButton(onStop: () {}));
    await t.tap(find.descendant(of: find.byType(EmergencyStopButton), matching: find.byType(InkWell)));
    await t.pump();
    expect(calls, feel);
  });
}
