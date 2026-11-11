// G4 render harness: every Figma frame of "G4 · Daily Guides (app)" in light/dark and en/id at
// 390 x 844, driven through the real screens with a fake backend and camera. With G4_RENDER=1 it
// writes docs/test-results/g4-guides/app/<mode>-<lang>-<frame>.png and Figma | app side-by-sides
// (compare/); a plain run only checks that every frame renders without an exception or overflow.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:elio/Screens/tabs/elearning/daily_guides_page.dart';
import 'package:elio/Screens/tabs/elearning/guides/guide_issue_page.dart';
import 'package:elio/Screens/tabs/elearning/guides/guide_lab_page.dart';
import 'package:elio/Screens/tabs/elearning/guides/guide_quiz_page.dart';
import 'package:elio/Screens/tabs/elearning/guides/guide_widgets.dart';
import 'package:elio/Screens/tabs/elearning_tab.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/services/daily_guide_service.dart';
import 'package:elio/services/elearning_content_service.dart';
import 'package:elio/services/frame_source/frame_source.dart';
import 'package:elio/services/frame_source/phone_frame_source.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:elio/widgets/learn/learn_l3.dart' show LearnIntroHost;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auth_test_support.dart' show loadElioFonts;
import 'g4_fixture.dart';
import 'g4_test_app.dart';

const _figma = 'docs/design/g4-figma';
const _out = 'docs/test-results/g4-guides/app';
final _write = Platform.environment['G4_RENDER'] == '1';

class FakeCamera extends PhoneFrameSource {
  final _photo = testPhoto();
  @override
  Future<void> initialize() async {}
  @override
  Future<CapturedFrame?> capture() async => CapturedFrame(
    bytes: _photo,
    width: 600,
    height: 400,
    timestamp: DateTime(2026, 11, 8),
  );
  @override
  Widget buildPreview({BoxFit fit = BoxFit.cover}) =>
      const ColoredBox(color: Color(0xFF334155));
}

