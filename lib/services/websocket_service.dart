import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'frame_source/frame_source.dart' show CapturedFrame;

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
  final StreamController<CapturedFrame> _capturedFramesController =
      StreamController<CapturedFrame>.broadcast();
  final ValueNotifier<String> connectionStatus = ValueNotifier('Disconnected');
  final StreamController<Map<String, dynamic>> _robotRepliesController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// R1 command-link replies (decision 0023): `{"event": ..., "seq": n}`.
  Stream<Map<String, dynamic>> get robotReplies => _robotRepliesController.stream;

  /// How long one connect attempt waits for the robot's first answer (tests
  /// shorten it).
  static Duration connectTimeout = const Duration(seconds: 10);

  /// Why the last [connect] failed, for the Config screen; null after a
  /// success or a cancel ([disconnect] during the attempt).
  String? get lastConnectError => _lastConnectError;
  String? _lastConnectError;
  Completer<void>? _connectCancel;

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

  /// Wait before each auto-reconnect attempt.
  static const reconnectDelay = Duration(milliseconds: 2000);
  DateTime? _nextRetryAt;

  /// Read-only for the Control screen's retry line (R2).
  int get retryCount => _retryCount;
  int get maxRetries => _maxRetries;
  bool get autoReconnectEnabled => _autoReconnectEnabled;

  /// When the scheduled reconnect fires; null when none is scheduled.
  DateTime? get nextRetryAt => (_reconnectTimer?.isActive ?? false) ? _nextRetryAt : null;
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

  /// The last frame's `arm_tags` (decision 0022); null when it had none.
  /// Nothing reads this yet (R1 will).
  List<ArmTag>? get armTags => _armTags;
  List<ArmTag>? _armTags;

  /// The last frame's `arm_moving` (decision 0026); null when the firmware doesn't say.
  bool? get armMoving => _armMoving;
  bool? _armMoving;
  Stream<Size> get resolutionAcks => _resolutionAckController.stream;
  Stream<CapturedFrame> get capturedFrames => _capturedFramesController.stream;

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

  /// Turns auto-reconnect on or off for the live link: the watchdog is what
  /// notices a dead Wi-Fi link that never closes the socket.
  void setAutoReconnect(bool on) {
    _autoReconnectEnabled = on;
    if (!on) {
      _stopWatchdog();
    } else if (_isConnected && _watchdogTimer == null) {
      _startWatchdog();
    }
  }

  Future<bool> connect({bool autoReconnect = false}) async {
    if (_isConnected) {
      setAutoReconnect(autoReconnect);
      return true;
    }
    _autoReconnectEnabled = autoReconnect;
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
      final cancel = _connectCancel = Completer<void>();
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
        cancel.future,
      ]).timeout(connectTimeout);
      if (cancel.isCompleted || generation != _connectionGeneration) {
        throw const _ConnectCancelled();
      }

      _isConnected = true;
      _lastConnectError = null;
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
      _lastConnectError = error is _ConnectCancelled
          ? null
          : connectFailureReason(error, '$_ip:$_port', connectTimeout);
      _isConnected = false;
      _detachAndCloseStaleSocket();
      _emitStatus('Disconnected');

      if (_autoReconnectEnabled && !_isIntentionallyClosed) {
        _scheduleReconnect();
      }
      return false;
    } finally {
      _isConnecting = false;
      _connectCancel = null;
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

    final delayMs = reconnectDelay.inMilliseconds;
    _retryCount++;
    _nextRetryAt = DateTime.now().add(reconnectDelay);

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
    _lastIncomingAt = DateTime.now();

    if (message is! String) return;

    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return;

      if (decoded['seq'] is int && decoded['event'] is String) {
        _robotRepliesController.add(decoded);
        return;
      }

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

      // --- Image dimensions (if provided by MaixCAM2) ---
      if (decoded['img_w'] is num) {
        _imageWidth = (decoded['img_w'] as num).toDouble();
      }
      if (decoded['img_h'] is num) {
        _imageHeight = (decoded['img_h'] as num).toDouble();
      }

      // --- MaixCAM2 detection coordinates ---
      List<Detection>? currentDetections;
      if (decoded['detections'] is List) {
        final raw = decoded['detections'] as List;
        currentDetections = <Detection>[];
        for (final item in raw) {
          if (item is! Map<String, dynamic>) continue;
          currentDetections.add(Detection.fromJson(item));
        }
        _armTags = ArmTag.listFromJson(decoded['arm_tags']);
        _armMoving = armMovingFromJson(decoded['arm_moving']);
        _detectionsController.add(currentDetections);
      }

      // --- Frame extraction (MaixCAM2 'image' or legacy 'frame') ---
      Uint8List? frameData;
      if (decoded['image'] is String) {
        frameData = base64Decode(decoded['image'] as String);
      } else if (decoded['frame'] is String) {
        frameData = base64Decode(decoded['frame'] as String);
      }
      
      if (frameData != null) {
        _recordFrame(frameData);
        _framesController.add(frameData);
        _capturedFramesController.add(CapturedFrame.fromRobotMessage(decoded,
          previewBytes: frameData,
          width: _imageWidth.toInt(),
          height: _imageHeight.toInt(),
          previewDetections: currentDetections,
        ));
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

  /// One R1 command (decision 0023); dropped while not connected (R1 times it out).
  void sendRobotCommand(Map<String, Object?> command) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode(command));
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
    // Also ends a connect still waiting for its first answer (Config "Cancel").
    if (!(_connectCancel?.isCompleted ?? true)) _connectCancel!.complete();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopWatchdog();

    // Best-effort orderly disconnect handshake — device can clean up its
    // side immediately rather than waiting to notice the TCP drop. Wheels off
    // first: the last motor command stays in force on the robot (0026).
    try {
      _channel?.sink.add(jsonEncode({'cmd': 'motor', 'left': 0, 'right': 0}));
      _channel?.sink.add(jsonEncode({'cmd': 'disconnect'}));
    } catch (_) {}

    // Bounded: a socket that never opened can leave close() pending (cancel case).
    final subscription = _channelSubscription;
    final channel = _channel;
    _channelSubscription = null;
    _channel = null;
    const bound = Duration(milliseconds: 500);
    await subscription?.cancel().timeout(bound, onTimeout: () {});
    await channel?.sink.close().timeout(bound, onTimeout: () {});

    _isConnected = false;
    _isConnecting = false;
    _retryCount = 0;

    _emitStatus('Disconnected');
  }
}

