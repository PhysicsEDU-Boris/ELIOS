// H3-cards: scan card grid, photo frame and photo viewer (decision 0187).
import 'dart:io';
import 'package:elio/Screens/history_photo_viewer.dart';
import 'package:elio/Screens/scan_history_screen.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/models/scan_record.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/widgets/history_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import '../screens/auth_test_support.dart' show loadElioFonts;
import 'h3_fixture.dart';

ScanRecord _rec(String id, String name, int ok, {String? photo}) => ScanRecord(
  id: id,
  time: DateTime.now(),
  trophies: ok * 10,
  itemName: name,
  category: ScanCategory.recyclable,
  cropPhotoPath: photo,
  questions: [
    for (var i = 0; i < 3; i++)
      RecordQuestion(
        question: 'Q$i',
        yourAnswer: 'a',
        rightAnswer: 'a',
        isCorrect: i < ok,
      ),
  ],
);

String _photo(int w, int h) {
  final f = File('${Directory.systemTemp.path}/h3_cards_${w}x$h.png');
  if (!f.existsSync()) {
    f.writeAsBytesSync(
      img.encodePng(
        img.fill(
          img.Image(width: w, height: h),
          color: img.ColorRgb8(40, 100, 180),
        ),
      ),
    );
  }
  return f.path;
}

void main() {
  setUpAll(() async {
    debugSetL10n(const Locale('id'));
    await loadElioFonts();
  });
  tearDownAll(() => debugSetL10n(const Locale('en')));

  Future<void> pump(
    WidgetTester t,
    Widget child, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ElioLightTheme.data,
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: c!,
        ),
        home: child,
      ),
    );
    await t.pump();
  }

  final long =
      'Modul buck converter dengan kabel dan baterai litium yang sangat panjang';

  testWidgets('long names take two lines, cards in a row share one height', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await pump(
      t,
      ScanHistoryScreen(
        store: HistoryTestStore([_rec('a', long, 3), _rec('b', 'Kardus', 0)]),
        showHeader: false,
      ),
    );
    final cards = find.byType(HistoryScanCard);
    await t.scrollUntilVisible(
      cards.first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(cards, findsNWidgets(2));
    expect(t.getSize(cards.at(0)).height, t.getSize(cards.at(1)).height);
    final name = t.widget<Text>(find.text(long));
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
    // One target per card with the spoken summary.
    expect(
      find.bySemanticsLabel('$long, Daur ulang, 3 dari 3 benar, +30 XP'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('no overflow at 320 dp and text scale 1.3', (t) async {
    await pump(
      t,
      ScanHistoryScreen(
        store: HistoryTestStore([
          _rec('a', long, 2),
          _rec('b', 'Kardus', 0),
          _rec('c', 'Botol', 1),
        ]),
        showHeader: false,
      ),
      size: const Size(320, 700),
      scale: 1.3,
    );
    for (var i = 0; i < 6; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -250));
      await t.pump();
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('score bar fill is correct / total; 0 hides it', (t) async {
    await pump(
      t,
      Scaffold(
        body: Row(
          children: [
            Expanded(child: HistoryScanCard(_rec('a', 'A', 2), onTap: () {})),
            Expanded(child: HistoryScanCard(_rec('b', 'B', 0), onTap: () {})),
          ],
        ),
      ),
    );
    final fill = find.byKey(const ValueKey('score_fill'));
    expect(fill, findsOneWidget); // B (0/3) has no fill
    expect(
      t.widget<FractionallySizedBox>(fill).widthFactor,
      closeTo(2 / 3, 1e-9),
    );
  });

  for (final (shape, w, h) in [('portrait', 300, 900), ('wide', 1600, 200)]) {
    testWidgets('$shape photo is fully visible in the viewer', (t) async {
      final r = _rec('v', 'Botol', 1, photo: _photo(w, h));
      await t.runAsync(() async {
        await pump(t, HistoryPhotoViewer(record: r));
        await precacheImage(
          FileImage(File(r.cropPhotoPath!)),
          t.element(find.byType(HistoryPhotoViewer)),
        );
      });
      await t.pump();
      final image = find.byType(Image);
      expect(t.widget<Image>(image).fit, BoxFit.contain);
      // The image box fits the screen, so contain shows the whole photo.
      final box = t.getRect(image);
      expect(box.width <= 390 && box.height <= 844, isTrue);
      await t.pump(const Duration(seconds: 3)); // hint timer
    });
  }

  testWidgets('photo tap opens the viewer; back and swipe down close it', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    final r = _rec('v', 'Botol', 1, photo: _photo(640, 360));
    await pump(t, ScanDetailScreen(record: r, store: HistoryTestStore([r])));
    Future<void> openByPhoto() async {
      await t.tap(find.bySemanticsLabel('Foto scan Botol').first);
      await t.pumpAndSettle();
      expect(find.byType(HistoryPhotoViewer), findsOneWidget);
    }

    await openByPhoto();
    await t.binding.handlePopRoute(); // Android back
    await t.pumpAndSettle();
    expect(find.byType(HistoryPhotoViewer), findsNothing);

    await openByPhoto();
    await t.drag(find.byType(InteractiveViewer), const Offset(0, 300));
    await t.pumpAndSettle();
    expect(find.byType(HistoryPhotoViewer), findsNothing);
    expect(find.byType(ScanDetailScreen), findsOneWidget);
    semantics.dispose();
  });
}
