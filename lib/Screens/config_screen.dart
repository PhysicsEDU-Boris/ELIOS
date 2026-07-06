// Copyright (c) Boris Agung, Irham Fajar

import 'package:elio/models/config_model.dart';
import 'package:elio/providers/udp_discovery_provider.dart';
import 'package:elio/providers/wifi_provisioning_provider.dart';
import 'package:elio/services/config_service.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'control_screen.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final TextEditingController _ip1 = TextEditingController(text: '192');
  final TextEditingController _ip2 = TextEditingController(text: '168');
  final TextEditingController _ip3 = TextEditingController(text: '1');
  final TextEditingController _ip4 = TextEditingController(text: '100');
  final TextEditingController _port = TextEditingController(text: '8080');
  final TextEditingController _settingsDefaultIp = TextEditingController(
    text: '192.168.1.100',
  );
  final TextEditingController _settingsPort = TextEditingController(
    text: '8080',
  );

  // ── Provisioning Controllers ────────────────────────────────────
  final TextEditingController _provSsid = TextEditingController();
  final TextEditingController _provPass = TextEditingController();

  final ConfigService _configService = ConfigService();

  bool saveDefault = true;
  bool _isConnecting = false;
  bool _connectionFailed = false;
  bool _settingsAutoReconnect = true;
  String _settingsResolution = '1080p (FHD)';
  bool _settingsShowFpsOverlay = false;
  bool _settingsSoundEffects = true;
  double _settingsMasterVolume = 0.75;
  String _settingsQuizDifficulty = 'Medium';
  String _settingsQuizTimer = '60s';
  bool _settingsSkipAllowed = false;

  final Color backgroundMain = const Color(0xFFFAFCFA);
  final Color textPrimary = const Color(0xFF1C2833);
  final Color textSecondary = const Color(0xFF7F8C8D);
  final Color primaryColor = const Color(0xFF004F38);
  final Color cardBorder = const Color(0xFFBEC9C2);
  final Color inputSurface = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
    _loadWifiSsid();

    // Start the UDP auto-discovery listener after the first frame
    // to ensure the Riverpod container is fully initialized.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(udpDiscoveryProvider.notifier).startListening();
    });
  }

  /// Pre-fill the provisioning SSID field with the current Wi-Fi name.
  void _loadWifiSsid() {
    // Read the provider asynchronously; when it resolves, populate the field.
    Future.microtask(() {
      ref.read(wifiSsidProvider.future).then((ssid) {
        if (ssid != null && mounted && _provSsid.text.isEmpty) {
          _provSsid.text = ssid;
        }
      });
    });
  }

  Future<void> _loadSavedConfig() async {
    final config = await _configService.loadConfig();
    final parts = config.esp32IpAddress.split('.');

    if (!mounted) return;

    if (parts.length == 4) {
      _ip1.text = parts[0];
      _ip2.text = parts[1];
      _ip3.text = parts[2];
      _ip4.text = parts[3];
    }
    _port.text = config.port.toString();
    setState(() {});
  }

  Future<void> _openControlScreen() async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ControlScreen()),
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      try {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (error) {
        debugPrint('Unable to restore portrait mode: $error');
      }
    }
  }

  Future<void> _connect() async {
    final ipParts = [_ip1.text, _ip2.text, _ip3.text, _ip4.text];
    final parsedParts = ipParts.map(int.tryParse).toList();
    final parsedPort = int.tryParse(_port.text);

    final ipValid = parsedParts.every(
      (segment) => segment != null && segment >= 0 && segment <= 255,
    );
    final portValid =
        parsedPort != null && parsedPort > 0 && parsedPort <= 65535;

    if (!ipValid || !portValid) {
      _showSnack('Please enter a valid IP address and port', isError: true);
      return;
    }

    final ip = parsedParts.join('.');
    final port = parsedPort;

    // 1. Start loading state
    setState(() {
      _isConnecting = true;
      _connectionFailed = false;
    });

    // 2. Configure and AWAIT the connection result
    debugPrint('[Config] Connecting to ws://$ip:$port');
    final ws = WebSocketService();
    ws.resetConnectionState();
    ws.configure(ip, port, autoReconnect: false);

    bool success = false;

    try {
      success = await ws
          .connect(autoReconnect: false)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              debugPrint('[Config] Connect hard-timeout for ws://$ip:$port');
              return false;
            },
          );
    } catch (error) {
      debugPrint('[Config] Connect exception for ws://$ip:$port -> $error');
      success = false;
    }

    debugPrint('[Config] Connect result: $success');

    // 3. Stop loading state
    if (!mounted) return;
    setState(() => _isConnecting = false);

    // 4. Handle Result
    if (success) {
      if (saveDefault) {
        await _configService.saveConfig(
          EspConfig(esp32IpAddress: ip, port: port),
        );
      }
      // Only navigate if actually connected
      if (!mounted) return;
      await _openControlScreen();
    } else {
      setState(() => _connectionFailed = true);
      // Show error and STAY on Config Screen
      _showSnack(
        'Connection failed. Is MaixCAM2 turned on and on the same WiFi?',
        isError: true,
      );
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFC62828)
            : const Color(0xFF0F6E56),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showConfigSettingsPanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _ConfigSettingsSheet(
              primaryColor: primaryColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              cardBorder: cardBorder,
              defaultIpController: _settingsDefaultIp,
              portController: _settingsPort,
              autoReconnect: _settingsAutoReconnect,
              onAutoReconnectChanged: (value) {
                setState(() => _settingsAutoReconnect = value);
                setSheetState(() {});
              },
              resolution: _settingsResolution,
              onResolutionChanged: (value) {
                if (value == null) return;
                setState(() => _settingsResolution = value);
                setSheetState(() {});
              },
              showFpsOverlay: _settingsShowFpsOverlay,
              onShowFpsOverlayChanged: (value) {
                setState(() => _settingsShowFpsOverlay = value);
                setSheetState(() {});
              },
              soundEffects: _settingsSoundEffects,
              onSoundEffectsChanged: (value) {
                setState(() => _settingsSoundEffects = value);
                setSheetState(() {});
              },
              masterVolume: _settingsMasterVolume,
              onMasterVolumeChanged: (value) {
                setState(() => _settingsMasterVolume = value);
                setSheetState(() {});
              },
              quizDifficulty: _settingsQuizDifficulty,
              onQuizDifficultyChanged: (value) {
                if (value == null) return;
                setState(() => _settingsQuizDifficulty = value);
                setSheetState(() {});
              },
              quizTimer: _settingsQuizTimer,
              onQuizTimerChanged: (value) {
                if (value == null) return;
                setState(() => _settingsQuizTimer = value);
                setSheetState(() {});
              },
              skipAllowed: _settingsSkipAllowed,
              onSkipAllowedChanged: (value) {
                setState(() => _settingsSkipAllowed = value);
                setSheetState(() {});
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    // Stop the UDP listener if still active when leaving the screen.
    ref.read(udpDiscoveryProvider.notifier).stopListening();
    _ip1.dispose();
    _ip2.dispose();
    _ip3.dispose();
    _ip4.dispose();
    _port.dispose();
    _settingsDefaultIp.dispose();
    _settingsPort.dispose();
    _provSsid.dispose();
    _provPass.dispose();
    super.dispose();
  }

  // ── QR Provisioning Dialog ──────────────────────────────────────
  /// Validates the provisioning inputs, fetches the host device IP,
  /// and displays a centered popup dialog containing the QrImageView.
  Future<void> _showProvisioningQrDialog() async {
    final ssid = _provSsid.text.trim();
    final pass = _provPass.text.trim();

    if (ssid.isEmpty || pass.isEmpty) {
      _showSnack('Enter both SSID and Password to generate QR.', isError: true);
      return;
    }

    // Fetch host device IP asynchronously (fallback to hotspot default).
    // getBestLocalIp() filters out link-local (169.254.x.x) and USB
    // interface addresses that NetworkInfo().getWifiIP() sometimes returns
    // when the phone is connected to a Mac via USB cable.
    String appIp = '192.168.43.1';
    try {
      appIp = await getBestLocalIp();
      debugPrint('[Provision] Using app_ip: $appIp');
    } catch (_) {
      // Silently fall back to default hotspot gateway IP.
    }

    // Parse port from the existing text controller.
    final portValue = int.tryParse(_port.text.trim()) ?? 8080;

    if (!mounted) return;

    // Serialize to expanded JSON:
    // {"ssid":"...","pass":"...","app_ip":"...","port":<int>}
    final payload = serializeProvisioningPayload(
      ssid: ssid,
      password: pass,
      appIp: appIp,
      port: portValue,
    );

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Title ──
                  Text(
                    'Scan to Provision',
                    style: GoogleFonts.inter(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Point ELIO\'s camera at this QR code to receive network credentials.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── QR Code (white background for dark-mode safety) ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cardBorder.withValues(alpha: 0.3),
                      ),
                    ),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF1C2833),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1C2833),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Payload preview (SSID + app_ip:port) ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'SSID: $ssid  ·  $appIp:$portValue',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Close Button (brand green) ──
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D9E75),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'CLOSE',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── UDP Auto-Discovery Listener ──────────────────────────────
    // When the UDP provider emits a discovered IP, auto-populate the
    // four IP text controllers and notify the user.
    ref.listen<String?>(udpDiscoveryProvider, (previous, next) {
      if (next != null && previous == null) {
        final parts = next.split('.');
        if (parts.length == 4) {
          _ip1.text = parts[0];
          _ip2.text = parts[1];
          _ip3.text = parts[2];
          _ip4.text = parts[3];
          _showSnack('ELIO Discovered at $next');
        }
      }
    });

    final height = MediaQuery.of(context).size.height;
    final compact = height < 760;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final batteryPercent = 62;
    final isCharging = false;
    final signalStatus = 'None';

    return Scaffold(
      backgroundColor: backgroundMain,
      body: SafeArea(
        child: Semantics(
          liveRegion: _connectionFailed,
          // ── Scrollable content area ──
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 14, 20, keyboardOpen ? 28 : 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 44),
                        const Spacer(),
                        Text(
                          'Connect ELIO',
                          style: GoogleFonts.inter(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        _buildHeaderIconButton(
                          child: Icon(
                            Icons.settings_rounded,
                            color: textPrimary,
                            size: 22,
                          ),
                          onPressed: _showConfigSettingsPanel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _RobotConnectionPanel(
                      primaryColor: primaryColor,
                      borderColor: cardBorder,
                      textPrimary: textPrimary,
                      inputSurface: inputSurface,
                      height: compact ? 200 : 220,
                      modelSize: compact ? 130 : 148,
                      batteryPercent: batteryPercent,
                      isCharging: isCharging,
                      signalStatus: signalStatus,
                    ),
                    const SizedBox(height: 10),
                    _GlassCard(
                      borderColor: cardBorder,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  Icons.settings_input_antenna_rounded,
                                  color: primaryColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Connection Settings',
                                      style: GoogleFonts.inter(
                                        color: textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'Configure ELIO WebSocket endpoint',
                                      style: GoogleFonts.inter(
                                        color: textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _FieldLabel('IP Address', color: textPrimary),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              _buildIpField(_ip1),
                              const _DotSeparator(),
                              _buildIpField(_ip2),
                              const _DotSeparator(),
                              _buildIpField(_ip3),
                              const _DotSeparator(),
                              _buildIpField(_ip4),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _FieldLabel('Port', color: textPrimary),
                          const SizedBox(height: 5),
                          _buildPortField(),
                          const SizedBox(height: 5),
                          Text(
                            'For MaixCAM2, check the IP on its LCD screen and use port 8080',
                            style: GoogleFonts.inter(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(
                            height: 1,
                            color: cardBorder.withValues(alpha: 0.34),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Save as default config',
                                  style: GoogleFonts.inter(
                                    color: textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Switch(
                                value: saveDefault,
                                onChanged: (val) =>
                                    setState(() => saveDefault = val),
                                activeThumbColor: primaryColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Wi-Fi Provisioning QR Section ────────
                    const SizedBox(height: 10),
                    _GlassCard(
                      borderColor: cardBorder,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1D9E75,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(
                                  Icons.qr_code_2_rounded,
                                  color: Color(0xFF1D9E75),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wi-Fi Provisioning',
                                      style: GoogleFonts.inter(
                                        color: textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'Share hotspot credentials via QR',
                                      style: GoogleFonts.inter(
                                        color: textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _FieldLabel(
                            'SSID (Network Name)',
                            color: textPrimary,
                          ),
                          const SizedBox(height: 5),
                          _buildProvisioningTextField(
                            controller: _provSsid,
                            hint: 'e.g. iPhone-Hotspot',
                            prefixIcon: Icons.wifi_rounded,
                          ),
                          const SizedBox(height: 10),
                          _FieldLabel('Password', color: textPrimary),
                          const SizedBox(height: 5),
                          _buildProvisioningTextField(
                            controller: _provPass,
                            hint: 'Hotspot password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscure: true,
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.qr_code_rounded,
                                color: Color(0xFF1D9E75),
                                size: 22,
                              ),
                              tooltip: 'Generate QR Code',
                              onPressed: _showProvisioningQrDialog,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: _showProvisioningQrDialog,
                              icon: const Icon(
                                Icons.qr_code_2_rounded,
                                size: 18,
                              ),
                              label: Text(
                                'GENERATE QR',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D9E75),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Bottom action bar (inside the scroll view) ──
                    const SizedBox(height: 12),
                    _buildBottomActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required Widget child,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder.withValues(alpha: 0.7)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cardBorder.withValues(alpha: 0.34)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF123524).withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isConnecting ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnecting
                          ? primaryColor.withValues(alpha: 0.6)
                          : primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: primaryColor.withValues(alpha: 0.24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isConnecting)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.3,
                            ),
                          )
                        else
                          const Icon(Icons.wifi_tethering, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _isConnecting ? 'CONNECTING...' : 'CONNECT NOW',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIpField(TextEditingController controller) {
    return Expanded(
      child: SizedBox(
        height: 42,
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            LengthLimitingTextInputFormatter(3),
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputSurface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortField() {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: _port,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: Color(0xFF1C2833),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: inputSurface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          suffixIcon: const Icon(Icons.lan, color: Color(0xFF7F8C8D)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  /// Builds a provisioning-specific text field that matches the card's design.
  Widget _buildProvisioningTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: inputSurface,
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(
            color: textSecondary.withValues(alpha: 0.6),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          prefixIcon: Icon(prefixIcon, color: textSecondary, size: 20),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _GlassCard({required this.child, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123524).withValues(alpha: 0.045),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RobotConnectionPanel extends StatelessWidget {
  final Color primaryColor;
  final Color borderColor;
  final Color textPrimary;
  final Color inputSurface;
  final double height;
  final double modelSize;
  final int batteryPercent;
  final bool isCharging;
  final String signalStatus;

  const _RobotConnectionPanel({
    required this.primaryColor,
    required this.borderColor,
    required this.textPrimary,
    required this.inputSurface,
    required this.height,
    required this.modelSize,
    required this.batteryPercent,
    required this.isCharging,
    required this.signalStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123524).withValues(alpha: 0.045),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.12),
                  radius: 0.8,
                  colors: [
                    primaryColor.withValues(alpha: 0.045),
                    Colors.white.withValues(alpha: 0.72),
                    Colors.white.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(child: _ElioConfigModelViewer(size: modelSize)),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Row(
              children: [
                SizedBox(
                  width: 128,
                  child: _BatteryStatusChip(
                    percent: batteryPercent,
                    isCharging: isCharging,
                    primaryColor: primaryColor,
                    borderColor: borderColor,
                    surfaceColor: inputSurface,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 108,
                  child: _FloatingStatusChip(
                    icon: Icons.signal_wifi_off_rounded,
                    label: 'Signal',
                    value: signalStatus,
                    accent: const Color(0xFFE74C3C),
                    borderColor: borderColor,
                    surfaceColor: inputSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryStatusChip extends StatelessWidget {
  final int percent;
  final bool isCharging;
  final Color primaryColor;
  final Color borderColor;
  final Color surfaceColor;

  const _BatteryStatusChip({
    required this.percent,
    required this.isCharging,
    required this.primaryColor,
    required this.borderColor,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isCharging ? const Color(0xFF1D9E75) : primaryColor;
    final icon = isCharging
        ? Icons.battery_charging_full_rounded
        : Icons.battery_6_bar_rounded;
    final value = isCharging ? 'Charging · $percent%' : '$percent%';

    final iconChild = Icon(icon, color: accent, size: 14);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: isCharging ? 0.58 : 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: isCharging ? 0.22 : 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isCharging ? 0.10 : 0.035),
            blurRadius: isCharging ? 18 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isCharging ? 0.16 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isCharging
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.92, end: 1.08),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: iconChild,
                    )
                  : iconChild,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Battery',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7F8C8D),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1C2833),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color borderColor;
  final Color surfaceColor;

  const _FloatingStatusChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.borderColor,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123524).withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accent, size: 14),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7F8C8D),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1C2833),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ElioConfigModelViewer extends StatefulWidget {
  final double size;

  const _ElioConfigModelViewer({required this.size});

  @override
  State<_ElioConfigModelViewer> createState() => _ElioConfigModelViewerState();
}

class _ElioConfigModelViewerState extends State<_ElioConfigModelViewer> {
  final Flutter3DController _controller = Flutter3DController();
  bool _hasError = false;
  bool _isLoaded = false;

  void _handleLoad(String modelAddress) {
    if (!mounted) return;
    setState(() => _isLoaded = true);
  }

  void _handleError(String error) {
    debugPrint('Config ELIO 3D model failed to load: $error');
    if (!mounted) return;
    setState(() => _hasError = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Icon(
        Icons.smart_toy_rounded,
        size: widget.size * 0.42,
        color: const Color(0xFF1D9E75),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Flutter3DViewer(
            controller: _controller,
            src: 'assets/models/robot-elio.glb',
            enableTouch: false,
            activeGestureInterceptor: false,
            progressBarColor: const Color(0xFF1D9E75),
            onLoad: _handleLoad,
            onError: _handleError,
          ),
          if (!_isLoaded)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1D9E75),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfigSettingsSheet extends StatelessWidget {
  final Color primaryColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBorder;
  final TextEditingController defaultIpController;
  final TextEditingController portController;
  final bool autoReconnect;
  final ValueChanged<bool> onAutoReconnectChanged;
  final String resolution;
  final ValueChanged<String?> onResolutionChanged;
  final bool showFpsOverlay;
  final ValueChanged<bool> onShowFpsOverlayChanged;
  final bool soundEffects;
  final ValueChanged<bool> onSoundEffectsChanged;
  final double masterVolume;
  final ValueChanged<double> onMasterVolumeChanged;
  final String quizDifficulty;
  final ValueChanged<String?> onQuizDifficultyChanged;
  final String quizTimer;
  final ValueChanged<String?> onQuizTimerChanged;
  final bool skipAllowed;
  final ValueChanged<bool> onSkipAllowedChanged;

  const _ConfigSettingsSheet({
    required this.primaryColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBorder,
    required this.defaultIpController,
    required this.portController,
    required this.autoReconnect,
    required this.onAutoReconnectChanged,
    required this.resolution,
    required this.onResolutionChanged,
    required this.showFpsOverlay,
    required this.onShowFpsOverlayChanged,
    required this.soundEffects,
    required this.onSoundEffectsChanged,
    required this.masterVolume,
    required this.onMasterVolumeChanged,
    required this.quizDifficulty,
    required this.onQuizDifficultyChanged,
    required this.quizTimer,
    required this.onQuizTimerChanged,
    required this.skipAllowed,
    required this.onSkipAllowedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAFCFA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: cardBorder.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.settings_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Config Settings',
                              style: GoogleFonts.inter(
                                color: textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Customize connection, video, audio, and quiz preferences.',
                              style: GoogleFonts.inter(
                                color: textSecondary,
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SettingsSectionCard(
                    title: 'Connection',
                    cardBorder: cardBorder,
                    children: [
                      _SettingsTextField(
                        label: 'Default IP',
                        controller: defaultIpController,
                        icon: Icons.wifi_rounded,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        cardBorder: cardBorder,
                      ),
                      _SettingsDivider(cardBorder: cardBorder),
                      _SettingsTextField(
                        label: 'Port',
                        controller: portController,
                        icon: Icons.router_rounded,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        cardBorder: cardBorder,
                        keyboardType: TextInputType.number,
                      ),
                      _SettingsDivider(cardBorder: cardBorder),
                      _SettingsSwitchRow(
                        title: 'Auto-reconnect',
                        subtitle: 'Reconnect when ELIO is available again.',
                        value: autoReconnect,
                        onChanged: onAutoReconnectChanged,
                        primaryColor: primaryColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SettingsSectionCard(
                    title: 'Video',
                    cardBorder: cardBorder,
                    children: [
                      _SettingsDropdownRow(
                        title: 'Resolution',
                        value: resolution,
                        options: const [
                          '720p (HD)',
                          '1080p (FHD)',
                          '1440p (QHD)',
                        ],
                        onChanged: onResolutionChanged,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      _SettingsDivider(cardBorder: cardBorder),
                      _SettingsSwitchRow(
                        title: 'Show FPS Overlay',
                        subtitle: 'Display stream performance while viewing.',
                        value: showFpsOverlay,
                        onChanged: onShowFpsOverlayChanged,
                        primaryColor: primaryColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SettingsSectionCard(
                    title: 'Audio',
                    cardBorder: cardBorder,
                    children: [
                      _SettingsSwitchRow(
                        title: 'Sound Effects',
                        subtitle: 'Play UI and robot feedback sounds.',
                        value: soundEffects,
                        onChanged: onSoundEffectsChanged,
                        primaryColor: primaryColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      _SettingsDivider(cardBorder: cardBorder),
                      _SettingsSliderRow(
                        title: 'Master Volume',
                        value: masterVolume,
                        onChanged: onMasterVolumeChanged,
                        primaryColor: primaryColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SettingsSectionCard(
                    title: 'Quiz',
                    cardBorder: cardBorder,
                    children: [
                      _SettingsDropdownRow(
                        title: 'Difficulty',
                        value: quizDifficulty,
                        options: const ['Easy', 'Medium', 'Hard'],
                        onChanged: onQuizDifficultyChanged,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      _SettingsDivider(cardBorder: cardBorder),
                      _SettingsDropdownRow(
                        title: 'Timer',
                        value: quizTimer,
                        options: const ['30s', '60s', '90s', '120s'],
                        onChanged: onQuizTimerChanged,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      _SettingsDivider(cardBorder: cardBorder),
                      _SettingsSwitchRow(
                        title: 'Skip Allowed',
                        subtitle: 'Let learners skip questions during quiz.',
                        value: skipAllowed,
                        onChanged: onSkipAllowedChanged,
                        primaryColor: primaryColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: const Text('DONE'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  final String title;
  final Color cardBorder;
  final List<Widget> children;

  const _SettingsSectionCard({
    required this.title,
    required this.cardBorder,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123524).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFF7F8C8D),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  final Color cardBorder;

  const _SettingsDivider({required this.cardBorder});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: cardBorder.withValues(alpha: 0.22)),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBorder;
  final TextInputType? keyboardType;

  const _SettingsTextField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBorder,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, color: textSecondary, size: 20),
        filled: true,
        fillColor: const Color(0xFFF7FAF6),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cardBorder.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cardBorder.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF004F38), width: 1.5),
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color primaryColor;
  final Color textPrimary;
  final Color textSecondary;

  const _SettingsSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.primaryColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: textSecondary,
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: primaryColor,
        ),
      ],
    );
  }
}

class _SettingsDropdownRow extends StatelessWidget {
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final Color textPrimary;
  final Color textSecondary;

  const _SettingsDropdownRow({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            borderRadius: BorderRadius.circular(14),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
            style: GoogleFonts.inter(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            items: options
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _SettingsSliderRow extends StatelessWidget {
  final String title;
  final double value;
  final ValueChanged<double> onChanged;
  final Color primaryColor;
  final Color textPrimary;
  final Color textSecondary;

  const _SettingsSliderRow({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.primaryColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: GoogleFonts.inter(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: primaryColor,
          inactiveColor: primaryColor.withValues(alpha: 0.16),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _FieldLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '.',
        style: TextStyle(
          color: Color(0xFF7F8C8D),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }
}
