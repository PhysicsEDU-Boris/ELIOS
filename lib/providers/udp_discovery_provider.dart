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

  /// Starts listening for MaixCAM2 broadcast packets on port [_discoveryPort].
  ///
  /// This method is idempotent — calling it while already listening is a no-op.
  Future<void> startListening() async {
    // Guard: don't bind again if already listening or already discovered.
    if (_udpSocket != null || state != null) return;

    try {
      debugPrint('[UdpDiscovery] Binding UDP receiver on port $_discoveryPort');

      // Bind to all network interfaces on the discovery port.
      _udpSocket = await UDP.bind(
        Endpoint.any(port: const Port(_discoveryPort)),
      );

      debugPrint('[UdpDiscovery] UDP socket bound, listening for datagrams...');

      // Listen to the incoming datagram stream.
      _subscription = _udpSocket!.asStream().listen(_handleDatagram);
    } catch (e, stackTrace) {
      debugPrint('[UdpDiscovery] Failed to bind UDP socket: $e');
      debugPrintStack(stackTrace: stackTrace);
      // Clean up any partial state on failure.
      _cleanup();
    }
  }

  /// Handles an incoming UDP datagram.
  ///
  /// Expected payload (UTF-8 JSON): {"ip": "192.168.x.x"}
  void _handleDatagram(Datagram? datagram) {
    if (datagram == null) return;

    try {
      // Decode the raw bytes to a UTF-8 string.
      final rawPayload = utf8.decode(datagram.data);
      debugPrint('[UdpDiscovery] Received datagram: $rawPayload');

      // Parse the JSON payload.
      final decoded = jsonDecode(rawPayload) as Map<String, dynamic>;
      final ip = decoded['ip'] as String?;

      if (ip == null || ip.isEmpty) {
        debugPrint('[UdpDiscovery] Payload missing "ip" field, ignoring.');
        return;
      }

      // Validate basic IPv4 format (4 octets, each 0–255).
      final parts = ip.split('.');
      if (parts.length != 4) {
        debugPrint('[UdpDiscovery] Invalid IP format: $ip');
        return;
      }

      final valid = parts.every((octet) {
        final n = int.tryParse(octet);
        return n != null && n >= 0 && n <= 255;
      });

      if (!valid) {
        debugPrint('[UdpDiscovery] IP octets out of range: $ip');
        return;
      }

      debugPrint('[UdpDiscovery] Robot discovered at $ip');

      // Emit the discovered IP address to all listeners.
      state = ip;

      // Immediately close the socket — discovery is complete.
      _cleanup();
    } on FormatException catch (e) {
      debugPrint('[UdpDiscovery] Malformed JSON payload: $e');
    } catch (e) {
      debugPrint('[UdpDiscovery] Error processing datagram: $e');
    }
  }

  /// Stops listening and releases the UDP socket.
  ///
  /// This is called automatically by Riverpod's `ref.onDispose`,
  /// and also invoked after a successful discovery.
  void stopListening() {
    _cleanup();
  }

  /// Internal cleanup: cancel the stream subscription and close the socket.
  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _udpSocket?.close();
    _udpSocket = null;
    debugPrint('[UdpDiscovery] UDP socket closed and cleaned up.');
  }
}
