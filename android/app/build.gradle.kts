plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.boris.elio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // The bundled Gemma model (assets/models/gemma-4-E2B-it.litertlm, ~2.4GB)
    // is already-compressed binary weights: deflating it again would make the
    // build take far longer for no size benefit, and — more importantly —
    // large_file_handler's fast on-device copy path needs the asset stored
    // UNCOMPRESSED to read it directly via AssetFileDescriptor. Same fix
    // flutter_gemma's own example app applies for its model assets.
    aaptOptions {
        noCompress("litertlm", "tflite", "task", "bin")
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.boris.elio"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // .litertlm inference needs API 30+: on API 29 and below the native
        // LiteRT-LM library fails to load at runtime (the build doesn't catch it).
        minSdk = maxOf(flutter.minSdkVersion, 30)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
