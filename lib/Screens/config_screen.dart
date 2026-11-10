// Copyright (c) Boris Agung, Irham Fajar

import 'dart:math' as math;

import 'package:elio/models/config_model.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/app_preferences_provider.dart';
import '../providers/config_link_provider.dart';
import '../providers/esp_config_provider.dart';
import '../providers/robot_provider.dart';
import '../services/robot_wifi.dart';
import '../theme/elio_motion.dart';
import '../theme/elio_theme.dart';
import '../theme/elio_tokens.dart';
import '../utils/system_ui.dart';
import '../widgets/learn/learn_ui.dart';
import '../widgets/tester_panel.dart';
import 'config/config_parts.dart';
import 'home/home_parts.dart' show homeArt;
import 'config/config_settings_sheet.dart' show ConfigSegmented;
import 'config/robot_wifi_qr_sheet.dart';
import 'control_screen.dart';
import 'package:elio/l10n/l10n.dart';
import '../services/elio_feedback.dart';

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

/// How each cable-stepper node looks (decision 0205).
enum SetupStep { done, current, todo, problem }

/// Node states for Join Wi-Fi → Find ELIOS → Connect. The app cannot see
/// which Wi-Fi the phone is on, so step 1 counts as done once ELIOS has been
/// found or a connection is underway.
List<SetupStep> setupSteps(LinkView view, {required bool found}) {
  final reached =
      found || view == LinkView.connecting || view == LinkView.connected;
  return [
    reached ? SetupStep.done : SetupStep.current,
    reached ? SetupStep.done : SetupStep.todo,
    switch (view) {
      LinkView.failed => SetupStep.problem,
      LinkView.connecting || LinkView.connected => SetupStep.current,
      LinkView.notConnected => reached ? SetupStep.current : SetupStep.todo,
    },
  ];
}

