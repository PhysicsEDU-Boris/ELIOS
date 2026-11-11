// ELIOS 3 motion, part 2 (decision 0203): celebration rules and overlay,
// shake, idle hints, buddy jump, quiz answer feedback, theme reveal fallback.
import 'package:elio/Screens/home_screen.dart' show celebrationsDue;
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/theme/elio_motion.dart';
import 'package:elio/widgets/elio_celebration.dart';
import 'package:elio/widgets/elio_theme_reveal.dart';
import 'package:elio/widgets/learn/learn_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduced = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduced),
  child: MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

double _dx(WidgetTester t, Type of) => t
    .widget<Transform>(
      find
          .descendant(of: find.byType(of), matching: find.byType(Transform))
          .first,
    )
    .transform
    .getTranslation()
    .x;

void main() {
  setUpAll(() {
    ElioSound.instance
      ..sink = ((_, _) {})
      ..isSilent = (() async => true);
  });

  test('celebrate only real changes; a first run only records', () {
    expect(
      celebrationsDue(lastLevel: null, level: 4, lastMedals: null, medals: {0}),
      (levelUp: false, newMedals: const <int>[]),
    );
    final due = celebrationsDue(
      lastLevel: 3,
      level: 4,
      lastMedals: {0},
      medals: {0, 2},
    );
    expect(due.levelUp, isTrue);
    expect(due.newMedals, [2]);
    expect(
      celebrationsDue(
        lastLevel: 4,
        level: 4,
        lastMedals: {0},
        medals: null,
      ).newMedals,
      isEmpty,
      reason: 'medals not loaded yet',
    );
  });

  testWidgets('celebration shows the title, then closes by itself', (t) async {
    await t.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => ElioCelebration.show(
              context,
              art: const Icon(Icons.star),
              title: 'Level 5!',
              subtitle: 'Eco Hero',
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await t.tap(find.text('go'));
    await t.pump(const Duration(milliseconds: 700));
    expect(find.text('Level 5!'), findsOneWidget);
    expect(find.text('Eco Hero'), findsOneWidget);
    await t.pumpAndSettle(); // 2.4 s on screen + 150 ms fade, then gone
    expect(find.text('Level 5!'), findsNothing);
  });

  testWidgets('shake moves on a new trigger and comes back to rest', (t) async {
    Widget shake(Object? trigger) =>
        _app(ElioShake(trigger: trigger, child: const Text('a')));
    await t.pumpWidget(shake(null));
    await t.pumpWidget(shake('wrong'));
    await t.pump(const Duration(milliseconds: 40));
    expect(_dx(t, ElioShake).abs(), greaterThan(0.5));
    await t.pumpAndSettle();
    expect(_dx(t, ElioShake), closeTo(0, 0.01));
  });

  testWidgets('idle hint stops after its length; nothing with reduced motion', (
    t,
  ) async {
    final seen = <double>[];
    Widget loop({bool reduced = false}) => _app(
      ElioIdleLoop(
        length: const Duration(seconds: 2),
        period: const Duration(seconds: 1),
        builder: (_, w, _) {
          seen.add(w);
          return const SizedBox();
        },
      ),
      reduced: reduced,
    );
    await t.pumpWidget(loop());
    await t.pump(const Duration(milliseconds: 500));
    expect(seen.last, greaterThan(0.9), reason: 'mid-wave');
    await t.pumpAndSettle();
    expect(seen.last, 0, reason: 'rests after 2 s');
    seen.clear();
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(loop(reduced: true));
    await t.pump(const Duration(milliseconds: 500));
    expect(seen.every((w) => w == 0), isTrue);
  });

  testWidgets('buddy jump goes up and lands at rest', (t) async {
    Widget jump(Object? k) =>
        _app(ElioJump(trigger: k, child: const Text('bin')));
    await t.pumpWidget(jump(null));
    await t.pumpWidget(jump(1));
    await t.pump(const Duration(milliseconds: 100));
    expect(
      t
          .widget<Transform>(
            find.descendant(
              of: find.byType(ElioJump),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .getTranslation()
          .y,
      lessThan(-2),
    );
    await t.pumpAndSettle();
    expect(
      t
          .widget<Transform>(
            find.descendant(
              of: find.byType(ElioJump),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .getTranslation()
          .y,
      closeTo(0, 0.01),
    );
  });

  testWidgets('a wrong quiz answer shakes', (t) async {
    Widget option({required bool answered}) => _app(
      QuizAnswerOption(
        index: 0,
        label: 'Bakar',
        selected: true,
        isCorrect: false,
        answered: answered,
        onTap: () {},
      ),
    );
    await t.pumpWidget(option(answered: false));
    await t.pumpWidget(option(answered: true));
    await t.pump(const Duration(milliseconds: 40));
    expect(_dx(t, ElioShake).abs(), greaterThan(0.5));
    await t.pumpAndSettle();
  });

  test('theme reveal without a host just switches', () async {
    var switched = false;
    await ThemeSwitchReveal.run(Offset.zero, () => switched = true);
    expect(switched, isTrue);
  });
}
