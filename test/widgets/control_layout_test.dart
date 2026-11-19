// R2 (Figma 358:2358, decisions 0026 and 0173): at every supported window size,
// in the three link states, light and dark, with and without a quiz and the
// STOPPED strip, nothing overflows and STOP is one tap away and never covered.
// Was U1's test; the finders moved to the R2 widgets, the safety assertions stay.
// `flutter test --dart-define=R2_PNG=true test/widgets/control_layout_test.dart`
// also saves one PNG per size/state/mode to docs/test-results/r2/widget/.
import 'package:elio/models/control_session.dart';
import 'package:elio/providers/robot_provider.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/widgets/control/r2_controls.dart';
import 'package:elio/widgets/control_layout.dart';
import 'package:elio/widgets/waste_quiz_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'r2_control_harness.dart';

const _savePngs = bool.fromEnvironment('R2_PNG');

const _sizes = {
  '1366x768': Size(1366, 768),
  '1024x768': Size(1024, 768),
  '915x412': Size(915, 412), // Edge 60 Fusion landscape
  '844x390': Size(844, 390), // phone landscape
  '800x632': Size(800, 632),
  '770x553': Size(770, 553), // the owner's Mac window
  '412x915': Size(412, 915), // Edge 60 Fusion portrait
  '390x844': Size(390, 844), // phone portrait
};

bool _portrait(Size s) => s.width < ControlLayout.landscapeMinWidth;

