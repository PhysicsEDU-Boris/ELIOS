// R3 phone Control: layout states at 3 phone sizes in light and dark, and the
// gate rules (GO sends nothing, offline sends nothing). Decision 0174.
import 'package:elio/models/control_session.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/widgets/control/phone/phone_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'phone_harness.dart';

const _pngDir = String.fromEnvironment('R3_PNG');

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadFonts(); // real glyph widths, not the test font's boxes
  });
  setUp(stubGemma);

  Future<void> shot(WidgetTester t, String name, Size s, bool dark) async {
    if (_pngDir.isEmpty) return;
    await savePng(
      t,
      _pngDir,
      '${name}_${s.width.toInt()}x${s.height.toInt()}_${dark ? 'dark' : 'light'}',
    );
  }

  /// STOP (or GO in its place) is on screen and not dimmed.
  void expectStopReachable(WidgetTester t, Size s) {
    expect(find.byKey(const ValueKey('phone_stop')), findsOneWidget);
    expectOnScreen(t, find.byKey(const ValueKey('phone_stop')), s, 'STOP');
  }

  for (final size in phoneSizes) {
    for (final dark in [false, true]) {
      final tag =
          '${size.width.toInt()}x${size.height.toInt()} ${dark ? 'dark' : 'light'}';

      testWidgets('driving $tag', (t) async {
        await pumpPhone(t, size, dark: dark);
        expect(t.takeException(), isNull);
        expectStopReachable(t, size);
        expect(find.text('Robot Control'), findsOneWidget);
        expect(find.text('Resume driving'), findsNothing);
        expect(find.text('Lanjutkan'), findsNothing);
        await shot(t, 'driving', size, dark);
      });

      testWidgets('offline $tag', (t) async {
        await pumpPhone(
          t,
          size,
          dark: dark,
          link: ControlLink.disconnected,
          stopped: true,
        );
        expect(t.takeException(), isNull);
        expectStopReachable(t, size); // STOP, never GO, with no link
        expect(find.text('Robot offline'), findsOneWidget);
        expect(find.byKey(const ValueKey('phone_connect')), findsOneWidget);
        await shot(t, 'offline', size, dark);
      });

      testWidgets('waiting $tag', (t) async {
        await pumpPhone(t, size, dark: dark, link: ControlLink.waiting);
        expect(t.takeException(), isNull);
        expectStopReachable(t, size);
        await shot(t, 'waiting', size, dark);
      });

      testWidgets('stopped shows GO $tag', (t) async {
        await pumpPhone(t, size, dark: dark, stopped: true);
        expect(t.takeException(), isNull);
        expect(find.byKey(const ValueKey('phone_go')), findsOneWidget);
        expect(find.byKey(const ValueKey('phone_stop')), findsNothing);
        expect(find.text('Robot stopped · scanning paused'), findsOneWidget);
        expectOnScreen(t, find.byKey(const ValueKey('phone_go')), size, 'GO');
        await shot(t, 'stopped', size, dark);
      });

      testWidgets('skeleton $tag', (t) async {
        await pumpPhone(t, size, dark: dark, skeleton: true);
        expect(t.takeException(), isNull);
        expectStopReachable(t, size);
        await shot(t, 'skeleton', size, dark);
      });

      testWidgets('quiz question $tag', (t) async {
        await pumpPhone(t, size, dark: dark, quiz: openQuiz);
        expect(t.takeException(), isNull);
        await shot(t, 'quiz_question', size, dark);
      });

      testWidgets('quiz explanation right $tag', (t) async {
        await pumpPhone(t, size, dark: dark, quiz: explaining(right: true));
        expect(t.takeException(), isNull);
        await shot(t, 'quiz_right', size, dark);
      });

      testWidgets('quiz explanation wrong $tag', (t) async {
        await pumpPhone(t, size, dark: dark, quiz: explaining(right: false));
        expect(t.takeException(), isNull);
        await shot(t, 'quiz_wrong', size, dark);
      });

      testWidgets('quiz explanation essay $tag', (t) async {
        await pumpPhone(t, size, dark: dark, quiz: explainingEssay());
        expect(t.takeException(), isNull);
        await shot(t, 'quiz_essay', size, dark);
      });

      for (final step in [0, 4]) {
        testWidgets('guide step ${step + 1} $tag', (t) async {
          await pumpPhone(t, size, dark: dark, guideStep: step);
          await t.pump(const Duration(milliseconds: 100));
          expect(t.takeException(), isNull);
          expect(
            find.byKey(ValueKey('guide_step_${step + 1}')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('guide_stop')),
            findsOneWidget,
          ); // STOP reachable under the guide
          await shot(t, 'guide${step + 1}', size, dark);
        });
      }
    }
  }

  group('gate rules', () {
    const size = Size(915, 412);

    testWidgets('GO clears STOPPED and sends no motion command', (t) async {
      final rig = await pumpPhone(t, size, stopped: true);
      await t.tap(find.byKey(const ValueKey('phone_go')));
      await t.pump();
      expect(rig.gate.stopped, isFalse);
      expect(taps['go'], 1);
      expect(
        rig.robot.commands.where(
          (c) => c.startsWith('motor') || c.startsWith('servo') || c == 'DRIVE',
        ),
        isEmpty,
      );
      expect(
        find.byKey(const ValueKey('phone_stop')),
        findsOneWidget,
      ); // back to STOP
    });

    testWidgets('STOP then GO then STOP', (t) async {
      final rig = await pumpPhone(t, size);
      await t.tap(find.byKey(const ValueKey('phone_stop')));
      await t.pump();
      expect(rig.gate.stopped, isTrue);
      await t.tap(find.byKey(const ValueKey('phone_go')));
      await t.pump();
      expect(rig.gate.stopped, isFalse);
      await t.tap(find.byKey(const ValueKey('phone_stop')));
      await t.pump();
      expect(rig.gate.stopped, isTrue);
      await t.pump(const Duration(seconds: 1)); // the stop repeats
    });

    testWidgets('offline: controls press and send zero commands', (t) async {
      final rig = await pumpPhone(t, size, link: ControlLink.disconnected);
      await t.tap(find.byKey(const ValueKey('toggle_Voice')));
      await t.tap(find.text('PICK UP'));
      await t.tap(find.text('RELEASE'));
      await t.tap(find.byKey(const ValueKey('gear_100')));
      await t.drag(
        find.byKey(const ValueKey('joystick_knob')),
        const Offset(0, -60),
      );
      await t.pump();
      expect(rig.robot.sent, isEmpty);
    });

    testWidgets(
      'joystick still works while STOPPED, and the gate drops the command',
      (t) async {
        final rig = await pumpPhone(t, size, stopped: true);
        final before = rig.gate.blocked;
        final g = await t.startGesture(
          t.getCenter(find.byKey(const ValueKey('joystick_knob'))),
        );
        await g.moveBy(const Offset(0, -50));
        await t.pump();
        expect(taps['drive'], 1); // the joystick took the touch
        expect(rig.gate.blocked, greaterThan(before)); // the gate refused it
        await g.up();
        expect(
          rig.robot.commands.where(
            (c) => c.startsWith('motor') && c != 'motor 0,0',
          ),
          isEmpty,
        );
      },
    );

    testWidgets(
      'top bar: no Resume button and no ELIOS badge beside Robot Control',
      (t) async {
        await pumpPhone(t, size, stopped: true);
        expect(find.textContaining('Resume'), findsNothing);
        expect(find.textContaining('Lanjutkan'), findsNothing);
        expect(
          find.byType(EliosAiBadge),
          findsNothing,
        ); // only the Quiz button carries it
      },
    );

    testWidgets('quiz button shows the badge only with a quiz', (t) async {
      await pumpPhone(t, size, quiz: openQuiz);
      expect(find.byKey(const ValueKey('phone_quiz')), findsOneWidget);
      expect(find.byType(EliosAiBadge), findsWidgets);
    });

    testWidgets('quiz hidden when there is no quiz', (t) async {
      await pumpPhone(t, size, quiz: const WasteQuizUiState());
      expect(find.byKey(const ValueKey('phone_quiz')), findsNothing);
    });

    testWidgets('nothing on top of the video', (t) async {
      await pumpPhone(t, size);
      final video = find.byKey(const ValueKey('phone_video'));
      expect(
        find.descendant(of: video, matching: find.byType(CustomPaint)),
        findsNothing,
      );
    });
  });
}
