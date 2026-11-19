// Decision 0232: Advanced settings screen and the teacher PIN.
import 'package:elio/Screens/advanced_settings_screen.dart';
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
        for (var i = 0; i < 6; i++) {
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

  testWidgets('offline: Save keeps the settings on the phone and says so', (t) async {
    final (c, sent) = await pump(t, linkUp: false);
    await t.tap(find.byKey(const ValueKey('adv_inv_0')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('adv_save')));
    await t.pump();
    expect(c.read(robotSettingsProvider).inverted[0], isTrue);
    expect(sent, isEmpty);
    expect(find.text('Saved on this phone. Connect the robot to send it.'), findsOneWidget);
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
    Future<(ProviderContainer, List<bool>)> gate(WidgetTester t) async {
      final results = <bool>[];
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => FilledButton(
                onPressed: () async => results.add(await confirmTeacherPin(context, ref)),
                child: const Text('gate'),
              ),
            ),
          ),
        ),
      );
      return (c, results);
    }

    testWidgets('first use sets the PIN; then only the right PIN opens', (t) async {
      final (c, results) = await gate(t);
      await t.tap(find.text('gate'));
      await t.pumpAndSettle();
      expect(find.text('Set a teacher PIN'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('adv_pin_field')), '2468');
      await t.tap(find.byKey(const ValueKey('adv_pin_ok')));
      await t.pumpAndSettle();
      expect(results, [true]);
      expect(c.read(robotSettingsProvider).teacherPin, '2468');

      await t.tap(find.text('gate'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('adv_pin_field')), '1111');
      await t.tap(find.byKey(const ValueKey('adv_pin_ok')));
      await t.pump();
      expect(find.text('Wrong PIN'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('adv_pin_field')), '2468');
      await t.tap(find.byKey(const ValueKey('adv_pin_ok')));
      await t.pumpAndSettle();
      expect(results, [true, true]);
    });

    testWidgets('a PIN shorter than 4 digits is not accepted; Cancel opens nothing', (t) async {
      final (c, results) = await gate(t);
      await t.tap(find.text('gate'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('adv_pin_field')), '12');
      await t.tap(find.byKey(const ValueKey('adv_pin_ok')));
      await t.pump();
      expect(c.read(robotSettingsProvider).teacherPin, isNull);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(results, [false]);
    });
  });
}