/// ELIOS setup body (Figma 629:91327): robot stage, camera row, the
/// Connection cable stepper, video stream and robot quiz. The header and
/// "Change" pill are in [EliosSetupScreen].
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

  /// The last Find result: an IP, or "not found" after a search that failed.
  String? _foundIp;
  bool _notFound = false;

  /// Guards against stomping on user typing when espConfigProvider rebuilds.
  bool _configPopulated = false;

  void _populateControllersFromConfig(EspConfig config) {
    if (_configPopulated) return;
    _configPopulated = true;
    // A live link (maybe to an unsaved address) wins over the saved default.
    final ws = WebSocketService();
    final live = ws.isConnected && ws.ip.isNotEmpty;
    _ip.text = live ? ws.ip : config.esp32IpAddress;
    final port = live ? ws.port : config.port;
    if (port > 0) _port.text = '$port';
  }

  Future<void> _openControlScreen() {
    elioFeedback(ElioSfx.blip, ElioHaptics.medium); // Figma 13 · 25
    return pushLandscapeScreen(context, const ControlScreen());
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
    if (ok && save) {
      await esp.patch((c) => c.copyWith(esp32IpAddress: ip, port: port));
    }
    // As before C1: a successful connect goes straight to Control (owner, 2 Nov).
    if (ok && mounted) await _openControlScreen();
  }

  void _disconnect() {
    ElioHaptics.heavy(); // H-heavy: Disconnect
    ref.read(configLinkProvider.notifier).disconnect();
  }

  /// The phone hotspot gives the robot a new IP after a restart; look for it.
  /// The result shows inline in step 2.
  Future<void> _find() async {
    setState(() => _finding = true);
    final ip = await findRobot(
      port: int.tryParse(_port.text) ?? EspConfig.maixCamPort,
    );
    if (!mounted) return;
    setState(() {
      _finding = false;
      _foundIp = ip;
      _notFound = ip == null;
      if (ip != null) _ip.text = ip;
    });
    elioFeedback(
      ip != null ? ElioSfx.chime : ElioSfx.knock,
      ip != null ? ElioHaptics.success : ElioHaptics.error,
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
      if (next != null && prev != null && ws.isConnected) {
        ws.setAutoReconnect(next);
      }
    });

    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = context.elio;
          return Scaffold(
            backgroundColor: p.background,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
              children: [
                ElioPopIn(
                  child: _RobotStage(
                    view: view,
                    endpoint: '${_ip.text} : ${_port.text}',
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          const ElioPopIn(index: 1, child: _CameraRow()),
                          const SizedBox(height: 24),
                          ElioPopIn(
                            index: 2,
                            child: _connectionSection(p, view, link),
                          ),
                          const SizedBox(height: 28),
                          const _VideoSection(),
                          const SizedBox(height: 28),
                          const _QuizSection(),
                          if (testerBuild) const TesterPanel(),
                        ],
                      ),
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

  Widget _connectionSection(ElioPalette p, LinkView view, ConfigLink link) {
    final esp = ref.read(espConfigProvider).valueOrNull ?? const EspConfig();
    final connecting = view == LinkView.connecting;
    final connected = view == LinkView.connected;
    final failed = view == LinkView.failed;
    // Connected means ELIOS answered at the address in the fields.
    final foundAt = _foundIp ?? (connected ? _ip.text.trim() : null);
    final steps = setupSteps(view, found: foundAt != null);
    // No link to cut: Disconnect is left out so Connect gets the full width.
    final (Widget first, Widget? second) = switch (view) {
      LinkView.notConnected => (
        ConfigButton(
          label: l10n.cfgConnectNow,
          icon: Icons.power_outlined,
          onPressed: _connect,
        ),
        null,
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
        // ELIOS 3: reopen Control while the robot stays connected.
        ConfigButton(
          label: l10n.setupOpenControl,
          icon: Icons.sports_esports_outlined,
          onPressed: _openControlScreen,
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
        null,
      ),
    };
    final saved =
        connected &&
        esp.esp32IpAddress == _ip.text.trim() &&
        '${esp.port}' == _port.text.trim();
    final stepTitle = setupStepTitle(p);

    final step1 = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.setupJoinWifi, style: stepTitle),
        const SizedBox(height: 6),
        Text(l10n.setupJoinWifiBody, style: configBody(p)),
        const SizedBox(height: 10),
        ConfigButton(
          label: l10n.setupShowWifiQr,
          icon: Icons.qr_code_2_rounded,
          primary: false,
          onPressed: () {
            elioFeedback(ElioSfx.pop, ElioHaptics.light);
            showRobotWifiQrSheet(context);
          },
        ),
      ],
    );

    final Widget? findResult = _finding
        ? Row(
            key: const ValueKey('finding'),
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: p.primaryText,
                ),
              ),
              const SizedBox(width: 8),
              Text(l10n.cfgSearching, style: configCaption(p)),
            ],
          )
        : foundAt != null
        ? _ResultChip(
            key: const ValueKey('found'),
            ok: true,
            text: l10n.setupFoundAt(foundAt),
          )
        : _notFound
        ? _ResultChip(
            key: const ValueKey('not-found'),
            ok: false,
            text: l10n.cfgNotFound,
          )
        : null;
    final step2 = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.cfgFindElio, style: stepTitle),
        const SizedBox(height: 6),
        Semantics(
          liveRegion: true,
          child: AnimatedSwitcher(
            duration: ElioMotion.reduced(context)
                ? Duration.zero
                : ElioMotion.base,
            switchInCurve: ElioMotion.pop,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: a,
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
            child: findResult ?? const SizedBox.shrink(),
          ),
        ),
        TextButton.icon(
          onPressed: connecting || _finding ? null : _find,
          style: TextButton.styleFrom(
            foregroundColor: p.primaryText,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(48, 44),
            textStyle: configStrong(p),
          ),
          icon: const Icon(Icons.search_rounded, size: 18),
          label: Text(
            foundAt != null || _notFound
                ? l10n.setupSearchAgain
                : l10n.setupSearch,
          ),
        ),
      ],
    );

    final step3Title = switch (view) {
      LinkView.connected => l10n.cfgConnected,
      LinkView.connecting => l10n.cfgConnecting,
      LinkView.failed => l10n.cfgCouldNotReach,
      LinkView.notConnected => l10n.setupConnectStep,
    };
    final step3 = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                step3Title,
                style: failed
                    ? stepTitle.copyWith(color: p.errorText)
                    : stepTitle,
              ),
            ),
            if (connected) ...[
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: p.primary,
                  shape: const StadiumBorder(),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Text(
                    l10n.cfgOnline,
                    style: ElioTokens.label.copyWith(color: p.onPrimary),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (failed) ...[
          const SizedBox(height: 8),
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
                    child: Text(
                      link.failure!,
                      style: configCaption(p, color: p.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
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
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
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
        const SizedBox(height: 6),
        if (saved)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(Icons.check_rounded, size: 16, color: p.primaryText),
                const SizedBox(width: 6),
                Text(l10n.setupSavedDefault, style: configCaption(p)),
              ],
            ),
          )
        else
          MergeSemantics(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: connecting
                  ? null
                  : () {
                      elioFeedback(ElioSfx.tick, ElioHaptics.select);
                      setState(() => saveDefault = !saveDefault);
                    },
              child: Row(
                children: [
                  Checkbox(
                    value: saveDefault,
                    onChanged: connecting
                        ? null
                        : (v) => setState(() => saveDefault = v ?? true),
                  ),
                  Expanded(
                    child: Text(l10n.setupSaveDefault, style: configCaption(p)),
                  ),
                ],
              ),
            ),
          ),
        _SwitchLine(
          title: l10n.setAutoReconnect,
          subtitle: l10n.setAutoReconnectSub,
          value: esp.autoReconnect,
          onChanged: (v) => ref
              .read(espConfigProvider.notifier)
              .patch((c) => c.copyWith(autoReconnect: v)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: first),
            if (second != null) ...[
              const SizedBox(width: 8),
              Expanded(child: second),
            ],
          ],
        ),
      ],
    );

    return Form(
      key: _form,
      child: Column(
        key: _connectionCard,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SetupSectionTitle(l10n.cfgConnection, squiggle: true),
          const SizedBox(height: 4),
          Text(l10n.setupWsOverWifi, style: configCaption(p)),
          const SizedBox(height: 16),
          for (final (i, body) in [step1, step2, step3].indexed)
            _CableStep(n: i + 1, state: steps[i], last: i == 2, child: body),
        ],
      ),
    );
  }
}

