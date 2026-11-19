// ELIOS 3 History (decision 0199): compact tab, timeline by device, device
// and contribution on records.
import 'package:elio/Screens/history/scan_timeline_screen.dart';
import 'package:elio/Screens/scan_history_screen.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/widgets/history_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'h3_fixture.dart';

ScanRecord _r(
  String id,
  String name, {
  String? device,
  String kind = 'scan',
  int minutesAgo = 0,
  bool quiz = true,
}) => ScanRecord(
  id: id,
  time: DateTime.now().subtract(Duration(minutes: minutesAgo)),
  itemName: name,
  category: ScanCategory.recyclable,
  questions: quiz
      ? const [
          RecordQuestion(
            question: 'q',
            yourAnswer: 'a',
            rightAnswer: 'b',
            isCorrect: false,
          ),
        ]
      : const [],
  trophies: kind == 'contribution' ? 10 : null,
  kind: kind,
  device: device,
);

Future<void> _pump(WidgetTester t, Widget child) async {
  t.view.physicalSize = const Size(400, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ElioLightTheme.data,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('device round-trips; old records have none', () {
    final r = _r('a', 'Botol', device: 'elios');
    expect(ScanRecord.fromJson(r.toJson()).device, 'elios');
    expect(historyDeviceOf(r), HistoryDevice.elios);
    final old = ScanRecord.fromJson({'id': 'o', 'itemName': 'x'});
    expect(old.device, isNull);
    expect(historyDeviceOf(old), isNull);
    expect(old.toJson().containsKey('device'), isFalse);
  });

  testWidgets('compact tab: latest 3, chips, by device, questions to review', (
    t,
  ) async {
    final store = HistoryTestStore([
      _r(
        '1',
        'Botol plastik',
        device: 'phone',
        kind: 'contribution',
        quiz: false,
      ),
      _r('2', 'Kardus', device: 'elios', minutesAgo: 5, quiz: false),
      _r('3', 'Kaleng', device: 'phone', minutesAgo: 10),
      _r('4', 'Lama', minutesAgo: 20),
    ]);
    await _pump(
      t,
      ScanHistoryScreen(store: store, showHeader: false, compact: true),
    );
    // Figma 629:99388: curved hero instead of the title + subtitle.
    expect(find.text('Scans, quizzes and contributions'), findsNothing);
    expect(find.text('YOUR ECO LEVEL'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Botol plastik'), findsOneWidget);
    expect(find.text('Kaleng'), findsWidgets);
    expect(find.text('Lama'), findsNothing, reason: 'only the latest 3');
    expect(find.text('Contribution'), findsOneWidget);
    expect(find.text('Scan only'), findsOneWidget);
    expect(find.text('Quiz 0/1'), findsOneWidget);
    expect(find.text('By device'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget, reason: 'drone locked');
    expect(find.text('Questions to review'), findsOneWidget);
    expect(find.textContaining('Kaleng 0/1'), findsOneWidget);

    // The locked drone stays on the tab; See timeline opens the timeline.
    await t.tap(find.text('Drone'));
    await t.pumpAndSettle();
    expect(find.byType(ScanTimelineScreen), findsNothing);
    await t.tap(find.text('See timeline'));
    await t.pumpAndSettle();
    expect(find.byType(ScanTimelineScreen), findsOneWidget);
  });

  testWidgets('timeline: device tabs filter; older records only under All', (
    t,
  ) async {
    final store = HistoryTestStore([
      _r('1', 'Botol plastik', device: 'phone'),
      _r('2', 'Kardus', device: 'elios', minutesAgo: 5),
      _r('3', 'Lama', minutesAgo: 20),
    ]);
    await _pump(t, ScanTimelineScreen(store: store));
    expect(find.text('Botol plastik'), findsOneWidget);
    expect(find.text('Kardus'), findsOneWidget);
    expect(find.text('Lama'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('ELIOS'));
    await t.pumpAndSettle();
    expect(find.text('Kardus'), findsOneWidget);
    expect(find.text('Botol plastik'), findsNothing);
    expect(find.text('Lama'), findsNothing);
    expect(find.text('ELIOS robot'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Phone'));
    await t.pumpAndSettle();
    expect(find.text('Botol plastik'), findsOneWidget);
    expect(find.text('Kardus'), findsNothing);

    // The drone tab is locked.
    await t.tap(find.bySemanticsLabel('Drone'));
    await t.pumpAndSettle();
    expect(find.text('Botol plastik'), findsOneWidget);
  });
}
