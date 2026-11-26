// App onboarding tour engine (decision 0238).
import 'package:elio/l10n/app_localizations.dart';
import 'package:elio/widgets/tour/app_tour.dart';
import 'package:elio/widgets/tour/main_tour.dart';
import 'package:elio/widgets/waste_quiz_popup.dart' show QuizCountdown;
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

  testWidgets('the quiz countdown waits while a tour card is on screen', (
    t,
  ) async {
    var up = 0;
    await t.pumpWidget(
      _app(Scaffold(body: QuizCountdown(seconds: 3, onTimeUp: () => up++))),
    );
    AppTour.running = true;
    await t.pump(const Duration(seconds: 6));
    expect(up, 0, reason: 'no time lost while the tour shows');
    AppTour.running = false;
    await t.pump(const Duration(seconds: 4));
    expect(up, 1);
  });

  test(
    'landscape, wide target, no full gap: the card sits in the bigger gap',
    () {
      const screen = Size(915, 412);
      // A wide quest-map row: 140 px above it, 152 px below, card is 176 tall.
      const hole = Rect.fromLTRB(160, 140, 896, 260);
      final p = tourCardBeside(screen, hole, const SizedBox()) as Positioned;
      expect(p.top, isNotNull);
      expect(p.top! + 176, lessThanOrEqualTo(412 - 12), reason: 'on screen');
      expect(p.top!, greaterThan(hole.center.dy), reason: 'below, not on top');
    },
  );
}
