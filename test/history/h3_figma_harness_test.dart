// H3-fix screenshot harness: renders the 9 Figma states (docs/design/h3-figma)
// in light and dark at 390 dp with the Figma sample text (Indonesian) and no
// photo, then writes app renders and Figma | app side-by-sides to
// docs/test-results/0184-h3-fix/. Isolated fixture; never touches real History.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:elio/Screens/question_explanation_screen.dart';
import 'package:elio/Screens/scan_history_screen.dart';
import 'package:elio/models/quiz_explanation.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/services/quiz_tts_service.dart';
import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/widgets/auth/auth_widgets.dart' show authPalette;
import 'package:elio/widgets/elio_bottom_nav.dart';
import 'package:elio/widgets/elio_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:image/image.dart' as img;
import '../screens/auth_test_support.dart' show loadElioFonts;
import 'h3_fixture.dart';

const _figma = 'docs/design/h3-figma';
const _out = 'docs/test-results/0184-h3-fix';

const figmaExplanation = QuizExplanation(
  summary: 'Kosongkan dan bilas wadah, lalu pisahkan baterainya.',
  correctAnswerReason:
      'Mesin daur ulang memilah plastik menurut jenisnya. Kotoran, sisa kabel atau baterai di dalam wadah mencemari seluruh tumpukan, dan satu muatan plastik bersih bisa ditolak. Mengosongkan dan membilas wadah menjaga plastiknya tetap murni, sehingga bisa dilelehkan dan dicetak menjadi barang baru.',
  selectedAnswerFeedback:
      'Baterai termasuk sampah B3 (berbahaya). Isinya litium, nikel atau kadmium dan bisa terbakar saat tergencet di truk sampah. Mencampurnya dengan plastik membahayakan petugas pemilah dan merusak daur ulang.',
  keyIdea:
      'Pisahkan sebelum memilah. Satu benda bisa berisi lebih dari satu jenis sampah: wadahnya plastik daur ulang, baterai di dalamnya B3.',
  steps: [
    'Keluarkan earbud dan baterainya.',
    'Buang debunya, bilas wadah dan biarkan kering.',
    'Masukkan wadah ke tempat sampah Daur ulang (anorganik).',
    'Bawa baterai ke kotak B3 di sekolah atau supermarket.',
  ],
  source: 'bank',
  bankId: 'harness',
  groundingStatus: GroundingStatus.bankGrounded,
);

DateTime _at(int h, int m, {int daysAgo = 0}) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day - daysAgo, h, m);
}

ScanRecord earphone({bool cached = true}) => ScanRecord(
  id: 'figma-earphone',
  time: _at(23, 29),
  trophies: 20,
  itemName: 'Wadah earphone',
  category: ScanCategory.recyclable,
  questions: [
    const RecordQuestion(
      question:
          'Mengapa wadah earphone plastik masuk ke tempat daur ulang, bukan sampah umum?',
      yourAnswer:
          'Plastiknya bisa dilelehkan dan dipakai lagi, jadi plastik baru yang dibuat lebih sedikit.',
      rightAnswer:
          'Plastiknya bisa dilelehkan dan dipakai lagi, jadi plastik baru yang dibuat lebih sedikit.',
      isCorrect: true,
      explanation: figmaExplanation,
    ),
    RecordQuestion(
      question:
          'Apa yang harus kamu lakukan sebelum mendaur ulang wadah earphone?',
      yourAnswer: 'Membuangnya bersama baterai.',
      rightAnswer:
          'Kosongkan, bilas dan keluarkan baterai atau komponen elektronik dulu.',
      isCorrect: false,
      explanation: cached ? figmaExplanation : null,
    ),
    const RecordQuestion(
      question:
          'Wadah plastik kosong mengapung di air padahal plastik lebih padat. Mengapa?',
      yourAnswer:
          'Udara di dalamnya membuat massa jenis rata-ratanya lebih kecil dari air.',
      rightAnswer:
          'Udara di dalamnya membuat massa jenis rata-ratanya lebih kecil dari air.',
      isCorrect: true,
      explanation: figmaExplanation,
    ),
  ],
);

ScanRecord _simple(
  String id,
  String name,
  ScanCategory c,
  DateTime t,
  int ok,
) => ScanRecord(
  id: id,
  time: t,
  itemName: name,
  category: c,
  trophies: ok * 10,
  questions: [
    for (var i = 0; i < 3; i++)
      RecordQuestion(
        question: 'Soal $i',
        yourAnswer: 'a',
        rightAnswer: 'a',
        isCorrect: i < ok,
      ),
  ],
);

List<ScanRecord> figmaRecords() => [
  _simple('e', 'Wadah earphone', ScanCategory.recyclable, _at(23, 29), 3),
  _simple('b', 'Modul buck converter', ScanCategory.b3, _at(22, 47), 0),
  _simple('j', 'Jalangkote', ScanCategory.organic, _at(21, 15), 1),
  _simple(
    'p',
    'Gelas plastik',
    ScanCategory.recyclable,
    _at(12, 0, daysAgo: 1),
    2,
  ),
  _simple('t', 'Baterai', ScanCategory.b3, _at(11, 0, daysAgo: 1), 0),
];

