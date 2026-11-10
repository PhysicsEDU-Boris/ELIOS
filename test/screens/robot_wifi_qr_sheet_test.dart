import 'package:barcode/barcode.dart';
import 'package:elio/Screens/config/robot_wifi_qr_sheet.dart';
import 'package:elio/services/robot_wifi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// ELIOS 3 Robot Wi-Fi QR sheet (decision 0204, Figma 629:91020 / 629:91453).
Widget _host({ThemeMode mode = ThemeMode.light}) => ProviderScope(
      child: MaterialApp(
        themeMode: mode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => showRobotWifiQrSheet(context), child: const Text('open')),
            ),
          ),
        ),
      ),
    );

SvgStringLoader _qrFor(String ssid, String pass) =>
    SvgStringLoader(Barcode.qrCode().toSvg(wifiQrPayload(ssid, pass), width: 260, height: 260));

Future<void> _open(WidgetTester t, {ThemeMode mode = ThemeMode.light}) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(_host(mode: mode));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

Future<void> _type(WidgetTester t, String ssid, String pass) async {
  await t.enterText(find.byType(TextFormField).at(0), ssid);
  await t.enterText(find.byType(TextFormField).at(1), pass);
  await t.tap(find.text('Show QR'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Figma header, labels above the fields, tip only with a QR', (t) async {
    await _open(t);
    expect(find.text('Robot Wi-Fi QR'), findsOneWidget);
    expect(find.text('Join ELIOS to a hotspot or Wi-Fi'), findsOneWidget);
    expect(find.text('Hotspot name (SSID)'), findsOneWidget);
    expect(find.text('Hotspot password'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.textContaining('Lower the screen brightness'), findsNothing);
    expect(t.getSize(find.byTooltip('Close')).height, greaterThanOrEqualTo(48));
  });

  testWidgets('fields → QR: exact firmware payload, cleared on edit, updated on Show', (t) async {
    await _open(t);
    await _type(t, 'ElioTest', 'dummy-pass-1');
    expect(t.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader, _qrFor('ElioTest', 'dummy-pass-1'));
    expect(find.bySemanticsLabel('Wi-Fi QR code for ElioTest'), findsOneWidget);
    expect(find.textContaining('Lower the screen brightness'), findsOneWidget);

    await t.enterText(find.byType(TextFormField).at(0), 'Other;Net');
    await t.pump();
    expect(find.byType(SvgPicture), findsNothing, reason: 'a stale QR never stays on screen');

    await t.tap(find.text('Show QR'));
    await t.pumpAndSettle();
    expect(t.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader, _qrFor('Other;Net', 'dummy-pass-1'));
  });

  testWidgets('QR stays black-on-white with a quiet zone in dark mode', (t) async {
    await _open(t, mode: ThemeMode.dark);
    await _type(t, 'ElioTest', 'dummy-pass-1');
    final card = t.widget<Container>(
        find.ancestor(of: find.byType(SvgPicture), matching: find.byType(Container)).first);
    expect((card.decoration! as BoxDecoration).color, Colors.white);
    expect(card.padding, const EdgeInsets.all(16));
  });

  testWidgets('close button dismisses the sheet', (t) async {
    await _open(t);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.byType(RobotWifiQrSheet), findsNothing);
  });
}
