# ELIO Flutter — Production Readiness Plan (Decisions Locked)

Give this whole document to your coding agent. It assumes the Riverpod migration from
the earlier `elio_flutter_agent_plan.md` is complete (it is, per your last verification
pass) and the paired `main.py` revision (already provided, already flashed) is current.

**Scope for this pass: Flutter-side changes ONLY.** Every fix below is achievable
against APIs `main.py` already exposes — none of it requires a firmware change. In
particular, `main.py`'s `set_resolution` WebSocket command already works mid-session
(it doesn't gate on "only right after connect"); the fact that Flutter previously only
called it once was a Flutter-side gap, not a firmware limitation. **Do not modify
`main.py` as part of this plan.**

**Decisions below are final for this pass** — no branching options, no "pick one."
Where an earlier draft of this plan offered choices, the choice has been made.

---

## Phase 1 — Fix the stuck-connection bug (highest priority)

**Symptom you hit**: pressed "Connect to ELIOS" on the device, canceled, device still
showed "Connected" (this part is actually correct — your Flutter app genuinely still
had a live socket open the whole time). Then tapping "Connect" in Flutter did nothing.

**Most likely cause**: `WebSocketService`'s internal flags (`_isConnected`,
`_isConnecting`) or the underlying channel weren't fully torn down before the retry,
so `connect()`'s early-return guards (`if (_isConnected) return true;` /
`if (_isConnecting) return false;`) silently blocked the new attempt.

**Fix — always fully disconnect before reconnecting, never assume clean state:**

1. In `config_screen.dart`'s `_connect()`, before `ws.resetConnectionState()`, add:
   ```dart
   await ws.disconnect();  // full teardown: cancels subscription, closes channel, resets all flags
   ```
   `resetConnectionState()` alone doesn't await the socket close — `disconnect()` does
   (`await _channelSubscription?.cancel(); await _channel?.sink.close();`). Use the
   thorough one before every fresh connect attempt, not just on intentional exit.
2. `main.py` (companion file, already updated) now supports a client-initiated
   `{"cmd":"disconnect"}` handshake that gets an ack and closes the socket in an
   orderly way from the device side too. Wire this into `WebSocketService.disconnect()`
   — send it before closing the local channel, best-effort:

   ```dart
   Future<void> disconnect() async {
     _isIntentionallyClosed = true;
     _autoReconnectEnabled = false;
     _reconnectTimer?.cancel();
     _reconnectTimer = null;
     _stopWatchdog();

     // Best-effort orderly disconnect handshake — device can clean up its
     // side immediately rather than waiting to notice the TCP drop.
     try {
       _channel?.sink.add(jsonEncode({'cmd': 'disconnect'}));
     } catch (_) {}

     await _channelSubscription?.cancel();
     _channelSubscription = null;
     await _channel?.sink.close();
     _channel = null;
     _isConnected = false;
     _isConnecting = false;
     _retryCount = 0;
     _emitStatus('Disconnected');
   }
   ```

---

## Phase 2 — Real Disconnect button in Flutter (this is where "control" should live)

You're right that the phone should be the control surface, not the device touchscreen.
`main.py`'s new "Force Disconnect Clients" button is a device-side escape hatch for
emergencies — the durable, everyday path is a real button in the app.

1. In `_ConfigScreenState`, add a `_disconnect()` method:
   ```dart
   Future<void> _disconnect() async {
     await ref.read(espConfigProvider.notifier).save(
       (ref.read(espConfigProvider).valueOrNull ?? const EspConfig()),
     ); // no-op save, or skip — just ensures provider state is untouched
     await WebSocketService().disconnect();
     setState(() {
       _connectionFailed = false;
     });
     _showSnack('Disconnected. Choose a new network or reconnect.');
   }
   ```
2. In `_buildBottomActions()`, change the single full-width Connect button into a Row
   with **Connect (primary, larger, `flex: 2`)** and **Disconnect (secondary outline,
   `flex: 1`)** side by side:
   ```dart
   Row(
     children: [
       Expanded(
         flex: 2,
         child: SizedBox(
           height: 52,
           child: ElevatedButton(
             onPressed: _isConnecting ? null : _connect,
             // ...existing CONNECT NOW styling...
           ),
         ),
       ),
       const SizedBox(width: 10),
       Expanded(
         flex: 1,
         child: SizedBox(
           height: 52,
           child: OutlinedButton(
             onPressed: _isConnecting ? null : _disconnect,
             style: OutlinedButton.styleFrom(
               foregroundColor: const Color(0xFFC62828),
               side: const BorderSide(color: Color(0xFFC62828)),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
             ),
             child: const Icon(Icons.link_off_rounded, size: 20),
           ),
         ),
       ),
     ],
   )
   ```
   This is also where "switch WiFi / use a different hotspot" becomes possible from the
   phone: tap Disconnect, then generate a new provisioning QR for a different network.

