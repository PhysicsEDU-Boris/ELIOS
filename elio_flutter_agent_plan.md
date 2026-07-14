# ELIO Flutter — Agent Plan (Riverpod-Structured)

Give this whole document to your coding agent as one instruction set. It supersedes
`elio_maixcam2_fix_plan.md` and the earlier `elio_flutter_agent_plan.md` — this version
folds everything into one consistent Riverpod architecture instead of leaving some pieces
wired through raw `ConfigService()` calls inside `StatefulWidget`s.

**Companion file**: `main.py` (already updated with real `set_resolution` support — see
Phase 5 below, which depends on it).

---

## Architecture decision (read this before writing any code)

Right now the codebase has two competing patterns for reaching services:

1. **Riverpod-wired** — `WebSocketService` via `robotControlProvider`
   (`NotifierProvider<RobotControlNotifier, RobotState>`), `udpDiscoveryProvider`,
   `wifiSsidProvider`. This is the good pattern.
2. **Direct instantiation** — `ConfigScreen` calls `ConfigService()` directly inside
   `_ConfigScreenState`, bypassing Riverpod entirely.

**Every phase below uses pattern 1.** `ConfigService` gets wrapped in a proper
`AsyncNotifier` so `EspConfig` becomes a first-class piece of app state — readable via
`ref.watch()`, mutable via `ref.read(...notifier)`, and automatically rebuilding any
widget that depends on it. No widget should call `ConfigService()` directly after this
plan is complete.

---

## Phase 0 — New provider: `espConfigProvider`

This is the foundation everything else builds on. Do this first.

1. Create `lib/providers/esp_config_provider.dart`:

   ```dart
   import 'package:flutter_riverpod/flutter_riverpod.dart';
   import '../models/config_model.dart';
   import '../services/config_service.dart';

   final espConfigProvider =
       AsyncNotifierProvider<EspConfigNotifier, EspConfig>(EspConfigNotifier.new);

   class EspConfigNotifier extends AsyncNotifier<EspConfig> {
     ConfigService get _service => ConfigService();

     @override
     Future<EspConfig> build() => _service.loadConfig();

     /// Persist a full config replacement and update state optimistically.
     Future<void> save(EspConfig config) async {
       await _service.saveConfig(config);
       state = AsyncData(config);
     }

     /// Convenience: patch just the fields that changed, keeping the rest.
     Future<void> update(EspConfig Function(EspConfig current) patch) async {
       final current = state.valueOrNull ?? const EspConfig();
       await save(patch(current));
     }

     Future<void> clear() async {
       await _service.clearConfig();
       state = const AsyncData(EspConfig());
     }
   }
   ```

2. **Before editing `config_model.dart`, view it** — it hasn't been shared in this
   conversation yet. Confirm its current shape, then extend `EspConfig` with the new
   fields needed for Phases 3–5:

   ```dart
   class EspConfig {
     final String esp32IpAddress;
     final int port;
     final bool autoReconnect;
     final String resolutionPreset; // e.g. '480p' | '720p' — must match main.py SUPPORTED_RESOLUTIONS
     final bool showFpsOverlay;

     const EspConfig({
       this.esp32IpAddress = '',   // empty, not a literal IP — see Phase 4
       this.port = 0,              // 0 = "unset"; UI treats 0 as empty field
       this.autoReconnect = true,
       this.resolutionPreset = '480p',
       this.showFpsOverlay = false,
     });

     EspConfig copyWith({...}) { ... }
     Map<String, dynamic> toMap() { ... }
     factory EspConfig.fromMap(Map<String, dynamic> map) { ... }
   }
   ```

   Keep `esp32IpAddress` defaulting to `''` and `port` to `0` — **not** `192.168.1.100`
   / `8080` — so "no config saved yet" is structurally distinguishable from "user typed
   a real value." The UI (Phase 4) treats empty/zero as "show hint text, not a value."

---

## Phase 1 — System bar / edge-to-edge fix (independent, do anytime)

Unrelated to Riverpod — this is a `SystemChrome` styling gap, not a state problem.

1. Create `lib/utils/system_ui.dart`:

   ```dart
   import 'package:flutter/material.dart';
   import 'package:flutter/services.dart';

   void applyTransparentSystemBars({Brightness iconBrightness = Brightness.dark}) {
     SystemChrome.setSystemUIOverlayStyle(
       SystemUiOverlayStyle(
         statusBarColor: Colors.transparent,
         statusBarIconBrightness: iconBrightness,
         systemNavigationBarColor: Colors.transparent,
         systemNavigationBarDividerColor: Colors.transparent,
         systemNavigationBarIconBrightness: iconBrightness,
         systemNavigationBarContrastEnforced: false,
       ),
     );
   }
   ```

2. Call it immediately after every existing
   `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` call
   (`config_screen.dart`'s `_openControlScreen()`, `home_shell.dart`'s
   `_openControlScreen()`), and once at app startup in `main.dart` before `runApp`.
