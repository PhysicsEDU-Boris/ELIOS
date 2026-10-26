import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/Screens/scan_history_screen.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/services/scan_record_store.dart';

void main() {
  const testSizes = <(int, int)>[
    (1366, 768),
    (1024, 768),
    (800, 632),
    (770, 553),
    (390, 844),
  ];

  late Directory tempDir;
  late File testFile;
  late ScanRecordStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scan_history_screen_test_');
    testFile = File('${tempDir.path}/records.json');
    store = ScanRecordStore(customFile: testFile);
    await store.load();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget createSubject({VoidCallback? onClose}) {
    return MaterialApp(
      home: ScanHistoryScreen(
        store: store,
        onClose: onClose,
      ),
    );
  }

  group('ScanHistoryScreen empty state', () {
    for (final (width, height) in testSizes) {
      testWidgets('$width x $height empty state has no overflow and shows empty title', (tester) async {
        tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createSubject());
        await tester.pumpAndSettle();

        expect(find.byType(ScanHistoryScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.text('Scan History'), findsOneWidget);
        expect(find.text('Tersimpan lokal'), findsOneWidget);
        expect(find.text('Belum Ada Riwayat Scan'), findsOneWidget);

        // Debug action button is present and tappable in debug mode
        final seedBtn = find.text('Tambah Contoh Data (Debug)');
        expect(seedBtn, findsOneWidget);
        await tester.tap(seedBtn);
        await tester.pumpAndSettle();

        // After tapping seed, 4 sample records appear
        expect(find.text('Phone'), findsAtLeastNWidgets(1));
        expect(find.text('Plastic Bottle'), findsAtLeastNWidgets(1));
      });
    }
  });

  group('ScanHistoryScreen populated state (Figma 100:170)', () {
    for (final (width, height) in testSizes) {
      testWidgets('$width x $height populated layout: no overflow, all controls tappable', (tester) async {
        tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await store.seedFigmaSampleRecords();

        var closed = false;
        await tester.pumpWidget(createSubject(onClose: () => closed = true));
        await tester.pumpAndSettle();

        // 1. Zero overflow
        expect(tester.takeException(), isNull);

        // 2. Header elements
        expect(find.text('Scan History'), findsOneWidget);
        expect(find.text('Tersimpan lokal'), findsOneWidget);
        expect(find.text('50 trophies'), findsOneWidget); // 20 + 20 + 10 + 0

        // 3. Filters
        final filterAll = find.byKey(const ValueKey('filter_chip_All'));
        final filterB3 = find.byKey(const ValueKey('filter_chip_B3'));
        final filterRecyclable = find.byKey(const ValueKey('filter_chip_Recyclable'));
        final filterOrganic = find.byKey(const ValueKey('filter_chip_Organic'));

        expect(filterAll, findsOneWidget);
        expect(filterB3, findsOneWidget);
        expect(filterRecyclable, findsOneWidget);
        expect(filterOrganic, findsOneWidget);

        // 4. Test filter interaction (tap B3 filter)
        await tester.tap(filterB3);
        await tester.pumpAndSettle();
        expect(find.text('Phone'), findsAtLeastNWidgets(1));
        expect(find.text('Battery'), findsAtLeastNWidgets(1));
        expect(find.text('Plastic Bottle'), findsNothing);

        // Return to All filter
        await tester.tap(filterAll);
        await tester.pumpAndSettle();
        expect(find.text('Plastic Bottle'), findsAtLeastNWidgets(1));

        // 5. Card tap interaction
        final phoneCard = find.byKey(const ValueKey('record_tile_sample-phone'));
        expect(phoneCard, findsOneWidget);
        await tester.tap(phoneCard);
        await tester.pumpAndSettle();

        // On mobile (390x844), tapping an item transitions to detail view with Back button
        if (width < 750) {
          final backBtn = find.text('Back to list');
          expect(backBtn, findsOneWidget);
          // Question details are visible
          expect(find.text('Which waste category does a used phone belong to?'), findsOneWidget);
          // Tap back to return to list
          await tester.tap(backBtn);
          await tester.pumpAndSettle();
          expect(find.text('Recent scans'), findsOneWidget);
        } else {
          // On wide screens, detail panel is visible side by side
          expect(find.byKey(const ValueKey('detail_list_view')), findsOneWidget);
          expect(find.text('Phone'), findsAtLeastNWidgets(2));
          await tester.drag(find.byKey(const ValueKey('detail_list_view')), const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(find.text('Which waste category does a used phone belong to?'), findsOneWidget);
        }

        // 6. Close button tap
        final closeBtn = find.byKey(const ValueKey('scan_history_close_button'));
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();
        expect(closed, isTrue);
      });
    }
  });

  group('ScanHistoryScreen G2c difficulty pill and local sync text', () {
    testWidgets('shows Tersimpan lokal instead of synced and displays real question count in difficulty pills', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed a record with Easy difficulty but 2 questions
      final record = ScanRecord(
        id: 'test-custom-q-count',
        time: DateTime(2026, 10, 26, 15, 30),
        itemName: 'Kardus Cokelat',
        category: ScanCategory.recyclable,
        difficulty: QuizDifficulty.easy,
        questions: const [
          RecordQuestion(
            question: 'Soal 1',
            yourAnswer: 'Daur ulang',
            rightAnswer: 'Daur ulang',
            isCorrect: true,
            trophies: 10,
          ),
          RecordQuestion(
            question: 'Soal 2',
            yourAnswer: 'Lipat',
            rightAnswer: 'Lipat',
            isCorrect: true,
            trophies: 10,
          ),
        ],
        trophies: 20,
      );

      await store.addRecord(record);

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Top chip
      expect(find.text('Tersimpan lokal'), findsOneWidget);
      expect(find.text('synced'), findsNothing);

      // Detail subtitle shows Tersimpan lokal
      expect(find.textContaining('Photo and 2 questions · Tersimpan lokal'), findsOneWidget);
      expect(find.textContaining('synced'), findsNothing);

      // Difficulty pill reflects real question count: 'Easy · 2Q' (detail pill and header)
      expect(find.text('Easy · 2Q'), findsAtLeastNWidgets(1));
    });
  });
}
