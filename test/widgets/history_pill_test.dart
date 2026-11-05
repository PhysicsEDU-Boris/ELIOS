import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/models/home_stats.dart' show questBonus;
import 'package:elio/Screens/scan_history_screen.dart';
import 'package:elio/services/scan_record_store.dart';
import 'package:elio/widgets/control_layout.dart';

void main() {
  late Directory tempDir;
  late File testFile;
  late ScanRecordStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('history_pill_test_');
    testFile = File('${tempDir.path}/records.json');
    store = ScanRecordStore(customFile: testFile);
    await store.load();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('HistoryPill displays real trophies and opens ScanHistoryScreen', (tester) async {
    await store.seedFigmaSampleRecords();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HistoryPill(store: store),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Shows total trophies from store (20 + 20 + 10 + 0 + quests)
    expect(find.text('${50 + questBonus(store.records)}'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // 2. Tapping opens ScanHistoryScreen
    await tester.tap(find.byType(HistoryPill));
    await tester.pumpAndSettle();

    expect(find.byType(ScanHistoryScreen), findsOneWidget);
    expect(find.text('Riwayat'), findsOneWidget);
  });
}
