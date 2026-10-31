# Lane I1 — app icon and native launch screens

- Branch: `feat/i1-app-icon`; base `feature/live-scan` d201cfb. Decision 0110.
- CodeGraph re-indexed in the source checkout; this clean worktree has no index.
- Clean dedicated worktree: `/Users/macbookairm12020/.codex/worktrees/i1-app-icon/elios-clean`.
- Only owned resources, launcher-generator section and lane/decision docs change.
- Original `ELIO_ICON.png` and `elio_leaf_loop.svg` remain: Flutter still references them.
- No Mac app build/run/registration; U4c owns that work.

## Figma → files

All source exports below live in `assets/icon/option-b/` at full node size.

| Node | Source stem | Installed use |
|---|---|---|
| 199:889 / 199:894 | master-dark / master-light | dark → Android legacy mipmap launcher_icon + ic_launcher; 48/96/192 previews |
| 199:899 / 199:904 | ios-dark / ios-light | iOS AppIcon dark / any and legacy device sizes; tinted is grayscale dark |
| 199:909 / 199:915 | macos-dark / macos-light | dark transparent → macOS app_icon_16…1024; light retained |
| 199:921 / 199:926 | android-foreground-dark / android-foreground-light | dark transparent → drawable-*/ic_launcher_foreground.png; light retained |
| 199:931 | android-monochrome | transparent → drawable-*/ic_launcher_monochrome.png, mipmap-anydpi-v33/launcher_icon.xml |
| 199:936 / 199:943 | guide-dark / guide-light | source guides only |
| 199:950 | legibility | source review only |
| 208:800 / 208:1172 | splash-f0-dark / splash-f0-light | native night/default background + seed: Android android12splash/splash PNGs; iOS LaunchBackground/LaunchImage |

Transparent outputs are derived from the exported frame's SVG group and filters,
removing the exporter-included parent section only. Raw full-size exports remain.
Android uses dark foreground on navy in both modes: bright leaf/cursor contrast
is stable on its fixed background. The monochrome alpha layer enables themed icons.

## Verification

- `flutter analyze`: one pre-existing info at `test/question_bank_integrity_test.dart:104`
  (`curly_braces_in_flow_control_structures`); no Dart changes.
- Full `flutter test --reporter expanded`: 628 pass, 2 known failures in
  `test/widget_test.dart` (signed-out login / signed-in home splash navigation).
- Xcode 27 `xcrun actool`: iOS and macOS catalogs compile into `/tmp` successfully.
  No application bundle was built. Every referenced PNG exists and matches its size.
- PNG integrity, dark/light background RGB and transparent mask corners: pass.
  iOS launch composition exactly matches both 3x F0 exports at the reference size.
  Compiled catalog confirms default/dark/tintable icon renditions and dark launch assets.
- `flutter build apk --debug --target-platform android-arm64`: pass (446.4s), no install.
  APK ZIP integrity and arm64 native-library presence also pass.
  Task-created private config copies and disposable root build output removed afterward.
- Staged secret scan (`bash scripts/check-secrets.sh`): clean.
  No build output or private configuration is committed.

## Integration and owner review

- Native backgrounds match the new F0; base d201cfb still has the old Flutter splash.
  U9's Flutter change is needed to eliminate that remaining transition mismatch.
- Do not rerun the old `flutter_native_splash` pubspec block over these resources.
- Review previews `assets/icon/option-b/preview-{48,96,192}.png`.
- Real phone launcher/themed mask, Mac Dock and iOS dark/tinted appearance remain
  device checks; catalog compilation does not prove their runtime appearance.

## Ponytail markers — start and end

Start: 10 code markers and 3 documentation references. End: unchanged; no new debt.

- `lib/providers/waste_quiz_provider.dart:717`, `:995`
- `lib/services/gemma_quiz_service.dart:662`, `:788`, `:928`, `:1065`
- `lib/services/live_scan_state_machine.dart:23`
- `lib/services/robot/r1_constants.dart:68`
- `tools/fake_maixcam/fake_maixcam.py:40`, `:378`
- Documentation references: `docs/decisions/0020-lock-rearm-rule.md:47`,
  `docs/decisions/0070-history-crop.md:20`, `docs/lanes/d1-history-crops.md:29`.
