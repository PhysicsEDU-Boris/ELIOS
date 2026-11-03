import 'package:elio/Screens/config/robot_wifi_qr_sheet.dart';
import 'package:elio/services/robot_wifi.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QR text is the standard WIFI: format, escaped like the firmware parses it', () {
    expect(wifiQrPayload('boris', 'secret123'), 'WIFI:T:WPA;S:boris;P:secret123;;');
    expect(wifiQrPayload('my;net', r'pa:ss\w,"d'), r'WIFI:T:WPA;S:my\;net;P:pa\:ss\\w\,\"d;;');
  });

  test('validators match the firmware limits', () {
    expect(validateWifiName(''), isNotNull);
    expect(validateWifiName('x' * 32), isNull);
    expect(validateWifiName('x' * 33), isNotNull);
    expect(validateWifiPassword('short'), isNotNull);
    expect(validateWifiPassword('secret123'), isNull);
    expect(validateWifiPassword('x' * 64), isNotNull);
    expect(validateWifiPassword('pässword1'), isNotNull);
  });

  test('candidate hosts: every other address on private /24s only', () {
    final hosts = candidateHosts(['10.51.200.145', '100.79.64.70', '127.0.0.1', '10.51.200.145']);
    expect(hosts.length, 253);
    expect(hosts, contains('10.51.200.84'));
    expect(hosts, isNot(contains('10.51.200.145')));
    expect(candidateHosts(['192.168.4.100', '172.20.1.5']).length, 506);
    expect(candidateHosts(['8.8.8.8', 'fe80::1']), isEmpty);
  });

  testWidgets('sheet shows the QR only for a valid name and password', (t) async {
    await t.pumpWidget(ProviderScope(
        child: MaterialApp(home: Scaffold(body: ElioTheme.wrap(const RobotWifiQrSheet())))));
    await t.enterText(find.widgetWithText(TextFormField, 'Hotspot name (SSID)'), 'boris');
    await t.enterText(find.widgetWithText(TextFormField, 'Hotspot password'), 'short');
    await t.tap(find.text('Show QR'));
    await t.pump();
    expect(find.text('Password: 8 to 63 plain characters'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);

    await t.enterText(find.widgetWithText(TextFormField, 'Hotspot password'), 'secret123');
    await t.tap(find.text('Show QR'));
    await t.pump();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.bySemanticsLabel('Wi-Fi QR code for boris'), findsOneWidget);
  });
}
