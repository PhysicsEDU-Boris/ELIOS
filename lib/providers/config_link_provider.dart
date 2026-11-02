import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/websocket_service.dart';

/// The Config screen's connect attempt (decision 0145). Lives in a provider,
/// not the widget, so an attempt finishes cleanly when the tab is left.
class ConfigLink {
  const ConfigLink({this.attempting = false, this.failure});

  final bool attempting;

  /// The last failed attempt's reason; cleared by a new attempt, a cancel or
  /// Disconnect.
  final String? failure;
}

/// What the Connection card and hero show.
enum LinkView { notConnected, connecting, connected, failed }

LinkView linkView(String status, ConfigLink link) {
  if (link.attempting || status == 'Connecting...' || status == 'Reconnecting...') {
    return LinkView.connecting;
  }
  if (status == 'Connected') return LinkView.connected;
  return link.failure != null ? LinkView.failed : LinkView.notConnected;
}

final configLinkProvider =
    NotifierProvider<ConfigLinkNotifier, ConfigLink>(ConfigLinkNotifier.new);

class ConfigLinkNotifier extends Notifier<ConfigLink> {
  WebSocketService get _ws => WebSocketService();
  int _attempt = 0;

  @override
  ConfigLink build() => const ConfigLink();

  /// One attempt, no retries; on success the user's auto-reconnect setting
  /// takes over the live link.
  Future<bool> connect(String ip, int port, {required bool autoReconnect}) async {
    final attempt = ++_attempt;
    state = const ConfigLink(attempting: true);
    await _ws.disconnect(); // full teardown: no second socket
    _ws.resetConnectionState();
    _ws.configure(ip, port);
    final timeout = WebSocketService.connectTimeout;
    var timedOut = false;
    final ok = await _ws.connect().timeout(timeout + const Duration(seconds: 2), onTimeout: () {
      timedOut = true;
      return false;
    });
    if (attempt != _attempt) return ok; // cancelled and superseded
    if (ok) _ws.setAutoReconnect(autoReconnect);
    final failure = ok
        ? null
        : timedOut
            ? connectFailureReason(TimeoutException('connect'), '$ip:$port', timeout)
            : _ws.lastConnectError; // null after Cancel
    state = ConfigLink(failure: failure);
    return ok;
  }

  /// Cancel during an attempt, or Disconnect: stops reconnects too.
  Future<void> disconnect() async {
    _attempt++;
    state = const ConfigLink();
    await _ws.disconnect();
  }
}
