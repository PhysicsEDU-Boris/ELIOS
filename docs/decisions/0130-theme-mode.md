# 0130 User-selected display mode, light by default

Status: accepted by the owner, 31 Oct 2026 (T1). Supersedes the system-following mode rule in 0090; keeps its scoped adoption rule.

## Decision
- `ElioThemeMode { light, dark }` lives in `elio_theme_mode_provider.dart`. It starts synchronously in light and loads the saved choice from SharedPreferences, the same device-local mechanism as application preferences. Missing or unknown values select light. A choice made during loading wins. No system mode.
- `ElioTheme.wrap` watches this provider. Only the two U9 screens (splash and login) use this wrapper, so their palette and system-bar icons follow the saved choice. Auth widgets inherit that palette. Before loading completes they use light even on a dark platform.
- Use the owner's fallback: keep `MaterialApp.theme` unchanged. The candidate `ElioLightTheme.data` changes inherited text and component styling in the legacy Scan History screen. Applying it globally would violate the light-mode preservation requirement. Root `darkTheme` and `themeMode` remain unchanged too; legacy screens stay on their existing light theme until S1–S3 migrate them.
- The existing Config Settings sheet gets “Mode tampilan”, displaying “Terang” or “Gelap”. It is visible only with `--dart-define=DARK_MODE_OPTION=true` or `--dart-define=TESTER_BUILD=true`, including in debug builds. Remove the gate only after S1–S3 move every screen to tokens.
- PDF exports always stay light; PDF code is unchanged. Native launch screens are light only; native resources are unchanged in this lane.

## Validation
The mode tests cover the first frame under a dark platform, persistence after a fresh provider scope, changes while loading, unknown stored values, both U9 screens, the real Config Settings sheet, and a pixel comparison of the legacy Scan History screen using the original and retained root themes. They also check that the candidate global light theme changes that legacy render. Existing U9 layout/render helpers now select their test mode explicitly instead of relying on platform brightness.
