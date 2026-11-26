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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(ProviderContainer, List<Map<String, Object?>>)> pump(
    WidgetTester t, {
    Size size = const Size(915, 412),
    bool linkUp = true,
    bool dark = false,
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

  testWidgets('0241: no PIN; a trim jog is stored and sent at once (no Save)', (t) async {
    final (c, sent) = await pump(t);
    expect(find.byKey(const ValueKey('adv_save')), findsNothing);
    final row = find.byKey(const ValueKey('adv_axis_1'));
    await t.tap(find.descendant(of: row, matching: find.byIcon(Icons.add_rounded)));
    await t.pump();
    expect(find.descendant(of: row, matching: find.text('+0.5°')), findsOneWidget);
    expect(c.read(robotSettingsProvider).trims[1], 0.5);
    expect(sent.single['trims'], [0, 0.5, 0, 0, 0]);
    await t.pump(const Duration(milliseconds: 200));
  });

  testWidgets('0241: quick steps go out at most every 100 ms, always ending with the last one', (t) async {
    final (c, sent) = await pump(t);
    final plus = find.descendant(of: find.byKey(const ValueKey('adv_axis_1')), matching: find.byIcon(Icons.add_rounded));
    for (var k = 0; k < 4; k++) {
      await t.tap(plus);
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(sent.length, 1, reason: 'the first at once, the rest wait');
    await t.pump(const Duration(milliseconds: 150));
    expect(sent.length, 2);
    expect(sent.last['trims'], [0, 2.0, 0, 0, 0]);
    expect(c.read(robotSettingsProvider).trims[1], 2.0);
  });

  testWidgets('0240: Speed & ramps edits the profile and sends it in CONFIG; Reset restores the defaults', (t) async {
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
      await t.pump(const Duration(milliseconds: 120));
    }
    expect(find.descendant(of: base, matching: find.text('31°/s')), findsOneWidget);
    expect(find.descendant(of: accel, matching: find.text('72 %')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('adv_decel_5')), matching: find.text('28 %')), findsOneWidget);
    expect((sent.last['profile'] as Map)['Arm Base'], {'vmax': 31.0, 'accel': 0.72, 'decel': 0.28});
    expect(c.read(robotSettingsProvider).profile['Arm Base'], const ArmAxisProfile(31, 0.72, 0.28));
    await t.tap(find.byKey(const ValueKey('adv_speed_reset')));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.descendant(of: base, matching: find.text('32°/s')), findsOneWidget);
    expect((sent.last['profile'] as Map)['Arm Base'], {'vmax': 32.0, 'accel': 0.33, 'decel': 0.33});
  });

  testWidgets('offline: a change is kept on the phone and says so once', (t) async {
    final (c, sent) = await pump(t, linkUp: false);
    await t.tap(find.byKey(const ValueKey('adv_inv_0')));
    await t.pump();
    expect(c.read(robotSettingsProvider).inverted[0], isTrue);
    expect(sent, isEmpty);
    expect(find.text('Saved on this phone. It goes to the robot as soon as it is connected and not stopped.'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 200));
  });

  testWidgets('back right after a change still stores and sends it', (t) async {
    final (c, sent) = await pump(t);
    final plus = find.descendant(of: find.byKey(const ValueKey('adv_axis_2')), matching: find.byIcon(Icons.add_rounded));
    await t.tap(plus);
    await t.pump(const Duration(milliseconds: 10));
    await t.tap(plus);
    await t.pump(const Duration(milliseconds: 10));
    await t.tap(find.byKey(const ValueKey('adv_back')));
    await t.pumpAndSettle();
    expect(find.byType(AdvancedSettingsScreen), findsNothing, reason: 'no discard prompt any more');
    expect(c.read(robotSettingsProvider).trims[2], 1.0);
    expect(sent.last['trims'], [0, 0, 1.0, 0, 0]);
  });

  testWidgets('drive section edits reach the joystick config at once', (t) async {
    final (c, _) = await pump(t);
    await t.tap(find.byKey(const ValueKey('adv_tab_2')));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(of: find.byKey(const ValueKey('adv_deadzone')), matching: find.byIcon(Icons.add_rounded)),
    );
    await t.pump(const Duration(milliseconds: 150));
    await t.tap(find.descendant(of: find.byKey(const ValueKey('adv_flip_turn')), matching: find.byType(Switch)));
    await t.pump(const Duration(milliseconds: 150));
    final j = c.read(robotSettingsProvider).joystick;
    expect(j.deadzone, closeTo(0.09, 1e-9));
    expect(j.driveTurnSign, -1);
  });

  testWidgets('reset puts the defaults back at once', (t) async {
    final (c, _) = await pump(t);
    c.read(robotSettingsProvider.notifier).save(const RobotSettings(deadzone: 0.2));
    await t.tap(find.byKey(const ValueKey('adv_back')));
    await t.pumpAndSettle();
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('adv_tab_5')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('adv_change_pin')), findsNothing);
    await t.tap(find.byKey(const ValueKey('adv_reset')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Reset'));
    await t.pumpAndSettle();
    expect(c.read(robotSettingsProvider), const RobotSettings());
  });
}
