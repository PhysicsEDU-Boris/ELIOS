// Config → Settings work on both cameras (decision 0189).
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/widgets/control/r2_controls.dart';
import 'package:elio/widgets/waste_quiz_popup.dart' show QuizCountdown;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Sound effects off silences the Control click, haptic stays', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (c) async {
      calls.add(c.method);
      return null;
    });
    addTearDown(() => soundEffectsOn = true);

    soundEffectsOn = false;
    controlFeedback();
    await pumpEventQueue();
    expect(calls, isNot(contains('SystemSound.play')));
    expect(calls, contains('HapticFeedback.vibrate'));

    calls.clear();
    soundEffectsOn = true;
    controlFeedback();
    await pumpEventQueue();
    expect(calls, contains('SystemSound.play'));
  });

  testWidgets('quiz countdown calls time up once at zero', (tester) async {
    var up = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: QuizCountdown(seconds: 3, onTimeUp: () => up++)),
    ));
    expect(find.text('3s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1s'), findsOneWidget);
    expect(up, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(up, 1);
  });
}
