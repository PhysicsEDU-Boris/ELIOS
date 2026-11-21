// App onboarding tour engine (decision 0238).
import 'package:elio/l10n/app_localizations.dart';
import 'package:elio/widgets/tour/app_tour.dart';
import 'package:elio/widgets/tour/main_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

/// A screen with two spotlight targets and a screen tour.
Widget _screen({bool showSecond = true}) => Scaffold(
  body: TourTip(
    id: 'test_screen',
    label: () => 'TEST',
    steps: (k) => [
      TourStep(k[0], 'First', 'one'),
      TourStep(k[1], 'Second', 'two'),
      TourStep(k[2], 'Third', 'three'),
    ],
    builder: (context, k) => Column(
      children: [
        SizedBox(key: k[0], height: 80, width: 200),
        if (showSecond) SizedBox(key: k[1], height: 80, width: 200),
        SizedBox(key: k[2], height: 80, width: 200),
      ],
    ),
  ),
);

void main() {
  setUp(() => AppTour.running = false);

  testWidgets('a screen tour shows once, walks its steps, then never again', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppTour.load();
    await t.pumpWidget(_app(_screen()));
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('TEST · STEP 1 OF 3'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('guide_next')));
    await t.pump(const Duration(seconds: 1)); // the next target settles
    await t.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('guide_next')));
    await t.pump(const Duration(seconds: 1)); // the next target settles
    await t.pumpAndSettle();
    // Last step: no Skip, the button says Got it.
    expect(find.byKey(const ValueKey('guide_skip')), findsNothing);
    await t.tap(find.text('Got it'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app_tour_overlay')), findsNothing);

    // Opening the screen again shows nothing.
    await t.pumpWidget(_app(const SizedBox()));
    await t.pumpWidget(_app(_screen()));
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app_tour_overlay')), findsNothing);
  });

  testWidgets('a step whose widget is not on screen is dropped', (t) async {
    SharedPreferences.setMockInitialValues({});
    await AppTour.load();
    await t.pumpWidget(_app(_screen(showSecond: false)));
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();

    expect(find.text('TEST · STEP 1 OF 2'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('guide_next')));
    await t.pump(const Duration(seconds: 1)); // the next target settles
    await t.pumpAndSettle();
    expect(find.text('Third'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
    await t.tap(find.text('Got it'));
    await t.pumpAndSettle();
  });

  testWidgets('Skip ends the tour; tips off shows nothing', (t) async {
    SharedPreferences.setMockInitialValues({});
    await AppTour.load();
    await t.pumpWidget(_app(_screen()));
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('guide_skip')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app_tour_overlay')), findsNothing);
    expect(AppTour.running, isFalse);

    SharedPreferences.setMockInitialValues({});
    await AppTour.setTipsEnabled(false);
    await t.pumpWidget(_app(const SizedBox()));
    await t.pumpWidget(_app(_screen()));
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('app_tour_overlay')), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getBool(AppTour.tipsEnabledKey),
      isFalse,
    );
  });

  testWidgets('Welcome: Next, Next, Start the tour pops true', (t) async {
    bool? result;
    await t.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text("Hi! I'm ELIOS"), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('welcome_next')));
    await t.pumpAndSettle();
    expect(find.text('Three ways to play'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('welcome_next')));
    await t.pumpAndSettle();
    expect(find.text('Start the tour'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('welcome_next')));
    await t.pumpAndSettle();
    expect(result, isTrue);
  });
}
