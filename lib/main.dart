import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import 'firebase_options_loader.dart';
import 'services/gemma_quiz_service.dart';
import 'widgets/desktop_viewport.dart';
import 'utils/system_ui.dart';
import 'Screens/home_shell.dart';
import 'Screens/login_screen.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  const envName = String.fromEnvironment('ELIO_ENV', defaultValue: 'dev');

  try {
    // Load platform-specific Firebase config from env files.
    // Android falls back to the generic .env.dev/.env.prod files when the
    // Android-specific file is not present.
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      try {
        await dotenv.load(fileName: '.env.android.$envName');
      } catch (_) {
        await dotenv.load(fileName: '.env.$envName');
      }
    } else if (kIsWeb) {
      await dotenv.load(fileName: '.env.$envName');
    }

    // Initialize Firebase with platform-specific config
    if (Firebase.apps.isEmpty) {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        // iOS/macOS: Use native GoogleService-Info.plist via Firebase.initializeApp()
        await Firebase.initializeApp();
      } else {
        // Android/Web: Use env-based FirebaseOptions
        await Firebase.initializeApp(options: createFirebaseOptionsByEnv());
      }
    }

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    applyTransparentSystemBars();

    // flutter_gemma registers no inference engine by default — without this
    // every Gemma call throws and the quiz silently falls back to offline
    // questions. Isolated so a Gemma problem can never block app startup.
    try {
      await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);
      // One-time, offline copy of the bundled model, in the background at
      // launch so it is done before the user drives the robot or scans.
      unawaited(GemmaQuizService.instance.prepare());
    } catch (error) {
      debugPrint('FlutterGemma.initialize failed: $error');
    }

    runApp(const ElioApp());
  } catch (error, stackTrace) {
    debugPrint('Startup failed: $error');
    debugPrintStack(stackTrace: stackTrace);

    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: Text('Startup failed: $error'))),
      ),
    );
  } finally {
    // Remove the splash even if env loading or Firebase initialization fails.
    FlutterNativeSplash.remove();
  }
}

class ElioApp extends StatelessWidget {
  final FirebaseAuth? auth;
  const ElioApp({super.key, this.auth});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'ELIOS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6E56)),
          useMaterial3: true,
        ),
        builder: (context, child) => DesktopViewport(child: child!),
        home: _AuthGate(auth: auth ?? FirebaseAuth.instance),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  final FirebaseAuth auth;

  const _AuthGate({required this.auth});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return HomeShell(auth: auth);
        }
        return LoginScreen(auth: auth);
      },
    );
  }
}
