# Lane I1 — app icon and native launch screens

- Branch: `feat/i1-app-icon`; base `feature/live-scan` d201cfb. Decision 0110.
- CodeGraph re-indexed in the source checkout; this clean worktree has no index.
- Clean dedicated worktree: `/Users/macbookairm12020/.codex/worktrees/i1-app-icon/elios-clean`.
- Only owned resources, launcher/splash generator sections and lane/decision docs change.
- Original `ELIO_ICON.png` and `elio_leaf_loop.svg` remain: Flutter still references them.
- No Mac app build/run/registration; U4c owns that work.

## Figma → files

All source exports below live in `assets/icon/option-b/` at full node size.

| Node | Source stem | Installed use |
|---|---|---|
| 199:889 / 199:894 | master-dark / master-light | light → Android legacy mipmap launcher_icon + ic_launcher (dark was first, superseded); 48/96/192 previews |
| 199:899 / 199:904 | ios-dark / ios-light | iOS AppIcon dark / any and legacy device sizes; tinted is grayscale dark |
| 199:909 / 199:915 | macos-dark / macos-light | dark transparent → macOS app_icon_16…1024; light retained |
| 199:921 / 199:926 | android-foreground-dark / android-foreground-light | light transparent → drawable-*/ic_launcher_foreground.png on `#F8FAFC`; dark retained |
| 199:931 | android-monochrome | transparent → drawable-*/ic_launcher_monochrome.png, mipmap-anydpi-v33/launcher_icon.xml |
| 199:936 / 199:943 | guide-dark / guide-light | source guides only |
| 199:950 | legibility | source review only |
| 208:800 / 208:1172 | splash-f0-dark / splash-f0-light | light only → Android android12splash/splash PNGs and iOS LaunchBackground/LaunchImage; dark source retained for provenance |

Transparent outputs are derived from the exported frame's SVG group and filters,
removing the exporter-included parent section only. Raw full-size exports remain.
Android uses the light foreground on `#F8FAFC` in both modes (light icon is primary,
owner decision 31 Oct 2026; it replaced the dark foreground on navy). The monochrome alpha layer enables themed icons.

## Light icon is primary (31 Oct 2026)

Android launcher icons switched to the light variants: foreground 199:926 on
`#F8FAFC`, legacy PNGs from master-light, `flutter_launcher_icons` config updated.
iOS (any/dark/tinted) and macOS (dark) are unchanged.

Phone check (Edge 60 Fusion, release APK sha256 `438c5ac9052784a07c955d669d73d06dc3208bc5e578cdcf7ef093feabbe54c4`,
installed over the app, no data clear): launcher drawer grid shows a white tile with
the green leaf and cursor, centred, not cropped, same size as neighbours. Themed icons
(Personalisasikan > Warna > Ikon bertema, beta) show the monochrome leaf and cursor on
a blue tile, centred. I turned the toggle on to look and back off afterwards (it was
off). Screenshots: `docs/test-results/i1-light-icon/`. Not checked: iOS and macOS.

## Light-only follow-up (31 Oct 2026)

Native launch screens are light only: light is the primary/default mode; dark is
chosen inside the app. Removed 15 Android night launch resources and 4 iOS dark
launch PNGs plus their catalog entries. Before deletion, references were checked:
AndroidManifest uses the shared LaunchTheme/NormalTheme names, which still resolve
to the light defaults; launch XML uses unqualified drawable/color names, which
also resolve to retained defaults. No explicit night-path references remain.
iOS AppIcon dark/tinted appearances and flutter_launcher_icons are unchanged.
The native-splash config is light and color-only; committed resources include the
F0 seed. The generator is not part of the build and would replace seed art if run.

Follow-up verification: Android arm64 debug APK build passed (no install); iOS
and macOS actool checks passed. Compiled iOS catalog has default-only launch
renditions and preserved dark/tintable icons. Light F0 composition is an exact
pixel match. Secret scan and whitespace checks passed; ponytail markers unchanged.
Analyze/full suite were not rerun for this resource-only follow-up; original
results are below. Temporary private config copies and root build output removed.

## Original verification

- `flutter analyze`: one pre-existing info at `test/question_bank_integrity_test.dart:104`
  (`curly_braces_in_flow_control_structures`); no Dart changes.
- Full `flutter test --reporter expanded`: 628 pass, 2 known failures in
  `test/widget_test.dart` (signed-out login / signed-in home splash navigation).
- Xcode 27 `xcrun actool`: iOS and macOS catalogs compile into `/tmp` successfully.
  No application bundle was built. Every referenced PNG exists and matches its size.
- PNG integrity, dark/light background RGB and transparent mask corners: pass.
  iOS launch composition exactly matches both 3x F0 exports at the reference size.
  Original compiled catalog confirmed default/dark/tintable icons; dark launch assets
  were subsequently removed by the owner’s light-only decision.
- `flutter build apk --debug --target-platform android-arm64`: pass (446.4s), no install.
  APK ZIP integrity and arm64 native-library presence also pass.
  Task-created private config copies and disposable root build output removed afterward.
- Staged secret scan (`bash scripts/check-secrets.sh`): clean.
  No build output or private configuration is committed.

## Integration and owner review

- Native backgrounds match the new F0; base d201cfb still has the old Flutter splash.
  U9's Flutter change is needed to eliminate that remaining transition mismatch.
- Do not regenerate committed seed artwork from the color-only native-splash block.
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
