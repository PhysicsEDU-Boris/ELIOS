import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/navigation_provider.dart';
import '../providers/waste_quiz_provider.dart';
import '../services/frame_source/phone_frame_source.dart';
import '../services/frame_source/viewfinder_crop.dart';
import '../services/ai_quiz_service.dart';
import '../services/scan_record_store.dart';
import '../theme/elio_theme.dart';
import '../theme/elio_tokens.dart';
import '../widgets/control/phone/phone_control.dart'
    show PhoneCard, PhonePill, TrophyCount;
import '../widgets/control/r2_controls.dart'
    show ControlCaps, ControlStatusChip;
import '../widgets/desktop_viewport.dart';
import '../widgets/elio_drawer_host.dart';
import '../widgets/elio_sidebar.dart';
import '../widgets/elio_top_bar.dart' show ElioAvatar;
import '../widgets/learn/learn_ui.dart' show LearnTheme;
import '../widgets/waste_quiz_popup.dart';
import 'login_screen.dart';
import 'scan_history_screen.dart';

/// Scan waste with this device's own camera (no robot needed) and get the
/// ELIOS AI quiz. Figma: "Device Scan · Kamera perangkat (landscape)".
class DeviceScanScreen extends ConsumerStatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  ConsumerState<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends ConsumerState<DeviceScanScreen> {
  static const _sampleLabels = [
    'Botol plastik',
    'Kulit pisang',
    'Kaleng minuman',
    'Baterai bekas',
  ];

  static const _sidebarWidth = 240.0;
  static const _boxWidth = 260.0;
  static const _boxHeight = 200.0;

  /// The identify crop (decisions 0041, 0070): the preview fills the screen minus the old
  /// 240 dp sidebar, the 260x200 box centred in it. Kept exactly; the R3 layout draws over it.
  @visibleForTesting
  static ({Size panel, Size box}) cropGeometry(Size screen) => (
    panel: Size(screen.width - _sidebarWidth, screen.height),
    box: const Size(_boxWidth, _boxHeight),
  );

  final _drawerKey = GlobalKey<ElioDrawerHostState>();

  final PhoneFrameSource _source = PhoneFrameSource();
  bool _capturing = false;
  late final WasteQuizNotifier _quiz;

