import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  static final WebSocketService _instance = WebSocketService._internal();

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  final StreamController<Uint8List> _framesController =
      StreamController<Uint8List>.broadcast();
  final StreamController<List<Detection>> _detectionsController =
      StreamController<List<Detection>>.broadcast();
  final StreamController<Size> _resolutionAckController =
      StreamController<Size>.broadcast();
  final ValueNotifier<String> connectionStatus = ValueNotifier('Disconnected');

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  StreamSubscription<dynamic>? _channelSubscription;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _ip = '';
  int _port = 0;
  bool _isIntentionallyClosed = false;
  bool _autoReconnectEnabled = false;
  String _lastEmittedStatus = 'Disconnected';
  int _retryCount = 0;
  final int _maxRetries = 30;
  int _connectionGeneration = 0;
  int _receivedFrameCount = 0;
  int _receivedFrameBytes = 0;
  DateTime? _lastFrameReceivedAt;
  double _imageWidth = 0;
  double _imageHeight = 0;
  Timer? _watchdogTimer;
  DateTime? _lastIncomingAt;
  DateTime? _lastPingSentAt;
  static const Duration _pingInterval = Duration(seconds: 3);
  static const Duration _staleConnectionTimeout = Duration(seconds: 8);

  Stream<String> get status => _statusController.stream;
  Stream<Uint8List> get frames => _framesController.stream;
  bool get isConnected => _isConnected;
  int get receivedFrameCount => _receivedFrameCount;
  int get receivedFrameBytes => _receivedFrameBytes;
  DateTime? get lastFrameReceivedAt => _lastFrameReceivedAt;
  Stream<List<Detection>> get detections => _detectionsController.stream;
  double get imageWidth => _imageWidth;
  double get imageHeight => _imageHeight;
  Stream<Size> get resolutionAcks => _resolutionAckController.stream;

  void _emitStatus(String status) {
    if (_lastEmittedStatus == status) return;

    _lastEmittedStatus = status;
    _statusController.add(status);
    connectionStatus.value = status;
  }

  void _recordFrame(Uint8List frame) {
    _receivedFrameCount++;
    _receivedFrameBytes = frame.length;
    _lastFrameReceivedAt = DateTime.now();

    assert(() {
      if (_receivedFrameCount == 1 || _receivedFrameCount % 30 == 0) {
        debugPrint(
          '[WS] Frame #$_receivedFrameCount received '
          '(${frame.length} bytes)',
        );
      }
      return true;
    }());
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();

    _lastIncomingAt = DateTime.now();
    _lastPingSentAt = null;

    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isConnected || _channel == null) return;

      final now = DateTime.now();
      final lastIncoming = _lastIncomingAt;

      if (lastIncoming != null &&
          now.difference(lastIncoming) > _staleConnectionTimeout) {
        debugPrint(
          '[WS] Watchdog stale connection. Last incoming '
          '${now.difference(lastIncoming).inSeconds}s ago. '
          'Forcing reconnect.',
        );

        _isConnected = false;
        _detachAndCloseStaleSocket();
        _emitStatus('Reconnecting...');

        if (_autoReconnectEnabled && !_isIntentionallyClosed) {
          _scheduleReconnect();
        }
        return;
      }

      final lastPing = _lastPingSentAt;
      if (lastPing == null || now.difference(lastPing) >= _pingInterval) {
        _lastPingSentAt = now;
        try {
          debugPrint('[WS] Sending ping');
          _channel?.sink.add(jsonEncode({'cmd': 'ping'}));
        } catch (error) {
          debugPrint('[WS] Ping send failed: $error');
          _isConnected = false;
          _detachAndCloseStaleSocket();

          if (_autoReconnectEnabled && !_isIntentionallyClosed) {
            _scheduleReconnect();
          }
        }
      }
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _lastIncomingAt = null;
    _lastPingSentAt = null;
  }

  void _detachAndCloseStaleSocket() {
    _connectionGeneration++;
    final oldSubscription = _channelSubscription;
    final oldChannel = _channel;

    _channelSubscription = null;
    _channel = null;
    _isConnected = false;

    if (oldSubscription != null) {
      unawaited(
        oldSubscription
            .cancel()
            .timeout(
              const Duration(milliseconds: 500),
              onTimeout: () {
                debugPrint('[WS] Stale subscription cancel timed out');
              },
            )
            .catchError((error) {
              debugPrint('[WS] Stale subscription cancel failed: $error');
            }),
      );
    }

    if (oldChannel != null) {
      unawaited(
        oldChannel.sink
            .close()
            .timeout(
              const Duration(milliseconds: 500),
              onTimeout: () {
                debugPrint('[WS] Stale socket close timed out');
              },
            )
            .catchError((error) {
              debugPrint('[WS] Stale socket close failed: $error');
            }),
      );
    }
  }

  void configure(String ip, int port, {bool autoReconnect = false}) {
    final endpointChanged = _ip != ip || _port != port;

    _ip = ip;
    _port = port;
    _autoReconnectEnabled = autoReconnect;
    _retryCount = 0;
    _isIntentionallyClosed = false;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (endpointChanged) {
      _detachAndCloseStaleSocket();
      _isConnecting = false;
      _emitStatus('Disconnected');
    }
  }

  void resetConnectionState({bool emitDisconnected = true}) {
    _isIntentionallyClosed = true;
    _autoReconnectEnabled = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _retryCount = 0;
    _isConnecting = false;
    _stopWatchdog();
    _detachAndCloseStaleSocket();

    if (emitDisconnected) {
      _emitStatus('Disconnected');
    }
  }

  Future<bool> connect({bool autoReconnect = false}) async {
    _autoReconnectEnabled = autoReconnect;
    if (_isConnected) return true;
    if (_isConnecting) return false;

    _isIntentionallyClosed = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      _isConnecting = true;
      _emitStatus('Connecting...');

      _detachAndCloseStaleSocket();
      final generation = ++_connectionGeneration;

      debugPrint('[WS] Opening socket ws://$_ip:$_port');
      final channel = WebSocketChannel.connect(Uri.parse('ws://$_ip:$_port'));
      _channel = channel;

      final firstMessageCompleter = Completer<void>();

      _channelSubscription = channel.stream.listen(
        (message) {
          if (generation != _connectionGeneration) return;

          if (!firstMessageCompleter.isCompleted) {
            firstMessageCompleter.complete();
          }
          _handleIncoming(message);
        },
        onError: (error) {
          if (generation != _connectionGeneration) return;

          if (!firstMessageCompleter.isCompleted) {
            firstMessageCompleter.completeError(error);
          }
          _handleSocketClosed();
        },
        onDone: () {
          if (generation != _connectionGeneration) return;
          _handleSocketClosed();
        },
        cancelOnError: true,
      );

      // Some ESP32 firmware sends a status/frame before channel.ready resolves.
      await Future.any<void>([
        channel.ready,
        firstMessageCompleter.future,
      ]).timeout(const Duration(seconds: 10));

      _isConnected = true;
      _retryCount = 0; // Reset retry count on success
      _emitStatus('Connected');
      if (_autoReconnectEnabled) {
        _startWatchdog();
      }
      return true;
    } catch (error) {
      assert(() {
        debugPrint('[WS] Connect failed ws://$_ip:$_port -> $error');
        return true;
      }());
      _isConnected = false;
      _detachAndCloseStaleSocket();
      _emitStatus('Disconnected');

      if (_autoReconnectEnabled && !_isIntentionallyClosed) {
        _scheduleReconnect();
      }
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  void _handleSocketClosed() {
    _isConnected = false;

    if (_isIntentionallyClosed || !_autoReconnectEnabled) {
      _stopWatchdog();
      _emitStatus('Disconnected');
      return;
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isIntentionallyClosed || !_autoReconnectEnabled) {
      _emitStatus('Disconnected');
      return;
    }

    if (_retryCount >= _maxRetries) {
      _stopWatchdog();
      _emitStatus('Disconnected');
      return;
    }

    if (_reconnectTimer?.isActive ?? false) return;

    _emitStatus('Reconnecting...');

    final delayMs = 2000;
    _retryCount++;

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      _reconnectTimer = null;

      if (_isIntentionallyClosed || !_autoReconnectEnabled) return;

      final success = await connect(autoReconnect: true);
      if (!success && !_isIntentionallyClosed && _autoReconnectEnabled) {
        _scheduleReconnect();
      }
    });
  }

  void _handleIncoming(dynamic message) {
    // TODO: TEMP DEBUG STAGE 3 - remove after capturing sample
    try {
      if (message is String) {
        final debugData = jsonDecode(message);
        if (debugData is Map && debugData.containsKey('detections')) {
          debugPrint('RAW DETECTION PAYLOAD: ${debugData['detections']}');
        }
      }
    } catch (_) {
      // Ignore parse errors in temp debug logging.
    }

    _lastIncomingAt = DateTime.now();

    if (message is! String) return;

    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return;

      if (decoded['event'] == 'pong') {
        debugPrint('[WS] Received pong');
      }

      // --- Resolution acknowledgement from device ---
      if (decoded['event'] == 'resolution_ack') {
        final w = (decoded['width'] as num?)?.toDouble();
        final h = (decoded['height'] as num?)?.toDouble();
        if (w != null && h != null) {
          debugPrint('[WS] Resolution ack: ${w.toInt()}x${h.toInt()}');
          _resolutionAckController.add(Size(w, h));
        }
      }

      // --- Frame extraction (MaixCAM2 'image' or legacy 'frame') ---
      if (decoded['image'] is String) {
        final frame = base64Decode(decoded['image'] as String);
        _recordFrame(frame);
        _framesController.add(frame);
      } else if (decoded['frame'] is String) {
        final frame = base64Decode(decoded['frame'] as String);
        _recordFrame(frame);
        _framesController.add(frame);
      }

      // --- MaixCAM2 detection coordinates ---
      if (decoded['detections'] is List) {
        final raw = decoded['detections'] as List;
        final detections = <Detection>[];
        for (final item in raw) {
          if (item is! Map<String, dynamic>) continue;
          detections.add(Detection(
            x: (item['x'] as num?)?.toDouble() ?? 0.0,
            y: (item['y'] as num?)?.toDouble() ?? 0.0,
            w: (item['w'] as num?)?.toDouble() ?? 0.0,
            h: (item['h'] as num?)?.toDouble() ?? 0.0,
            label: item['label'] as String? ?? '',
            score: (item['score'] as num?)?.toDouble() ?? 0.0,
          ));
        }
        _detectionsController.add(detections);
      }

      // --- Image dimensions (if provided by MaixCAM2) ---
      if (decoded['img_w'] is num) {
        _imageWidth = (decoded['img_w'] as num).toDouble();
      }
      if (decoded['img_h'] is num) {
        _imageHeight = (decoded['img_h'] as num).toDouble();
      }

      // --- Connection status ---
      if (decoded['status'] is String) {
        final status = decoded['status'] as String;

        if (status == 'Connected') {
          _isConnected = true;
          _retryCount = 0;
        }

        _emitStatus(status);
      }
    } catch (_) {
      // Ignore plain text and malformed payloads.
    }
  }

  void sendMotorCommand(int left, int right) {
    if (!_isConnected || _channel == null) return;

    _channel!.sink.add(
      jsonEncode({'cmd': 'motor', 'left': left, 'right': right}),
    );
  }

  void sendServoCommand(String part, int value) {
    if (!_isConnected || _channel == null) return;

    _channel!.sink.add(
      jsonEncode({'cmd': 'servo', 'part': part, 'val': value}),
    );
  }

  void sendStartStreamCommand() {
    if (!_isConnected || _channel == null) {
      debugPrint(
        '[WS] start_stream skipped: connected=$_isConnected channel=${_channel != null}',
      );
      return;
    }

    debugPrint('[WS] Sending start_stream');
    _channel!.sink.add(jsonEncode({'cmd': 'start_stream'}));
  }

  void sendStopStreamCommand() {
    if (!_isConnected || _channel == null) {
      debugPrint(
        '[WS] stop_stream skipped: connected=$_isConnected channel=${_channel != null}',
      );
      return;
    }

    debugPrint('[WS] Sending stop_stream');
    _channel!.sink.add(jsonEncode({'cmd': 'stop_stream'}));
  }

  void sendResolutionCommand({String? preset, int? width, int? height}) {
    if (!_isConnected || _channel == null) return;
    final cmd = <String, dynamic>{'cmd': 'set_resolution'};
    if (width != null && height != null) {
      cmd['width'] = width;
      cmd['height'] = height;
    } else if (preset != null) {
      cmd['preset'] = preset;
    } else {
      return;
    }
    debugPrint('[WS] Sending set_resolution: $cmd');
    _channel!.sink.add(jsonEncode(cmd));
  }

  Future<void> disconnect() async {
    _isIntentionallyClosed = true;
    _autoReconnectEnabled = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopWatchdog();

    // Best-effort orderly disconnect handshake — device can clean up its
    // side immediately rather than waiting to notice the TCP drop.
    try {
      _channel?.sink.add(jsonEncode({'cmd': 'disconnect'}));
    } catch (_) {}

    await _channelSubscription?.cancel();
    _channelSubscription = null;

    await _channel?.sink.close();
    _channel = null;

    _isConnected = false;
    _isConnecting = false;
    _retryCount = 0;

    _emitStatus('Disconnected');
  }
}

/// Lightweight detection result parsed from MaixCAM2 JSON payload.
///
/// Coordinates are in image-space pixels:
/// - [x], [y]: center of the detected object
/// - [w], [h]: width and height of the bounding box
class Detection {
  final double x;
  final double y;
  final double w;
  final double h;
  final String label;
  final double score;

  const Detection({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.label = '',
    this.score = 0.0,
  });

  @override
  String toString() =>
      'Detection($label ${(score * 100).toStringAsFixed(0)}% '
      'x=$x y=$y w=$w h=$h)';
}