class _ConnectCancelled implements Exception {
  const _ConnectCancelled();
}

/// One English sentence for a failed connect, shown on the Config screen.
String connectFailureReason(Object error, String endpoint, Duration timeout) {
  final text = '$error'.toLowerCase();
  if (error is TimeoutException) {
    return 'No answer from $endpoint after ${timeout.inSeconds} s. '
        'Check that this phone is on the ELIOS Wi-Fi and the robot is on.';
  }
  if (text.contains('refused')) {
    return '$endpoint refused the connection. Check the port and that the robot app is running.';
  }
  if (text.contains('unreachable') || text.contains('no route')) {
    return 'No route to $endpoint. Join the ELIOS Wi-Fi on this phone first.';
  }
  if (error is SocketException) {
    return 'Could not reach $endpoint (${error.osError?.message ?? error.message}).';
  }
  return 'Could not connect to $endpoint.';
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

  /// Optional fields (decision 0022); null when the firmware doesn't send
  /// them or sends a malformed value. Nothing depends on them yet.
  final int? trackId;

  /// Floor distance (cm) from the point below the lens, along the optical
  /// axis, to the box's bottom edge.
  final double? distCm;

  /// Sideways floor offset (cm) from the optical axis.
  final double? lateralCm;

  /// The tracked box only (0182): true while the item is still, false while it moves.
  final bool? held;

  const Detection({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.label = '',
    this.score = 0.0,
    this.trackId,
    this.distCm,
    this.lateralCm,
    this.held,
  });

  factory Detection.fromJson(Map<String, dynamic> item) => Detection(
    x: (item['x'] as num?)?.toDouble() ?? 0.0,
    y: (item['y'] as num?)?.toDouble() ?? 0.0,
    w: (item['w'] as num?)?.toDouble() ?? 0.0,
    h: (item['h'] as num?)?.toDouble() ?? 0.0,
    label: item['label'] as String? ?? '',
    score: (item['score'] as num?)?.toDouble() ?? 0.0,
    trackId: _optInt(item['track_id']),
    distCm: _optDouble(item['dist_cm']),
    lateralCm: _optDouble(item['lateral_cm']),
    held: item['held'] is bool ? item['held'] as bool : null,
  );

  @override
  String toString() =>
      'Detection($label ${(score * 100).toStringAsFixed(0)}% '
      'x=$x y=$y w=$w h=$h)';
}

/// One AprilTag on the arm, from a frame's `arm_tags` (decision 0022):
/// id 0 = gripper underside, id 1 = arm B rear face.
class ArmTag {
  const ArmTag({required this.id, required this.distMm});

  final int id;
  final double distMm;

  /// Null when [raw] is not a list; malformed entries are skipped.
  static List<ArmTag>? listFromJson(Object? raw) {
    if (raw is! List) return null;
    return [
      for (final t in raw)
        if (t is Map && _optInt(t['id']) != null && _optDouble(t['dist_mm']) != null)
          ArmTag(id: _optInt(t['id'])!, distMm: _optDouble(t['dist_mm'])!),
    ];
  }
}

int? _optInt(Object? v) => v is int ? v : null;

/// A frame's optional `arm_moving` (decision 0026): a bool, else null (unknown).
bool? armMovingFromJson(Object? v) => v is bool ? v : null;

double? _optDouble(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
