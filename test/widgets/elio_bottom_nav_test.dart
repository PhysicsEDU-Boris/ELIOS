import 'dart:ui' show Tristate;

import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/elio_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/auth_test_support.dart';

/// N3 bottom nav. Visual order: Home, Learn, Control, Config, History.
class _Calls {
  final tabs = <int>[];
  int control = 0;
}

Future<_Calls> _pump(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  double textScale = 1,
  int current = 0,
}) async {
  final c = _Calls();
  await pumpAt(
    t,
    ElioTheme.wrap(
      Scaffold(
        floatingActionButtonLocation: const ElioControlFabLocation(),
        floatingActionButton: ElioControlButton(onTap: () => c.control++),
        bottomNavigationBar: ElioBottomNav(
          currentIndex: current,
          onSelectTab: c.tabs.add,
          onControl: () => c.control++,
        ),
      ),
    ),
    size: size,
    brightness: brightness,
    textScale: textScale,
  );
  await t.pump(const Duration(milliseconds: 50));
  return c;
}

void main() {
  setUpAll(loadElioFonts);

  for (final b in Brightness.values) {
    testWidgets('${b.name}: order, taps, Control never selected', (t) async {
      final c = await _pump(t, brightness: b, current: 2);
      final x = {
        for (final l in ['Home', 'Learn', 'Control', 'Config', 'History'])
          l: t.getCenter(find.text(l)).dx,
      };
      final order = x.keys.toList()..sort((a, b) => x[a]!.compareTo(x[b]!));
      expect(order, ['Home', 'Learn', 'Control', 'Config', 'History']);

      await t.tap(find.text('Home'));
      await t.tap(find.text('Learn'));
      await t.tap(find.text('Config'));
      expect(c.tabs, [0, 1, 2]);

      await t.tap(find.text('Control'));
      await t.tapAt(t.getCenter(find.byIcon(Icons.smart_toy)));
      expect(c.control, 2);
      expect(c.tabs.length, 3);
      await t.tap(find.text('History'));
      expect(c.tabs, [0, 1, 2, 4]);

      // Config is selected; Control never is.
      final sem = t.getSemantics(find.bySemanticsLabel('Config'));
      expect(sem.flagsCollection.isButton, isTrue);
      expect(sem.flagsCollection.isSelected, Tristate.isTrue);
      expect(
        t
            .getSemantics(find.bySemanticsLabel('Control, opens robot control'))
            .flagsCollection
            .isSelected,
        isNot(Tristate.isTrue),
      );
      expect(find.bySemanticsLabel('Main'), findsOneWidget);
      expect(find.bySemanticsLabel('History'), findsOneWidget);
    });
  }

  testWidgets('History 4 is the active tab with the stroke', (t) async {
    await _pump(t, current: 4);
    final sem = t.getSemantics(find.bySemanticsLabel('History'));
    expect(sem.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('320 wide, text 1.3: 48 dp targets, one-line labels', (t) async {
    await _pump(t, size: const Size(320, 700), textScale: 1.3);
    for (final l in ['Home', 'Learn', 'Control', 'Config', 'History']) {
      final cell = find.ancestor(
        of: find.text(l),
        matching: find.byType(InkWell),
      );
      expect(t.getSize(cell.first).width, greaterThanOrEqualTo(48));
      expect(t.getSize(cell.first).height, greaterThanOrEqualTo(48));
      expect(t.getSize(find.text(l)).height, lessThan(30));
    }
    expect(t.takeException(), isNull);
  });
}
