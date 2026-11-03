import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/elio_theme.dart';
import '../theme/elio_tokens.dart';
import '../widgets/splash/splash_growth.dart';
import 'login_screen.dart';
import 'home_shell.dart';

class SplashScreen extends StatefulWidget {
  final FirebaseAuth auth;

  const SplashScreen({super.key, required this.auth});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // One controller drives the whole "Growth v2" timeline (milliseconds).
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // The default scales a forward() to 5 % of its length when the OS asks for
    // reduced motion; the 600 ms hold must stay 600 ms.
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _started = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    final end = _reduced
        ? SplashGrowthSpec.reducedHoldMs
        : SplashGrowthSpec.navigateAt;
    _controller
      ..duration = Duration(milliseconds: end)
      ..forward().whenComplete(_navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final user = widget.auth.currentUser;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => user != null
            ? HomeShell(auth: widget.auth)
            : LoginScreen(auth: widget.auth),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        // Reduced motion cuts; otherwise the 250 ms dissolve ends at 3650 ms.
        transitionDuration: _reduced
            ? Duration.zero
            : const Duration(milliseconds: SplashGrowthSpec.dissolveMs),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = Theme.of(context).brightness == Brightness.dark
              ? ElioTokens.dark
              : ElioTokens.light;
          return Scaffold(
            body: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => SplashGrowth(
                // Reduced motion shows F11 (3300 ms) for the whole hold.
                t: _reduced
                    ? SplashGrowthSpec.f11.toDouble()
                    : _controller.value * SplashGrowthSpec.navigateAt,
                palette: p,
              ),
            ),
          );
        },
      ),
    );
  }
}
