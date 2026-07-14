class EspConfig {
  final String esp32IpAddress;
  final int port;
  final bool autoReconnect;
  final String resolutionPreset;
  final bool showFpsOverlay;

  const EspConfig({
    this.esp32IpAddress = '',
    this.port = 0,
    this.autoReconnect = true,
    this.resolutionPreset = '480p',
    this.showFpsOverlay = false,
  });

  EspConfig copyWith({
    String? esp32IpAddress,
    int? port,
    bool? autoReconnect,
    String? resolutionPreset,
    bool? showFpsOverlay,
  }) {
    return EspConfig(
      esp32IpAddress: esp32IpAddress ?? this.esp32IpAddress,
      port: port ?? this.port,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      showFpsOverlay: showFpsOverlay ?? this.showFpsOverlay,
    );
  }

  Map<String, dynamic> toMap() => {
    'esp32IpAddress': esp32IpAddress,
    'port': port,
    'autoReconnect': autoReconnect,
    'resolutionPreset': resolutionPreset,
    'showFpsOverlay': showFpsOverlay,
  };

  factory EspConfig.fromMap(Map<String, dynamic> map) => EspConfig(
    esp32IpAddress: map['esp32IpAddress'] ?? '',
    port: map['port'] ?? 0,
    autoReconnect: map['autoReconnect'] ?? true,
    resolutionPreset: map['resolutionPreset'] ?? '480p',
    showFpsOverlay: map['showFpsOverlay'] ?? false,
  );
}
