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
import 'l10n/l10n.dart';
import 'widgets/elio_theme_reveal.dart';
import 'providers/app_locale_provider.dart';
import 'providers/app_preferences_provider.dart' show testerBuild;
import 'services/tester_log.dart';
import 'services/scan_record_store.dart';
import 'services/history_cloud.dart';
import 'services/quiz_tts_service.dart';
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
      TesterLog.instance.log(
        'error',
        '${details.exceptionAsString()}\n${details.stack}',
      );
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

class ElioApp extends StatefulWidget {
  final FirebaseAuth? auth;
  const ElioApp({super.key, this.auth});

  @override
  State<ElioApp> createState() => _ElioAppState();
}

class _ElioAppState extends State<ElioApp> with WidgetsBindingObserver {
  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;
  StreamSubscription<User?>? _authSubscription;
  Timer? _syncTimer;
  String? _uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectUser(_auth.currentUser);
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user?.uid == _uid) return;
      unawaited(QuizTtsService.instance.stop());
      setState(() => _selectUser(user));
    });
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) => _sync());
  }

  void _selectUser(User? user) {
    _uid = user?.uid;
    ScanRecordStore.selectAccount(
      _uid,
      cloud: user == null ? null : HistoryCloud.forUser(user),
    );
    unawaited(ScanRecordStore.instance.load());
    _sync();
  }

  void _sync() => unawaited(ScanRecordStore.instance.sync());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _syncTimer?.cancel();
    ScanRecordStore.instance.active = false;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      key: ValueKey(_uid),
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          title: 'ELIOS',
          locale: ref.watch(appLocaleProvider),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6E56)),
            useMaterial3: true,
          ),
          builder: (context, child) {
            updateCurrentL10n(context);
            return ThemeSwitchReveal(child: DesktopViewport(child: child!));
          },
          home: SplashScreen(auth: _auth),
        ),
      ),
    );
  }
}
