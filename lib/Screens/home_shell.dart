import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, SystemChrome, SystemUiMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../providers/app_notification_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/robot_provider.dart';
import '../widgets/app_notification_banner.dart';
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

  late final HomeScreen _homeScreen;

  @override
  void initState() {
    super.initState();
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

  List<Widget> get _screens => [
    _homeScreen,
    ElearningTab(
      quizResetGeneration: _quizResetGeneration,
      onQuizActiveChanged: (active) {
        if (_quizInProgress == active) return;
        setState(() => _quizInProgress = active);
      },
    ),
    const ConfigScreen(),
    const SizedBox.shrink(),
  ];

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

    final wasConnected = _isRobotConnected(previous);
    final isConnected = _isRobotConnected(next);
    final isDisconnected = _isRobotDisconnected(next);
    final wasConnecting = _isRobotConnecting(previous);
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

    if (wasConnecting && isDisconnected) {
      notifications.push(
        type: AppNotificationType.error,
        title: 'Connection failed',
        message: 'Could not connect to ELIO.',
        routeHint: 'robot',
      );
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
      } catch (error) {
        debugPrint('Unable to restore portrait mode: $error');
      }
      _controlScreenOpen = false;
    }
  }

  Future<void> _onBottomNavigationTap(
    int index, {
    bool updateProvider = true,
  }) async {
    if (index < 0 || index > _controlIndex) return;

    if (index == _currentIndex && index != _controlIndex) return;

    if (_currentIndex == 1 && _quizInProgress) {
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

      if (shouldLeave != true || !mounted) {
        _syncNavigationProvider(_currentIndex);
        return;
      }

      setState(() {
        _quizInProgress = false;
        _quizResetGeneration++;
      });
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
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF0F6E56)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'ELIO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: user?.photoURL != null
                              ? ClipOval(
                                  child: Image.network(
                                    user!.photoURL!,
                                    fit: BoxFit.cover,
                                    width: 52,
                                    height: 52,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.person,
                                              size: 28,
                                              color: Colors.white,
                                            ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 28,
                                  color: Colors.white,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? 'Guest User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? 'Local session',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (user?.isAnonymous == true) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'GUEST MODE',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              _buildDrawerItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                title: 'Home',
                isActive: _currentIndex == 0,
                onTap: () => _onDrawerTap(0),
              ),
              _buildDrawerItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                title: 'Learn',
                subtitle: 'Waste types & quizzes',
                isActive: _currentIndex == 1,
                onTap: () => _onDrawerTap(1),
              ),
              _buildDrawerItem(
                icon: Icons.wifi_outlined,
                activeIcon: Icons.wifi,
                title: 'Configure',
                subtitle: 'Setup ESP32 WebSocket',
                isActive: _currentIndex == 2,
                onTap: () => _onDrawerTap(2),
              ),
              _buildDrawerItem(
                icon: Icons.gamepad_outlined,
                activeIcon: Icons.gamepad,
                title: 'Control',
                subtitle: 'Drive robot & Camera',
                isActive: false,
                onTap: () => _onDrawerTap(_controlIndex),
              ),
              const Divider(height: 20, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Color(0xFFE74C3C),
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Color(0xFFE74C3C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () async {
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
              const SizedBox(height: 20),
            ],
          ),
        ),
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onBottomNavigationTap,
          selectedItemColor: const Color(0xFF1D9E75),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Learn',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.wifi_outlined),
              activeIcon: Icon(Icons.wifi),
              label: 'Config',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gamepad_outlined),
              activeIcon: Icon(Icons.gamepad),
              label: 'Control',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    String? subtitle,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive
            ? const Color(0xFF1D9E75).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: isActive
                      ? const Color(0xFF1D9E75)
                      : const Color(0xFF7F8C8D),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? const Color(0xFF1D9E75)
                              : const Color(0xFF1C2833),
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(
                              0xFF7F8C8D,
                            ).withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