---

## Phase 3 — Wire the settings that currently do nothing

Two real gaps found during your testing. **Decision: both must have real effect —
this is non-negotiable for production readiness, not an optional polish item.**

1. **Auto-reconnect setting has zero effect.** `ControlScreen._connectAndStartStream()`
   hardcodes `autoReconnect: true` — it never reads `espConfigProvider`. The toggle
   must actually govern behavior: when off, a dropped connection stays dropped until
   the user manually taps Connect; when on, `WebSocketService`'s existing watchdog/
   reconnect-timer logic (already implemented, just never being enabled per-user-choice)
   takes over. Fix:
   ```dart
   Future<void> _connectAndStartStream() async {
     final autoReconnect =
         ref.read(espConfigProvider).valueOrNull?.autoReconnect ?? true;
     final connected = await _robotNotifier.connect(autoReconnect: autoReconnect);
     // ...rest unchanged
   }
   ```
2. **Resolution changes made mid-session (while already connected) never take effect**
   — `setResolution()` is currently only called once, right after connecting. If the
   user opens settings and changes resolution while already streaming, nothing resends
   the command. Decision: the user must be able to change resolution at any time and
   have it actually apply, live, without needing to disconnect/reconnect first — this
   is a real requirement, not a nice-to-have. `main.py` already supports this correctly
   (it re-opens the stream camera and re-acks on any `set_resolution` command,
   regardless of when it arrives); this is purely a missing trigger on the Flutter
   side. Fix: add a listener in `ControlScreen` for `espConfigProvider` changes:
   ```dart
   ref.listen<AsyncValue<EspConfig>>(espConfigProvider, (previous, next) {
     final prevPreset = previous?.valueOrNull?.resolutionPreset;
     final nextPreset = next.valueOrNull?.resolutionPreset;
     if (nextPreset != null && nextPreset != prevPreset) {
       ref.read(robotControlProvider.notifier).setResolution(preset: nextPreset);
     }
   });
   ```
   Put this in `build()`, same pattern as the existing `udpDiscoveryProvider` listener
   in `config_screen.dart`.

**Direct answer to "does changing resolution increase FPS?"**: yes, in principle —
fewer pixels means less JPEG-encode CPU time and a smaller payload to send, both of
which are real bottlenecks per the earlier FPS investigation. But it's not guaranteed
to be the dominant factor on its own; the dashboard-loop GIL contention fixed in
`main.py` matters too. Test both presets after this phase and compare.

---

## Phase 4 — Fix the hardcoded "Signal: None" chip

`config_screen.dart` has `final signalStatus = 'None';` — a literal, never computed
from anything. **Decision: Option A, no new permissions.** Repurpose this chip to show
the robot's actual connection status instead of WiFi signal strength — something
genuinely available via `robotStatusProvider`, versus RSSI which isn't currently
accessible at all (would need a plugin like `wifi_iot`, which requires location
permission on Android — explicitly not wanted for this pass).

```dart
final robotStatus = ref.watch(robotStatusProvider).valueOrNull ?? 'Disconnected';
// pass robotStatus into _RobotConnectionPanel instead of the old signalStatus
```

Rename the chip label from "Signal" to "Link" or "Status" so it's honest about what it
shows — do not keep the word "Signal" once it's showing connection status, not RSSI.

**Battery chip: leave alone, no action this pass.** `batteryPercent = 62` in the same
file stays exactly as-is — hardcoded, unchanged, not hidden, not relabeled. This is a
deliberate decision, not an oversight: don't "improve" it, don't add an N/A label,
don't touch this line at all in this pass.

---

## Phase 5 — Compact the Wi-Fi Provisioning card

1. Remove the full-width "GENERATE QR" `ElevatedButton.icon` entirely — the QR icon
   already sitting in the password field's `suffixIcon` (`Icons.qr_code_rounded`,
   already wired to `_showProvisioningQrDialog`) does the same thing. One trigger is
   enough; the duplicate button is pure vertical space cost.
2. After removing it, adjust the `SizedBox(height: 12)` before it accordingly so the
   card doesn't leave an odd gap.

