import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, SystemChannels, SystemChrome, SystemUiMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/system_ui.dart';

import '../models/app_notification.dart';
import '../providers/app_notification_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/robot_provider.dart';
import '../theme/elio_theme.dart';
import '../widgets/app_notification_banner.dart';
import '../widgets/auth/auth_widgets.dart' show authPalette;
import '../widgets/elio_bottom_nav.dart';
import '../widgets/elio_sidebar.dart';
import 'login_screen.dart';
import 'home_screen.dart';
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

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  bool _quizInProgress = false;
  int _quizResetGeneration = 0;
  bool _syncingNavigationProvider = false;
  bool _controlScreenOpen = false;
  bool _drawerOpen = false;
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
    if (initialNavigationIndex >= 0 && initialNavigationIndex < _controlIndex) {
      _currentIndex = initialNavigationIndex;
    } else if (initialNavigationIndex == _controlIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_onBottomNavigationTap(_controlIndex, updateProvider: false));
      });
    }

    _homeScreen = HomeScreen(
      auth: widget.auth,
      onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      onOpenLearning: () => _onBottomNavigationTap(1),
    );
  }

  Widget _buildCurrentScreen() {
    if (_loggedTabBuilds.add(_currentIndex)) {
      final label = switch (_currentIndex) {
        0 => 'Home/Dashboard',
        1 => 'Learn',
        2 => 'Config',
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
    if (_syncingNavigationProvider || index < 0 || index > _controlIndex) {
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

  Future<void> _openProfile() async {
    if (!await _confirmLeaveQuiz()) return;
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _onBottomNavigationTap(
    int index, {
    bool updateProvider = true,
  }) async {
    if (index < 0 || index > _controlIndex) return;

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

  Future<void> _onDrawerTap(int index) async {
    Navigator.pop(context);
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
      child: Scaffold(
        key: _scaffoldKey,
        drawer: ElioTheme.wrap(
          Builder(
            builder: (context) => Drawer(
              width: 304,
              backgroundColor: authPalette(context).surface,
              child: ElioSidebar(
                user: user,
                currentIndex: _currentIndex,
                onSelect: _onDrawerTap,
                onClose: () => Navigator.pop(context),
                onSignOut: () async {
                  Navigator.pop(context);
                  await widget.auth.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(auth: widget.auth),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        body: _buildCurrentScreen(),
        drawerScrimColor: Colors.black.withValues(alpha: 0.4),
        floatingActionButtonLocation: const ElioControlFabLocation(),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        floatingActionButton: ElioTheme.wrap(
          ElioControlButton(onTap: () => _onBottomNavigationTap(_controlIndex)),
        ),
        onDrawerChanged: (open) => setState(() => _drawerOpen = open),
        bottomNavigationBar: ElioTheme.wrap(
          ElioBottomNav(
            // Control (3) is an action, never the active tab.
            currentIndex: _currentIndex,
            onSelectTab: _onBottomNavigationTap,
            onControl: () => _onBottomNavigationTap(_controlIndex),
            onProfile: _openProfile,
            user: user,
            profileOpen: _drawerOpen,
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