void main() {
  setUpAll(loadElioFonts);
  setUp(() => LearnIntroHost.played = true);

  for (final dark in [false, true]) {
    for (final lang in ['en', 'id']) {
      final m = '${dark ? 'dark' : 'light'}-$lang';

      Future<void> render(
        WidgetTester t,
        String frame,
        Widget Function(DailyGuide g) home, {
        FakeGuidesServer? server,
        DailyGuideService? service,
        Future<void> Function()? act,
        Map<String, Object> prefs = const {},
      }) async {
        SharedPreferences.setMockInitialValues({
          'daily-guide-notified': '2099-01-01',
          ...prefs,
        });
        debugSetL10n(Locale(lang));
        guideImageCache = PhotoCache(testPhoto());
        QuizTtsService.instance.mockSpeak = (_) async {};
        QuizTtsService.instance.mockStop = () async {};
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        t.view.padding = const FakeViewPadding(top: 28);
        t.view.viewPadding = const FakeViewPadding(top: 28);
        addTearDown(t.view.reset);
        final g = (await fakeService().load()).guides.first;
        await t.pumpWidget(
          RepaintBoundary(
            key: const Key('capture'),
            child: G4TestApp(
              overrides: guideOverrides(
                server: server ?? FakeGuidesServer(),
                service: service,
              ),
              home: home(g),
              locale: ValueNotifier(Locale(lang)),
              dark: dark,
            ),
          ),
        );
        Future<void> settle() async {
          for (var i = 0; i < 8; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await t.pump(const Duration(milliseconds: 120));
          }
        }

        await settle();
        if (act != null) {
          await act();
          await settle();
        }
        expect(t.takeException(), isNull);
        if (_write) {
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('capture')),
          );
          await t.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            image.dispose();
            final png = data.buffer.asUint8List();
            Directory('$_out/compare').createSync(recursive: true);
            File('$_out/$m-$frame.png').writeAsBytesSync(png);
            final ref = img.decodePng(
              File(
                '$_figma/${dark ? 'dark' : 'light'}-$frame.png',
              ).readAsBytesSync(),
            )!;
            final app = img.decodePng(png)!;
            final side = img.Image(
              width: 390 * 2 + 12,
              height: ref.height > app.height ? ref.height : app.height,
            );
            img.fill(side, color: img.ColorRgb8(255, 0, 255));
            img.compositeImage(side, ref);
            img.compositeImage(side, app, dstX: 390 + 12);
            File(
              '$_out/compare/$m-$frame.png',
            ).writeAsBytesSync(img.encodePng(side));
          });
        }
        await t.pumpWidget(const SizedBox());
        await t.pump(
          const Duration(seconds: 25),
        ); // drain the 20 s feed timeout
        guideImageCache = null;
      }

      Future<void> answer(WidgetTester t, String option) async {
        await t.tap(find.text(option).hitTestable());
        await t.pump();
        await t.tap(
          find.widgetWithText(FilledButton, l10n.g4Check).hitTestable(),
        );
        await t.pump(const Duration(milliseconds: 400));
      }

      Future<void> next(WidgetTester t, String label) async {
        await t.tap(find.widgetWithText(FilledButton, label).hitTestable());
        await t.pump(const Duration(milliseconds: 500));
      }

      String o(String en, String id) => lang == 'id' ? id : en;

      testWidgets(
        '$m 01 hub',
        (t) => render(
          t,
          '01-hub',
          (_) => Scaffold(
            body: LearnHub(
              streams: LearnStreams(
                ElearningContentService(firestore: FakeFirebaseFirestore()),
              ),
              onRetry: () {},
            ),
          ),
        ),
      );

      testWidgets('$m 02 feed', (t) {
        final server = FakeGuidesServer()
          ..stops[older] = {'story': 'x', 'physics': 'y'};
        return render(
          t,
          '02-feed',
          (_) => const DailyGuidesPage(),
          server: server,
        );
      });

      testWidgets('$m 03 issue', (t) {
        final server = FakeGuidesServer()
          ..stops[date] = {'story': '2026-11-08T03:00:00Z'};
        return render(
          t,
          '03-issue',
          (g) => GuideIssuePage(guide: g),
          server: server,
        );
      });

      testWidgets(
        '$m 04 quiz card 1',
        (t) => render(t, '04-quiz-card1', (g) => GuideQuizPage(guide: g)),
      );

      testWidgets(
        '$m 05 quiz card 2 answered',
        (t) => render(
          t,
          '05-quiz-card2',
          (g) => GuideQuizPage(guide: g),
          act: () async {
            await answer(t, 'v = s ÷ t');
            await next(t, l10n.g4NextCard);
            await answer(t, '2,400 m/s');
          },
        ),
      );

      testWidgets(
        '$m 06 quiz result',
        (t) => render(
          t,
          '06-quiz-result',
          (g) => GuideQuizPage(guide: g),
          act: () async {
            await answer(t, 'v = s ÷ t');
            await next(t, l10n.g4NextCard);
            await answer(t, '2,400 m/s');
            await next(t, l10n.g4NextCard);
            await answer(
              t,
              o('More energy and sediment', 'Lebih banyak energi dan sedimen'),
            );
            await next(t, l10n.g4SeeResult);
          },
        ),
      );

      testWidgets(
        '$m 07 lab brief',
        (t) => render(t, '07-lab-brief', (g) => GuideLabPage(guide: g)),
      );

      Future<void> photos(WidgetTester t) async {
        await t.tap(find.text(l10n.g4ThreePhotos));
        await t.pump();
        for (var i = 0; i < 3; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await t.pump();
          await t.tap(find.text(l10n.g4TakePhoto));
          for (var k = 0; k < 6; k++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 60)),
            );
            await t.pump();
          }
        }
        await t.tap(find.text(l10n.g4Send));
        await t.pump();
      }

      testWidgets('$m 08 lab checking', (t) {
        final hold = Completer<Map<String, dynamic>>();
        final server = _HeldLab(hold.future);
        return render(
          t,
          '08-lab-checking',
          (g) => GuideLabPage(guide: g, camera: FakeCamera()),
          server: server,
          act: () => photos(t),
        );
      });

      testWidgets(
        '$m 09 lab approved',
        (t) => render(
          t,
          '09-lab-approved',
          (g) => GuideLabPage(guide: g, camera: FakeCamera()),
          act: () => photos(t),
        ),
      );

      testWidgets('$m 10 lab try again', (t) {
        final server = FakeGuidesServer()
          ..lab = {
            'verdict': 'retry',
            'reason_en':
                'I can see the tray and the cork, but no ruler or timer. Show the timer next to the tray at the start and the finish.',
            'reason_id':
                'Nampan dan gabus terlihat, tetapi penggaris atau pengatur waktu tidak. Tunjukkan pengatur waktu di samping nampan saat mulai dan selesai.',
            'checklist': [true, true, false],
          };
        return render(
          t,
          '10-lab-retry',
          (g) => GuideLabPage(guide: g, camera: FakeCamera()),
          server: server,
          act: () => photos(t),
        );
      });

      testWidgets(
        '$m 11 feed loading',
        (t) => render(
          t,
          '11-feed-loading',
          (_) => const DailyGuidesPage(),
          service: DailyGuideService(
            fetch: () => Completer<String>().future,
            fetchContent: (_) async => '{}',
          ),
        ),
      );

      testWidgets(
        '$m 12 feed offline + empty',
        (t) => render(
          t,
          '12-feed-offline-empty',
          (_) => const DailyGuidesPage(),
          prefs: {'daily-guide-manifest-v1': manifest([])},
          service: DailyGuideService(
            fetch: () => Future.error(const SocketException('offline')),
            fetchContent: (_) async => '{}',
          ),
        ),
      );
    }
  }
}

/// A backend whose lab check never answers (the checking screen).
class _HeldLab extends FakeGuidesServer {
  _HeldLab(this.hold);
  final Future<Map<String, dynamic>> hold;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> body) =>
      body['op'] == 'lab' ? hold : super.call(body);
}