/// Step titles in the cable stepper and the video rows.
TextStyle setupStepTitle(ElioPalette p) => ElioTokens.body.copyWith(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  height: 1.5,
  color: p.textPrimary,
);

/// "Connection", "Video stream", "Quiz" (optionally with the green squiggle).
class SetupSectionTitle extends StatelessWidget {
  const SetupSectionTitle(this.title, {super.key, this.squiggle = false});
  final String title;
  final bool squiggle;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ElioTokens.body.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: p.textPrimary,
            ),
          ),
          if (squiggle)
            ExcludeSemantics(
              child: SvgPicture.asset(
                'assets/illustrations/scan/squiggle.svg',
                width: 84,
                height: 10,
                colorFilter: ColorFilter.mode(p.primary, BlendMode.srcIn),
              ),
            ),
        ],
      ),
    );
  }
}

/// One step on the cable: the node, the wire down to the next node and the
/// step's content (Figma "Cable stepper").
class _CableStep extends StatelessWidget {
  const _CableStep({
    required this.n,
    required this.state,
    required this.last,
    required this.child,
  });

  final int n;
  final SetupStep state;
  final bool last;
  final Widget child;

  static const _rail = 56.0;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Stack(
      children: [
        if (!last)
          Positioned(
            left: 0,
            top: 16,
            bottom: 0,
            width: 48,
            child: ExcludeSemantics(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                  end: state == SetupStep.done ? p.primary : p.borderMedium,
                ),
                duration: ElioMotion.reduced(context)
                    ? Duration.zero
                    : ElioMotion.slow,
                builder: (context, c, _) =>
                    CustomPaint(painter: _WirePainter(c ?? p.borderMedium)),
              ),
            ),
          ),
        Positioned(
          left: 8,
          top: 0,
          child: _StepNode(n: n, state: state),
        ),
        Padding(
          padding: EdgeInsets.only(left: _rail, top: 2, bottom: last ? 0 : 28),
          child: child,
        ),
      ],
    );
  }
}

