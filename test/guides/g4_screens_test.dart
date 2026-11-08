import 'package:cached_network_image/cached_network_image.dart';
import 'package:elio/Screens/tabs/elearning/daily_guides_page.dart';
import 'package:elio/Screens/tabs/elearning/guides/guide_issue_page.dart';
import 'package:elio/Screens/tabs/elearning/guides/guide_lab_page.dart';
import 'package:elio/Screens/tabs/elearning/guides/guide_quiz_page.dart';
import 'package:elio/Screens/tabs/elearning/guides/guide_widgets.dart';
import 'package:elio/Screens/tabs/elearning_tab.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/services/daily_guide_service.dart';
import 'package:elio/services/elearning_content_service.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auth_test_support.dart' show loadElioFonts;
import 'g4_fixture.dart';
import 'g4_test_app.dart';

GuideQuestion q(String id, int answer) => GuideQuestion(
  qid: id,
  question: '$id?',
  options: const ['a', 'b', 'c', 'd'],
  answer: answer,
);

void main() {
  setUpAll(loadElioFonts);
  late FakeGuidesServer server;
  late ValueNotifier<Locale> locale;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'daily-guide-notified': '2099-01-01',
    });
    server = FakeGuidesServer();
    locale = ValueNotifier(const Locale('en'));
    debugSetL10n(const Locale('en'));
    guideImageCache = PhotoCache(testPhoto());
    QuizTtsService.instance.mockSpeak = (_) async {};
    QuizTtsService.instance.mockStop = () async {};
  });
  tearDown(() {
    guideImageCache = null;
    debugSetL10n(const Locale('en'));
  });

  Future<DailyGuide> guide({bool photo = true}) async => (await fakeService(
    source: manifest([entry(date, photo: photo)]),
  ).load()).guides.single;

  Future<void> pump(
    WidgetTester t,
    Widget home, {
    double width = 390,
    double height = 844,
    double textScale = 1,
    bool reduceMotion = false,
    double dpr = 3,
  }) async {
    t.view.physicalSize = Size(width * dpr, height * dpr);
    t.view.devicePixelRatio = dpr;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      G4TestApp(
        overrides: guideOverrides(server: server),
        home: home,
        locale: locale,
        textScale: textScale,
        reduceMotion: reduceMotion,
      ),
    );
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  group('quiz deck state machine', () {
    test('answer, check, next, result, flip back', () {
      final deck = QuizDeck([q('p1', 1), q('p2', 0), q('p3', 2)]);
      expect(deck.canCheck, isFalse);
      deck.next();
      expect(deck.current, 0, reason: 'no skipping an unchecked card');
      deck.select(1);
      deck.check();
      deck.select(3);
      expect(deck.choices[0], 1, reason: 'a checked answer is locked');
      deck.next();
      deck.select(2);
      deck.check();
      deck.next();
      deck.select(2);
      deck.check();
      deck.review(0);
      expect(deck.reviewing, isNull, reason: 'flip back only from the result');
      deck.next();
      expect(deck.finished, isTrue);
      expect(deck.score, 2);
      expect(deck.answers.map((a) => '${a.qid}:${a.choice}'), [
        'p1:b',
        'p2:c',
        'p3:c',
      ]);
      deck.review(1);
      expect(deck.reviewing, 1);
      deck.review(null);
      expect(deck.reviewing, isNull);
    });

    test('try again uses spare questions not seen yet', () {
      final pool = [for (var i = 0; i < 5; i++) q('pool-$i', 0)];
      final first = QuizDeck.retry(pool, {'p1', 'p2', 'p3'});
      expect(first.map((x) => x.qid), ['pool-0', 'pool-1', 'pool-2']);
      final second = QuizDeck.retry(pool, {'pool-0', 'pool-1', 'pool-2'});
      expect(second.map((x) => x.qid), ['pool-3', 'pool-4', 'pool-0']);
    });
  });

  testWidgets('quiz: a swipe never answers; buttons drive the deck to the result', (
    t,
  ) async {
    await pump(t, GuideQuizPage(guide: await guide()));
    final question = find.text('What equation calculates speed?');
    expect(question, findsOneWidget);
    // Screen readers hear only the front card (the phone UI dump listed all three).
    expect(find.bySemanticsLabel(RegExp('Answer A: 6 m/s')), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'Answer A: v = s × t')),
      findsOneWidget,
    );
    await t.drag(question, const Offset(-300, 0));
    await t.drag(question, const Offset(300, 0));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('✓'), findsNothing);
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Check').hitTestable(),
          )
          .onPressed,
      isNull,
    );
    for (final (choice, next) in [
      ('v = s ÷ t', 'Next card'),
      ('2,400 m/s', 'Next card'),
      ('More energy and sediment', 'See result'),
    ]) {
      await t.tap(find.text(choice).hitTestable());
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Check').hitTestable());
      await t.pump();
      if (choice == '2,400 m/s') {
        expect(find.text('Not quite. You multiplied.'), findsOneWidget);
      }
      await t.tap(find.widgetWithText(FilledButton, next).hitTestable());
      await t.pump(const Duration(milliseconds: 400));
    }
    for (var i = 0; i < 4; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('2 of 3 correct'), findsOneWidget);
    // The result card is centred and its Q1-Q3 chips sit in one row (phone bugs).
    final card = t.getRect(find.byKey(const ValueKey('result')));
    expect(card.center.dx, closeTo(195, 1));
    final chips = [
      for (final q in ['✓ Q1', '✗ Q2', '✓ Q3']) t.getCenter(find.text(q).last),
    ];
    expect(chips.map((c) => c.dy).toSet().length, 1);
    expect(find.text('Saved to your account'), findsOneWidget);
    expect(server.calls.where((c) => c['op'] == 'quiz').length, 1);
    await t.tap(find.bySemanticsLabel('Look at question 2 again'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Back to result'), findsOneWidget);
    await t.tap(find.text('Back to result'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Try the quiz again'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Spare question 1?'), findsOneWidget);
  });

  testWidgets(
    'quiz: reduced motion shows one card at a time (cross-fade, no stack)',
    (t) async {
      await pump(t, GuideQuizPage(guide: await guide()), reduceMotion: true);
      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byType(AnimatedRotation), findsNothing);
      expect(find.text('What equation calculates speed?'), findsOneWidget);
      expect(
        find.text(
          'If distance s is 120 m and time t is 20 s, what is speed v?',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'images: hero uses photo.src decoded at shown width x DPR; archive uses the thumb; no photo = art',
    (t) async {
      final g = await guide();
      await pump(t, GuideIssuePage(guide: g));
      final hero = t.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage).first,
      );
      expect(
        Uri.parse(hero.imageUrl).path,
        endsWith('/issues/$date/photo.jpg'),
      );
      // Hero polaroid is 176 dp wide: photo 158.4 x 224.4 dp, cover-cropped from a 2000 x 1333 photo.
      const photoW = 176 - 8.64 * 176 / 86.4;
      const photoH = photoW * 110.16 / 77.76;
      expect(hero.memCacheWidth, (photoH * 2000 / 1333 * 3).round());
      expect(hero.fit, BoxFit.cover);

      await pump(
        t,
        Scaffold(
          body: SizedBox(
            width: 171,
            child: GuideArchiveCard(guide: g, tiltLeft: true, onTap: () {}),
          ),
        ),
      );
      final thumb = t.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        Uri.parse(thumb.imageUrl).path,
        endsWith('/issues/$date/photo-800.jpg'),
      );

      final plain = await guide(photo: false);
      await pump(
        t,
        Scaffold(
          body: SizedBox(
            width: 171,
            child: GuideArchiveCard(
              guide: plain,
              tiltLeft: false,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is ResizeImage &&
              ((w.image as ResizeImage).imageProvider as AssetImage).assetName
                  .endsWith('topic_water.png'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'feed: streak, week dots, today card, archive; app language switches live',
    (t) async {
      await pump(t, const DailyGuidesPage());
      expect(find.text('ELIOS Guides'), findsOneWidget);
      expect(find.text('0-day reading streak'), findsOneWidget);
      expect(find.text('How fast rivers carve deep rocks'), findsWidgets);
      expect(find.text('2 issues'), findsOneWidget);
      await t.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Heat'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.widgetWithText(ChoiceChip, 'Heat'));
      await t.pump();
      expect(
        find.byType(GuideArchiveCard),
        findsOneWidget,
        reason: 'the topic filter leaves the heat issue',
      );
      locale.value = const Locale('id');
      await t.pump();
      await t.pump();
      expect(find.text('Arsip'), findsOneWidget);
      expect(find.text('Secepat apa sungai mengikis batu'), findsWidgets);
    },
  );

  testWidgets(
    'issue: EN | ID switch changes only the guide; Continue goes to the next unfinished stop',
    (t) async {
      await pump(t, GuideIssuePage(guide: await guide()));
      expect(find.text('Your quest map'), findsOneWidget);
      expect(find.text('Continue · Stop 1'), findsOneWidget);
      // Multi-placeholder strings keep their argument order (phone bug: "60 / 0 XP", "English-page PDF").
      expect(find.text('0 / 60 XP'), findsOneWidget);
      expect(
        find.text('4-page PDF · English · saved for offline'),
        findsOneWidget,
      );
      await t.tap(find.text('Bahasa Indonesia'));
      for (var i = 0; i < 4; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Secepat apa sungai mengikis batu'), findsOneWidget);
      expect(
        find.text('Your quest map'),
        findsOneWidget,
        reason: 'the app stays English',
      );
      await t.scrollUntilVisible(
        find.text('Finish Stop 2 to unlock'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Finish Stop 2 to unlock'), findsOneWidget);
    },
  );

  testWidgets(
    'lab brief lists the published rubric; nothing is sent before Send',
    (t) async {
      await pump(t, GuideLabPage(guide: await guide()));
      expect(
        find.text('A floating object like a cork or leaf'),
        findsOneWidget,
      );
      expect(find.text('Record 15–30 s'), findsOneWidget);
      expect(server.calls.where((c) => c['op'] == 'lab'), isEmpty);
    },
  );

  test('frames are picked evenly from the clip', () {
    expect(pickEvenly(List.generate(30, (i) => i), 8), [
      0,
      4,
      8,
      12,
      17,
      21,
      25,
      29,
    ]);
    expect(pickEvenly([1, 2, 3], 8), [1, 2, 3]);
  });

  testWidgets(
    'hub: Today card above the knowledge challenge, even with no course modules',
    (t) async {
      await pump(
        t,
        Scaffold(
          body: LearnHub(
            streams: LearnStreams(
              ElearningContentService(firestore: FakeFirebaseFirestore()),
            ),
            onRetry: () {},
          ),
        ),
      );
      expect(find.text('Guide archive'), findsOneWidget);
      expect(find.byType(GuideTodayCard), findsOneWidget);
    },
  );

  for (final (name, build) in <(String, Widget Function(DailyGuide))>[
    ('feed', (_) => const DailyGuidesPage()),
    ('issue', (g) => GuideIssuePage(guide: g)),
    ('quiz', (g) => GuideQuizPage(guide: g)),
    ('lab', (g) => GuideLabPage(guide: g)),
  ]) {
    for (final lang in ['en', 'id']) {
      testWidgets(
        '$name ($lang) has no overflow at 320 dp and text scale 1.3',
        (t) async {
          locale.value = Locale(lang);
          debugSetL10n(Locale(lang));
          await pump(
            t,
            build(await guide()),
            width: 320,
            height: 700,
            textScale: 1.3,
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