3. Check `android/app/src/main/res/values/styles.xml` for a leftover solid
   `android:navigationBarColor` fighting the transparency; remove if present.
4. Verify on a rounded-corner / gesture-nav device that the dark bottom bar is gone.

---

## Phase 2 — Config screen reads/writes through `espConfigProvider`

Replace direct `ConfigService` usage in `config_screen.dart` entirely.

1. Convert IP/port fields to be driven by `ref.watch(espConfigProvider)`:
   - Remove `_loadSavedConfig()`'s manual `ConfigService().loadConfig()` call.
   - In `build()`, use `ref.watch(espConfigProvider)` (an `AsyncValue<EspConfig>`) and
     `.when(data: ..., loading: ..., error: ...)` to populate `_ip1`–`_ip4` and `_port`
     controllers the first time data arrives (guard with an "already populated" flag so
     you don't stomp on user typing on every rebuild).
2. On successful `_connect()`, replace:
   ```dart
   if (saveDefault) {
     await _configService.saveConfig(EspConfig(esp32IpAddress: ip, port: port));
   }
   ```
   with:
   ```dart
   if (saveDefault) {
     await ref.read(espConfigProvider.notifier).update(
       (c) => c.copyWith(esp32IpAddress: ip, port: port),
     );
   }
   ```
3. Delete the `final ConfigService _configService = ConfigService();` field entirely —
   nothing in this widget should touch `ConfigService` directly anymore.

---

## Phase 3 — Settings sheet becomes provider-backed (replaces local `setState` sheet state)

The current `_ConfigSettingsSheet` is fed by ~9 local variables in `_ConfigScreenState`
(`_settingsAutoReconnect`, `_settingsResolution`, `_settingsShowFpsOverlay`,
`_settingsSoundEffects`, `_settingsMasterVolume`, `_settingsQuizDifficulty`,
`_settingsQuizTimer`, `_settingsSkipAllowed`) that are never persisted or read anywhere
else. Split these by what they actually govern:

**Connection-relevant settings → `espConfigProvider`** (Phase 0's `EspConfig`):
`autoReconnect`, `resolutionPreset`, `showFpsOverlay`.

**App-cosmetic settings with no device counterpart → separate lightweight provider**,
not `EspConfig` (don't conflate device connection config with UI preferences):

```dart
// lib/providers/app_preferences_provider.dart
class AppPreferences {
  final bool soundEffects;
  final double masterVolume;
  final String quizDifficulty;
  final String quizTimer;
  final bool skipAllowed;
  const AppPreferences({
    this.soundEffects = true,
    this.masterVolume = 0.75,
    this.quizDifficulty = 'Medium',
    this.quizTimer = '60s',
    this.skipAllowed = false,
  });
  AppPreferences copyWith({...}) { ... }
}

final appPreferencesProvider =
    NotifierProvider<AppPreferencesNotifier, AppPreferences>(AppPreferencesNotifier.new);

class AppPreferencesNotifier extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => const AppPreferences();
  void update(AppPreferences Function(AppPreferences) patch) =>
      state = patch(state);
}
```

Flag to the agent: these are **held in memory only** unless you also back them with
`shared_preferences` — call that out as a known limitation rather than silently losing
settings on app restart. Not required for this plan, but don't claim persistence you
haven't built.

1. Rewrite `_ConfigSettingsSheet` from a `StatelessWidget` fed by ~13 constructor
   parameters into a `ConsumerWidget` (or keep `_showConfigSettingsPanel` but have the
   sheet's controls call `ref.read(espConfigProvider.notifier).update(...)` and
   `ref.read(appPreferencesProvider.notifier).update(...)` directly — no more
   `setState` + `setSheetState` double-bookkeeping in `_ConfigScreenState`.
2. Remove `_settingsAutoReconnect` through `_settingsSkipAllowed` fields from
   `_ConfigScreenState` entirely — they're now fully owned by the two providers above.
3. **Resolution dropdown options must match `main.py`'s `SUPPORTED_RESOLUTIONS`**
   (currently `'480p'`, `'720p'`) — not the old cosmetic labels
   (`'720p (HD)'`, `'1080p (FHD)'`, `'1440p (QHD)'`). 1080p/1440p don't exist in the
   firmware; don't offer options the device will reject.

---

## Phase 4 — Remove hardcoded IP literals (now trivial given Phase 0–2)

Because `EspConfig` now defaults to `''`/`0` instead of literal IPs, most of this phase
is already done by Phase 0's model change. Remaining cleanup:

1. In `config_screen.dart`, change `_ip1`–`_ip4` and `_port` from
   `TextEditingController(text: '192')` etc. to plain `TextEditingController()`
   (empty) — they'll be populated from `espConfigProvider`, never from a literal.
   Add hint text per field (`"192"`, `"168"`, `"1"`, `"x"`) instead.
2. In `wifi_provisioning_provider.dart`, `_showProvisioningQrDialog()`: remove
   `String appIp = '192.168.43.1';` as a silent fallback. If `getBestLocalIp()` throws
   or returns `'0.0.0.0'`, show an error via `_showSnack` and **do not generate the
   QR** — don't embed a guessed IP the robot will trust.
3. Check the project for a duplicate `wifi_provisioning_provider.dart` file (it was
   pasted twice identically in an earlier review) — verify via directory listing and
   remove the stray copy if it exists.
4. Grep `lib/` for any other literal `192.168.` / `10.0.` strings used as defaults
   (not regex/validation/comments) and apply the same empty-default treatment.

---

## Phase 5 — Real device-side resolution control (Riverpod-wired end to end)

Requires the paired `main.py` (already updated — see companion file). The device now
accepts `{"cmd":"set_resolution","preset":"720p"}` and replies with
`{"event":"resolution_ack","width":...,"height":...}`.

1. **`websocket_service.dart`** (not a provider itself, but the singleton every
   provider ultimately calls through — keep the existing pattern):

   ```dart
   void sendResolutionCommand({String? preset, int? width, int? height}) {
     if (!_isConnected || _channel == null) return;
     final cmd = <String, dynamic>{'cmd': 'set_resolution'};
     if (width != null && height != null) {
       cmd['width'] = width;
       cmd['height'] = height;
     } else if (preset != null) {
       cmd['preset'] = preset;
     } else {
       return;
     }
     _channel!.sink.add(jsonEncode(cmd));
   }

   final _resolutionAckController = StreamController<Size>.broadcast();
   Stream<Size> get resolutionAcks => _resolutionAckController.stream;
   ```

   In `_handleIncoming`, alongside the existing `pong`/`status` handling, add:

   ```dart
   if (decoded['event'] == 'resolution_ack') {
     final w = (decoded['width'] as num?)?.toDouble();
     final h = (decoded['height'] as num?)?.toDouble();
     if (w != null && h != null) _resolutionAckController.add(Size(w, h));
   }
   ```

2. **`robot_provider.dart`** — add to `RobotControlNotifier` (this is the Riverpod
   entry point the UI actually calls):
   ```dart
   void setResolution({String? preset, int? width, int? height}) =>
       _ws.sendResolutionCommand(preset: preset, width: width, height: height);
   ```
3. **New provider for the acknowledged resolution** (so UI can show what's _actually_
   active, not just what was requested — the device may fall back):
   ```dart
   final resolutionAckProvider = StreamProvider<Size>((ref) {
     return WebSocketService().resolutionAcks;
   });
   ```
4. **Wire it on connect**: in `ControlScreen`, after the existing
   `startStream()` call in the `robotStatusProvider` listener (when status becomes
   `Connected`), also call:
   ```dart
   final preset = ref.read(espConfigProvider).valueOrNull?.resolutionPreset ?? '480p';
   ref.read(robotControlProvider.notifier).setResolution(preset: preset);
   ```
5. **Display confirmed resolution**: in `_CameraDiagnosticsBadge` (or nearby), watch
   `resolutionAckProvider` and show it — don't display the requested preset as if it
   were guaranteed, since `main.py` may silently fall back to a different resolution.

---

## Phase 6 — Verification checklist for the agent

- [ ] No file outside `esp_config_provider.dart` calls `ConfigService()` directly.
- [ ] `EspConfig()` default constructor produces `''`/`0` for IP/port, never a literal
      real-looking address.
- [ ] Settings sheet reads/writes only through `espConfigProvider` and
      `appPreferencesProvider` — zero local `setState` fields left in
      `_ConfigScreenState` for settings-sheet values.
- [ ] Resolution dropdown options are exactly `SUPPORTED_RESOLUTIONS` keys from
      `main.py` (`480p`, `720p`) — verify by string match, not by eye.
- [ ] Dark edge-to-edge bar confirmed gone on a real rounded-corner device.
- [ ] `wifi_provisioning_provider.dart` has no hardcoded fallback IP and no duplicate
      file remains in the project.
- [ ] End-to-end: change resolution in settings → reconnect → confirm
      `resolutionAckProvider` emits a value and the camera panel doesn't error.

---

## Instructions to the agent

- Do Phase 0 first — every later phase assumes `espConfigProvider` exists.
- Phase 1 is fully independent; safe to do in parallel with anything else.
- Don't invent additional resolution presets beyond what `main.py` defines. If more
  are wanted, they need to be added to `main.py`'s `SUPPORTED_RESOLUTIONS` first and
  tested on real hardware — the firmware comment already flags that list as unverified.
- If `config_model.dart`'s current shape conflicts with the Phase 0 sketch above, stop
  and show it before proceeding — don't guess and overwrite silently.
