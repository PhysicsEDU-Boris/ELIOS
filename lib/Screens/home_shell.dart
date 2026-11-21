import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/system_ui.dart';
import '../providers/auth_provider.dart';

import '../models/app_notification.dart';
import '../providers/app_notification_provider.dart';
import '../providers/daily_guide_provider.dart';
import '../providers/learning_progress_provider.dart' show learnXpProvider;
import '../services/scan_record_store.dart';
import '../providers/elio_theme_mode_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/robot_provider.dart';
import '../theme/elio_theme.dart';
import '../theme/elio_tokens.dart';
import '../widgets/app_notification_banner.dart';
import '../widgets/elio_bottom_nav.dart';
import '../widgets/tour/app_tour.dart';
import '../widgets/tour/main_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'scan_history_screen.dart';
import 'tabs/elearning_tab.dart';
import 'control_screen.dart';
import 'profile/profile_screen.dart';
import 'scan/scan_hub_screen.dart';
import 'package:elio/l10n/l10n.dart';
import '../services/elio_feedback.dart';

class HomeShell extends ConsumerStatefulWidget {
  final FirebaseAuth auth;

  const HomeShell({super.key, required this.auth});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  // ELIOS 3 tabs: Home 0, Learn 1, Scan 2, History 4, Profile 5. Index 3 is
  // not a tab: setting it opens robot Control (Home quests, notifications).
  static const int _controlIndex = 3;
  static const int _historyIndex = 4;
  static const int _profileIndex = 5;
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
    if (initialNavigationIndex >= 0 &&
        initialNavigationIndex <= _profileIndex &&
        initialNavigationIndex != _controlIndex) {
      _currentIndex = initialNavigationIndex;
    } else if (initialNavigationIndex == _controlIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_onBottomNavigationTap(_controlIndex, updateProvider: false));
      });
    }

    AppTour.request.addListener(_onTourRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWelcome());

    _homeScreen = HomeScreen(
      auth: widget.auth,
      onOpenLearning: () => _onBottomNavigationTap(1),
    );
  }

  @override
  void dispose() {
    AppTour.request.removeListener(_onTourRequest);
    super.dispose();
  }

  /// First launch on this device: Welcome pages, then (if chosen) the tour.
  Future<void> _maybeWelcome() async {
    await AppTour.load();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || (prefs.getBool(AppTour.welcomeSeenKey) ?? false)) return;
    await prefs.setBool(AppTour.welcomeSeenKey, true);
    if (!mounted) return;
    final start = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ElioTheme.wrap(const WelcomeScreen())),
    );
    if (start == true && mounted) await _runTour('all');
  }

  void _onTourRequest() {
    final which = AppTour.request.value;
    if (which == null) return;
    AppTour.request.value = null;
    _runTour(which);
  }

  /// Runs the whole tour ('all') or one part, switching tab before each part.
  Future<void> _runTour(String which) async {
    if (AppTour.running) return;
    for (final part in mainTourParts) {
      if (which != 'all' && part.id != which) continue;
      await _onBottomNavigationTap(part.tab);
      // Let the tab's entrance animation settle before measuring targets.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      final finished = await AppTour.run(
        context,
        part.steps(),
        label: part.label(),
      );
      if (!finished || !mounted) return;
    }
    if (which == 'all' && mounted) await showTourFinish(context);
  }

  Widget _buildCurrentScreen() {
    if (_loggedTabBuilds.add(_currentIndex)) {
      final label = switch (_currentIndex) {
        0 => 'Home/Dashboard',
        1 => 'Learn',
        2 => 'Scan',
        _historyIndex => 'History',
        _profileIndex => 'Profile',
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
      2 => const ScanHubScreen(),
      _historyIndex => ElioTheme.wrap(
        ScanHistoryScreen(
          onClose: () => _onBottomNavigationTap(0),
          onStartScan: () => _onBottomNavigationTap(2),
          showHeader: false,
          compact: true,
        ),
      ),
      _profileIndex => ProfileScreen(
        user: widget.auth.currentUser,
        onSignOut: _signOut,
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
    if (_syncingNavigationProvider || index < 0 || index > _profileIndex) {
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
      // S6 + H-success: the result of the user's connect.
      elioFeedback(ElioSfx.blip, ElioHaptics.success);
      notifications.push(
        type: AppNotificationType.robot,
        title: l10n.shellConnected,
        message: l10n.shellConnectedMsg,
        routeHint: 'robot',
      );
      return;
    }

    if (wasConnected && isDisconnected) {
      notifications.push(
        type: AppNotificationType.warning,
        title: l10n.shellDisconnected,
        message: l10n.shellDisconnectedMsg,
        routeHint: 'robot',
      );
      return;
    }
  }

  Future<void> _openControlScreen() async {
    if (!mounted || _controlScreenOpen) return;
    _controlScreenOpen = true;
    try {
      await pushLandscapeScreen(context, const ControlScreen());
    } finally {
      _controlScreenOpen = false;
    }
  }

  Future<void> _signOut() async {
    await widget.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(auth: widget.auth)),
    );
  }

  /// True when no quiz is running, or the user chose to leave it (progress reset).
  Future<bool> _confirmLeaveQuiz() async {
    if (_currentIndex != 1 || !_quizInProgress) return true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.leaveQuizTitle),
        content: Text(l10n.leaveQuizBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.leaveQuiz),
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
    if (index < 0 || index > _profileIndex) return;

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
    if (index == 1) {
      unawaited(ref.read(dailyGuideFeedProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guide catalogue and progress sync from app start (Home shows the "New guide" notification).
    ref.listen(dailyGuideFeedProvider, (_, _) {});
    // Starts at 0 XP and emits once loaded, so no fireImmediately; the level counts it (0210, 0212).
    ref.listen(
      learnXpProvider,
      (_, xp) => ScanRecordStore.instance.learnXp = xp,
    );
    ref.listen<int>(
      navigationIndexProvider,
      (_, next) => _handleNavigationProviderChange(next),
    );
    ref.listen<AsyncValue<String>>(robotStatusProvider, (previous, next) {
      final nextStatus = next.valueOrNull;
      if (nextStatus == null) return;
      _handleRobotStatusChange(previous?.valueOrNull, nextStatus);
    });

    final user = ref.watch(currentUserProvider) ?? widget.auth.currentUser;
    final guest = user == null || user.isAnonymous;

    return AppNotificationBannerHost(
      child: Scaffold(
        // Shows behind the bar's rounded corners; the shell is outside ElioTheme.
        backgroundColor:
            (ref.watch(elioThemeModeProvider) == ElioThemeMode.dark
                    ? ElioTokens.dark
                    : ElioTokens.light)
                .background,
        // ELIOS 3: no top bar and no sidebar; each tab draws its own title.
        // History draws its green hero under the status bar (0215).
        body: _buildCurrentScreen(),
        floatingActionButtonLocation: const ElioControlFabLocation(),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        floatingActionButton: ElioTheme.wrap(
          ElioScanOrb(onTap: () => _onBottomNavigationTap(2)),
        ),
        bottomNavigationBar: ElioTheme.wrap(
          ElioBottomNav(
            key: TourKeys.nav,
            currentIndex: _currentIndex,
            onSelectTab: _onBottomNavigationTap,
            photoUrl: guest ? null : user.photoURL,
            initials: guest ? null : initialsOf(user),
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
            l10n.comingSoon(title),
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
