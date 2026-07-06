// Copyright (c) Boris Agung, Irham Fajar

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';

// ── Wi-Fi SSID Provider ───────────────────────────────────────────────────────
/// A Riverpod FutureProvider that fetches the current Wi-Fi network name
/// using `network_info_plus`. Returns the cleaned SSID string or null
/// if the device is not connected to a Wi-Fi network or the SSID
/// cannot be determined (e.g., missing location permission on Android).
final wifiSsidProvider = FutureProvider<String?>((ref) async {
  final info = NetworkInfo();
  final rawSsid = await info.getWifiName();

  // NetworkInfo may return the SSID wrapped in quotes on some platforms.
  // Strip the surrounding quotes for a clean value.
  if (rawSsid != null) {
    return rawSsid.replaceAll('"', '');
  }
  return null;
});

// ── Best local IP ─────────────────────────────────────────────────────────────
/// Returns the most appropriate local IP for the active WiFi/hotspot.
///
/// Problem: [NetworkInfo.getWifiIP] sometimes returns a link-local address
/// (169.254.x.x) when the phone is simultaneously connected to a Mac via USB
/// cable, because iOS/Android exposes multiple virtual network interfaces and
/// the plugin picks the wrong one.
///
/// This function enumerates ALL interfaces and selects the best one by priority:
///   1. 192.168.x.x  — standard router / iPhone hotspot range
///   2. 10.x.x.x     — Android hotspot / corporate WiFi range
///   3. 172.16–31.x  — less common but valid private range
///   4. Any other non-link-local, non-loopback IPv4
///
/// Link-local (169.254.x.x) and loopback (127.x.x.x) are always rejected.
Future<String> getBestLocalIp() async {
  // Fast path: try network_info_plus first
  try {
    final ip = await NetworkInfo().getWifiIP();
    if (ip != null && _isGoodIp(ip)) {
      debugPrint('[Provision] getWifiIP returned: $ip');
      return ip;
    }
    debugPrint('[Provision] getWifiIP returned bad IP: $ip — falling back');
  } catch (e) {
    debugPrint('[Provision] getWifiIP error: $e — falling back');
  }

  // Fallback: enumerate all interfaces
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );

    debugPrint('[Provision] Network interfaces:');
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        debugPrint('  ${iface.name}: ${addr.address}');
      }
    }

    // Priority 1: 192.168.x.x
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.address.startsWith('192.168.') && _isGoodIp(addr.address)) {
          debugPrint(
            '[Provision] Selected 192.168 IP: ${addr.address} (${iface.name})',
          );
          return addr.address;
        }
      }
    }

    // Priority 2: 10.x.x.x
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.address.startsWith('10.') && _isGoodIp(addr.address)) {
          debugPrint(
            '[Provision] Selected 10.x IP: ${addr.address} (${iface.name})',
          );
          return addr.address;
        }
      }
    }

    // Priority 3: 172.16–31.x.x
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final parts = addr.address.split('.');
        if (parts.length == 4 && parts[0] == '172' && _isGoodIp(addr.address)) {
          final second = int.tryParse(parts[1]) ?? 0;
          if (second >= 16 && second <= 31) {
            debugPrint(
              '[Provision] Selected 172.x IP: ${addr.address} (${iface.name})',
            );
            return addr.address;
          }
        }
      }
    }

    // Priority 4: anything valid
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (_isGoodIp(addr.address)) {
          debugPrint(
            '[Provision] Selected fallback IP: ${addr.address} (${iface.name})',
          );
          return addr.address;
        }
      }
    }
  } catch (e) {
    debugPrint('[Provision] NetworkInterface.list error: $e');
  }

  debugPrint('[Provision] No valid IP found, using 0.0.0.0');
  return '0.0.0.0';
}

/// Returns true if [ip] is a usable private IPv4 address.
bool _isGoodIp(String ip) {
  if (ip.isEmpty || ip == '0.0.0.0') return false;
  if (ip.startsWith('127.')) return false; // loopback
  if (ip.startsWith('169.254.')) return false; // link-local (DHCP failed)
  return true;
}

// ── QR Payload Serializer ─────────────────────────────────────────────────────
/// Serializes the Wi-Fi credentials and host device information into a
/// minified JSON string for QR code encoding:
/// `{"ssid":"...","pass":"...","app_ip":"...","port":<int>}`
String serializeProvisioningPayload({
  required String ssid,
  required String password,
  required String appIp,
  required int port,
}) {
  return jsonEncode({
    'ssid': ssid,
    'pass': password,
    'app_ip': appIp,
    'port': port,
  });
}
