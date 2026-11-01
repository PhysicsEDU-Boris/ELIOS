import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, SystemChannels, SystemChrome, SystemUiMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/system_ui.dart';

import '../models/app_notification.dart';
import '../providers/app_notification_provider.dart';
import '../providers/elio_theme_mode_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/robot_provider.dart';
import '../theme/elio_theme.dart';
import '../theme/elio_tokens.dart';
import '../widgets/app_notification_banner.dart';
import '../widgets/auth/auth_widgets.dart' show authPalette;
import '../widgets/elio_bottom_nav.dart';
import '../widgets/elio_drawer_host.dart';
import '../widgets/elio_sidebar.dart';
import '../widgets/elio_top_bar.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'scan_history_screen.dart';
import 'tabs/elearning_tab.dart';
import 'config_screen.dart';
import 'control_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  final FirebaseAuth auth;

  const HomeShell({super.key, required this.auth});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const int _controlIndex = 3;
  // Added by N3; the other indices are unchanged.
  static const int _historyIndex = 4;

  final _drawerKey = GlobalKey<ElioDrawerHostState>();
  final _avatarFocus = FocusNode(debugLabel: 'profile avatar');
  int _currentIndex = 0;
  bool _quizInProgress = false;
  int _quizResetGeneration = 0;
  bool _syncingNavigationProvider = false;
  bool _controlScreenOpen = false;
  final Set<int> _loggedTabBuilds = <int>{};

  late final HomeScreen _homeScreen;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    });

    final initialNavigationIndex = ref.read(navigationIndexProvider);
    if ((initialNavigationIndex >= 0 &&
            initialNavigationIndex < _controlIndex) ||
        initialNavigationIndex == _historyIndex) {
      _currentIndex = initialNavigationIndex;
    } else if (initialNavigationIndex == _controlIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_onBottomNavigationTap(_controlIndex, updateProvider: false));
      });
    }

    _homeScreen = HomeScreen(
      auth: widget.auth,
      onOpenLearning: () => _onBottomNavigationTap(1),
    );
  }

  String get _pageTitle => switch (_currentIndex) {
    0 => 'Home',
    1 => 'Learn',
    2 => 'Configure',
    _ => 'History',
  };

  Widget _buildCurrentScreen() {
    if (_loggedTabBuilds.add(_currentIndex)) {
      final label = switch (_currentIndex) {
        0 => 'Home/Dashboard',
        1 => 'Learn',
        2 => 'Config',
        _historyIndex => 'History',
        _ => 'Control placeholder',
      };
      debugPrint('[StartupDiag] building $label');
    }

    return switch (_currentIndex) {
      0 => _homeScreen,
      1 => ElearningTab(
        quizResetGeneration: _quizResetGeneration,
        onQuizActiveChanged: (active) {
          if (_quizInProgress == active) return;
          setState(() => _quizInProgress = active);
        },
      ),
      2 => const ConfigScreen(),
      _historyIndex => ScanHistoryScreen(
        onClose: () => _onBottomNavigationTap(0),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _syncNavigationProvider(int index) {
    if (ref.read(navigationIndexProvider) == index) return;

    _syncingNavigationProvider = true;
    ref.read(navigationIndexProvider.notifier).state = index;
    _syncingNavigationProvider = false;
  }

  void _handleNavigationProviderChange(int index) {
    if (_syncingNavigationProvider || index < 0 || index > _historyIndex) {
      return;
    }

    unawaited(_onBottomNavigationTap(index, updateProvider: false));
  }

  void _handleRobotStatusChange(String? previous, String next) {
    if (previous == null || previous == next) return;
    if (_isRobotConnecting(next)) return;

    final wasConnected = _isRobotConnected(previous);
    final isConnected = _isRobotConnected(next);
    final isDisconnected = _isRobotDisconnected(next);
    final notifications = ref.read(appNotificationProvider.notifier);

    if (!wasConnected && isConnected) {
      notifications.push(
        type: AppNotificationType.robot,
        title: 'ELIO connected',
        message: 'Robot connection is ready.',
        routeHint: 'robot',
      );
      return;
    }

    if (wasConnected && isDisconnected) {
      notifications.push(
        type: AppNotificationType.warning,
        title: 'ELIO disconnected',
        message: 'Robot connection was lost. Check the device or network.',
        routeHint: 'robot',
      );
      return;
    }
  }

  Future<void> _openControlScreen() async {
    if (!mounted || _controlScreenOpen) return;

    _controlScreenOpen = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ControlScreen(),
          fullscreenDialog: true,
        ),
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
      _controlScreenOpen = false;
    }
  }

  /// True when no quiz is running, or the user chose to leave it (progress reset).
  Future<bool> _confirmLeaveQuiz() async {
    if (_currentIndex != 1 || !_quizInProgress) return true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave quiz?'),
        content: const Text(
          'You have an active quiz. If you leave now, your current quiz '
          'progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave Quiz'),
          ),
        ],
      ),
    );
    if (shouldLeave != true || !mounted) return false;
    setState(() {
      _quizInProgress = false;
      _quizResetGeneration++;
    });
    return true;
  }

  Future<void> _onBottomNavigationTap(
    int index, {
    bool updateProvider = true,
  }) async {
    if (index < 0 || index > _historyIndex) return;

    if (index == _currentIndex && index != _controlIndex) return;

    if (!await _confirmLeaveQuiz()) {
      _syncNavigationProvider(_currentIndex);
      return;
    }

    if (!mounted) return;

    if (index == _controlIndex) {
      if (updateProvider) _syncNavigationProvider(index);
      await _openControlScreen();
      if (mounted) _syncNavigationProvider(_currentIndex);
      return;
    }

    setState(() => _currentIndex = index);
    if (updateProvider) _syncNavigationProvider(index);
  }

  @override
  void dispose() {
    _avatarFocus.dispose();
    super.dispose();
  }

  Future<void> _onDrawerTap(int index) async {
    _drawerKey.currentState?.close();
    await _onBottomNavigationTap(index);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      navigationIndexProvider,
      (_, next) => _handleNavigationProviderChange(next),
    );
    ref.listen<AsyncValue<String>>(robotStatusProvider, (previous, next) {
      final nextStatus = next.valueOrNull;
      if (nextStatus == null) return;
      _handleRobotStatusChange(previous?.valueOrNull, nextStatus);
    });

    final user = widget.auth.currentUser;

    return AppNotificationBannerHost(
      child: ElioDrawerHost(
        key: _drawerKey,
        onClosed: _avatarFocus.requestFocus,
        drawer: ElioTheme.wrap(
          Builder(
            builder: (context) => Material(
              color: authPalette(context).surface,
              child: ElioSidebar(
                user: user,
                currentIndex: _currentIndex,
                onSelect: _onDrawerTap,
                onClose: () => _drawerKey.currentState?.close(),
                onSignOut: () async {
                  _drawerKey.currentState?.close();
                  await widget.auth.signOut();
                  if (!mounted) return;
                  Navigator.of(this.context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(auth: widget.auth),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        child: Scaffold(
          // Shows behind the bar's rounded corners; the shell is outside ElioTheme.
          backgroundColor:
              (ref.watch(elioThemeModeProvider) == ElioThemeMode.dark
                      ? ElioTokens.dark
                      : ElioTokens.light)
                  .background,
          body: Column(
            children: [
              ElioTheme.wrap(
                Builder(
                  builder: (context) => ColoredBox(
                    color: authPalette(context).background,
                    child: SafeArea(
                      bottom: false,
                      child: ElioTopBar(
                        title: _currentIndex == 0
                            ? 'Hello, ${homeDisplayName(user)}'
                            : _pageTitle,
                        subtitle: _currentIndex == 0
                            ? 'Ready to learn with ELIO?'
                            : null,
                        trailing: _currentIndex == 0
                            ? HomeHeaderActions(
                                onOpenLearning: () => _onBottomNavigationTap(1),
                              )
                            : null,
                        photoUrl: user?.photoURL,
                        avatarFocusNode: _avatarFocus,
                        onOpenProfile: () => _drawerKey.currentState?.open(),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                // The top bar already took the status bar inset.
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: _buildCurrentScreen(),
                ),
              ),
            ],
          ),
          floatingActionButtonLocation: const ElioControlFabLocation(),
          floatingActionButtonAnimator:
              FloatingActionButtonAnimator.noAnimation,
          floatingActionButton: ElioTheme.wrap(
            ElioControlButton(
              onTap: () => _onBottomNavigationTap(_controlIndex),
              modelAsset: 'assets/models/mobilElios5.glb',
            ),
          ),
          bottomNavigationBar: ElioTheme.wrap(
            ElioBottomNav(
              // Control (3) is an action, never the active tab.
              currentIndex: _currentIndex,
              onSelectTab: _onBottomNavigationTap,
              onControl: () => _onBottomNavigationTap(_controlIndex),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isRobotConnected(String status) {
  return status.trim().toLowerCase() == 'connected';
}

bool _isRobotDisconnected(String status) {
  return status.trim().toLowerCase() == 'disconnected';
}

bool _isRobotConnecting(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized.contains('connecting') ||
      normalized.contains('reconnecting');
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '$title — coming soon',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