class FigmaStore extends HistoryTestStore {
  FigmaStore(super.records, {this.loaded = true});
  final bool loaded;
  @override
  bool get isLoaded => loaded;
  @override
  int get totalTrophies => 442;
  @override
  Future<List<ScanRecord>> load({bool force = false}) =>
      loaded ? Future.value(data) : Completer<List<ScanRecord>>().future;
}

/// The History tab as HomeShell hosts it: profile top bar, screen, bottom nav.
Widget shell(Widget child) => Builder(
  builder: (context) => Scaffold(
    backgroundColor: authPalette(context).background,
    body: Column(
      children: [
        SafeArea(
          bottom: false,
          child: ElioTopBar(
            title: 'Riwayat',
            subtitle: 'Hasil scan, kuis, dan piala',
            onOpenProfile: () {},
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    ),
    floatingActionButtonLocation: const ElioControlFabLocation(),
    floatingActionButton: ElioControlButton(onTap: () {}),
    bottomNavigationBar: ElioBottomNav(
      currentIndex: 4,
      onSelectTab: (_) {},
      onControl: () {},
    ),
  ),
);

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

  for (final mode in Brightness.values) {
    final m = mode.name;
    Future<void> render(
      WidgetTester t,
      String name,
      Widget screen, {
      Future<void> Function()? act,
    }) async {
      final ref = img.decodePng(
        File('$_figma/$m-$name.png').readAsBytesSync(),
      )!;
      final size = Size(390, ref.height.toDouble());
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      t.view.padding = const FakeViewPadding(top: 28);
      t.view.viewPadding = const FakeViewPadding(top: 28);
      addTearDown(t.view.reset);
      QuizTtsService.instance.mockStop = () async {};
      QuizTtsService.instance.mockSpeak = (_) => Completer<void>().future;
      AiQuizService.instance.mockSendExecute =
          (p, {imageBytes, isUser = false}) =>
              Completer<String?>().future; // explanation stays loading
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
            home: screen,
          ),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      if (act != null) await act();
      expect(t.takeException(), isNull);
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        image.dispose();
        final png = data.buffer.asUint8List();
        Directory('$_out/app').createSync(recursive: true);
        Directory('$_out/compare').createSync(recursive: true);
        File('$_out/app/$m-$name.png').writeAsBytesSync(png);
        final app = img.decodePng(png)!;
        final side = img.Image(width: 390 * 2 + 12, height: ref.height);
        img.fill(side, color: img.ColorRgb8(255, 0, 255));
        img.compositeImage(side, ref);
        img.compositeImage(side, app, dstX: 390 + 12);
        File(
          '$_out/compare/$m-$name.png',
        ).writeAsBytesSync(img.encodePng(side));
      });
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 60)); // drain load timeouts
    }

    Widget explanation({bool cached = true}) {
      final r = earphone(cached: cached);
      return QuestionExplanationScreen(
        record: r,
        questionIndex: 1,
        store: FigmaStore([r]),
      );
    }

    testWidgets('$m 01 history list', (t) async {
      await render(
        t,
        '01-history-list',
        shell(
          ScanHistoryScreen(
            store: FigmaStore(figmaRecords()),
            showHeader: false,
          ),
        ),
      );
    });
    testWidgets('$m 02 scan detail', (t) async {
      final r = earphone();
      await render(
        t,
        '02-scan-detail',
        ScanDetailScreen(record: r, store: FigmaStore([r])),
      );
    });
    testWidgets('$m 03 loading list', (t) async {
      await render(
        t,
        '03-loading-list',
        shell(
          ScanHistoryScreen(
            store: FigmaStore(const [], loaded: false),
            showHeader: false,
          ),
        ),
      );
    });
    testWidgets('$m 04 loading detail', (t) async {
      final r = earphone();
      await render(
        t,
        '04-loading-detail',
        ScanDetailScreen(record: r, store: FigmaStore([r], loaded: false)),
      );
    });
    testWidgets('$m 05 empty', (t) async {
      await render(
        t,
        '05-empty',
        shell(
          ScanHistoryScreen(store: FigmaStore(const []), showHeader: false),
        ),
      );
    });
    testWidgets('$m 06 explanation', (t) async {
      await render(
        t,
        '06-explanation',
        explanation(),
        act: () async {
          // Listen on the question and the two text sections only; Key idea
          // and Steps are read with the whole question (README).
          expect(find.byTooltip('Dengarkan'), findsNWidgets(3));
          expect(find.text('IDE UTAMA'), findsOneWidget);
        },
      );
    });
    testWidgets('$m 07 explanation reading', (t) async {
      await render(
        t,
        '07-explanation-reading',
        explanation(),
        act: () async {
          await t.tap(find.byTooltip('Dengarkan').at(1));
          await t.pump();
        },
      );
    });
    testWidgets('$m 08 export sheet', (t) async {
      await render(
        t,
        '08-export-sheet',
        explanation(),
        act: () async {
          await t.tap(find.text('Ekspor PDF'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 600));
        },
      );
    });
    testWidgets('$m 09 explanation loading', (t) async {
      await render(t, '09-explanation-loading', explanation(cached: false));
    });
  }
}
