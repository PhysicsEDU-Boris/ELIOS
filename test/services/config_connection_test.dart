// C1 Config connection (decision 0145) against a fake robot: a WebSocket
// server on localhost, plus a TCP server that never answers.
import 'dart:async';
import 'dart:io';

import 'package:elio/providers/config_link_provider.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Upgrades every request; counts sockets that are open right now.
class _FakeRobot {
  late final HttpServer server;
  final sockets = <WebSocket>[];
  int accepted = 0;
  int get open => sockets.where((s) => s.closeCode == null).length;
  int get port => server.port;

  Future<void> start([int port = 0]) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    server.listen((req) async {
      final ws = await WebSocketTransformer.upgrade(req);
      accepted++;
      sockets.add(ws);
      ws.add('{"status": "Connected"}');
      ws.listen((_) {}, onDone: () {});
    });
  }

  /// The robot vanishes (Wi-Fi lost, robot off).
  Future<void> dropAll() async {
    for (final s in sockets) {
      await s.close();
    }
  }

  Future<void> stop() async {
    await dropAll();
    await server.close(force: true);
  }
}

Future<void> _until(bool Function() ok, {Duration max = const Duration(seconds: 6)}) async {
  final end = DateTime.now().add(max);
  while (!ok() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  final ws = WebSocketService();
  late ProviderContainer container;
  ConfigLinkNotifier link() => container.read(configLinkProvider.notifier);
  LinkView view() => linkView(ws.connectionStatus.value, container.read(configLinkProvider));

  setUp(() async {
    await ws.disconnect();
    ws.resetConnectionState();
    WebSocketService.connectTimeout = const Duration(seconds: 1);
    container = ProviderContainer();
  });
  tearDown(() async {
    container.dispose();
    await ws.disconnect();
    WebSocketService.connectTimeout = const Duration(seconds: 10);
  });

  test('linkView maps status and attempt to the four card states', () {
    expect(linkView('Disconnected', const ConfigLink()), LinkView.notConnected);
    expect(linkView('Disconnected', const ConfigLink(attempting: true)), LinkView.connecting);
    expect(linkView('Reconnecting...', const ConfigLink()), LinkView.connecting);
    expect(linkView('Connected', const ConfigLink()), LinkView.connected);
    expect(linkView('Disconnected', const ConfigLink(failure: 'x')), LinkView.failed);
  });

  test('failure reasons name the endpoint and the real timeout', () {
    expect(connectFailureReason(TimeoutException('t'), '1.2.3.4:8765', const Duration(seconds: 10)),
        startsWith('No answer from 1.2.3.4:8765 after 10 s.'));
    expect(connectFailureReason(const SocketException('Connection refused'), 'a:1', Duration.zero),
        contains('refused'));
    expect(connectFailureReason(const SocketException('Network is unreachable'), 'a:1', Duration.zero),
        contains('Join the ELIOS Wi-Fi'));
  });

  test('connect, then Disconnect: connected, then no reconnect loop', () async {
    final robot = _FakeRobot();
    await robot.start();
    addTearDown(robot.stop);

    expect(await link().connect('127.0.0.1', robot.port, autoReconnect: true), isTrue);
    expect(view(), LinkView.connected);
    await link().disconnect();
    expect(view(), LinkView.notConnected);
    await Future<void>.delayed(const Duration(milliseconds: 2600)); // past the 2 s reconnect delay
    expect(robot.accepted, 1, reason: 'no reconnect after Disconnect');
    expect(view(), LinkView.notConnected);
  });

  test('a second Connect closes the first socket (no duplicates)', () async {
    final robot = _FakeRobot();
    await robot.start();
    addTearDown(robot.stop);

    await link().connect('127.0.0.1', robot.port, autoReconnect: false);
    await link().connect('127.0.0.1', robot.port, autoReconnect: false);
    await _until(() => robot.open == 1);
    expect(robot.accepted, 2);
    expect(robot.open, 1);
  });

  test('wrong port / robot off: refused, with the reason', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final closedPort = probe.port;
    await probe.close();

    expect(await link().connect('127.0.0.1', closedPort, autoReconnect: true), isFalse);
    expect(view(), LinkView.failed);
    expect(container.read(configLinkProvider).failure, contains('refused'));
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    expect(ws.connectionStatus.value, 'Disconnected', reason: 'a failed Config attempt never retries');
  });

  test('wrong IP / no answer: times out after connectTimeout with that value', () async {
    final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(silent.close);
    silent.listen((_) {}); // accepts TCP, never answers the upgrade

    final sw = Stopwatch()..start();
    expect(await link().connect('127.0.0.1', silent.port, autoReconnect: false), isFalse);
    expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    expect(container.read(configLinkProvider).failure, startsWith('No answer from 127.0.0.1:${silent.port} after 1 s.'));
  });

  test('Cancel during connect really stops the attempt, with no error shown', () async {
    final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(silent.close);
    silent.listen((_) {});
    WebSocketService.connectTimeout = const Duration(seconds: 8);

    final sw = Stopwatch()..start();
    final attempt = link().connect('127.0.0.1', silent.port, autoReconnect: true);
    await _until(() => ws.connectionStatus.value == 'Connecting...');
    expect(view(), LinkView.connecting);
    await link().disconnect();
    expect(await attempt, isFalse);
    expect(sw.elapsed, lessThan(const Duration(seconds: 3)), reason: 'not the 8 s timeout');
    expect(view(), LinkView.notConnected);
    expect(container.read(configLinkProvider).failure, isNull);
    expect(ws.lastConnectError, isNull);
  });

  test('link lost with auto-reconnect on: reconnects when ELIO is back', () async {
    final robot = _FakeRobot();
    await robot.start();
    addTearDown(robot.stop);

    await link().connect('127.0.0.1', robot.port, autoReconnect: true);
    await robot.dropAll();
    await _until(() => ws.connectionStatus.value == 'Reconnecting...');
    expect(view(), LinkView.connecting);
    await _until(() => robot.accepted == 2 && ws.connectionStatus.value == 'Connected');
    expect(view(), LinkView.connected);
  });

  test('link lost with auto-reconnect off: offline, no retry', () async {
    final robot = _FakeRobot();
    await robot.start();
    addTearDown(robot.stop);

    await link().connect('127.0.0.1', robot.port, autoReconnect: false);
    await robot.dropAll();
    await _until(() => ws.connectionStatus.value == 'Disconnected');
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    expect(robot.accepted, 1);
    expect(view(), LinkView.notConnected);
  });

  test('turning auto-reconnect on applies to the live link', () async {
    final robot = _FakeRobot();
    await robot.start();
    addTearDown(robot.stop);

    await link().connect('127.0.0.1', robot.port, autoReconnect: false);
    ws.setAutoReconnect(true);
    await robot.dropAll();
    await _until(() => robot.accepted == 2 && ws.connectionStatus.value == 'Connected');
    expect(robot.accepted, 2, reason: 'the setting applies without reconnecting by hand');
  });
}