/// The gently wavy cable between two nodes.
class _WirePainter extends CustomPainter {
  _WirePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const x = 24.0;
    final path = Path()..moveTo(x, 0);
    for (var y = 4.0; y <= size.height; y += 4) {
      path.lineTo(x + 3 * math.sin(y / 48 * math.pi), y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WirePainter old) => old.color != color;
}

class _StepNode extends StatelessWidget {
  const _StepNode({required this.n, required this.state});
  final int n;
  final SetupStep state;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final stateText = switch (state) {
      SetupStep.done => l10n.setupStepDone,
      SetupStep.current => l10n.setupStepNow,
      SetupStep.todo => l10n.setupStepTodo,
      SetupStep.problem => l10n.setupStepProblem,
    };
    final Widget node = switch (state) {
      SetupStep.done => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded, size: 20, color: p.onPrimary),
      ),
      SetupStep.current => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: p.background,
          shape: BoxShape.circle,
          border: Border.all(color: p.primary, width: 3),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
        ),
      ),
      SetupStep.todo => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: p.background,
          shape: BoxShape.circle,
          border: Border.all(color: p.borderMedium, width: 2),
        ),
        alignment: Alignment.center,
        child: Text('$n', style: configStrong(p, color: p.textTertiary)),
      ),
      SetupStep.problem => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: p.error, shape: BoxShape.circle),
        child: Icon(Icons.priority_high_rounded, size: 20, color: p.onError),
      ),
    };
    return Semantics(
      key: ValueKey('setup-step-$n-${state.name}'),
      label: l10n.setupStepState(n, stateText),
      excludeSemantics: true,
      child: AnimatedSwitcher(
        duration: ElioMotion.reduced(context) ? Duration.zero : ElioMotion.slow,
        switchInCurve: ElioMotion.pop,
        transitionBuilder: (child, a) =>
            ScaleTransition(scale: a, child: child),
        child: KeyedSubtree(key: ValueKey(state), child: node),
      ),
    );
  }
}

/// "✓ Found at 192.168.4.1" / "ELIOS not found on this Wi-Fi".
class _ResultChip extends StatelessWidget {
  const _ResultChip({super.key, required this.ok, required this.text});
  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final c = ok ? p.primaryText : p.errorText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: ShapeDecoration(
        color: (ok ? p.primary : p.error).withValues(alpha: 0.12),
        shape: StadiumBorder(
          side: BorderSide(
            color: (ok ? p.primary : p.error).withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_rounded : Icons.error_outline_rounded,
            size: 14,
            color: c,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: ElioTokens.label.copyWith(color: c)),
          ),
        ],
      ),
    );
  }
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

/// Robot stage (Figma "Robot stage"): spotlight, the real 3D model on a floor
/// shadow, "Drag to rotate", Status and Camera orbit bubbles and the name tag.
/// The robot does not report its battery, so there is no Battery bubble.
class _RobotStage extends StatelessWidget {
  const _RobotStage({required this.view, required this.endpoint});
  final LinkView view;
  final String endpoint;

