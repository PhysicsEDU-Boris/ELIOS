# 0006: macOS release builds may run a local server (for the 3D viewer)

- Status: Accepted
- Date: 2026-10-09
- Milestone: none (Notion plan 1.3, not part of M0)

## Context

In macOS **release** builds, the 3D robot viewer on the Home screen and the
Config screen (`Flutter3DViewer`, `robot-elio.glb`) never loaded. It failed
with:

```
Unhandled Exception: SocketException: Failed to create server socket
(OS Error: Operation not permitted, errno = 1), address = 127.0.0.1, port = 0
#4 ModelViewerState._initProxy (package:flutter_3d_controller/src/core/modules/model_viewer/model_viewer_mobile.dart:123)
```

`flutter_3d_controller` 2.3.0 shows the model in an embedded web view. To
feed that web view, it starts a small HTTP server inside the app:
`HttpServer.bind(InternetAddress.loopbackIPv4, 0)` (`model_viewer_mobile.dart:123`).
The server serves the viewer page, the viewer script and the `.glb` file.

The app runs in the macOS App Sandbox (`com.apple.security.app-sandbox`).
Inside the sandbox, an app may only open a listening socket, even on
loopback, if it has `com.apple.security.network.server`.

The macOS build configurations use different entitlement files:

| File | Used by | `network.server` | `network.client` |
|---|---|---|---|
| `macos/Runner/DebugProfile.entitlements` | Debug, Profile | yes | yes |
| `macos/Runner/Release.entitlements` | Release (`project.pbxproj:773`) | **no** | yes |

That's why the viewer worked in debug and failed in release. The signed
release app (`codesign -d --entitlements`) confirmed it: `network.server`
was missing.

## Decision

Add **only** `com.apple.security.network.server` to
`macos/Runner/Release.entitlements`. `network.client` was already present.
`com.apple.security.cs.allow-jit`, the other key only Debug/Profile has,
is **not** added: it's for the Dart VM's run-time compiler in debug builds,
and release builds are compiled ahead of time.

## What it exposes

- **The entitlement:** it allows the app to *listen* for incoming
  connections. It does not limit which network interface; that is up to
  the code that opens the socket.
- **What the app does with it today:** its only listener is the 3D
  viewer's server, bound to the **loopback interface only** (127.0.0.1),
  on a random port picked by the OS. Checked on 2026-10-09 with the fixed
  release build running: `lsof -nP -a -p <ELIOS pid> -iTCP -sTCP:LISTEN`
  showed exactly one listener, `TCP 127.0.0.1:50554 (LISTEN)`. Other
  computers on the network can't reach a loopback socket.
- **What the server serves:** the viewer page, the viewer script, and the
  model file named in the widget (`assets/models/robot-elio.glb`), with
  `Access-Control-Allow-Origin: *`. Any process on the same Mac could
  read those three things while the viewer is open. They are public app
  assets, not user data.

## Evidence (2026-10-09, macOS 27.0 arm64, Flutter 3.44.2, `flutter run -d macos --release`)

| | Before (branch as cut) | After (this change) |
|---|---|---|
| Signed release entitlements include `network.server` | no | yes |
| `SocketException ... Operation not permitted` | yes, on opening Home | none (0 in the log) |
| `ELIO 3D model loaded: assets/models/robot-elio.glb` | never logged | logged |
| Listening sockets of the app | – | one, `127.0.0.1:50554` |

Seeing the model rendered on screen was not checked by the agent. The owner
needs to confirm it visually.

## Consequences

- The 3D viewer works in macOS release builds.
- If `flutter_3d_controller` is upgraded, or another package starts a
  server, re-check what the app listens on with the `lsof` command above.
  It should stay on 127.0.0.1.
- Not checked: the 3D viewer in iOS and Android release builds. This change
  only touches the macOS release entitlements.
