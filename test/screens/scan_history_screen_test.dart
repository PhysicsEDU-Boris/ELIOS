import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/Screens/scan_history_screen.dart';
import 'package:elio/Screens/question_explanation_screen.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/theme/elio_tokens.dart';
import 'package:elio/widgets/elio_bottom_nav.dart';
import 'package:elio/widgets/history_ui.dart';
import '../history/h3_fixture.dart';
import 'auth_test_support.dart' show loadElioFonts;

class WaitingStore extends HistoryTestStore {
  @override
  bool get isLoaded => false;
  @override
  Future<List<ScanRecord>> load({bool force = false}) =>
      Completer<List<ScanRecord>>().future;
}

void main() {
  // H3 copy is asserted in Indonesian (decision 0185).
  setUpAll(() => debugSetL10n(const Locale('id')));
  tearDownAll(() => debugSetL10n(const Locale('en')));
  setUpAll(loadElioFonts);
  tearDown(() {
    AiQuizService.instance.mockSendExecute = null;
    QuizTtsService.instance.mockSpeak = null;
    QuizTtsService.instance.mockStop = null;
  });
  Future<void> pump(
    WidgetTester t,
    Widget child,
    Brightness mode, {
    Size size = const Size(390, 844),
    bool reduce = true,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: mode == Brightness.dark
            ? ElioDarkTheme.data
            : ElioLightTheme.data,
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: reduce),
          child: child,
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('redesigned list follows a live language switch', (t) async {
    final store = HistoryTestStore([h3Record()]);
    Widget app(String lang) => MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ElioLightTheme.data,
      home: ScanHistoryScreen(store: store, showHeader: false),
    );
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app('id'));
    await t.pump();
    expect(find.text('PIALA KAMU'), findsOneWidget);
    expect(find.text('Semua scan'), findsOneWidget);
    expect(find.text('HARI INI'), findsOneWidget);
    await t.pumpWidget(app('en'));
    await t.pump();
    expect(find.text('YOUR TROPHIES'), findsOneWidget);
    expect(find.text('All scans'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('PIALA KAMU'), findsNothing);
  });
  for (final mode in Brightness.values) {
    final name = mode.name;
    testWidgets(
      '$name list pushes detail on phone, filters and uses saved trophies',
      (t) async {
        final record = h3Record(), store = HistoryTestStore([h3Record()]);
        await pump(t, ScanHistoryScreen(store: store), mode);
        expect(find.text('Riwayat'), findsOneWidget);
        expect(find.text('${record.trophies}'), findsOneWidget);
        expect(find.text('PIALA KAMU'), findsOneWidget);
        expect(find.text('HARI INI'), findsOneWidget);
        expect(find.text('Tersimpan lokal'), findsOneWidget);
        await t.tap(find.widgetWithText(HistoryCategoryTile, 'Organik'));
        await t.pumpAndSettle();
        expect(find.text('Wadah earphone'), findsNothing);
        await t.tap(find.widgetWithText(HistoryCategoryTile, 'Semua scan'));
        await t.pumpAndSettle();
        await t.tap(find.text('Wadah earphone'));
        await t.pumpAndSettle();
        expect(find.byType(ScanDetailScreen), findsOneWidget);
        expect(find.text('Detail scan'), findsOneWidget);
        // Result stats replace the score card (Figma 02 redesign).
        expect(find.byType(HistoryResultStats), findsOneWidget);
        expect(find.byType(HistoryDifficultyTabs), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
    for (final size in [const Size(770, 553), const Size(1366, 768)]) {
      testWidgets('$name wide $size keeps two panes', (t) async {
        await pump(
          t,
          ScanHistoryScreen(store: HistoryTestStore([h3Record()])),
          mode,
          size: size,
        );
        expect(find.byType(ScanDetailScreen), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
    testWidgets('$name empty starts scanning without seed controls', (t) async {
      var scans = 0;
      await pump(
        t,
        ScanHistoryScreen(
          store: HistoryTestStore(),
          onStartScan: () => scans++,
        ),
        mode,
      );
      expect(find.text('Belum ada scan'), findsOneWidget);
      expect(find.textContaining('Contoh Data'), findsNothing);
      await t.tap(find.text('Mulai scan'));
      expect(scans, 1);
      expect(t.takeException(), isNull);
    });
    testWidgets(
      '$name explanation uses saved text, next question and export sheet',
      (t) async {
        var calls = 0;
        AiQuizService.instance.mockSendExecute =
            (_, {imageBytes, isUser = false}) async {
              calls++;
              return null;
            };
        final record = h3Record();
        await pump(
          t,
          QuestionExplanationScreen(
            record: record,
            questionIndex: 0,
            store: HistoryTestStore([record]),
          ),
          mode,
        );
        await t.pumpAndSettle();
        expect(find.text('Penjelasan'), findsWidgets);
        expect(find.text('Jawabanmu'.toUpperCase()), findsOneWidget);
        expect(find.text(h3Explanation.correctAnswerReason), findsOneWidget);
        expect(find.textContaining('MUST_NOT_RENDER'), findsNothing);
        expect(calls, 0);
        final out = Directory('docs/screenshots/h3')
          ..createSync(recursive: true);
        // Capture the visible phone route, with no native app installation or owner data.
        await t.pumpWidget(
          RepaintBoundary(
            key: const Key('capture'),
            child: MaterialApp(
              locale: const Locale('id'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              debugShowCheckedModeBanner: false,
              theme: mode == Brightness.dark
                  ? ElioDarkTheme.data
                  : ElioLightTheme.data,
              home: QuestionExplanationScreen(
                record: record,
                questionIndex: 0,
                store: HistoryTestStore([record]),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('capture')),
        );
        await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          File(
            '${out.path}/explanation-$name.png',
          ).writeAsBytesSync(bytes.buffer.asUint8List());
          image.dispose();
        });
        await t.drag(find.byType(ListView).first, const Offset(0, -600));
        await t.pumpAndSettle();
        expect(
          t.getSize(
            find.descendant(
              of: find.byType(HistoryKeyIdea),
              matching: find.byType(SvgPicture),
            ),
          ),
          const Size(40, 40),
        );
        await t.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          File(
            '${out.path}/explanation-$name-sections.png',
          ).writeAsBytesSync(bytes.buffer.asUint8List());
          image.dispose();
        });
        await t.tap(find.text('Ekspor PDF'));
        await t.pumpAndSettle();
        expect(find.byType(QuestionExportSheet), findsOneWidget);
        expect(find.text('ELIOS_Wadah-earphone_Q1.pdf'), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNWidgets(4));
        await t.tap(find.text('Foto scan'));
        await t.pump();
        expect(
          t
              .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
              .elementAt(2)
              .value,
          isTrue,
        );
        expect(t.takeException(), isNull);
        expect(calls, 0);
        Navigator.of(t.element(find.byType(QuestionExportSheet))).pop();
        await t.pumpAndSettle();
        await t.tap(find.text('Soal berikutnya'));
        await t.pumpAndSettle();
        expect(find.text('Mengapa plastik harus bersih?'), findsOneWidget);
        expect(find.text('Soal berikutnya'), findsNothing);
        expect(find.text('Kenapa jawabanmu kurang tepat'), findsNothing);
      },
    );
    for (final layout in HistoryLoadingLayout.values) {
      testWidgets(
        '$name ${layout.name} skeleton supports reduced motion and sweep',
        (t) async {
          await pump(t, Scaffold(body: HistorySkeleton(layout)), mode);
          await t.pumpAndSettle();
          expect(t.hasRunningAnimations, isFalse);
          expect(t.takeException(), isNull);
          await pump(
            t,
            Scaffold(body: HistorySkeleton(layout)),
            mode,
            reduce: false,
          );
          await t.pump(const Duration(milliseconds: 600));
          expect(t.hasRunningAnimations, isTrue);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
    testWidgets(
      '$name only History nav tab has selected colors and semantics',
      (t) async {
        await pump(
          t,
          Scaffold(
            bottomNavigationBar: ElioBottomNav(
              currentIndex: 4,
              onSelectTab: (_) {},
              onControl: () {},
            ),
          ),
          mode,
        );
        final selected = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.selected == true,
        );
        expect(selected, findsOneWidget);
        expect(t.widget<Semantics>(selected).properties.label, 'Riwayat');
        final history = t.widget<Text>(find.text('Riwayat')),
            home = t.widget<Text>(find.text('Beranda'));
        expect(
          history.style!.color,
          mode == Brightness.dark
              ? ElioTokens.dark.primaryText
              : ElioTokens.light.primaryText,
        );
        expect(
          home.style!.color,
          mode == Brightness.dark
              ? ElioTokens.dark.textSecondary
              : ElioTokens.light.textSecondary,
        );
      },
    );
  }
  testWidgets('list timeout leaves skeleton and exposes retry', (t) async {
    await pump(
      t,
      ScanHistoryScreen(
        store: WaitingStore(),
        loadTimeout: const Duration(seconds: 1),
      ),
      Brightness.light,
    );
    expect(find.byType(HistorySkeleton), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.byType(HistorySkeleton), findsNothing);
    expect(find.text('Coba lagi'), findsOneWidget);
    await t.tap(find.text('Coba lagi'));
    await t.pump();
    expect(find.byType(HistorySkeleton), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
  });
  testWidgets(
    'explanation timeout and offline show retry without invented text',
    (t) async {
      final record = h3Record(cached: false);
      AiQuizService.instance.mockSendExecute =
          (_, {imageBytes, isUser = false}) => Completer<String?>().future;
      await pump(
        t,
        QuestionExplanationScreen(
          record: record,
          questionIndex: 0,
          store: HistoryTestStore([record]),
          loadTimeout: const Duration(seconds: 1),
        ),
        Brightness.dark,
      );
      expect(find.byType(HistorySkeleton), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      expect(find.text('Penjelasan lengkap belum tersedia'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(find.textContaining('Berdasarkan klasifikasi'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await AiQuizService.instance.cancel();
      await t.pump();
      await AiQuizService.instance.cancel();
      await t.pump();
    },
  );
  testWidgets('section switching, pause, background and route exit stop TTS', (
    t,
  ) async {
    final spoken = <String>[], completions = <Completer<void>>[];
    var stops = 0;
    QuizTtsService.instance.mockStop = () async {
      stops++;
      if (completions.isNotEmpty && !completions.last.isCompleted) {
        completions.last.complete();
      }
    };
    QuizTtsService.instance.mockSpeak = (text) {
      spoken.add(text);
      final done = Completer<void>();
      completions.add(done);
      return done.future;
    };
    final record = h3Record();
    await pump(
      t,
      QuestionExplanationScreen(
        record: record,
        questionIndex: 0,
        store: HistoryTestStore([record]),
      ),
      Brightness.light,
      size: const Size(800, 1400),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Dengarkan').at(1));
    await t.pump();
    expect(spoken.single, h3Explanation.correctAnswerReason);
    expect(find.text('SEDANG DIBACAKAN'), findsOneWidget);
    final beforeSwitch = stops;
    await t.tap(find.byTooltip('Dengarkan').at(1));
    await t.pump();
    expect(stops, greaterThan(beforeSwitch));
    expect(spoken.last, h3Explanation.selectedAnswerFeedback);
    await t.tap(find.byTooltip('Jeda'));
    await t.pump();
    expect(find.text('SEDANG DIBACAKAN'), findsNothing);
    await t.tap(find.byTooltip('Dengarkan').at(1));
    await t.pump();
    final beforeBackground = stops;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    expect(stops, greaterThan(beforeBackground));
    expect(find.text('SEDANG DIBACAKAN'), findsNothing);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.tap(find.byTooltip('Dengarkan').first);
    await t.pump();
    expect(spoken.last, record.questions.first.question);
    completions.last.complete();
    await t.pump();
    expect(spoken.last, contains(h3Explanation.correctAnswerReason));
    final beforeExit = stops;
    await t.pumpWidget(const SizedBox());
    await t.pump();
    expect(stops, greaterThan(beforeExit));
  });
  testWidgets(
    'essay keeps pending/score and feedback without right/wrong tints',
    (t) async {
      final record = h3Record(essay: true);
      await pump(
        t,
        QuestionExplanationScreen(
          record: record,
          questionIndex: 0,
          store: HistoryTestStore([record]),
        ),
        Brightness.dark,
      );
      await t.pumpAndSettle();
      expect(find.text('Skor 7/10'), findsOneWidget);
      expect(find.text('Salah'), findsNothing);
      expect(find.text('Benar'), findsNothing);
      expect(find.text('JAWABAN ACUAN'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('detail loading times out and retries', (t) async {
    await pump(
      t,
      ScanDetailScreen(
        record: h3Record(),
        store: WaitingStore(),
        loadTimeout: const Duration(seconds: 1),
      ),
      Brightness.dark,
    );
    expect(find.byType(HistorySkeleton), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.byType(HistorySkeleton), findsNothing);
    expect(find.text('Coba lagi'), findsOneWidget);
    await t.tap(find.text('Coba lagi'));
    await t.pump();
    expect(find.byType(HistorySkeleton), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
  });
  for (final mode in Brightness.values) {
    testWidgets(
      '${mode.name} corrupt History shows an error, not empty records',
      (t) async {
        final store = HistoryTestStore()
          ..loadError = const FormatException('corrupt');
        await pump(t, ScanHistoryScreen(store: store), mode);
        expect(find.text('Coba lagi'), findsOneWidget);
        expect(find.text('Belum ada scan'), findsNothing);
      },
    );
    for (final shape in [
      'portrait',
      'landscape',
      'tiny',
      'missing',
      'unreadable',
      'legacy',
    ]) {
      testWidgets(
        '${mode.name} $shape photo is retained and cover-fit in list and detail',
        (t) async {
          final dir = Directory.systemTemp.createTempSync('h3-photo-');
          addTearDown(() => dir.deleteSync(recursive: true));
          final file = File('${dir.path}/crop.jpg');
          final size = shape == 'portrait'
              ? (90, 240)
              : shape == 'tiny'
              ? (2, 1)
              : (380, 270);
          final valid = ['portrait', 'landscape', 'tiny'].contains(shape);
          if (valid) {
            file.writeAsBytesSync(
              img.encodeJpg(
                img.fill(
                  img.Image(width: size.$1, height: size.$2),
                  color: img.ColorRgb8(40, 100, 180),
                ),
              ),
            );
          }
          if (shape == 'unreadable') file.writeAsStringSync('not a photo');
          final record = h3Record(photo: shape == 'legacy' ? null : file.path),
              store = HistoryTestStore();
          store.data = [record];
          await t.runAsync(() async {
            await pump(t, ScanHistoryScreen(store: store), mode);
            if (shape != 'legacy') {
              await precacheImage(
                FileImage(file),
                t.element(find.byType(ScanHistoryScreen)),
                onError: (_, stack) {},
              );
            }
          });
          await t.pumpAndSettle();
          if (valid) {
            expect(t.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
            expect(t.getSize(find.byType(Image)), const Size(64, 64));
          }
          await t.runAsync(() async {
            await t.tap(find.text(record.itemName));
            await t.pumpAndSettle();
            if (shape != 'legacy') {
              await precacheImage(
                FileImage(file),
                t.element(find.byType(ScanDetailScreen)),
                onError: (_, stack) {},
              );
            }
          });
          await t.pumpAndSettle();
          if (valid) {
            final photo = find.descendant(
              of: find.byType(ScanDetailScreen),
              matching: find.byType(Image),
            );
            expect(t.widget<Image>(photo).fit, BoxFit.cover);
            expect(t.getSize(photo).height, 200);
          } else if (shape == 'legacy') {
            expect(find.byType(SvgPicture), findsWidgets);
          } else {
            expect(find.byIcon(Icons.broken_image_outlined), findsWidgets);
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final mode in Brightness.values) {
    testWidgets('${mode.name} category tiles select with H3 styling', (
      t,
    ) async {
      await pump(
        t,
        ScanHistoryScreen(store: HistoryTestStore([h3Record()])),
        mode,
      );
      final p = mode == Brightness.dark ? ElioTokens.dark : ElioTokens.light;
      Material tile(String label) => t.widget<Material>(
        find
            .descendant(
              of: find.widgetWithText(HistoryCategoryTile, label),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        (tile('Semua scan').shape as RoundedSuperellipseBorder).side.color,
        p.primary,
      );
      await t.tap(find.widgetWithText(HistoryCategoryTile, 'B3 · Berbahaya'));
      await t.pump();
      expect(
        (tile('B3 · Berbahaya').shape as RoundedSuperellipseBorder).side.width,
        2,
      );
      expect(
        t.widget<Text>(find.text('Semua scan')).style?.fontFamily,
        ElioTokens.fontSans,
      );
    });
    testWidgets('${mode.name} detail title keeps H3 sans styling', (t) async {
      final record = h3Record();
      await pump(
        t,
        ScanDetailScreen(record: record, store: HistoryTestStore([record])),
        mode,
      );
      expect(
        t.widget<Text>(find.text('Detail scan')).style?.fontFamily,
        ElioTokens.fontSans,
      );
    });
    testWidgets('${mode.name} empty scan CTA keeps H3 rounded styling', (
      t,
    ) async {
      await pump(t, ScanHistoryScreen(store: HistoryTestStore()), mode);
      final button = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Mulai scan'),
      );
      expect(button.style?.shape?.resolve({}), isA<StadiumBorder>());
    });
  }
}