  static const _w = 390.0, _h = 380.0;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final connected = view == LinkView.connected;
    // Robots always use MaixCAM2 (ELIOS 3); the phone scans from the Scan hub.
    final subtitle = switch (view) {
      LinkView.connected => '$endpoint · MaixCAM2',
      LinkView.connecting => l10n.cfgConnectingTo(endpoint),
      LinkView.failed => l10n.cfgLastTryFailed,
      LinkView.notConnected => l10n.cfgNotConnectedYet,
    };
    final (statusText, dot) = switch (view) {
      LinkView.connected => (l10n.cfgOnline, p.primaryText),
      LinkView.connecting => (l10n.cfgConnectingShort, p.secondaryText),
      LinkView.failed => (l10n.cfgOffline, p.errorText),
      LinkView.notConnected => (l10n.cfgOffline, p.textTertiary),
    };
    final stage = SizedBox(
      width: _w,
      height: _h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 30,
            top: 6,
            child: _Disc(
              330,
              p.primary.withValues(alpha: p.isDark ? 0.16 : 0.12),
            ),
          ),
          Positioned(
            left: 68,
            top: 44,
            child: AnimatedContainer(
              duration: ElioMotion.reduced(context)
                  ? Duration.zero
                  : ElioMotion.slow,
              curve: ElioMotion.standard,
              width: 254,
              height: 254,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected
                    ? p.primary
                    : p.primary.withValues(alpha: p.isDark ? 0.28 : 0.24),
              ),
            ),
          ),
          Positioned(
            left: 115,
            top: 266,
            child: Container(
              width: 160,
              height: 22,
              decoration: ShapeDecoration(
                color: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.14),
                shape: const OvalBorder(),
              ),
            ),
          ),
          const Positioned(
            left: 68,
            top: 44,
            width: 254,
            height: 254,
            child: ClipOval(child: _ElioModelViewer()),
          ),
          if (view == LinkView.connecting)
            Positioned(
              left: 0,
              right: 0,
              top: 276,
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
          Positioned(
            left: 18,
            top: 20,
            child: Transform.rotate(
              angle: 0.14,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: p.surface,
                  shape: StadiumBorder(side: BorderSide(color: p.borderSubtle)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
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
            ),
          ),
          Positioned(
            left: 8,
            top: 226,
            child: Semantics(
              liveRegion: true,
              label: '${l10n.cfgStatus}: $statusText',
              excludeSemantics: true,
              child: _OrbitBubble(
                size: 92,
                label: l10n.cfgStatus,
                value: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        statusText,
                        style: configStrong(
                          p,
                          color: connected ? p.primaryText : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 274,
            top: 226,
            child: Semantics(
              label: l10n.setupCameraAuto,
              excludeSemantics: true,
              child: _OrbitBubble(
                size: 108,
                label: l10n.cfgCamera,
                value: Text('MaixCAM2', style: configStrong(p)),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 318,
            child: Column(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'ELIOS',
                    style: ElioTokens.bodyLarge.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: configCaption(p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    // Narrow phones scale the stage down instead of cutting the bubbles off.
    return LayoutBuilder(
      builder: (context, c) => Center(
        child: c.maxWidth >= _w
            ? stage
            : SizedBox(
                width: c.maxWidth,
                height: _h * c.maxWidth / _w,
                child: FittedBox(child: stage),
              ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _OrbitBubble extends StatelessWidget {
  const _OrbitBubble({
    required this.size,
    required this.label,
    required this.value,
  });
  final double size;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: p.isDark ? p.surfaceRaised : p.surface,
        shape: CircleBorder(side: BorderSide(color: p.borderSubtle)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: configCaption(p),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          value,
        ],
      ),
    );
  }
}

/// "Camera: MaixCAM2 · Automatic": robots always use MaixCAM2 (0196).
class _CameraRow extends StatelessWidget {
  const _CameraRow();

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: ShapeDecoration(
        color: p.surfaceRaised,
        shape: const StadiumBorder(),
      ),
      child: Row(
        children: [
          Icon(Icons.photo_camera_outlined, size: 20, color: p.textPrimary),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.setupCameraAuto, style: configStrong(p))),
          Text(
            l10n.setupAutomatic,
            style: configStrong(p, color: p.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Video stream (Figma "Section · Video"): resolution and FPS overlay.
class _VideoSection extends ConsumerWidget {
  const _VideoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.elio;
    final esp = ref.watch(espConfigProvider).valueOrNull ?? const EspConfig();
    void patch(EspConfig Function(EspConfig) f) =>
        ref.read(espConfigProvider.notifier).patch(f);
    final divider = Divider(height: 1, color: configDivider(p));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: p.secondaryText.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.desktop_windows_outlined,
                  size: 18,
                  color: p.secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: SetupSectionTitle(l10n.setupVideoStream)),
          ],
        ),
        const SizedBox(height: 8),
        divider,
        const SizedBox(height: 13),
        Text(l10n.setResolution, style: setupStepTitle(p)),
        Text(l10n.setResolutionSub, style: configCaption(p)),
        const SizedBox(height: 10),
        ConfigSegmented(
          label: l10n.setResolution,
          options: const ['480p', '720p'],
          selected: esp.resolutionPreset,
          onSelected: (v) => patch((c) => c.copyWith(resolutionPreset: v)),
        ),
        const SizedBox(height: 12),
        divider,
        const SizedBox(height: 8),
        _SwitchLine(
          title: l10n.setShowFps,
          subtitle: l10n.setShowFpsSub,
          value: esp.showFpsOverlay,
          large: true,
          onChanged: (v) => patch((c) => c.copyWith(showFpsOverlay: v)),
        ),
      ],
    );
  }
}

/// Robot quiz (0198): on/off and Question bank | ELIOS AI, with the bulb
/// buddy peeking over the card. ELIOS AI can be chosen at any time; with no
/// AI answer a scan uses the bank (decision 0179). Phone scans use Profile.
class _QuizSection extends ConsumerWidget {
  const _QuizSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(
      appPreferencesProvider.select((p) => p.robotQuestionSource),
    );
    final on = ref.watch(
      appPreferencesProvider.select((p) => p.robotQuizEnabled),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: 18,
          top: -20,
          child: ExcludeSemantics(
            child: ElioIdleLoop(
              builder: (context, wave, child) => Transform.translate(
                offset: Offset(0, -3 * wave),
                child: child,
              ),
              child: homeArt('bulb_buddy', width: 56, height: 64),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SetupSectionTitle(l10n.quizWord),
            const SizedBox(height: 12),
            ConfigCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SwitchLine(
                    title: l10n.setupQuizAfterScan,
                    subtitle: on ? null : l10n.wqSavedNoQuiz,
                    value: on,
                    large: true,
                    onChanged: (v) => ref
                        .read(appPreferencesProvider.notifier)
                        .update((prefs) => prefs.copyWith(robotQuizEnabled: v)),
                  ),
                  const SizedBox(height: 12),
                  IgnorePointer(
                    ignoring: !on,
                    child: Opacity(
                      opacity: on ? 1 : 0.45,
                      child: ConfigSegmented(
                        label: l10n.cfgQuizQuestions,
                        options: [
                          for (final s in QuestionSource.values) s.name,
                        ],
                        labels: [l10n.questionBank, 'ELIOS AI'],
                        selected: shown.name,
                        onSelected: (v) => ref
                            .read(appPreferencesProvider.notifier)
                            .update(
                              (prefs) => prefs.copyWith(
                                robotQuestionSource: QuestionSource.values
                                    .byName(v),
                              ),
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const EliosAiCard(),
          ],
        ),
      ],
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
    if (_hasError) {
      return Center(
        child: Icon(Icons.smart_toy_rounded, size: 72, color: p.primaryText),
      );
    }
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

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.large = false,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Section-row title size (Figma video / quiz rows).
  final bool large;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    void flip(bool v) {
      elioFeedback(
        v ? ElioSfx.toggleOn : ElioSfx.toggleOff,
        ElioHaptics.select,
      );
      onChanged(v);
    }

    return MergeSemantics(
      child: InkWell(
        onTap: () => flip(!value),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: large ? setupStepTitle(p) : configStrong(p),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: configCaption(p)),
                ],
              ),
            ),
            Switch(value: value, onChanged: flip),
          ],
        ),
      ),
    );
  }
}
