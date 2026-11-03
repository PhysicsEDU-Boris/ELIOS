import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options_loader.dart';
import 'providers/app_preferences_provider.dart' show testerBuild;
import 'services/tester_log.dart';
import 'services/scan_record_store.dart';
import 'widgets/desktop_viewport.dart';
import 'utils/system_ui.dart';
import 'Screens/splash_screen.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  const envName = String.fromEnvironment('ELIO_ENV', defaultValue: 'dev');

  if (testerBuild) {
    await TesterLog.instance.init();
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      TesterLog.instance.log('error', '${details.exceptionAsString()}\n${details.stack}');
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      TesterLog.instance.log('error', 'uncaught $error\n$stack');
      return false;
    };
  }

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

    // Preload scan records from disk so trophies and history are immediately available.
    unawaited(ScanRecordStore.instance.load());

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
        home: SplashScreen(auth: auth ?? FirebaseAuth.instance),
      ),
    );
  }
}