**Decision on auto-triggering the device's QR scanner from Flutter's "Generate QR"
tap: explicitly declined for this pass — not needed.** Worth noting briefly why it
wouldn't be a simple Flutter change even if it were wanted later: the MaixCAM2 has no
network connection at the point the QR is generated (that's the whole point of the QR
— it's how the device _gets onto_ WiFi in the first place), so there's no channel for
Flutter to send it a "start scanning" command at that moment. This isn't being pursued
now. The actual, agreed goal for this phase is narrower and achievable: make the
existing manual QR flow (tap password field's QR icon → scan on device) feel smooth
and tidy, which Phase 5's button-removal above already accomplishes.

---

## Phase 6 — Clean up ESP32-CAM legacy code

You're right to flag this — a few remnants from before the MaixCAM2 migration:

1. `websocket_service.dart`: `String _ip = '192.168.4.1'; int _port = 81;` — these were
   ESP32-CAM's default AP address/port. They're always overwritten by `configure()`
   before any real connect, but leaving them as realistic-looking defaults is
   misleading. Replace with clearly-placeholder values:
   ```dart
   String _ip = '';
   int _port = 0;
   ```
2. `websocket_service.dart`'s `_handleIncoming`, the two legacy binary-frame branches:
   ```dart
   // Legacy: raw binary frames (ESP32-CAM backward compatibility).
   if (message is Uint8List) { ... }
   if (message is List<int>) { ... }
   ```
   Since `main.py` (per this revision) sends frames as base64-in-JSON, not raw binary,
   these branches are dead code for MaixCAM2. **Remove them** — keep only the
   `decoded['image']` / `decoded['frame']` JSON paths that MaixCAM2 actually uses.
   (If you ever revisit a binary-transport optimization later, re-add deliberately with
   its own testing pass — don't leave unused paths lying around in the meantime.)
3. `robot_provider.dart`: the doc comment `/// Live MJPEG frame stream from the ESP32
camera.` on `robotFrameProvider` is stale — update to reference MaixCAM2.
4. Leave `EspConfig.esp32IpAddress` field name as-is for this pass — renaming it
   (e.g. to `deviceIpAddress`) is purely cosmetic naming debt, but touches
   `config_model.dart`, `config_service.dart`'s serialized storage key compatibility,
   and every call site. Not worth the churn/regression risk bundled into this
   production-readiness pass; do it standalone later if it matters.

---

## Direct answers to your other questions

**"Is speaker volume synced with Flutter?"** No — and there's nothing on the device
side to sync with. `appPreferencesProvider`'s `soundEffects`/`masterVolume` are pure
in-memory UI state with no audio player wired up in Flutter and no speaker-control code
in `main.py` (the MaixCAM2 hardware does have a physical speaker per its spec sheet, but
this firmware never touches it). If you want this real: decide first whether "sound"
means _local UI feedback sounds in the Flutter app_ (achievable now with a Flutter audio
package, no device involvement) versus _the robot itself playing sounds through its
speaker_ (requires new `main.py` code + a WS command + actual audio asset handling on
device — a separate scoped feature, not a settings-sheet wiring fix).

**"Is auto-reconnect active?"** No, per Phase 3 above — the toggle existed and
persisted correctly, but nothing downstream read it. Fixed in Phase 3.

**"Can the user change resolution and does it sync with MaixCAM2?"** Yes, structurally
— `resolutionAckProvider` shows the _device-confirmed_ resolution, which may differ
from what was requested if the device fell back. But per Phase 3, it currently only
applies on initial connect, not on a live mid-session change — fixed in Phase 3.

---

## Things this plan does NOT fix (flagging so nothing is assumed done)

- **Real-time segmentation with your `.mud` model** — a separate, larger piece of work
  (model loading, inference cadence decoupled from video FPS, mask-to-polygon
  extraction and transmission). Deliberately not bundled into this stability/production
  pass so it doesn't get tangled up with the connection-bug fixes. Worth its own
  follow-up plan once this phase is verified stable on real hardware.
- **Real battery telemetry** and **real WiFi signal strength** — both flagged in
  Phase 4 as requiring either new sensor hardware (battery) or a new permission-gated
  plugin (signal). Not silently faked further, not silently fixed either — genuinely
  needs a decision from you on scope before building.
- **Device-initiated BLE pairing** for the "auto-trigger QR scan" idea — flagged in
  Phase 5 as a separate hardware/firmware project, not a Flutter change.
- **Actual speaker audio** on the MaixCAM2 — flagged above, needs a scope decision.

---

## Verification checklist

- [ ] Stuck-connection repro (Connect on device → Cancel → Connect in Flutter) no
      longer fails, after Phase 1's `disconnect()`-before-`connect()` fix.
- [ ] Disconnect button in Flutter actually drops the socket and lets a fresh Connect
      succeed immediately after, without needing to force-kill the app.
- [ ] Toggling auto-reconnect off in settings, then killing WiFi mid-stream, results in
      the app NOT auto-reconnecting (previously it always would, regardless of the
      toggle).
- [ ] Changing resolution while already connected (not just before connecting) causes
      a new `resolution_ack` to arrive with the new dimensions.
- [ ] FOV complaint resolved on real hardware — confirm 480p no longer looks
      zoomed/cropped compared to 720p.
- [ ] Stream feels smooth again at 10-15fps (not choppy) after the transport revert in
      `main.py`.
- [ ] "GENERATE QR" button is gone; the password field's QR icon still opens the same
      dialog.
- [ ] No remaining references to `192.168.4.1`/port `81` or the two legacy binary-frame
      branches in `websocket_service.dart`.