  @override
  void initState() {
    super.initState();
    _quiz = ref.read(wasteQuizProvider.notifier);
    _source.addListener(_onSourceChanged);

    setDesktopLandscape(true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } catch (_) {}
    });
    _source.initialize();
  }

  void _onSourceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    if (!_source.isInitialized || _capturing) return;
    final screen = MediaQuery.sizeOf(context);
    setState(() => _capturing = true);
    try {
      final frame = await _source.capture();
      if (frame == null) throw StateError('kamera tidak mengembalikan foto');
      // The AI and Scan History get only what is inside the viewfinder box: a
      // small battery in a wide frame was misread as a can (A1 phone test).
      final g = cropGeometry(screen);
      final photo = await cropToViewfinder(
        frame.bytes,
        panel: g.panel,
        box: g.box,
      );
      _quiz.onPhotoCaptured(photo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memotret: $e')));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _source.removeListener(_onSourceChanged);
    _source.dispose();
    Future.microtask(_quiz.dismiss);
    unawaited(AiQuizService.instance.cancel());
    setDesktopLandscape(false);
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  /// The live preview is stopped while the quiz popup covers it (saves CPU
  /// and battery for the AI) and comes back when the popup is closed or
  /// minimized.
  void _onQuizCoverChanged(bool covered) {
    if (covered) {
      _source.pausePreview();
    } else {
      _source.resumePreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WasteQuizUiState>(wasteQuizProvider, (prev, next) {
      final was =
          prev != null && prev.phase != WasteQuizPhase.idle && !prev.minimized;
      final now = next.phase != WasteQuizPhase.idle && !next.minimized;
      if (was != now) _onQuizCoverChanged(now);
    });
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = context.elio;
          return ElioDrawerHost(
            key: _drawerKey,
            drawer: Material(
              color: p.surface,
              child: ElioSidebar(
                user: user,
                currentIndex: -1,
                onClose: () => _drawerKey.currentState?.close(),
                onSelect: (index) {
                  final nav = ref.read(navigationIndexProvider.notifier);
                  _drawerKey.currentState?.close();
                  Navigator.of(context).pop();
                  nav.state = index;
                },
                onSignOut: () async {
                  final nav = Navigator.of(context, rootNavigator: true);
                  _drawerKey.currentState?.close();
                  await FirebaseAuth.instance.signOut();
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => LoginScreen(auth: FirebaseAuth.instance),
                    ),
                    (_) => false,
                  );
                },
              ),
            ),
            child: Scaffold(
              backgroundColor: p.background,
              body: Stack(
                children: [
                  ScanScreenLayout(
                    ready: _source.isInitialized,
                    error: _source.error,
                    cameraName: _source.cameraName,
                    preview: _source.isInitialized && _source.error == null
                        ? _source.buildPreview()
                        : null,
                    capturing: _capturing,
                    cropGeometry: cropGeometry(MediaQuery.sizeOf(context)),
                    onBack: () => Navigator.of(context).pop(),
                    onHistory: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ScanHistoryScreen(store: ScanRecordStore.instance),
                      ),
                    ),
                    avatar: ElioAvatar(
                      photoUrl: user?.photoURL,
                      onTap: () => _drawerKey.currentState?.open(),
                    ),
                    onScan: _capture,
                    onSwitchCamera: _source.switchCamera,
                    testLabels: kDebugMode ? _sampleLabels : null,
                    onTestLabel: _quiz.startForLabel,
                  ),
                  // The photo is being taken and cropped: the popup is opening, no quiz state yet.
                  if (_capturing)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x59000000),
                        child: SafeArea(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                            child: QuizPopupSkeleton(),
                          ),
                        ),
                      ),
                    ),
                  const WasteQuizPopup(showLauncher: false),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Test access to the screen's crop geometry.
abstract final class DeviceScanScreenTestHook {
  static ({Size panel, Size box}) cropGeometry(Size screen) =>
      _DeviceScanScreenState.cropGeometry(screen);
}

/// The R3 phone camera scan screen (Figma 423:8162 ready, 423:8441 skeleton). [cropGeometry] places the preview and the white corners where
/// the identify crop is, unchanged from before (decisions 0041, 0070).
class ScanScreenLayout extends StatelessWidget {
  const ScanScreenLayout({
    super.key,
    required this.ready,
    required this.error,
    required this.cameraName,
    required this.preview,
    required this.capturing,
    required this.cropGeometry,
    required this.onBack,
    required this.onHistory,
    required this.avatar,
    required this.onScan,
    required this.onSwitchCamera,
    required this.testLabels,
    required this.onTestLabel,
    this.ai,
  });

  final bool ready, capturing;
  final String? error;
  final String cameraName;
  final Widget? preview;
  final ({Size panel, Size box}) cropGeometry;
  final VoidCallback onBack, onHistory, onScan, onSwitchCamera;
  final Widget avatar;

  /// Debug builds only: "Test mode" starts a quiz for a sample item without the camera.
  final List<String>? testLabels;
  final ValueChanged<String> onTestLabel;

  /// For tests; the last cloud call's status otherwise.
  final ValueListenable<AiStatus>? ai;

