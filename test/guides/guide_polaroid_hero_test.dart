// Owner video 2026-11-11 20:13: popping the guide issue page (or Daily
// Guides) showed "type 'GuidePolaroid' is not a subtype of type
// 'GuidePolaroidHero'" — the hero flight cast the Hero's child wrongly.
import 'package:elio/Screens/tabs/elearning/guides/guide_widgets.dart';
import 'package:elio/services/daily_guide_service.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'g4_fixture.dart' as g4;

void main() {
  testWidgets('polaroid hero flies on push and pop without a cast error', (
    tester,
  ) async {
    final guide = DailyGuide.parse(
      g4.manifest([g4.entry(g4.date, photo: false)]),
    ).single;
    Widget hero(double width, double angle) => Center(
      child: GuidePolaroidHero(
        polaroid: GuidePolaroid(guide: guide, width: width, angle: angle),
      ),
    );
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        builder: (_, child) => ElioLightTheme.wrap(child!),
        home: Scaffold(body: hero(80, -4)),
      ),
    );

    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => Scaffold(body: hero(200, 3))),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();

    nav.currentState!.pop();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
