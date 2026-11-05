// Copyright (c) Boris Agung, Irham Fajar

import 'package:elio/models/config_model.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_preferences_provider.dart';
import '../providers/config_link_provider.dart';
import '../providers/esp_config_provider.dart';
import '../providers/robot_provider.dart';
import '../services/ai_quiz_service.dart';
import '../services/robot_wifi.dart';
import '../theme/elio_theme.dart';
import '../theme/elio_tokens.dart';
import '../utils/system_ui.dart';
import '../widgets/learn/learn_ui.dart';
import '../widgets/tester_panel.dart';
import 'config/config_parts.dart';
import 'config/robot_wifi_qr_sheet.dart';
import 'control_screen.dart';
import 'device_scan_screen.dart';
import 'package:elio/l10n/l10n.dart';

/// "Enter an IP like 192.168.4.1", or null when [value] is a dotted IPv4.
String? validateIp(String? value) {
  final parts = (value ?? '').trim().split('.');
  final ok =
      parts.length == 4 &&
      parts.every(
        (s) => s.isNotEmpty && s.length <= 3 && (int.tryParse(s) ?? 256) <= 255,
      );
  return ok ? null : l10n.cfgIpHint;
}

String? validatePort(String? value) {
  final n = int.tryParse(value ?? '');
  return n == null || n < 1 || n > 65535 ? l10n.cfgPortRange : null;
}

