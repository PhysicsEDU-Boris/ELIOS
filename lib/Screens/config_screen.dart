// Copyright (c) Boris Agung, Irham Fajar

import 'package:elio/models/config_model.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/app_preferences_provider.dart';
import '../providers/esp_config_provider.dart';
import '../providers/robot_provider.dart';
import '../services/gemma_quiz_service.dart';
import '../utils/system_ui.dart';
import 'control_screen.dart';
import 'device_scan_screen.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final TextEditingController _ip1 = TextEditingController();
  final TextEditingController _ip2 = TextEditingController();
  final TextEditingController _ip3 = TextEditingController();
  final TextEditingController _ip4 = TextEditingController();
  final TextEditingController _port = TextEditingController();

  bool saveDefault = true;
  bool _isConnecting = false;
  bool _connectionFailed = false;

  /// Guards against stomping on user typing when espConfigProvider rebuilds.
  bool _configPopulated = false;

  final Color backgroundMain = const Color(0xFFFAFCFA);
  final Color textPrimary = const Color(0xFF1C2833);
  final Color textSecondary = const Color(0xFF7F8C8D);
  final Color primaryColor = const Color(0xFF004F38);
  final Color cardBorder = const Color(0xFFBEC9C2);
  final Color inputSurface = Colors.white;

  /// Populate IP/port controllers from [EspConfig] once on first data arrival.
  void _populateControllersFromConfig(EspConfig config) {
    if (_configPopulated) return;
    _configPopulated = true;

    final ip = config.esp32IpAddress;
    if (ip.isNotEmpty) {
      final parts = ip.split('.');
      if (parts.length == 4) {
        _ip1.text = parts[0];
        _ip2.text = parts[1];
        _ip3.text = parts[2];
        _ip4.text = parts[3];
      }
    }
    if (config.port > 0) {
      _port.text = config.port.toString();
    }
  }

  Future<void> _openControlScreen() => _openLandscapeScreen(const ControlScreen());

  Future<void> _openDeviceScan() => _openLandscapeScreen(const DeviceScanScreen());

  Future<void> _openLandscapeScreen(Widget screen) async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      try {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        applyTransparentSystemBars();
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
    await ws
        .disconnect(); // full teardown: cancels subscription, closes channel, resets all flags
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
        await ref
            .read(espConfigProvider.notifier)
            .patch((c) => c.copyWith(esp32IpAddress: ip, port: port));
      }
      // Only navigate if actually connected
      if (!mounted) return;
      await _openControlScreen();
    } else {
      setState(() => _connectionFailed = true);
      // Show error and STAY on Config Screen
      _showSnack(
        'Make sure your phone is connected to the ELIOS Wi-Fi network in Settings',
        isError: true,
      );
    }
  }

  Future<void> _disconnect() async {
    await WebSocketService().disconnect();
    if (!mounted) return;
    setState(() {
      _connectionFailed = false;
    });
    _showSnack('Disconnected. Choose a new network or reconnect.');
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
        return _ConfigSettingsSheet(
          primaryColor: primaryColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          cardBorder: cardBorder,
        );
      },
    );
  }

  @override
  void dispose() {
    _ip1.dispose();
    _ip2.dispose();
    _ip3.dispose();
    _ip4.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Populate IP/port from persisted config (once) ────────────
    final espConfigAsync = ref.watch(espConfigProvider);
    espConfigAsync.whenData(_populateControllersFromConfig);
    final cameraSource = espConfigAsync.valueOrNull?.cameraSource ?? CameraSource.maixCam2;
    final deviceMode = cameraSource == CameraSource.device;

    final height = MediaQuery.of(context).size.height;
    final compact = height < 760;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final batteryPercent = 62;
    final isCharging = false;
    final robotStatus =
        ref.watch(robotStatusProvider).valueOrNull ?? 'Disconnected';

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
                      linkStatus: robotStatus,
                    ),
                    const SizedBox(height: 10),
                    _CameraSourceCard(
                      selected: cameraSource,
                      onChanged: (source) => ref
                          .read(espConfigProvider.notifier)
                          .patch((c) => c.copyWith(cameraSource: source)),
                      primaryColor: primaryColor,
                      borderColor: cardBorder,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: 10),
                    _OfflineAiCard(
                      primaryColor: primaryColor,
                      borderColor: cardBorder,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                    const SizedBox(height: 10),
                    if (!deviceMode)
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
                              _buildIpField(_ip1, hintText: '192'),
                              const _DotSeparator(),
                              _buildIpField(_ip2, hintText: '168'),
                              const _DotSeparator(),
                              _buildIpField(_ip3, hintText: '1'),
                              const _DotSeparator(),
                              _buildIpField(_ip4, hintText: 'x'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _FieldLabel('Port', color: textPrimary),
                          const SizedBox(height: 5),
                          _buildPortField(),
                          const SizedBox(height: 5),
                          Text(
                            "Connect your phone to the robot's ELIOS Wi-Fi network first, then tap Connect",
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

                    // ── Bottom action bar (inside the scroll view) ──
                    const SizedBox(height: 12),
                    deviceMode ? _buildScanAction() : _buildBottomActions(),
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

  Widget _buildScanAction() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder.withValues(alpha: 0.34)),
      ),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openDeviceScan,
          icon: const Icon(Icons.photo_camera_rounded, size: 20),
          label: const Text('MULAI SCAN'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.4),
          ),
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
                flex: 2,
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
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isConnecting ? null : _disconnect,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Icon(Icons.link_off_rounded, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIpField(TextEditingController controller, {String? hintText}) {
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
            hintText: hintText,
            hintStyle: TextStyle(
              color: textSecondary.withValues(alpha: 0.4),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
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
  final String linkStatus;

  const _RobotConnectionPanel({
    required this.primaryColor,
    required this.borderColor,
    required this.textPrimary,
    required this.inputSurface,
    required this.height,
    required this.modelSize,
    required this.batteryPercent,
    required this.isCharging,
    required this.linkStatus,
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
                  width: 118,
                  child: _FloatingStatusChip(
                    icon: linkStatus == 'Connected'
                        ? Icons.link_rounded
                        : linkStatus == 'Reconnecting...' ||
                              linkStatus == 'Connecting...'
                        ? Icons.sync_rounded
                        : Icons.link_off_rounded,
                    label: 'Status',
                    value: linkStatus == 'Connected'
                        ? 'Connected'
                        : linkStatus == 'Reconnecting...'
                        ? 'Reconnecting'
                        : linkStatus == 'Connecting...'
                        ? 'Connecting'
                        : 'Disconnected',
                    accent: linkStatus == 'Connected'
                        ? const Color(0xFF1D9E75)
                        : linkStatus == 'Reconnecting...' ||
                              linkStatus == 'Connecting...'
                        ? const Color(0xFFE67E22)
                        : const Color(0xFFE74C3C),
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

class _ConfigSettingsSheet extends ConsumerWidget {
  final Color primaryColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBorder;

  const _ConfigSettingsSheet({
    required this.primaryColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBorder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final espConfig =
        ref.watch(espConfigProvider).valueOrNull ?? const EspConfig();
    final appPrefs = ref.watch(appPreferencesProvider);

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

                  // ── Connection ──
                  _SettingsSectionCard(
                    title: 'Connection',
                    cardBorder: cardBorder,
                    children: [
                      _SettingsSwitchRow(
                        title: 'Auto-reconnect',
                        subtitle: 'Reconnect when ELIO is available again.',
                        value: espConfig.autoReconnect,
                        onChanged: (value) {
                          ref
                              .read(espConfigProvider.notifier)
                              .patch((c) => c.copyWith(autoReconnect: value));
                        },
                        primaryColor: primaryColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Video ──
                  _SettingsSectionCard(
                    title: 'Video',
                    cardBorder: cardBorder,
                    children: [
                      _SettingsDropdownRow(
                        title: 'Resolution',
                        value: espConfig.resolutionPreset,
                        options: const ['480p', '720p'],
                        onChanged: (value) {
                          if (value == null) return;
                          ref
                              .read(espConfigProvider.notifier)
                              .patch(
                                (c) => c.copyWith(resolutionPreset: value),
                              );
                        },
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      _SettingsDivider(cardBorder: cardBorder),
                      _SettingsSwitchRow(
                        title: 'Show FPS Overlay',
                        subtitle: 'Display stream performance while viewing.',
                        value: espConfig.showFpsOverlay,
                        onChanged: (value) {
                          ref
                              .read(espConfigProvider.notifier)
                              .patch((c) => c.copyWith(showFpsOverlay: value));
                        },
                        primaryColor: primaryColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Audio ──
                  _SettingsSectionCard(
                    title: 'Audio',
                    cardBorder: cardBorder,
                    children: [
                      _SettingsSwitchRow(
                        title: 'Sound Effects',
                        subtitle: 'Play UI and robot feedback sounds.',
                        value: appPrefs.soundEffects,
                        onChanged: (value) {
                          ref
                              .read(appPreferencesProvider.notifier)
                              .update((p) => p.copyWith(soundEffects: value));
                        },
                        primaryColor: primaryColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      _SettingsDivider(cardBorder: cardBorder),
                      _SettingsSliderRow(
                        title: 'Master Volume',
                        value: appPrefs.masterVolume,
                        onChanged: (value) {
                          ref
                              .read(appPreferencesProvider.notifier)
                              .update((p) => p.copyWith(masterVolume: value));
                        },
                        primaryColor: primaryColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Quiz ──
                  _SettingsSectionCard(
                    title: 'Quiz',
                    cardBorder: cardBorder,
                    children: [
                      _SettingsDropdownRow(
                        title: 'Difficulty',
                        value: appPrefs.quizDifficulty,
                        options: const ['Easy', 'Medium', 'Hard'],
                        onChanged: (value) {
                          if (value == null) return;
                          ref
                              .read(appPreferencesProvider.notifier)
                              .update((p) => p.copyWith(quizDifficulty: value));
                        },
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      _SettingsDivider(cardBorder: cardBorder),
                      _SettingsDropdownRow(
                        title: 'Timer',
                        value: appPrefs.quizTimer,
                        options: const ['30s', '60s', '90s', '120s'],
                        onChanged: (value) {
                          if (value == null) return;
                          ref
                              .read(appPreferencesProvider.notifier)
                              .update((p) => p.copyWith(quizTimer: value));
                        },
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      _SettingsDivider(cardBorder: cardBorder),
                      _SettingsSwitchRow(
                        title: 'Skip Allowed',
                        subtitle: 'Let learners skip questions during quiz.',
                        value: appPrefs.skipAllowed,
                        onChanged: (value) {
                          ref
                              .read(appPreferencesProvider.notifier)
                              .update((p) => p.copyWith(skipAllowed: value));
                        },
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

/// "Sumber Kamera" card: pick the robot's MaixCAM2 or this device's camera.
class _CameraSourceCard extends StatelessWidget {
  const _CameraSourceCard({
    required this.selected,
    required this.onChanged,
    required this.primaryColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  final CameraSource selected;
  final ValueChanged<CameraSource> onChanged;
  final Color primaryColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.photo_camera_rounded,
            title: 'Sumber Kamera',
            subtitle: 'Pilih kamera untuk scan sampah',
            primaryColor: primaryColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _SourceOption(
                    icon: Icons.videocam_rounded,
                    title: 'MaixCAM2',
                    description: 'Kamera robot lewat Wi-Fi ELIOS',
                    selected: selected == CameraSource.maixCam2,
                    onTap: () => onChanged(CameraSource.maixCam2),
                    primaryColor: primaryColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SourceOption(
                    icon: Icons.smartphone_rounded,
                    title: 'Kamera perangkat',
                    description: 'Scan pakai kamera HP/laptop, tanpa robot',
                    selected: selected == CameraSource.device,
                    onTap: () => onChanged(CameraSource.device),
                    primaryColor: primaryColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
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

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    required this.primaryColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? primaryColor.withValues(alpha: 0.07) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? primaryColor : borderColor, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 22, color: selected ? primaryColor : textSecondary),
                    const Spacer(),
                    Icon(
                      selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: selected ? primaryColor : textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(title, style: GoogleFonts.inter(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 11, height: 1.35, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows whether the offline Gemma model is ready (device-camera mode).
class _OfflineAiCard extends StatelessWidget {
  const _OfflineAiCard({
    required this.primaryColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color primaryColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: Icons.smart_toy_rounded,
            title: 'AI Offline (Gemma 4 E2B)',
            subtitle: 'Berjalan di perangkat · tidak butuh internet',
            primaryColor: primaryColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<GemmaProgress>(
            valueListenable: GemmaQuizService.instance.progress,
            builder: (context, p, _) {
              final service = GemmaQuizService.instance;
              const amber = Color(0xFFE67E22);
              const red = Color(0xFFC62828);
              final busy = p.status == GemmaStatus.installing || p.status == GemmaStatus.loading;
              final (text, color) = switch (p.status) {
                GemmaStatus.installing => ('Menyiapkan AI (sekali saja)… ${p.installPercent}%', amber),
                GemmaStatus.loading => ('Memuat AI ke memori…', amber),
                GemmaStatus.ready => ('Siap — AI sedang aktif', primaryColor),
                GemmaStatus.error => (p.error ?? 'AI gagal disiapkan', red),
                GemmaStatus.idle when service.isPrepared => ('Siap dipakai — tidak butuh internet', primaryColor),
                GemmaStatus.idle => ('Belum disiapkan', textSecondary),
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(text, style: GoogleFonts.inter(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  if (p.status == GemmaStatus.installing) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: p.installPercent / 100,
                        minHeight: 6,
                        color: primaryColor,
                        backgroundColor: primaryColor.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                  if (!busy && (!service.isPrepared || p.status == GemmaStatus.error)) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => service.prepare(),
                        icon: Icon(p.status == GemmaStatus.error ? Icons.refresh_rounded : Icons.download_for_offline_rounded, size: 18),
                        label: Text(p.status == GemmaStatus.error ? 'Coba lagi' : 'Siapkan AI offline'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Model AI sudah ikut terpasang bersama aplikasi. Di Android, persiapan pertama '
            'menyalinnya ke penyimpanan (±2,4 GB, 1–3 menit, sekali saja). Tidak butuh internet.',
            style: GoogleFonts.inter(color: textSecondary, fontSize: 11, height: 1.35, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: primaryColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 1),
              Text(subtitle, style: GoogleFonts.inter(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
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
