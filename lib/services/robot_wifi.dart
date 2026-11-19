import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/config_model.dart';

/// Robot Wi-Fi setup (decision 0178): the QR the MaixCAM2 scans to join a
/// hotspot, and the search that finds it there afterwards.

/// Same limits the firmware's `parse_wifi_qr` enforces (WPA-PSK via wpa_passphrase).
String? validateWifiName(String? v) {
  final n = utf8.encode(v ?? '').length;
  return n < 1 || n > 32 ? 'Wi-Fi name: 1 to 32 characters' : null;
}

String? validateWifiPassword(String? v) {
  final s = v ?? '';
  final plain = s.codeUnits.every((c) => c >= 32 && c < 127);
  return s.length < 8 || s.length > 63 || !plain ? 'Password: 8 to 63 plain characters' : null;
}

/// The standard `WIFI:` QR text (the same format Android's hotspot "Share" QR uses).
String wifiQrPayload(String ssid, String password) {
  String esc(String s) => s.replaceAllMapped(RegExp(r'[\\;,:"]'), (m) => '\\${m[0]}');
  return 'WIFI:T:WPA;S:${esc(ssid)};P:${esc(password)};;';
}

bool _isPrivate(List<int> o) =>
    o[0] == 10 || (o[0] == 172 && o[1] >= 16 && o[1] <= 31) || (o[0] == 192 && o[1] == 168);

/// Every other host on this device's private /24 networks.
// ponytail: assumes /24 (phone hotspots and the ELIOS AP are); a bigger LAN is not searched.
List<String> candidateHosts(Iterable<String> ownIps) {
  final hosts = <String>{};
  for (final ip in ownIps) {
    final o = ip.split('.').map(int.tryParse).toList();
    if (o.length != 4 || o.contains(null) || !_isPrivate(o.cast<int>())) continue;
    final prefix = '${o[0]}.${o[1]}.${o[2]}';
    for (var i = 1; i < 255; i++) {
      if (i != o[3]) hosts.add('$prefix.$i');
    }
  }
  return hosts.toList();
}

/// The first host on this device's networks with the ELIO WebSocket port open, or null.
Future<String?> findRobot({
  int port = EspConfig.maixCamPort,
  Duration timeout = const Duration(milliseconds: 900),
}) async {
  final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  final hosts = candidateHosts(ifaces.expand((i) => i.addresses).map((a) => a.address));
  if (hosts.isEmpty) return null;
  final found = Completer<String?>();
  var left = hosts.length;
  for (final host in hosts) {
    Socket.connect(host, port, timeout: timeout).then((s) {
      s.destroy();
      if (!found.isCompleted) found.complete(host);
    }, onError: (_) {
      if (--left == 0 && !found.isCompleted) found.complete(null);
    });
  }
  return found.future;
}
