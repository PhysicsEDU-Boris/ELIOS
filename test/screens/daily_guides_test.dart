import 'package:elio/Screens/tabs/elearning/daily_guides_page.dart';
import 'package:elio/Screens/tabs/elearning_tab.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/providers/auth_provider.dart';
import 'package:elio/providers/learning_progress_provider.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:elio/services/daily_guide_service.dart';
import 'package:elio/services/elearning_content_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../daily_guide_service_test.dart' show issue, manifest;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugSetL10n(const Locale('en'));
  });

  testWidgets('daily feed remains accessible when course modules are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LearnHub(
              streams: LearnStreams(
                ElearningContentService(firestore: FakeFirebaseFirestore()),
              ),
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Daily Guide'), findsOneWidget);
  });

  testWidgets('shows latest and archive, refreshes, switches language', (
    tester,
  ) async {
    var calls = 0;
    final service = DailyGuideService(
      fetch: () async {
        calls++;
        return manifest([issue('2026-11-07'), issue('2026-11-08')]);
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dailyGuideServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: DailyGuidesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Latest issue'), findsOneWidget);
    expect(find.text('Previous issues'), findsOneWidget);
    expect(find.text('River flow'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Refresh guides'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    debugSetL10n(const Locale('id'));
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Aliran sungai'), findsNWidgets(2));
    debugSetL10n(const Locale('en'));
  });
  testWidgets('first-use failure can retry into an empty published feed', (
    tester,
  ) async {
    var fail = true;
    final service = DailyGuideService(
      fetch: () async {
        if (fail) throw Exception('offline');
        return manifest([]);
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dailyGuideServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: DailyGuidesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Refresh guides'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Refresh guides'));
    await tester.pumpAndSettle();
    expect(find.text('The first daily guide is on its way.'), findsOneWidget);
  });
  testWidgets(
    'opens daily PDF without course progress and retains account position',
    (tester) async {
      const key = 'daily-guide-page:reader:daily-2026-11-08';
      SharedPreferences.setMockInitialValues({
        key: 3,
        'daily-guide-page:guest:daily-2026-11-08': 2,
      });
      final service = DailyGuideService(
        fetch: () async => manifest([issue('2026-11-08')]),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyGuideServiceProvider.overrideWithValue(service),
            currentUserProvider.overrideWithValue(MockUser(uid: 'reader')),
            learningProgressProvider.overrideWith(
              () =>
                  throw StateError('daily guides must not use course progress'),
            ),
          ],
          child: const MaterialApp(home: DailyGuidesPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('River flow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(key), 3);
      expect(prefs.getInt('daily-guide-page:guest:daily-2026-11-08'), 2);
    },
  );
}