  static const _sideWidth = 271.0;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return ValueListenableBuilder<AiStatus>(
      valueListenable: ai ?? AiQuizService.instance.status,
      builder: (context, status, _) {
        if (!ready && error == null) return _skeleton(context);
        // The AI never blocks Scan: with no AI answer the quiz uses the bank (decision 0179).
        final canScan = ready && error == null && !capturing;
        final (chipText, chipColor) = switch (status) {
          AiStatus.offline => ('ELIOS AI offline · question bank', p.error),
          _ => ('ELIOS AI ready', p.primary),
        };
        return LayoutBuilder(
          builder: (context, c) {
            final pad = MediaQuery.paddingOf(context);
            final video = Rect.fromLTRB(
              pad.left + 16,
              pad.top + 96,
              c.maxWidth - pad.right - 16 - _sideWidth - 8,
              c.maxHeight - 12,
            );
            final panel = cropGeometry.panel, box = cropGeometry.box;
            return Stack(
              children: [
                // The preview at the old panel's place and size, shown through the video card.
                Positioned.fromRect(
                  rect: video,
                  child: ClipRRect(
                    key: const ValueKey('scan_video'),
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: p.surfaceRaised,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          if (preview != null)
                            Positioned(
                              left: -video.left,
                              top: -video.top,
                              width: panel.width,
                              height: panel.height,
                              child: preview!,
                            ),
                          if (error != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: p.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          if (error == null)
                            Positioned(
                              key: const ValueKey('scan_corners'),
                              left:
                                  panel.width / 2 - box.width / 2 - video.left,
                              top:
                                  panel.height / 2 - box.height / 2 - video.top,
                              width: box.width,
                              height: box.height,
                              child: const IgnorePointer(
                                child: CustomPaint(painter: _CornersPainter()),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 44,
                          child: Row(
                            children: [
                              PhonePill(
                                key: const ValueKey('scan_back'),
                                semantic: 'Back',
                                onTap: onBack,
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  size: 20,
                                  color: p.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Scan an item',
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              const QuizLauncherButton(),
                              const SizedBox(width: 8),
                              AnimatedBuilder(
                                animation: ScanRecordStore.instance,
                                builder: (context, _) => PhonePill(
                                  key: const ValueKey('scan_history'),
                                  semantic: 'History',
                                  onTap: onHistory,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.history_rounded,
                                        size: 18,
                                        color: p.textPrimary,
                                      ),
                                      const SizedBox(width: 6),
                                      TrophyCount(
                                        count: ScanRecordStore
                                            .instance
                                            .totalTrophies,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              avatar,
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 30,
                                      child: Row(
                                        children: [
                                          _Chip(
                                            dot: ready && error == null
                                                ? p.error
                                                : p.borderStrong,
                                            text: ready && error == null
                                                ? 'LIVE'
                                                : 'No camera',
                                          ),
                                          const SizedBox(width: 6),
                                          _Chip(
                                            icon: Icons.photo_camera_outlined,
                                            text: cameraName,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: _AiChip(
                                                key: const ValueKey(
                                                  'scan_ai_chip',
                                                ),
                                                text: chipText,
                                                color: chipColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: _sideWidth,
                                child: _ScanCard(
                                  status: status,
                                  canScan: canScan,
                                  capturing: capturing,
                                  onScan: onScan,
                                  onSwitchCamera: ready ? onSwitchCamera : null,
                                  testLabels: testLabels,
                                  onTestLabel: onTestLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Camera starting (Figma 423:8441): flat placeholders in the same grid.
  Widget _skeleton(BuildContext context) {
    final p = context.elio;
    Widget block(double? w, double h, [double r = 12]) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(r),
      ),
    );
    return SafeArea(
      child: Padding(
        key: const ValueKey('scan_skeleton'),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  block(44, 44, 22),
                  const SizedBox(width: 8),
                  block(112, 28, 14),
                  const Spacer(),
                  block(104, 40, 20),
                  const SizedBox(width: 8),
                  block(38, 38, 19),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Flexible(child: block(108, 28, 14)),
                            const SizedBox(width: 6),
                            Flexible(child: block(120, 28, 14)),
                            const Spacer(),
                            Flexible(child: block(132, 28, 14)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(child: block(null, double.infinity, 16)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: _sideWidth,
                    child: PhoneCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              block(16, 16, 8),
                              const SizedBox(width: 6),
                              block(36, 12, 6),
                              const Spacer(),
                              block(64, 22, 11),
                            ],
                          ),
                          const SizedBox(height: 10),
                          block(null, 56),
                          const SizedBox(height: 10),
                          // Shrinks on very short screens instead of overflowing.
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 84),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: block(null, double.infinity, 42),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          block(140, 14, 7),
                          const SizedBox(height: 8),
                          block(180, 12, 6),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(child: block(null, 34, 17)),
                              const SizedBox(width: 6),
                              Expanded(child: block(null, 34, 17)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.dot, this.icon});
  final String text;
  final Color? dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: p.borderSubtle),
        boxShadow: [
          BoxShadow(color: p.borderMedium, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null)
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            if (icon != null) Icon(icon, size: 14, color: p.textPrimary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ELIOS AI status from the last cloud call.
class _AiChip extends StatelessWidget {
  const _AiChip({
    super.key,
    required this.text,
    required this.color,
  });
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final ok = color == p.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: p.borderSubtle),
        boxShadow: [
          BoxShadow(color: p.borderMedium, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ok
                ? const EliosAiBadge(size: 20)
                : Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                  ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({
    required this.status,
    required this.canScan,
    required this.capturing,
    required this.onScan,
    required this.onSwitchCamera,
    required this.testLabels,
    required this.onTestLabel,
  });
  final AiStatus status;
  final bool canScan, capturing;
  final VoidCallback onScan;
  final VoidCallback? onSwitchCamera;
  final List<String>? testLabels;
  final ValueChanged<String> onTestLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final (word, wordColor) = status == AiStatus.offline
        ? ('Bank mode', p.textSecondary)
        : ('Ready', p.primaryText);
    return PhoneCard(
      child: LayoutBuilder(
        builder: (context, c) {
          // Short phones (360 dp): a smaller Scan button and tip, same content.
          final compact = c.maxHeight < 280;
          final button = compact ? 60.0 : 76.0;
          return Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    size: 16,
                    color: p.primaryText,
                  ),
                  const SizedBox(width: 6),
                  const ControlCaps('SCAN'),
                  const Spacer(),
                  ControlStatusChip(label: word, color: wordColor),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: SvgPicture.asset(
                        'assets/illustrations/control/bottle_buddy_happy.svg',
                        height: 40,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Put one item inside the white box, then tap Scan.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Semantics(
                button: true,
                enabled: canScan,
                label: 'Scan and make quiz',
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('scan_button'),
                  onTap: canScan ? onScan : null,
                  child: Opacity(
                    opacity: canScan || capturing ? 1 : 0.45,
                    child: Container(
                      width: button,
                      height: button,
                      decoration: BoxDecoration(
                        color: p.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.surface, width: 5),
                        boxShadow: [
                          BoxShadow(
                            color: p.primaryActive,
                            offset: const Offset(0, 4),
                          ),
                          if (canScan) ...ElioGlow.medium,
                        ],
                      ),
                      child: capturing
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                color: p.onPrimary,
                                strokeWidth: 3,
                              ),
                            )
                          : Icon(
                              Icons.photo_camera_outlined,
                              size: 30,
                              color: p.onPrimary,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan & make quiz',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: p.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'About 2–4 s · needs internet',
                    style: TextStyle(color: p.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: PhonePill(
                      key: const ValueKey('scan_switch_camera'),
                      semantic: 'Switch camera',
                      onTap: onSwitchCamera ?? () {},
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cameraswitch_outlined,
                            size: 14,
                            color: p.textPrimary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Switch camera',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (testLabels != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 4,
                      child: PopupMenuButton<String>(
                        key: const ValueKey('scan_test_mode'),
                        tooltip: 'Test mode: quiz without the camera',
                        onSelected: onTestLabel,
                        itemBuilder: (context) => [
                          for (final l in testLabels!)
                            PopupMenuItem(value: l, child: Text(l)),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: p.surfaceRaised,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: p.borderMedium),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.science_outlined,
                                size: 14,
                                color: p.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Test mode',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// White viewfinder corners (Figma 423:8162): the only thing drawn on the video.
class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const l = 22.0, r = 12.0;
    for (final (x, y, sx, sy) in [
      (0.0, 0.0, 1.0, 1.0),
      (size.width, 0.0, -1.0, 1.0),
      (0.0, size.height, 1.0, -1.0),
      (size.width, size.height, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(x, y + sy * l)
        ..lineTo(x, y + sy * r)
        ..arcToPoint(
          Offset(x + sx * r, y),
          radius: const Radius.circular(r),
          clockwise: sx * sy > 0,
        )
        ..lineTo(x + sx * l, y);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
