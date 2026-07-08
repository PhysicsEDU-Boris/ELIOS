import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:udp/udp.dart';

/// ── UDP Discovery State ──────────────────────────────────────────────
/// Represents the current state of the UDP auto-discovery listener.
/// - `null` means no robot has been discovered yet (idle or listening).
/// - A non-null `String` contains the discovered IPv4 address.
///
/// The discovery flow:
///   1. Bind a UDP receiver to port 5000 on all interfaces.
///   2. Listen for incoming datagrams from MaixCAM2.
///   3. Parse the JSON payload: {"ip": "192.168.x.x"}.
///   4. Emit the IP address string and close the socket.

/// The Riverpod provider that exposes the [UdpDiscoveryNotifier].
final udpDiscoveryProvider = NotifierProvider<UdpDiscoveryNotifier, String?>(
  UdpDiscoveryNotifier.new,
);

/// ── UDP Discovery Port ───────────────────────────────────────────────
/// The UDP port that MaixCAM2 broadcasts its IP on after provisioning.
const int _discoveryPort = 5000;

/// ── Notifier ─────────────────────────────────────────────────────────
/// Manages the full lifecycle of the UDP socket: bind → listen → parse → close.
class UdpDiscoveryNotifier extends Notifier<String?> {
  /// Internal reference to the bound UDP socket.
  UDP? _udpSocket;

  /// Internal stream subscription for incoming datagrams.
  StreamSubscription<Datagram?>? _subscription;

  @override
  String? build() {
    // Clean up the socket when the provider is disposed (e.g., screen navigated away).
    ref.onDispose(_cleanup);
    return null;
  }

  /// Start listening for MaixCAM2 discovery broadcasts.
  /// No-op if already listening OR if a device was already discovered this
  /// session AND [force] is false.
  Future<void> startListening({bool force = false}) async {
    if (_udpSocket != null) return; // already bound
    if (state != null && !force) return; // already discovered, don't re-bind

    await _bind();
  }

  /// Clear any previous discovery result and start listening fresh.
  /// Call this every time the user opens the config screen or generates a
  /// new QR code so the previous home-WiFi discovery doesn't block the
  /// hotspot-scenario discovery.
  Future<void> resetAndListen() async {
    _cleanup();
    state = null; // clear stale discovered IP
    await _bind();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _bind() async {
    try {
      debugPrint('[UdpDiscovery] Binding on port $_discoveryPort...');

      // Bind on ALL interfaces so we receive:
      //   • Subnet broadcasts (255.255.255.255) — home WiFi scenario
      //   • Direct unicast from MaixCAM2 to app_ip — hotspot scenario
      //     (iOS does not reliably deliver hotspot-client broadcasts to
      //      apps on the hotspot-creating phone, so MaixCAM2 also sends
      //      a unicast directly to app_ip, which IS delivered).
      _udpSocket = await UDP.bind(
        Endpoint.any(port: const Port(_discoveryPort)),
      );

      debugPrint('[UdpDiscovery] Bound. Waiting for MaixCAM2...');
      _subscription = _udpSocket!.asStream().listen(_handleDatagram);
    } catch (e, st) {
      debugPrint('[UdpDiscovery] Bind failed: $e');
      debugPrintStack(stackTrace: st);
      _cleanup();
    }
  }

  void _handleDatagram(Datagram? datagram) {
    if (datagram == null) return;

    try {
      final raw = utf8.decode(datagram.data);
      debugPrint('[UdpDiscovery] Received from ${datagram.address.address}: $raw');

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final ip = decoded['ip'] as String?;

      if (ip == null || ip.isEmpty) return;

      // Basic IPv4 validation
      final parts = ip.split('.');
      if (parts.length != 4) return;

      final valid = parts.every((octet) {
        final n = int.tryParse(octet);
        return n != null && n >= 0 && n <= 255;
      });

      if (!valid) return;

      // Reject link-local and loopback — MaixCAM2 shouldn't send these
      // but guard anyway.
      if (ip.startsWith('169.254.') || ip.startsWith('127.')) {
        debugPrint('[UdpDiscovery] Ignoring bad IP: $ip');
        return;
      }

      debugPrint('[UdpDiscovery] MaixCAM2 discovered at $ip');
      state = ip;
      _cleanup(); // stop listening — discovery complete
    } on FormatException catch (e) {
      debugPrint('[UdpDiscovery] Bad JSON: $e');
    } catch (e) {
      debugPrint('[UdpDiscovery] Error: $e');
    }
  }

  void stopListening() => _cleanup();

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _udpSocket?.close();
    _udpSocket = null;
    debugPrint('[UdpDiscovery] Socket closed.');
  }
}
