// Every trophy icon is the XP sticker now (decision 0220).
import 'dart:io';

import 'package:elio/widgets/history_ui.dart';
import 'package:elio/widgets/xp_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no trophy icon is left in lib/', () {
    final hits = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('Icons.emoji_events'))
          f.path,
    ];
    expect(hits, isEmpty);
  });

  for (final dark in [false, true]) {
    testWidgets('XP chip shows the sticker at 14 dp (dark: $dark)', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: const Scaffold(body: Center(child: HistoryTrophyChip(10))),
        ),
      );
      expect(t.getSize(find.byType(XpIcon)), const Size(14, 14));
      expect(find.text('+10'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  }
}
