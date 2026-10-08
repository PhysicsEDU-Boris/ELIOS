import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Firebase configuration loader for Android and Web platforms.
///
/// IMPORTANT: This function should ONLY be used for Android and Web platforms.
/// iOS/macOS must use the native GoogleService-Info.plist via Firebase.initializeApp().
///
/// Do not pass Android Firebase config to iOS, as it will cause bundle ID mismatches
/// and duplicate app initialization errors.
///
/// Config priority:
/// 1. Android: Load from .env.android.{dev|prod} via createFirebaseOptionsByEnv()
/// 2. Web: Load from .env.{dev|prod} via createFirebaseOptionsByEnv()
/// 3. iOS/macOS: Use native GoogleService-Info.plist via Firebase.initializeApp()

String _requiredEnv(String key) {
  final value = dotenv.env[key]?.trim();
  if (value == null || value.isEmpty) {
    throw StateError('Missing required Firebase env var: $key');
  }
  return value;
}

String? _optionalEnv(String key) {
  final value = dotenv.env[key]?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

/// Creates Firebase options from environment variables.
///
/// Used only for Android and Web platforms. iOS/macOS use native config.
FirebaseOptions createFirebaseOptionsByEnv() {
  return FirebaseOptions(
    apiKey: _requiredEnv('FIREBASE_API_KEY'),
    appId: _requiredEnv('FIREBASE_APP_ID'),
    messagingSenderId: _requiredEnv('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _requiredEnv('FIREBASE_PROJECT_ID'),
    authDomain: _optionalEnv('FIREBASE_AUTH_DOMAIN'),
    storageBucket: _optionalEnv('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: _optionalEnv('FIREBASE_IOS_BUNDLE_ID'),
    measurementId: _optionalEnv('FIREBASE_MEASUREMENT_ID'),
    androidClientId: _optionalEnv('FIREBASE_ANDROID_CLIENT_ID'),
    iosClientId: _optionalEnv('FIREBASE_IOS_CLIENT_ID'),
    appGroupId: _optionalEnv('FIREBASE_APP_GROUP_ID'),
    databaseURL: _optionalEnv('FIREBASE_DATABASE_URL'),
    deepLinkURLScheme: _optionalEnv('FIREBASE_DEEP_LINK_URL_SCHEME'),
  );
}