/// C1 Config tab "Connect ELIO" (decision 0145, Figma 337:2358). The title and
/// the Settings button sit in the shell's top bar.
class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  final _ip = TextEditingController();
  final _port = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _connectionCard = GlobalKey();

  bool saveDefault = true;
  bool _finding = false;

  /// Guards against stomping on user typing when espConfigProvider rebuilds.
  bool _configPopulated = false;

  void _populateControllersFromConfig(EspConfig config) {
    if (_configPopulated) return;
    _configPopulated = true;
    _ip.text = config.esp32IpAddress;
    if (config.port > 0) _port.text = config.port.toString();
  }

  Future<void> _openControlScreen() =>
      _openLandscapeScreen(const ControlScreen());

  Future<void> _openDeviceScan() =>
      _openLandscapeScreen(const DeviceScanScreen());

  Future<void> _openLandscapeScreen(Widget screen) async {
    try {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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
    if (!(_form.currentState?.validate() ?? false)) return;
    final ip = _ip.text.trim();
    final port = int.parse(_port.text);
    final save = saveDefault;
    // Read before the await: the attempt may finish after this tab is gone.
    final esp = ref.read(espConfigProvider.notifier);
    final autoReconnect =
        ref.read(espConfigProvider).valueOrNull?.autoReconnect ?? true;
    debugPrint('[Config] Connecting to ws://$ip:$port');
    final ok = await ref
        .read(configLinkProvider.notifier)
        .connect(ip, port, autoReconnect: autoReconnect);
    debugPrint('[Config] Connect result: $ok');
    if (ok && save)
      await esp.patch((c) => c.copyWith(esp32IpAddress: ip, port: port));
    // As before C1: a successful connect goes straight to Control (owner, 2 Nov).
    if (ok && mounted) await _openControlScreen();
  }

  void _disconnect() => ref.read(configLinkProvider.notifier).disconnect();

  /// The phone hotspot gives the robot a new IP after a restart; look for it.
  Future<void> _find() async {
    setState(() => _finding = true);
    final ip = await findRobot(
      port: int.tryParse(_port.text) ?? EspConfig.maixCamPort,
    );
    if (!mounted) return;
    setState(() => _finding = false);
    if (ip != null) _ip.text = ip;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ip != null ? l10n.cfgFoundAt(ip) : l10n.cfgNotFound),
        ),
      );
  }

  /// The failure snackbar is only for a card the user scrolled away from;
  /// the inline alert already says it otherwise.
  bool _connectionCardOnScreen() {
    final box =
        _connectionCard.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return false;
    final top = box.localToGlobal(Offset.zero).dy;
    return top < MediaQuery.sizeOf(context).height && top + box.size.height > 0;
  }

  void _showFailureSnack() {
    final messenger = ScaffoldMessenger.of(context);
    final p = context.elio;
    messenger
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: p.errorText),
              const SizedBox(width: 12),
              Expanded(child: Text(context.l10n.configConnectionFailed)),
            ],
          ),
          action: SnackBarAction(
            label: l10n.cfgRetry,
            textColor: p.primaryText,
            onPressed: _connect,
          ),
        ),
      );
  }

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final espConfigAsync = ref.watch(espConfigProvider);
    espConfigAsync.whenData(_populateControllersFromConfig);
    final cameraSource =
        espConfigAsync.valueOrNull?.cameraSource ?? CameraSource.maixCam2;
    final deviceMode = cameraSource == CameraSource.device;
    final status = ref.watch(robotStatusProvider).valueOrNull ?? 'Disconnected';
    final link = ref.watch(configLinkProvider);
    final view = linkView(status, link);

    ref.listen(configLinkProvider, (prev, next) {
      if (next.failure != null &&
          next.failure != prev?.failure &&
          !_connectionCardOnScreen()) {
        _showFailureSnack();
      }
    });
    // The settings switch applies to a live link straight away.
    ref.listen(espConfigProvider.select((c) => c.valueOrNull?.autoReconnect), (
      prev,
      next,
    ) {
      final ws = WebSocketService();
      if (next != null && prev != null && ws.isConnected)
        ws.setAutoReconnect(next);
    });

    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = context.elio;
          return Scaffold(
            backgroundColor: p.background,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RobotHero(
                          view: view,
                          deviceMode: deviceMode,
                          endpoint: '${_ip.text} : ${_port.text}',
                        ),
                        const SizedBox(height: 16),
                        const EliosAiCard(),
                        if (testerBuild) const TesterPanel(),
                        const SizedBox(height: 24),
                        ConfigSectionHeader(
                          l10n.cfgCameraSource,
                          l10n.cfgCameraSourceSub,
                        ),
                        const SizedBox(height: 12),
                        _TilePair(
                          left: ChoiceTile(
                            icon: Icons.photo_camera_outlined,
                            title: 'MaixCAM2',
                            description: l10n.cfgMaixDesc,
                            selected: !deviceMode,
                            onTap: () =>
                                _setCameraSource(CameraSource.maixCam2),
                          ),
                          right: ChoiceTile(
                            icon: Icons.smartphone_outlined,
                            title: l10n.cfgPhoneCamera,
                            description: l10n.cfgPhoneCameraDesc,
                            selected: deviceMode,
                            onTap: () => _setCameraSource(CameraSource.device),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (deviceMode)
                          _startScanCard(p)
                        else
                          _connectionCardFor(p, view, link),
                        const SizedBox(height: 24),
                        ConfigSectionHeader(
                          l10n.cfgQuizQuestions,
                          l10n.cfgQuizQuestionsSub,
                        ),
                        const SizedBox(height: 12),
                        const _QuizSourceTiles(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _setCameraSource(CameraSource source) => ref
      .read(espConfigProvider.notifier)
      .patch((c) => c.copyWith(cameraSource: source));

  Widget _startScanCard(ElioPalette p) => ConfigCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.configPhoneOnlyHint, style: configBody(p)),
        const SizedBox(height: 12),
        ConfigButton(
          label: l10n.cfgStartScan,
          icon: Icons.center_focus_strong_outlined,
          onPressed: _openDeviceScan,
        ),
      ],
    ),
  );

  Widget _connectionCardFor(ElioPalette p, LinkView view, ConfigLink link) {
    final connecting = view == LinkView.connecting;
    final failed = view == LinkView.failed;
    final (Widget first, Widget second) = switch (view) {
      LinkView.notConnected => (
        ConfigButton(
          label: l10n.cfgConnectNow,
          icon: Icons.power_outlined,
          onPressed: _connect,
        ),
        ConfigButton(
          label: l10n.cfgDisconnect,
          icon: Icons.link_off_rounded,
          primary: false,
          destructive: true,
          onPressed: null,
        ),
      ),
      LinkView.connecting => (
        ConfigButton(label: l10n.cfgConnecting, busy: true, onPressed: null),
        ConfigButton(
          label: l10n.commonCancel,
          icon: Icons.link_off_rounded,
          primary: false,
          onPressed: _disconnect,
          semanticsLabel: l10n.cfgCancelConnecting,
        ),
      ),
      LinkView.connected => (
        ConfigButton(
          label: l10n.cfgConnected,
          icon: Icons.check_rounded,
          onPressed: null,
        ),
        ConfigButton(
          label: l10n.cfgDisconnect,
          icon: Icons.link_off_rounded,
          primary: false,
          destructive: true,
          onPressed: _disconnect,
        ),
      ),
      LinkView.failed => (
        ConfigButton(
          label: l10n.cfgTryAgain,
          icon: Icons.refresh_rounded,
          onPressed: _connect,
        ),
        ConfigButton(
          label: l10n.cfgDisconnect,
          icon: Icons.link_off_rounded,
          primary: false,
          destructive: true,
          onPressed: null,
        ),
      ),
    };
    return ConfigCard(
      key: _connectionCard,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConfigCardHeader(
              icon: Icons.wifi_rounded,
              title: l10n.cfgConnection,
              subtitle: l10n.cfgWsAddress,
            ),
            if (failed) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                container: true,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: ShapeDecoration(
                    color: Color.alphaBlend(
                      p.error.withValues(alpha: 0.08),
                      p.surface,
                    ),
                    shape: learnShape(
                      learnRadiusM,
                      BorderSide(color: p.error.withValues(alpha: 0.45)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: p.errorText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.cfgCouldNotReach,
                              style: configStrong(p, color: p.errorText),
                            ),
                            Text(
                              link.failure!,
                              style: configCaption(p, color: p.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _AddressField(
                    label: l10n.cfgIpAddress,
                    controller: _ip,
                    icon: Icons.dns_outlined,
                    enabled: !connecting,
                    error: failed,
                    validator: validateIp,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    formatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      LengthLimitingTextInputFormatter(15),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 116,
                  child: _AddressField(
                    label: l10n.cfgPort,
                    controller: _port,
                    icon: Icons.tag_rounded,
                    enabled: !connecting,
                    error: failed,
                    validator: validatePort,
                    keyboardType: TextInputType.number,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                  ),
                ),
              ],
            ),
            if (view != LinkView.connected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ConfigButton(
                      label: _finding ? l10n.cfgSearching : l10n.cfgFindElio,
                      icon: Icons.travel_explore_rounded,
                      busy: _finding,
                      primary: false,
                      onPressed: connecting || _finding ? null : _find,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ConfigButton(
                      label: l10n.robotWifiQr,
                      icon: Icons.qr_code_2_rounded,
                      primary: false,
                      onPressed: () => showRobotWifiQrSheet(context),
                    ),
                  ),
                ],
              ),
            ],
            if (view == LinkView.notConnected) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: ShapeDecoration(
                  color: p.surfaceRaised,
                  shape: learnShape(learnRadiusM),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: p.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.configSameWifiHint,
                        style: configCaption(p),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.configSaveDefault,
                          style: configStrong(p),
                        ),
                        Text(
                          context.l10n.configUseAddressNextTime,
                          style: configCaption(p),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: saveDefault,
                    onChanged: connecting
                        ? null
                        : (v) => setState(() => saveDefault = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: configDivider(p)),
            ),
            Row(
              children: [
                Expanded(child: first),
                const SizedBox(width: 12),
                Expanded(child: second),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TilePair extends StatelessWidget {
  const _TilePair({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    ),
  );
}

/// Input 337:2480: label above, leading icon, red border after a failure.
class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.enabled,
    required this.error,
    required this.validator,
    required this.keyboardType,
    required this.formatters,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final bool error;
  final FormFieldValidator<String> validator;
  final TextInputType keyboardType;
  final List<TextInputFormatter> formatters;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(learnRadiusM),
      borderSide: BorderSide(color: c, width: w),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Text(label, style: configCaption(p))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          style: ElioTokens.body.copyWith(color: p.textPrimary, height: 1.2),
          decoration: InputDecoration(
            hintText: label,
            prefixIcon: Icon(icon, color: p.textSecondary),
            constraints: const BoxConstraints(minHeight: 48),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: border(p.formBorder),
            enabledBorder: border(error ? p.error : p.formBorder),
            focusedBorder: border(error ? p.error : p.primaryText, 2),
            errorBorder: border(p.error),
            focusedErrorBorder: border(p.error, 2),
            disabledBorder: border(p.borderMedium),
          ),
        ),
      ],
    );
  }
}

