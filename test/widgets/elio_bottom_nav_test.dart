import 'dart:ui' show Tristate;

import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/elio_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/auth_test_support.dart';

/// ELIOS 3 bottom nav (Figma 270:5746). Visual order: Home, Learn, Scan,
/// History, Profile; provider indices 0, 1, 2, 4, 5.
Future<List<int>> _pump(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  double textScale = 1,
  int current = 0,
  String? initials = 'BA',
}) async {
  final tabs = <int>[];
  await pumpAt(
    t,
    ElioTheme.wrap(
      Scaffold(
        floatingActionButtonLocation: const ElioControlFabLocation(),
        floatingActionButton: ElioScanOrb(onTap: () => tabs.add(2)),
        bottomNavigationBar: ElioBottomNav(
          currentIndex: current,
          onSelectTab: tabs.add,
          initials: initials,
        ),
      ),
    ),
    size: size,
    brightness: brightness,
    textScale: textScale,
  );
  await t.pump(const Duration(milliseconds: 50));
  return tabs;
}

const _labels = ['Home', 'Learn', 'Scan', 'History', 'Profile'];

void main() {
  setUpAll(loadElioFonts);

  for (final b in Brightness.values) {
    testWidgets('${b.name}: order, taps, the orb opens Scan', (t) async {
      final tabs = await _pump(t, brightness: b, current: 2);
      final x = {for (final l in _labels) l: t.getCenter(find.text(l)).dx};
      final order = x.keys.toList()..sort((a, b) => x[a]!.compareTo(x[b]!));
      expect(order, _labels);

      for (final l in _labels) {
        await t.tap(find.text(l));
      }
      expect(tabs, [0, 1, 2, 4, 5]);
      await t.tapAt(t.getCenter(find.byIcon(Icons.crop_free_rounded)));
      expect(tabs.last, 2);

      // Scan (the centre tab) is selected; there is no Config or Control.
      final sem = t.getSemantics(
        find.bySemanticsLabel('Scan, opens the scan hub'),
      );
      expect(sem.flagsCollection.isButton, isTrue);
      expect(sem.flagsCollection.isSelected, Tristate.isTrue);
      expect(find.text('Config'), findsNothing);
      expect(find.text('Control'), findsNothing);
      expect(find.bySemanticsLabel('Main'), findsOneWidget);
    });
  }

  testWidgets('Profile 5 is active; avatar shows initials, else guest icon', (
    t,
  ) async {
    await _pump(t, current: 5);
    expect(
      t
          .getSemantics(find.bySemanticsLabel('Profile'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(find.text('BA'), findsOneWidget);

    await _pump(t, initials: null);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
  });

  testWidgets('320 wide, text 1.3: 48 dp targets, one-line labels', (t) async {
    await _pump(t, size: const Size(320, 700), textScale: 1.3);
    for (final l in _labels) {
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
