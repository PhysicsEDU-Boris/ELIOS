/// Which camera feeds the waste scan + quiz.
enum CameraSource {
  /// The robot's MaixCAM2, over the ELIOS Wi-Fi WebSocket.
  maixCam2,

  /// This phone/laptop's own camera — no robot needed.
  device,
}

class EspConfig {
  /// The MaixCAM2 firmware's WebSocket port (`WS_PORT` in `elio_maixcam2.py`).
  static const maixCamPort = 8765;

  final String esp32IpAddress;
  final int port;
  final bool autoReconnect;
  final String resolutionPreset;
  final bool showFpsOverlay;
  final CameraSource cameraSource;

  const EspConfig({
    this.esp32IpAddress = '192.168.4.1',
    this.port = maixCamPort,
    this.autoReconnect = true,
    this.resolutionPreset = '480p',
    this.showFpsOverlay = false,
    this.cameraSource = CameraSource.maixCam2,
  });

  EspConfig copyWith({
    String? esp32IpAddress,
    int? port,
    bool? autoReconnect,
    String? resolutionPreset,
    bool? showFpsOverlay,
    CameraSource? cameraSource,
  }) {
    return EspConfig(
      esp32IpAddress: esp32IpAddress ?? this.esp32IpAddress,
      port: port ?? this.port,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      showFpsOverlay: showFpsOverlay ?? this.showFpsOverlay,
      cameraSource: cameraSource ?? this.cameraSource,
    );
  }

  Map<String, dynamic> toMap() => {
    'esp32IpAddress': esp32IpAddress,
    'port': port,
    'autoReconnect': autoReconnect,
    'resolutionPreset': resolutionPreset,
    'showFpsOverlay': showFpsOverlay,
    'cameraSource': cameraSource.name,
  };

  factory EspConfig.fromMap(Map<String, dynamic> map) => EspConfig(
    esp32IpAddress: map['esp32IpAddress'] ?? '192.168.4.1',
    // 8080 was the old default and nothing listens there, so saved configs move to 8765.
    port: switch (map['port']) { null || 8080 => maixCamPort, final p => p },
    autoReconnect: map['autoReconnect'] ?? true,
    resolutionPreset: map['resolutionPreset'] ?? '480p',
    showFpsOverlay: map['showFpsOverlay'] ?? false,
    cameraSource: CameraSource.values.firstWhere(
      (s) => s.name == map['cameraSource'],
      orElse: () => CameraSource.maixCam2,
    ),
  );
}
