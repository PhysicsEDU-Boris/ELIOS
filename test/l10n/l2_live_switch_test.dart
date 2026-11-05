// Switching the language in the running app updates open History screens at
// once, with no restart (decision 0185). Same locale wiring as ElioApp.
import 'package:elio/Screens/question_explanation_screen.dart';
import 'package:elio/Screens/scan_history_screen.dart';
import 'package:elio/models/physics_module.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/providers/app_locale_provider.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../history/h3_fixture.dart';

void main() {
  late ProviderContainer container;
  setUp(() {
    SharedPreferences.setMockInitialValues({'elio_locale_v1': 'en'});
    QuizTtsService.instance.mockStop = () async {};
    container = ProviderContainer();
  });
  tearDown(() {
    container.dispose();
    QuizTtsService.instance.mockStop = null;
    debugSetL10n(const Locale('en'));
  });

  Future<void> pump(WidgetTester t, Widget home) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    container.read(appLocaleProvider.notifier).setLocale(const Locale('en'));
    await t.pumpWidget(UncontrolledProviderScope(
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
          home: home,
        ),
      ),
    ));
    await t.pumpAndSettle();
  }

  Future<void> switchTo(WidgetTester t, String lang) async {
    container.read(appLocaleProvider.notifier).setLocale(Locale(lang));
    await t.pumpAndSettle();
  }

  ScanRecord yesterday() {
    final r = h3Record();
    final y = DateTime.now().subtract(const Duration(days: 1));
    return ScanRecord(id: r.id, time: y, itemName: r.itemName, category: r.category,
        questions: r.questions, lang: 'id', translations: r.translations);
  }

  testWidgets('History list: headers, day words, counts and chips switch live', (t) async {
    final record = yesterday();
    await pump(t, ScanHistoryScreen(store: HistoryTestStore([record])));
    expect(find.text('Recent scans'), findsOneWidget);
    expect(find.text('Yesterday · 2 questions'), findsOneWidget);
    expect(find.text('1 scan'), findsOneWidget);
    await switchTo(t, 'id');
    expect(find.text('Scan terbaru'), findsOneWidget);
    expect(find.text('Kemarin · 2 soal'), findsOneWidget);
    expect(find.text('B3 · Berbahaya'), findsOneWidget);
    expect(find.text('Recent scans'), findsNothing);
    await switchTo(t, 'en');
    expect(find.text('Recent scans'), findsOneWidget);
  });

  testWidgets('Scan detail switches live', (t) async {
    final record = h3Record();
    await pump(t, ScanDetailScreen(record: record, store: HistoryTestStore([record])));
    expect(find.text('Scan detail'), findsOneWidget);
    expect(find.text('Questions'), findsOneWidget);
    await switchTo(t, 'id');
    expect(find.text('Detail scan'), findsOneWidget);
    expect(find.text('Soal'), findsOneWidget);
  });

  testWidgets('Explanation: title, cards and section titles switch live', (t) async {
    debugSetL10n(const Locale('id'));
    final record = h3Record();
    await pump(t, QuestionExplanationScreen(record: record, questionIndex: 0, store: HistoryTestStore([record])));
    expect(find.text('Explanation'), findsWidgets);
    expect(find.text('YOUR ANSWER'), findsOneWidget);
    await switchTo(t, 'id');
    expect(find.text('Penjelasan'), findsWidgets);
    expect(find.text('JAWABANMU'), findsOneWidget);
    expect(find.text('Kenapa ini jawaban yang benar'), findsOneWidget);
  });

  testWidgets('Learn physics module texts (moved to ARB) switch live', (t) async {
    await pump(t, Scaffold(body: Builder(builder: (_) => Text(physicsModules[2].title))));
    expect(find.text('Robot Shoulder Torque'), findsWidgets);
    await switchTo(t, 'id');
    expect(find.text('Torsi Bahu Robot'), findsWidgets);
  });
}