/// Robot hero: name, address line, the real 3D model and status tiles.
class _RobotHero extends StatelessWidget {
  const _RobotHero({
    required this.view,
    required this.deviceMode,
    required this.endpoint,
  });
  final LinkView view;
  final bool deviceMode;
  final String endpoint;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final connected = !deviceMode && view == LinkView.connected;
    final onHero = connected ? p.onPrimary : p.textPrimary;
    final subtitle = deviceMode
        ? l10n.cfgRobotNotUsed
        : switch (view) {
            LinkView.connected => '$endpoint · MaixCAM2',
            LinkView.connecting => l10n.cfgConnectingTo(endpoint),
            LinkView.failed => l10n.cfgLastTryFailed,
            LinkView.notConnected => l10n.cfgNotConnectedYet,
          };
    final (statusText, dot) = deviceMode
        ? (l10n.cfgNotUsed, p.textTertiary)
        : switch (view) {
            LinkView.connected => (l10n.cfgOnline, p.primaryText),
            LinkView.connecting => (l10n.cfgConnectingShort, p.secondaryText),
            LinkView.failed => (l10n.cfgOffline, p.errorText),
            LinkView.notConnected => (l10n.cfgOffline, p.textTertiary),
          };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: connected ? p.primary : p.surfaceRaised,
        shape: learnShape(
          learnRadiusXl,
          connected ? BorderSide.none : BorderSide(color: p.borderSubtle),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'ELIOS',
                          style: ElioTokens.bodyLarge.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: onHero,
                          ),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: configCaption(
                          p,
                          color: connected ? p.onPrimary : p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: p.surface,
                    shape: const StadiumBorder(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.threesixty_rounded,
                          size: 18,
                          color: p.textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.configDragToRotate,
                          style: configCaption(p, color: p.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 196,
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: p.surface,
                shape: learnShape(learnRadiusL),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: _ElioModelViewer()),
                  if (view == LinkView.connecting && !deviceMode)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Center(
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: p.surfaceRaised,
                            shape: const StadiumBorder(),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: p.secondaryText,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.l10n.configLookingForElio,
                                  style: configCaption(p, color: p.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: StatusTile(
                      label: l10n.cfgStatus,
                      value: statusText,
                      leading: Container(
                        width: 8,
                        height: 8,
                        decoration: ShapeDecoration(
                          color: dot,
                          shape: const CircleBorder(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // The robot does not report its battery: never show a made-up value.
                Expanded(
                  child: StatusTile(
                    label: l10n.cfgBattery,
                    value: '—',
                    semanticsValue: l10n.cfgNotReported,
                    leading: RotatedBox(
                      quarterTurns: 1,
                      child: Icon(
                        Icons.battery_3_bar_rounded,
                        size: 16,
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatusTile(
                    label: l10n.cfgCamera,
                    value: deviceMode ? l10n.cfgPhone : 'MaixCAM2',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The real ELIO model; drag to rotate. Falls back to an icon without WebView.
class _ElioModelViewer extends StatefulWidget {
  const _ElioModelViewer();

  @override
  State<_ElioModelViewer> createState() => _ElioModelViewerState();
}

class _ElioModelViewerState extends State<_ElioModelViewer> {
  final Flutter3DController _controller = Flutter3DController();
  bool _hasError = false;
  bool _isLoaded = false;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    if (_hasError)
      return Center(
        child: Icon(Icons.smart_toy_rounded, size: 72, color: p.primaryText),
      );
    return Semantics(
      label: l10n.cfgRobotModel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Flutter3DViewer(
            controller: _controller,
            src: 'assets/models/robot-elio.glb',
            enableTouch: true,
            activeGestureInterceptor: true,
            progressBarColor: p.primary,
            onLoad: (_) {
              if (mounted) setState(() => _isLoaded = true);
            },
            onError: (error) {
              debugPrint('Config ELIO 3D model failed to load: $error');
              if (mounted) setState(() => _hasError = true);
            },
          ),
          if (!_isLoaded)
            SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: p.primaryText,
              ),
            ),
        ],
      ),
    );
  }
}

/// Question bank / ELIOS AI (saved choice, decision 0145). ELIOS AI can be
/// chosen at any time; with no AI answer a scan uses the bank (decision 0179).
class _QuizSourceTiles extends ConsumerWidget {
  const _QuizSourceTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(
      appPreferencesProvider.select((p) => p.questionSource),
    );
    return ValueListenableBuilder<AiStatus>(
      valueListenable: AiQuizService.instance.status,
      builder: (context, status, _) {
        final p = context.elio;
        void choose(QuestionSource s) => ref
            .read(appPreferencesProvider.notifier)
            .update((prefs) => prefs.copyWith(questionSource: s));
        return _TilePair(
          left: ChoiceTile(
            icon: Icons.storage_rounded,
            title: l10n.questionBank,
            description: l10n.cfgQuestionBankDesc,
            selected: shown == QuestionSource.bank,
            onTap: () => choose(QuestionSource.bank),
          ),
          right: ChoiceTile(
            icon: Icons.auto_awesome_rounded,
            iconWidget: Container(
              width: 40,
              height: 40,
              decoration: ShapeDecoration(
                color: shown == QuestionSource.ai ? p.surface : p.surfaceRaised,
                shape: const CircleBorder(),
              ),
              child: Center(
                child: EliosAiLogo(state: aiCardState(status), size: 26),
              ),
            ),
            title: 'ELIOS AI',
            description: l10n.cfgAiDesc,
            selected: shown == QuestionSource.ai,
            onTap: () => choose(QuestionSource.ai),
          ),
        );
      },
    );
  }
}
