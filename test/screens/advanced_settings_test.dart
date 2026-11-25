// Decision 0232: Advanced settings screen and the teacher PIN.
import 'package:elio/Screens/advanced_settings_screen.dart';
import 'package:elio/services/robot/arm_profile.dart';
import 'package:elio/services/robot/robot_settings.dart';
import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> enterPin(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.byKey(ValueKey('adv_pin_$d')));
    await t.pump();
  }
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(ProviderContainer, List<Map<String, Object?>>)> pump(
    WidgetTester t, {
    Size size = const Size(915, 412),
    bool linkUp = true,
    bool dark = false,
    String? pin = '1234',
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    addTearDown(t.view.reset);
    final sent = <Map<String, Object?>>[];
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: (dark ? ElioDarkTheme.wrap : ElioLightTheme.wrap)(
            Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdvancedSettingsScreen(
                        linkUp: linkUp,
                        address: '192.168.4.1:8765',
                        onSend: (m) {
                          if (!linkUp) return false;
                          sent.add(m);
                          return true;
                        },
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    if (pin != null) await enterPin(t, pin);
    return (c, sent);
  }

  for (final size in [const Size(915, 412), const Size(844, 390)]) {
    for (final dark in [false, true]) {
      testWidgets('every section renders without overflow at $size ${dark ? 'dark' : 'light'}', (t) async {
        await pump(t, size: size, dark: dark);
        for (var i = 0; i < 7; i++) {
          await t.ensureVisible(find.byKey(ValueKey('adv_tab_$i')));
          await t.tap(find.byKey(ValueKey('adv_tab_$i')));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: 'section $i');
        }
      });
    }
  }

  testWidgets('a trim jog changes the draft; Save stores it and sends CONFIG', (t) async {
    final (c, sent) = await pump(t);
    final row = find.byKey(const ValueKey('adv_axis_1'));
    await t.tap(find.descendant(of: row, matching: find.byIcon(Icons.add_rounded)));
    await t.pump();
    expect(find.descendant(of: row, matching: find.text('+0.5°')), findsOneWidget);
    expect(c.read(robotSettingsProvider).trims[1], 0, reason: 'nothing saved before Save');
    await t.tap(find.byKey(const ValueKey('adv_save')));
    await t.pump();
    expect(c.read(robotSettingsProvider).trims[1], 0.5);
    expect(sent.single['trims'], [0, 0.5, 0, 0, 0]);
    expect(find.text('Saved and sent to the robot'), findsOneWidget);
  });

  testWidgets('0240: Speed & ramps edits the profile; Save sends it in CONFIG; Reset restores the defaults', (t) async {
    final (c, sent) = await pump(t);
    await t.tap(find.byKey(const ValueKey('adv_tab_6')));
    await t.pumpAndSettle();
    final base = find.byKey(const ValueKey('adv_speed_5'));
    expect(find.descendant(of: base, matching: find.text('32°/s')), findsOneWidget);
    // Base top speed one step down, then its speed-up ramp up to 72 %: slow-down gives way to 28 %.
    await t.tap(find.descendant(of: find.byKey(const ValueKey('adv_vmax_5')), matching: find.byIcon(Icons.remove_rounded)));
    await t.pump();
    final accel = find.byKey(const ValueKey('adv_accel_5'));
    for (var k = 0; k < 39; k++) {
      await t.tap(find.descendant(of: accel, matching: find.byIcon(Icons.add_rounded)));
      await t.pump();
    }
    expect(find.descendant(of: base, matching: find.text('31°/s')), findsOneWidget);
    expect(find.descendant(of: accel, matching: find.text('72 %')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('adv_decel_5')), matching: find.text('28 %')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('adv_save')));
    await t.pump();
    expect((sent.single['profile'] as Map)['Arm Base'], {'vmax': 31.0, 'accel': 0.72, 'decel': 0.28});
    expect(c.read(robotSettingsProvider).profile['Arm Base'], const ArmAxisProfile(31, 0.72, 0.28));
    await t.tap(find.byKey(const ValueKey('adv_speed_reset')));
    await t.pump();
    expect(find.descendant(of: base, matching: find.text('32°/s')), findsOneWidget);
  });

  testWidgets('offline: Save keeps the settings on the phone and says so', (t) async {
    final (c, sent) = await pump(t, linkUp: false);
    await t.tap(find.byKey(const ValueKey('adv_inv_0')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('adv_save')));
    await t.pump();
    expect(c.read(robotSettingsProvider).inverted[0], isTrue);
    expect(sent, isEmpty);
    expect(find.text('Saved on this phone. It goes to the robot as soon as it is connected and not stopped.'), findsOneWidget);
  });

  testWidgets('back with unsaved changes asks first; Discard drops them', (t) async {
    final (c, _) = await pump(t);
    await t.tap(find.byKey(const ValueKey('adv_inv_2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('adv_back')));
    await t.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await t.tap(find.text('Discard'));
    await t.pumpAndSettle();
    expect(find.byType(AdvancedSettingsScreen), findsNothing);
    expect(c.read(robotSettingsProvider).inverted[2], isFalse);
  });

  testWidgets('drive section edits reach the joystick config after Save', (t) async {
    final (c, _) = await pump(t);
    await t.tap(find.byKey(const ValueKey('adv_tab_2')));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(of: find.byKey(const ValueKey('adv_deadzone')), matching: find.byIcon(Icons.add_rounded)),
    );
    await t.tap(find.descendant(of: find.byKey(const ValueKey('adv_flip_turn')), matching: find.byType(Switch)));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('adv_save')));
    await t.pump();
    final j = c.read(robotSettingsProvider).joystick;
    expect(j.deadzone, closeTo(0.09, 1e-9));
    expect(j.driveTurnSign, -1);
  });

  testWidgets('reset puts the defaults back in the draft, keeping the PIN', (t) async {
    final (c, _) = await pump(t);
    c.read(robotSettingsProvider.notifier).save(const RobotSettings(deadzone: 0.2, teacherPin: '1111'));
    await t.tap(find.byKey(const ValueKey('adv_back')));
    await t.pumpAndSettle();
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await enterPin(t, '1111');
    await t.tap(find.byKey(const ValueKey('adv_tab_5')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('adv_reset')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Reset'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('adv_save')));
    await t.pump();
    expect(c.read(robotSettingsProvider), const RobotSettings(teacherPin: '1111'));
  });

  group('teacher PIN', () {
    testWidgets('first open sets the PIN; then only the right PIN opens', (t) async {
      final (c, _) = await pump(t, pin: null);
      expect(find.text('Set a teacher PIN'), findsOneWidget);
      expect(find.byKey(const ValueKey('adv_tab_0')), findsNothing, reason: 'locked');
      expect(find.byKey(const ValueKey('adv_save')), findsNothing);
      await enterPin(t, '2468');
      expect(c.read(robotSettingsProvider).teacherPin, '2468');
      expect(find.byKey(const ValueKey('adv_tab_0')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('adv_back')));
      await t.pumpAndSettle();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('Teacher PIN'), findsOneWidget);
      await enterPin(t, '1111');
      expect(find.text('Wrong PIN'), findsOneWidget);
      expect(find.byKey(const ValueKey('adv_tab_0')), findsNothing);
      await enterPin(t, '2468');
      expect(find.byKey(const ValueKey('adv_tab_0')), findsOneWidget);
    });

    testWidgets('backspace removes a digit; back while locked saves no PIN', (t) async {
      final (c, _) = await pump(t, pin: null);
      await enterPin(t, '12');
      await t.tap(find.byKey(const ValueKey('adv_pin_back')));
      await t.pump();
      await enterPin(t, '9');
      expect(c.read(robotSettingsProvider).teacherPin, isNull, reason: 'only 2 digits typed');
      await t.tap(find.byKey(const ValueKey('adv_back')));
      await t.pumpAndSettle();
      expect(find.byType(AdvancedSettingsScreen), findsNothing);
      expect(c.read(robotSettingsProvider).teacherPin, isNull);
    });

    testWidgets('change PIN asks for a new one; the close key keeps the old one', (t) async {
      final (c, _) = await pump(t);
      await t.tap(find.byKey(const ValueKey('adv_tab_5')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('adv_change_pin')));
      await t.pumpAndSettle();
      expect(find.text('Set a teacher PIN'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('adv_pin_cancel')));
      await t.pumpAndSettle();
      expect(c.read(robotSettingsProvider).teacherPin, '1234');
      await t.tap(find.byKey(const ValueKey('adv_change_pin')));
      await t.pumpAndSettle();
      await enterPin(t, '1357');
      expect(c.read(robotSettingsProvider).teacherPin, '1357');
      expect(find.byKey(const ValueKey('adv_tab_0')), findsOneWidget);
    });
  });
}
