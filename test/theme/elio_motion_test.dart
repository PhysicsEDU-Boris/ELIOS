// ELIOS 3 motion (decision 0202): springs, entrances, count-up, sliding
// stroke and pill, and reduced motion.
import 'package:elio/Screens/config/config_settings_sheet.dart';
import 'package:elio/theme/elio_motion.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/elio_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/auth_test_support.dart';

double _peak(Curve c) {
  var max = 0.0;
  for (var i = 0; i <= 100; i++) {
    final v = c.transform(i / 100);
    if (v > max) max = v;
  }
  return max;
}

void main() {
  test('springs end at rest; overshoot grows soft < pop < bounce', () {
    for (final c in [ElioMotion.soft, ElioMotion.pop, ElioMotion.bounce]) {
      expect(c.transform(0), 0);
      expect(c.transform(1), 1);
    }
    final soft = _peak(ElioMotion.soft);
    final pop = _peak(ElioMotion.pop);
    final bounce = _peak(ElioMotion.bounce);
    expect(soft, lessThan(pop));
    expect(pop, lessThan(bounce));
    expect(bounce, greaterThan(1.15), reason: '≈ 25 % overshoot');
    expect(soft, lessThan(1.1), reason: '≈ 5 % overshoot');
  });

  Widget app(Widget child, {bool reduced = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  double opacityOf(WidgetTester t) => t
      .widget<Opacity>(
        find.ancestor(of: find.text('hi'), matching: find.byType(Opacity)),
      )
      .opacity;

  testWidgets('pop-in waits for its stagger, then settles opaque', (t) async {
    await t.pumpWidget(app(const ElioPopIn(index: 2, child: Text('hi'))));
    expect(opacityOf(t), 0);
    await t.pump(const Duration(milliseconds: 60));
    expect(opacityOf(t), 0, reason: 'still inside the 80 ms stagger');
    await t.pumpAndSettle();
    expect(opacityOf(t), 1);
  });

  testWidgets('reduced motion: a plain 150 ms fade, no movement', (t) async {
    await t.pumpWidget(
      app(const ElioPopIn(index: 5, child: Text('hi')), reduced: true),
    );
    expect(
      find.descendant(
        of: find.byType(ElioPopIn),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    await t.pump(); // starts after the first frame
    await t.pump(const Duration(milliseconds: 160));
    expect(opacityOf(t), 1);
  });

  testWidgets('count-up runs to the value; reduced motion shows it at once', (
    t,
  ) async {
    Widget count() => ElioCountUp(value: 46, builder: (_, v) => Text('$v'));
    await t.pumpWidget(app(count()));
    expect(find.text('46'), findsNothing);
    await t.pumpAndSettle();
    expect(find.text('46'), findsOneWidget);
    await t.pumpWidget(app(count(), reduced: true));
    expect(find.text('46'), findsOneWidget);
  });

  testWidgets('nav: one stroke slides to the tab; hidden on Scan', (t) async {
    Future<void> show(int i) => pumpAt(
      t,
      ElioTheme.wrap(
        Scaffold(
          bottomNavigationBar: ElioBottomNav(
            currentIndex: i,
            onSelectTab: (_) {},
          ),
        ),
      ),
      brightness: Brightness.light,
    );
    AnimatedAlign stroke() => t.widget<AnimatedAlign>(
      find.descendant(
        of: find.byType(ElioBottomNav),
        matching: find.byType(AnimatedAlign),
      ),
    );
    await show(0);
    expect((stroke().alignment as Alignment).x, -1);
    await show(5);
    expect((stroke().alignment as Alignment).x, 1, reason: 'Profile column');
    await show(2);
    final fade = t.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(ElioBottomNav),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(fade.opacity, 0, reason: 'the orb is the Scan mark');
  });

  testWidgets('segmented: the pill slides to the chosen option', (t) async {
    var chosen = '60s';
    await pumpAt(
      t,
      ElioTheme.wrap(
        StatefulBuilder(
          builder: (context, set) => Scaffold(
            body: ConfigSegmented(
              label: 'Timer',
              options: const ['30s', '60s', '90s', '120s'],
              selected: chosen,
              onSelected: (v) => set(() => chosen = v),
            ),
          ),
        ),
      ),
      brightness: Brightness.light,
    );
    double x() =>
        (t.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment
                as Alignment)
            .x;
    expect(x(), closeTo(-1 / 3, 1e-9));
    await t.tap(find.text('120s'));
    await t.pump();
    expect(x(), 1);
    await t.pumpAndSettle();
  });
}
