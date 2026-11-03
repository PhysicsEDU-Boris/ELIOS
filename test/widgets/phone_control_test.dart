// R3 phone Control: layout states at 3 phone sizes in light and dark, and the
// gate rules (GO sends nothing, offline sends nothing). Decision 0174.
import 'package:elio/models/control_session.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/widgets/waste_quiz_popup.dart' show EliosAiBadge;
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

      // Every quiz popup state: no overflow, and the compact STOP is in the header (or the skeleton).
      final popups = <String, WasteQuizUiState>{
        'quiz_question': openQuiz,
        'quiz_loading': loading(),
        'quiz_identifying': loading(identifying: true),
        'quiz_skeleton': skeletonQuiz,
        'quiz_essay_input': essayInput(),
        'quiz_right': explaining(right: true),
        'quiz_wrong': explaining(right: false),
        'quiz_wrong_no_why': explaining(right: false, why: false),
        'quiz_essay': explainingEssay(),
        'quiz_essay_pending': explainingEssay(pending: true),
        'quiz_long_text': explaining(right: true, long: true),
      };
      for (final e in popups.entries) {
        testWidgets('${e.key} $tag', (t) async {
          await pumpPhone(t, size, dark: dark, quiz: e.value);
          await t.pump(const Duration(milliseconds: 50));
          expect(t.takeException(), isNull);
          expectTappable(t, find.byKey(const ValueKey('quiz_stop')), 'compact STOP');
          await shot(t, e.key, size, dark);
        });
      }

      for (final step in [0, 2, 4]) {
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

  group('q3 popups (decision 0175)', () {
    const size = Size(915, 412);

    testWidgets('wrong answer with a reviewed wrongWhy shows both headings; struck-through pick; options table', (t) async {
      await pumpPhone(t, size, quiz: explaining(right: false));
      expect(find.text('Not quite'), findsOneWidget);
      expect(find.text('Why your answer is not right'), findsOneWidget);
      expect(find.text('Why the correct answer is right'), findsOneWidget);
      expect(find.text('Table 1. The answer options'), findsOneWidget);
      expect(find.text('Your answer'), findsOneWidget);
      expect(find.text('Correct answer'), findsOneWidget);
      final picked = t.widget<Text>(find.text('Organik bin').first);
      expect(picked.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('wrong answer without wrongWhy hides that heading (no generic sentence)', (t) async {
      await pumpPhone(t, size, quiz: explaining(right: false, why: false));
      expect(find.text('Why your answer is not right'), findsNothing);
      expect(find.text('Why the correct answer is right'), findsOneWidget);
    });

    testWidgets('right answer: bin reference table, quote with section and page, bank source', (t) async {
      await pumpPhone(t, size, quiz: explaining(right: true));
      expect(find.text('Correct!'), findsOneWidget);
      expect(find.textContaining('Table 1. Where'), findsOneWidget);
      expect(find.text('ELIOS module · section 4.2 · page 21'), findsOneWidget);
      expect(find.text('Reviewed question bank'), findsOneWidget);
      expect(find.text('plastic-mc-04'), findsOneWidget);
      expect(find.text('ELIOS'), findsNothing); // no logo in the review header
    });

    testWidgets('essay: score banner, scoring table, AI graded source; pending is grey +0', (t) async {
      await pumpPhone(t, size, quiz: explainingEssay());
      expect(find.text('Score 8 / 10'), findsOneWidget);
      expect(find.text('Table 1. Scoring breakdown'), findsOneWidget);
      expect(find.text('AI graded · check with your teacher'), findsOneWidget);
    });

    testWidgets('essay pending: grey Waiting for grading, +0', (t) async {
      await pumpPhone(t, size, quiz: explainingEssay(pending: true));
      expect(find.byKey(const ValueKey('banner_pending')), findsOneWidget);
      expect(find.text('Waiting for grading'), findsOneWidget);
      expect(find.text('+0'), findsOneWidget);
    });

    testWidgets('long text scrolls inside the document, not the popup', (t) async {
      await pumpPhone(t, size, quiz: explaining(right: true, long: true));
      final doc = find.byKey(const ValueKey('quiz_document'));
      final popupBefore = t.getRect(find.byKey(const ValueKey('quiz_popup')));
      final scroll = t.widget<SingleChildScrollView>(find.descendant(of: doc, matching: find.byType(SingleChildScrollView)));
      expect(scroll.controller!.position.maxScrollExtent, greaterThan(0));
      await t.drag(doc, const Offset(0, -400));
      await t.pump();
      expect(scroll.controller!.offset, greaterThan(0));
      expect(t.getRect(find.byKey(const ValueKey('quiz_popup'))), popupBefore);
    });

    testWidgets('question popup keeps its ELIOS header', (t) async {
      await pumpPhone(t, size, quiz: openQuiz);
      expect(find.text('ELIOS'), findsOneWidget);
    });

    testWidgets('loading: real timer, steps, Minimise puts the Quiz button into Waiting', (t) async {
      await pumpPhone(t, size, quiz: loading());
      expect(find.byKey(const ValueKey('quiz_loading_timer')), findsOneWidget);
      expect(find.text('Read the scan'), findsOneWidget);
      expect(find.text('Writing the question'), findsOneWidget);
      expect(find.text('Checking the answer'), findsNothing); // no such event in the code
      await t.tap(find.byKey(const ValueKey('quiz_loading_minimise')));
      await t.pump();
      expect(find.byKey(const ValueKey('quiz_loading')), findsNothing);
      expect(find.byKey(const ValueKey('quiz_button_waiting')), findsOneWidget);
    });

    for (final (name, q) in [('loading', loading()), ('skeleton', skeletonQuiz), ('review', explaining(right: true))]) {
      testWidgets('STOP works from the $name popup', (t) async {
        final rig = await pumpPhone(t, size, quiz: q);
        await t.tap(find.byKey(const ValueKey('quiz_stop')));
        await t.pump();
        expect(rig.gate.stopped, isTrue);
        await t.pump(const Duration(seconds: 1));
      });
    }
  });
}
