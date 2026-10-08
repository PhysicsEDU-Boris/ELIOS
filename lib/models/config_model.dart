/// Which camera feeds the waste scan + quiz.
enum CameraSource {
  /// The robot's MaixCAM2, over the ELIOS Wi-Fi WebSocket.
  maixCam2,

  /// This phone/laptop's own camera — no robot needed.
  device,
}

class EspConfig {
  final String esp32IpAddress;
  final int port;
  final bool autoReconnect;
  final String resolutionPreset;
  final bool showFpsOverlay;
  final CameraSource cameraSource;

  const EspConfig({
    this.esp32IpAddress = '192.168.4.1',
    this.port = 8080,
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
    port: map['port'] ?? 8080,
    autoReconnect: map['autoReconnect'] ?? true,
    resolutionPreset: map['resolutionPreset'] ?? '480p',
    showFpsOverlay: map['showFpsOverlay'] ?? false,
    cameraSource: CameraSource.values.firstWhere(
      (s) => s.name == map['cameraSource'],
      orElse: () => CameraSource.maixCam2,
    ),
  );
}
