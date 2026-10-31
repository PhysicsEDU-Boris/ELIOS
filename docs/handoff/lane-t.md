# Lane T — T1 theme mode

Owner decision: 31 Oct 2026. Branch: `feat/t1-theme-mode`. Base: `feature/live-scan` at `578e009536470b5a5dda3152639439b37769da4e`, after merged #59. Worktree: `/Users/macbookairm12020/.codex/worktrees/t1-theme-mode/elios-clean`.

## Scope and result

SharedPreferences mode provider, `ElioTheme.wrap`, one gated entry in the existing Config Settings sheet, matching tests, only the Mode rule in `docs/design.md`, this handoff, and decision 0130. No dependencies, fixtures, exports, tokens or theme-builder changes needed. Splash/login and auth widgets already use the wrapper and inherit its theme.

MaterialApp fallback: `lib/main.dart` is unchanged. Scan History inherits default text styles; replacing the root with `ElioLightTheme.data` changes its light render. Keep the current root light theme while S1–S3 migrate screens. Dark mode is scoped to the two U9 screens; Settings persists the choice without recolouring the legacy sheet. No preferences are deleted or reset; the mode has its own key. No system mode.

PDF code, native resources, pubspec, other screens and the original dirty checkout are untouched. No Mac application was built or registered. Tests use empty gitignored `.env.dev` and `.env.prod` asset placeholders locally, with no credentials.

## Files changed

- `lib/providers/elio_theme_mode_provider.dart`
- `lib/theme/elio_theme.dart`
- `lib/Screens/config_screen.dart` (Settings entry and its import only)
- `test/theme/elio_theme_mode_test.dart`
- `test/theme/elio_light_theme_test.dart` (replaced the old platform-following assertions)
- `test/screens/auth_test_support.dart` (explicit mode for the existing U9 matrices)
- `docs/design.md` (Mode rule only)
- `docs/decisions/0130-theme-mode.md`
- `docs/handoff/lane-t.md`

## Ponytail markers — start

Snapshot before edits (`rg -n 'ponytail:|shortcut:' lib test docs`):

```text
docs/lanes/d1-history-crops.md:29:   cropping or recompression. The `ponytail:` marker records the fallback limit.
docs/decisions/0020-lock-rearm-rule.md:47:- `ponytail:` objects are matched by box overlap only (no track ids until ByteTrack, M6). An
lib/services/live_scan_state_machine.dart:23:// ponytail: box overlap only (no track ids yet, ByteTrack is M6); an object
docs/decisions/0070-history-crop.md:20:(the `ponytail:` marker records this limit). Legacy photos are not rewritten.
lib/services/robot/r1_constants.dart:68:// ponytail: one fixed rectangle at J1 home; derive it from the arm pose if boxes near the arm still leak through.
lib/Screens/login_screen.dart:80:  // ponytail: the snackbar shows in the Home scaffold after the route change, so it
lib/services/gemma_quiz_service.dart:662:        // ponytail: 8 s cap = 2 s stop cap + ~6 s worst prefill (decision 0003); a stream that never ends frees the slot here.
lib/services/gemma_quiz_service.dart:788:  /// ponytail: 3 scans per size cannot show an accuracy difference, retest if naming drops.
lib/services/gemma_quiz_service.dart:928:  // ponytail: catches only case/punctuation-level repeats, not paraphrases --
lib/services/gemma_quiz_service.dart:1065:    // ponytail: extra distractors past 3 are dropped (safe, the key is `correct`);
docs/decisions/0100-u9-splash-login.md:19:- Snackbars show in the Home scaffold after the route change and keep the app theme (`ponytail:` in `login_screen.dart`).
lib/providers/waste_quiz_provider.dart:717:  // ponytail: three MC and two essay variants; an object with no bank entry
lib/providers/waste_quiz_provider.dart:995:    // ponytail: legacy/device crops lack a paired clean frame; keep their bytes until recaptured.
```

## Verification

- `flutter analyze --no-pub`: no new diagnostics; one existing info at `test/question_bank_integrity_test.dart:104` (missing braces).
- Full `flutter test --no-pub --reporter expanded`: **680 passed, 8 skipped, 2 known token failures, 0 new failures**. DS2 owns the inherited token failures; no token files or their tests were changed.
- Normal focused mode tests: **8 passed**.
- `--dart-define=DARK_MODE_OPTION=true` focused run: **8 passed**, including toggling the real Settings switch both ways.
- `--dart-define=TESTER_BUILD=true` focused run: **8 passed**, including the same Settings behavior.
- Break-check: restoring the base commit’s system-following `ElioTheme.wrap` makes the exact default-light-under-dark-platform test fail (`expected light`, `actual dark`). Restoring the provider implementation makes it pass (**1 passed**). The old implementation was restored only temporarily for this check.
- Staged secret scan: clean. `git diff --check`: clean.
- Scope checks: `lib/main.dart`, both PDF code and its existing tests, tokens, theme builder, native resources and pubspec have no diff. The legacy Scan History pixel comparison is identical with the original and retained root themes and differs with the candidate global light theme.

## Ponytail markers — end / diff

Same scan as the start, excluding this ledger so copied references are not counted:

```text
docs/lanes/d1-history-crops.md:29:   cropping or recompression. The `ponytail:` marker records the fallback limit.
lib/services/robot/r1_constants.dart:68:// ponytail: one fixed rectangle at J1 home; derive it from the arm pose if boxes near the arm still leak through.
docs/decisions/0100-u9-splash-login.md:19:- Snackbars show in the Home scaffold after the route change and keep the app theme (`ponytail:` in `login_screen.dart`).
docs/decisions/0020-lock-rearm-rule.md:47:- `ponytail:` objects are matched by box overlap only (no track ids until ByteTrack, M6). An
lib/services/gemma_quiz_service.dart:662:        // ponytail: 8 s cap = 2 s stop cap + ~6 s worst prefill (decision 0003); a stream that never ends frees the slot here.
lib/services/gemma_quiz_service.dart:788:  /// ponytail: 3 scans per size cannot show an accuracy difference, retest if naming drops.
lib/services/gemma_quiz_service.dart:928:  // ponytail: catches only case/punctuation-level repeats, not paraphrases --
lib/services/gemma_quiz_service.dart:1065:    // ponytail: extra distractors past 3 are dropped (safe, the key is `correct`);
lib/services/live_scan_state_machine.dart:23:// ponytail: box overlap only (no track ids yet, ByteTrack is M6); an object
docs/decisions/0070-history-crop.md:20:(the `ponytail:` marker records this limit). Legacy photos are not rewritten.
lib/providers/waste_quiz_provider.dart:717:  // ponytail: three MC and two essay variants; an object with no bank entry
lib/providers/waste_quiz_provider.dart:995:    // ponytail: legacy/device crops lack a paired clean frame; keep their bytes until recaptured.
lib/Screens/login_screen.dart:80:  // ponytail: the snackbar shows in the Home scaffold after the route change, so it
lib/providers/elio_theme_mode_provider.dart:9:// shortcut: hidden until S1–S3 migrate every screen to tokens; then remove the gate.
```

Diff: all 13 pre-existing references retained at the same file:line; one new marker at `lib/providers/elio_theme_mode_provider.dart:9` documents when to remove the Settings gate. No existing marker was removed or edited.
