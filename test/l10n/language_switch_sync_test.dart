// Language switch (decision 0218): Today's Guide follows the app language in
// the same frame, and a saved scan opens at once while its translation loads.
import 'dart:async';
import 'dart:typed_data';

import 'package:elio/Screens/question_explanation_screen.dart';
import 'package:elio/Screens/scan_history_screen.dart';
import 'package:elio/Screens/tabs/elearning/guides/guide_widgets.dart';
import 'package:elio/Screens/tabs/elearning/learn_hub_v3.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/providers/app_locale_provider.dart';
import 'package:elio/services/guide_progress.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:elio/widgets/history_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../guides/g4_fixture.dart';
import '../guides/g4_test_app.dart';
import '../history/h3_fixture.dart';

void main() {
  late ValueNotifier<Locale> locale;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'daily-guide-notified': '2099-01-01',
    });
    var now = DateTime(2026);
    ElioSound.instance
      ..sink = ((_, _) {})
      ..isSilent = (() async => false)
      ..clock = () => now = now.add(const Duration(seconds: 1));
    locale = ValueNotifier(const Locale('en'));
    debugSetL10n(const Locale('en'));
    guideImageCache = PhotoCache(testPhoto());
    QuizTtsService.instance.mockSpeak = (_) async {};
    QuizTtsService.instance.mockStop = () async {};
  });
  tearDown(() {
    guideImageCache = null;
    AiQuizService.instance.mockSendExecute = null;
    QuizTtsService.instance.mockSpeak = null;
    QuizTtsService.instance.mockStop = null;
    debugSetL10n(const Locale('en'));
  });

  Future<void> pump(WidgetTester t, Widget home, {bool dark = false}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      G4TestApp(
        overrides: guideOverrides(server: FakeGuidesServer()),
        home: home,
        locale: locale,
        dark: dark,
      ),
    );
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  for (final dark in [false, true]) {
    testWidgets(
      'Today\'s Guide ticket switches language in one frame (dark: $dark)',
      (t) async {
        final guide = (await fakeService(
          source: manifest([entry(date)]),
        ).load()).guides.single;
        await pump(
          t,
          Scaffold(
            body: SingleChildScrollView(
              child: GuideTicket(guide: guide, onOpen: () {}),
            ),
          ),
          dark: dark,
        );
        await t.pump(const Duration(seconds: 1));
        expect(find.text('How fast rivers carve deep rocks'), findsOneWidget);
        expect(find.textContaining('TODAY'), findsOneWidget);

        locale.value = const Locale('id');
        await t.pump(); // one frame, no settle
        expect(find.text('Secepat apa sungai mengikis batu'), findsOneWidget);
        expect(find.text('How fast rivers carve deep rocks'), findsNothing);
        expect(find.textContaining('TODAY'), findsNothing);

        locale.value = const Locale('en');
        await t.pump();
        expect(find.text('How fast rivers carve deep rocks'), findsOneWidget);
      },
    );
  }

  testWidgets('an app language switch wins over an older in-guide pick', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final guide = (await fakeService(
      source: manifest([entry(date)]),
    ).load()).guides.single;
    final container = ProviderContainer(
      overrides: guideOverrides(server: FakeGuidesServer()),
    );
    container.read(appLocaleProvider.notifier).setLocale(const Locale('id'));
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: ref.watch(appLocaleProvider),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ElioLightTheme.data,
            builder: (context, child) {
              updateCurrentL10n(context);
              return child!;
            },
            home: Scaffold(
              body: SingleChildScrollView(
                child: GuideTicket(guide: guide, onOpen: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    // The student once flipped the language switch inside a guide.
    await t.runAsync(
      () => container.read(guideProgressProvider.notifier).setGuideLang('id'),
    );
    await t.pump();
    expect(find.text('Secepat apa sungai mengikis batu'), findsOneWidget);

    container.read(appLocaleProvider.notifier).setLocale(const Locale('en'));
    for (var i = 0; i < 3; i++) {
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pump();
    }
    expect(find.text('How fast rivers carve deep rocks'), findsOneWidget);
    expect(find.textContaining('TODAY'), findsOneWidget);
    // The progress sync timer ends with its container.
    await t.pumpWidget(const SizedBox());
    container.dispose();
    await t.pump(const Duration(minutes: 1));
  });

  /// An Indonesian record with no English translation cached yet.
  ScanRecord untranslated() {
    final r = h3Record();
    return ScanRecord(
      id: r.id,
      time: r.time,
      itemName: r.itemName,
      category: r.category,
      questions: r.questions,
      lang: 'id',
    );
  }

  for (final lang in ['en', 'id']) {
    testWidgets('saved scan opens at once while the network hangs ($lang)', (
      t,
    ) async {
      // The record is in the other language, so a translation is wanted.
      final src = untranslated();
      final record = ScanRecord(
        id: src.id,
        time: src.time,
        itemName: src.itemName,
        category: src.category,
        questions: src.questions,
        lang: lang == 'en' ? 'id' : 'en',
      );
      var calls = 0;
      final never = Completer<String?>();
      AiQuizService.instance.mockSendExecute =
          (String prompt, {Uint8List? imageBytes, bool isUser = false}) {
            calls++;
            return never.future;
          };
      locale.value = Locale(lang);
      final store = HistoryTestStore([record]);
      await pump(t, ScanDetailScreen(record: record, store: store));

      expect(calls, 1, reason: 'one translation request per scan and language');
      expect(find.byType(HistorySkeleton), findsNothing);
      expect(find.text('Wadah earphone'), findsWidgets);
      expect(
        find.text(lang == 'en' ? 'Translating…' : 'Menerjemahkan…'),
        findsOneWidget,
      );

      // The reply never came: the saved text stays, with the retry note.
      never.complete(null);
      await t.pump();
      await t.pump();
      expect(find.byType(HistorySkeleton), findsNothing);
      expect(find.text('Wadah earphone'), findsWidgets);
      expect(find.byType(HistoryOriginalNote), findsOneWidget);
    });
  }

  testWidgets('saved explanation shows at once after a language switch', (
    t,
  ) async {
    final record = untranslated();
    final never = Completer<String?>();
    AiQuizService.instance.mockSendExecute =
        (String prompt, {Uint8List? imageBytes, bool isUser = false}) =>
            never.future;
    await pump(
      t,
      QuestionExplanationScreen(
        record: record,
        store: HistoryTestStore([record]),
        questionIndex: 0,
      ),
    );
    expect(find.byType(HistorySkeleton), findsNothing);
    expect(find.text('Translating…'), findsOneWidget);
    never.complete(null);
    await t.pump();
  });
}