/// The STOP label is one line and fits its button.
void _expectOneLine(WidgetTester tester, Finder label, Finder button) {
  expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines, isFalse);
  final text = tester.getRect(label);
  expect(text.height, lessThan(text.width), reason: 'wider than high: one line, not "STO" / "P"');
  final box = tester.getRect(button);
  expect(box.contains(text.topLeft) && box.contains(text.bottomRight), isTrue, reason: 'the label fits the button');
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    stubGemma();
    if (_savePngs) await loadFonts();
  });

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    for (final link in ControlLink.values) {
      for (final dark in [false, true]) {
        for (final quiz in [Quiz.none, Quiz.open]) {
          for (final stopped in [false, true]) {
            final label =
                '$name ${link.name} ${dark ? 'dark' : 'light'}'
                '${quiz == Quiz.open ? ', quiz open' : ''}${stopped ? ', STOPPED' : ''}';
            testWidgets('$label: no overflow, STOP one tap, quiz reachable', (tester) async {
              final rig = await pumpControl(tester, size, link: link, dark: dark, quiz: quiz, stopped: stopped);
              expect(tester.takeException(), isNull);
              if (_savePngs && quiz == Quiz.none) {
                await savePng(
                  tester,
                  'docs/test-results/r2/widget',
                  '$name-${link.name}-${dark ? 'dark' : 'light'}${stopped ? '-stopped' : ''}',
                );
              }
              if (!_portrait(size)) {
                expect(
                  find.ancestor(of: find.byType(DriveJoystick), matching: find.byType(Scrollable)),
                  findsNothing,
                  reason: 'landscape fits without scrolling at $name',
                );
              }

              if (quiz == Quiz.open) {
                // The R3 popup's compact STOP (decision 0175).
                final quizStop = find.byKey(const ValueKey('quiz_stop'));
                expectOnScreen(tester, quizStop, size, 'quiz-header STOP');
                _expectOneLine(tester, find.descendant(of: quizStop, matching: find.text('STOP')), quizStop);
                expectTappable(tester, find.byKey(const ValueKey('quiz_close')), 'quiz close (X)');
                expectTappable(tester, find.byKey(const ValueKey('quiz_minimise')), 'quiz minimise');
                await tester.tap(quizStop);
                await tester.pump();
                expect(taps['quiz stop'], 1, reason: 'one tap on the quiz STOP');
                return;
              }

              // STOP: on screen before any scrolling, on top, 64 dp or more, one tap.
              final stop = find.byType(EmergencyStopButton);
              final stopCircle = find.descendant(of: stop, matching: find.byType(InkWell));
              expectOnScreen(tester, stopCircle, size, 'STOP');
              expectTappable(tester, stopCircle, 'STOP');
              expect(tester.getSize(stopCircle).shortestSide, greaterThanOrEqualTo(EmergencyStopButton.minSize));
              expect(
                find.ancestor(of: stop, matching: find.byType(Opacity)),
                findsNothing,
                reason: 'STOP is never dimmed',
              );
              _expectOneLine(tester, find.descendant(of: stop, matching: find.text('STOP')), stopCircle);
              await tester.tap(stopCircle);
              await tester.pump();
              expect(taps['stop'], 1, reason: 'one tap on STOP');
              expect(rig.gate.stopped, isTrue);
              if (link == ControlLink.connected) {
                expect(rig.robot.commands.take(2), ['STOP', 'motor 0,0'], reason: 'STOP, then motor 0,0');
              }
              await tester.pump(const Duration(milliseconds: 500));

              // Camera, joystick, arm faders and power stay on screen in landscape.
              if (!_portrait(size)) {
                for (final (f, what) in [
                  (find.byKey(const ValueKey('control_camera')), 'camera'),
                  (find.byType(DriveJoystick), 'joystick'),
                  (find.byKey(const ValueKey('height_fader')), 'height fader'),
                  (find.byKey(const ValueKey('reach_fader')), 'reach fader'),
                  (find.byKey(const ValueKey('robot_power')), 'power'),
                ]) {
                  expectOnScreen(tester, f, size, what);
                }
              }
              if (stopped) {
                await tester.tap(find.text('Continue'));
                await tester.pump();
                expect(taps['resume'], 1, reason: 'one tap on Lanjutkan');
              }
              if (link == ControlLink.disconnected) {
                expect(find.text('Reconnect now'), findsOneWidget);
                expect(find.textContaining('of 30'), findsOneWidget, reason: 'the real attempt cap, not Figma\'s');
              }
              if (link == ControlLink.waiting) expect(find.text('Looking for MaixCAM2...'), findsOneWidget);
            });
          }
        }
      }
    }
  }

  // Every control one tap away, connected, at every size (light).
  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    for (final quiz in Quiz.values) {
      testWidgets('$name connected, quiz ${quiz.name}: every control reachable', (tester) async {
        final rig = await pumpControl(tester, size, quiz: quiz);
        if (quiz == Quiz.open) {
          // Minimise, then the yellow button brings it back.
          await tester.tap(find.byKey(const ValueKey('quiz_minimise')));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.ensureVisible(find.byTooltip('Open quiz'));
          await tester.pump();
          expectTappable(tester, find.byTooltip('Open quiz'), 'yellow quiz button');
          await tester.tap(find.byTooltip('Open quiz'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byTooltip('Open quiz'), findsNothing, reason: 'no quiz button while the quiz is open');
          expectTappable(tester, find.byKey(const ValueKey('quiz_close')), 'quiz reopened');
          await tester.pump(const Duration(seconds: 2)); // tooltip timers
          return;
        }
        Future<void> tapOnce(Finder f, String what) async {
          await tester.ensureVisible(f);
          await tester.pump();
          expectTappable(tester, f, what);
          await tester.tap(f);
          await tester.pump();
          expect(taps[what], 1, reason: 'one tap on $what');
        }

        final joy = find.byType(DriveJoystick);
        await tester.ensureVisible(joy);
        await tester.pump();
        final g = await tester.startGesture(tester.getCenter(joy));
        await g.moveBy(const Offset(0, -60));
        await tester.pump(const Duration(milliseconds: 300));
        await g.up();
        await tester.pump(const Duration(milliseconds: 500));
        expect((taps['drive'], taps['wheels stop']), (1, 1), reason: 'the joystick took the push and the let go');
        final m = motors(rig);
        expect(m, isNotEmpty);
        expect(m.every((lr) => lr.$1 == lr.$2 && lr.$1 >= 0), isTrue, reason: 'straight forward only: $m');
        expect(m.last, (0, 0), reason: 'ramps down to 0,0 after let go');
        await tapOnce(find.byKey(const ValueKey('height_fader')), 'height');
        await tapOnce(find.byKey(const ValueKey('reach_fader')), 'reach');
        await tapOnce(find.byKey(const ValueKey('speed_fader')), 'speed');
        await tapOnce(find.byKey(const ValueKey('gripper_fader')), 'width');
        await tapOnce(find.text('PICK UP'), 'pick up');
        await tapOnce(find.text('RELEASE'), 'release');
        await tapOnce(find.text('Exit'), 'exit');
        await tapOnce(find.text('Debug Scan'), 'debug');
        await tapOnce(find.byTooltip('Open profile menu'), 'avatar');
        await tester.ensureVisible(find.byType(HomeButton));
        expectTappable(tester, find.byType(HomeButton), 'HOME');
        await tester.ensureVisible(find.text('History'));
        await tester.pump();
        expectTappable(tester, find.text('History'), 'History');
        await tapOnce(find.byKey(const ValueKey('robot_power')), 'power');
        if (quiz == Quiz.minimised) {
          await tester.ensureVisible(find.byTooltip('Open quiz'));
          expectTappable(tester, find.byTooltip('Open quiz'), 'yellow quiz button');
        } else {
          expect(find.byTooltip('Open quiz'), findsNothing, reason: 'no quiz button without a minimised quiz');
        }
        await tester.pump(const Duration(seconds: 2)); // tooltip timers
      });
    }
  }

  for (final link in [ControlLink.waiting, ControlLink.disconnected]) {
    for (final stopped in [false, true]) {
      testWidgets('${link.name}${stopped ? ', STOPPED' : ''}: motion controls send nothing; STOP still works', (
        tester,
      ) async {
        final rig = await pumpControl(tester, const Size(1366, 768), link: link, stopped: stopped);
        final g = await tester.startGesture(tester.getCenter(find.byType(DriveJoystick)));
        await g.moveBy(const Offset(0, -80));
        await g.up();
        for (final f in [
          find.byKey(const ValueKey('height_fader')),
          find.byKey(const ValueKey('reach_fader')),
          find.byKey(const ValueKey('speed_fader')),
          find.byKey(const ValueKey('gripper_fader')),
          find.byKey(const ValueKey('gear_50')),
          find.text('PICK UP'),
          find.text('RELEASE'),
        ]) {
          await tester.tap(f, warnIfMissed: false);
        }
        await tester.longPress(find.byType(HomeButton), warnIfMissed: false);
        await tester.pump(const Duration(seconds: 2));
        expect(taps, isEmpty, reason: 'no handler ran');
        expect(rig.robot.commands, isEmpty, reason: 'zero commands reached the fake robot');
        final c = ProviderScope.containerOf(tester.element(find.byType(ControlLayout)));
        expect(c.read(robotControlProvider).pwmSpeed, 75, reason: 'the gear chip did nothing');
        for (final f in [find.byType(DriveJoystick), find.byKey(const ValueKey('height_fader'))]) {
          expect(
            tester.widget<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)).first).opacity,
            lessThan(1),
            reason: 'dimmed',
          );
        }
        await tester.tap(find.descendant(of: find.byType(EmergencyStopButton), matching: find.byType(InkWell)));
        await tester.pump();
        expect(taps['stop'], 1, reason: 'STOP stays live');
        expect(rig.gate.stopped, isTrue);
      });
    }
  }

  group('joystick', () {
    testWidgets('a tiny wobble inside the dead zone sends nothing, not even 0,0', (tester) async {
      final rig = await pumpControl(tester, const Size(1366, 768));
      final g = await tester.startGesture(tester.getCenter(find.byType(DriveJoystick)));
      await g.moveBy(const Offset(2, -2));
      await tester.pump(const Duration(milliseconds: 500));
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(rig.robot.commands, isEmpty);
    });

    // A full push in each direction, held 1 s, then let go (0231).
    for (final (name, push, steady) in [
      ('forward', const Offset(0, -200), (75, 75)),
      ('back', const Offset(0, 200), (-75, -75)),
      ('left', const Offset(-200, 0), (-45, 45)), // turn gain 0.6
      ('right', const Offset(200, 0), (45, -45)),
    ]) {
      testWidgets('$name: eases up to $steady, eases down to 0,0, then silence', (tester) async {
        final rig = await pumpControl(tester, const Size(1366, 768));
        final g = await tester.startGesture(tester.getCenter(find.byType(DriveJoystick)));
        await g.moveBy(push);
        await tester.pump(const Duration(seconds: 1));
        final held = motors(rig);
        expect(held.last, steady);
        expect(held.first.$1.abs(), lessThan(steady.$1.abs()), reason: 'no jump to full speed: $held');
        await g.up();
        await tester.pump(const Duration(milliseconds: 250));
        final all = motors(rig);
        expect(all.last, (0, 0));
        expect(all.length - held.length, lessThanOrEqualTo(4), reason: 'stops within 4 ticks');
        await tester.pump(const Duration(milliseconds: 500));
        expect(motors(rig).length, all.length, reason: 'nothing more once stopped');
      });
    }

    testWidgets('reversing brakes to 0 before driving the other way', (tester) async {
      final rig = await pumpControl(tester, const Size(1366, 768));
      final g = await tester.startGesture(tester.getCenter(find.byType(DriveJoystick)));
      await g.moveBy(const Offset(0, -200));
      await tester.pump(const Duration(seconds: 1));
      await g.moveBy(const Offset(0, 400));
      await tester.pump(const Duration(seconds: 1));
      final v = [for (final m in motors(rig)) m.$1];
      final firstBack = v.indexWhere((x) => x < 0);
      expect(v[firstBack - 1], 0, reason: 'passes through 0: $v');
      expect(v.last, -75);
    });

    testWidgets('STOPPED: the joystick sends no drive command (break-check target)', (tester) async {
      final rig = await pumpControl(tester, const Size(1366, 768), stopped: true);
      final before = motors(rig).length;
      final g = await tester.startGesture(tester.getCenter(find.byType(DriveJoystick)));
      await g.moveBy(const Offset(0, -80));
      await tester.pump(const Duration(milliseconds: 500));
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(motors(rig).skip(before).where((m) => m != (0, 0)), isEmpty);
    });

    testWidgets('a gear chip sets the speed the joystick drives at; the fader still sets any value', (tester) async {
      final rig = await pumpControl(tester, const Size(1366, 768));
      await tester.tap(find.byKey(const ValueKey('gear_50')));
      await tester.pump();
      final c = ProviderScope.containerOf(tester.element(find.byType(ControlLayout)));
      expect(c.read(robotControlProvider).pwmSpeed, 50);
      final g = await tester.startGesture(tester.getCenter(find.byType(DriveJoystick)));
      await g.moveBy(const Offset(0, -200));
      await tester.pump(const Duration(seconds: 1));
      expect(motors(rig).last, (50, 50), reason: 'a full push drives at the gear');
      await g.up();
      await tester.pump(const Duration(milliseconds: 500));
      c.read(robotControlProvider.notifier).setPwmSpeed(63);
      await tester.pump();
      expect(find.text('63%'), findsOneWidget);
      for (final gear in speedGears) {
        expect(
          tester
              .widget<Semantics>(
                find.ancestor(of: find.byKey(ValueKey('gear_$gear')), matching: find.byType(Semantics)).first,
              )
              .properties
              .selected,
          isFalse,
        );
      }
    });
  });

  testWidgets('STOPPED: the open quiz stays usable (answer, then close with X)', (tester) async {
    await pumpControl(tester, const Size(800, 632), quiz: Quiz.open, stopped: true);
    final container = ProviderScope.containerOf(tester.element(find.byType(WasteQuizPopup)));
    await tester.tap(find.text('Dibilas lalu dikeringkan'));
    await tester.pump();
    expect(container.read(wasteQuizProvider).selectedOption, isNotNull, reason: 'answering is not motion');
    await tester.tap(find.byKey(const ValueKey('quiz_close')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(wasteQuizProvider).phase, WasteQuizPhase.idle);
  });

  testWidgets('release build: no Debug Scan', (tester) async {
    await pumpControl(tester, const Size(1366, 768), debugBuild: false);
    expect(find.text('Debug Scan'), findsNothing);
    expect(find.text('History'), findsOneWidget);
  });
}
