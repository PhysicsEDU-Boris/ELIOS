# ELIOS

ELIOS is a waste-sorting robot app for physics and environmental education.
The Flutter app reads a camera (the phone camera or a MaixCAM2 camera robot,
with an ESP32 for motion), finds the waste item, asks Gemma once on-device
through LiteRT-LM, and shows a quiz about it while the camera keeps running.

Waste categories: organik, anorganik, B3 (hazardous) and residu.

## Plan and design

- Plan and milestones (M0 to M7): [Notion: ELIOS](https://app.notion.com/p/ELIOS-3f29675ed4f3800abef3fbb7daefe405)
- Architecture, ERD and pipeline charts 1 to 7: [Figma board, node 74:130](https://www.figma.com/design/J2jSbARJSyJCStNFeWkWDj/?node-id=74-130)
- How the charts map to milestones: [`docs/pipeline/README.md`](docs/pipeline/README.md)
- Decisions: [`docs/decisions/`](docs/decisions/)
- Changes: [`CHANGELOG.md`](CHANGELOG.md)

## Gemma model

The model is about 2.59 GB and is **never committed** (`*.litertlm` is in
`.gitignore`). The app loads it from:

```
assets/models/gemma-4-E2B-it.litertlm
```

(see `GemmaQuizService.modelFileName` in `lib/services/gemma_quiz_service.dart`).
Copy your local copy of the model to that path before building, for example:

```bash
cp /path/to/gemma-4-E2B-it.litertlm assets/models/
```

## Run on macOS

Requirements: Flutter stable with macOS desktop enabled, Xcode, the Gemma model
(above) and the Firebase files (below, at least `.env.dev` and
`macos/Runner/GoogleService-Info.plist`).

```bash
git config core.hooksPath .githooks   # once per clone, enables the secret check
flutter pub get
flutter run -d macos

# Tests
flutter test                                                   # unit and widget tests
flutter test integration_test/gemma_offline_test.dart -d macos # real Gemma, needs the model
flutter analyze
```

## Firebase setup

Real Firebase config files hold API keys and are **never committed**. They are
listed in `.gitignore`. Each developer downloads their own copies.

| File | Used by | How to get it |
|---|---|---|
| `.env.dev`, `.env.prod` | Web, Android fallback | Copy `.env.example` and fill in the values from Firebase console → Project settings → Your apps → Web app → SDK setup and configuration |
| `.env.android.dev`, `.env.android.prod` | Android | Same as above, using the Android app values |
| `android/app/google-services.json` | Android Gradle plugin | Firebase console → Project settings → Your apps → Android app (`com.boris.elio`) → download `google-services.json`. Template: `android/app/google-services.json.example` |
| `ios/Runner/GoogleService-Info.plist` | iOS | Firebase console → Your apps → iOS app (`com.boris.elio`) → download `GoogleService-Info.plist` |
| `macos/Runner/GoogleService-Info.plist` | macOS | Same file as iOS, copied into `macos/Runner/` |
| `lib/firebase_options.dart` | Not used today | Only if you run `flutterfire configure`. Template: `lib/firebase_options.dart.example` |

The app picks the environment with `--dart-define=ELIO_ENV=dev|prod` (default
`dev`). Missing required keys fail fast at startup with a clear error.

Before pushing, the pre-push hook runs `scripts/check-secrets.sh`. Enable it once
per clone with `git config core.hooksPath .githooks`.
