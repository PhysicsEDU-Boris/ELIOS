# Agent Task: Inventory `lib/` and Reorganize Flat Folders into Feature Subfolders

## Context

This is a Flutter app (Riverpod for state, Firebase/Firestore for backend)
called ELIO — a waste-sorting robot companion app with e-learning, robot
control, and config features. The codebase has grown with several folders
(starting with `lib/providers/`) that are **flat** — many unrelated files
sitting directly inside one folder with no grouping — which makes it slow
to find things and easy to create duplicate/conflicting providers.

Your job has two parts, done in order: **(1) inventory**, then
**(2) reorganize**. Do not skip to part 2 without producing the inventory
first — the inventory is what makes the reorganization plan verifiable
instead of guesswork.

---

## Part 1 — Full `lib/` Inventory

1. Recursively list every file under `lib/`.
2. For each `.dart` file, open it and record:
   - **Path**
   - **What it exports** (class names, top-level providers, enums —
     whatever another file would `import` this for)
   - **One-line purpose** (what problem this file solves, in plain
     language — not a restatement of the class name)
   - **Internal dependencies** (which other files under `lib/` it imports)
3. Produce `FILE_MAP.md` at the repo root with:
   - A full folder tree of `lib/` (use `tree lib` or equivalent if
     available, otherwise reconstruct it from the file listing)
   - A table per top-level folder (`lib/providers/`, `lib/models/`,
     `lib/screens/`, `lib/services/`, `lib/widgets/`, `lib/utils/`, etc.)
     with columns: `File | Exports | Purpose | Depends on`
4. While building this, explicitly flag:
   - Any folder with **more than ~8 files sitting flat** (no
     subfolders) — these are reorganization candidates.
   - Any file whose purpose doesn't obviously match its folder (e.g. a
     robot-control provider sitting in a folder otherwise full of
     auth/session providers).
   - Any two files that look like they overlap or duplicate
     responsibility (possible dead code or accidental duplication —
     don't delete anything, just flag it in the report).

Stop after Part 1 and show me `FILE_MAP.md` before moving anything, unless
I've told you to run both parts unattended.

---

## Part 2 — Reorganize Flat Folders into Feature Subfolders

### Priority target: `lib/providers/`

This folder is the known offender — it currently mixes providers for
unrelated domains (auth, navigation, notifications, robot connectivity,
learning progress, etc.) in one flat list. Group them by **feature domain**,
not by technical type. A reasonable starting split (adjust based on what
Part 1's inventory actually finds):

```
lib/providers/
  auth/            auth_provider.dart, ...
  navigation/       navigation_provider.dart, ...
  notifications/    app_notification_provider.dart, ...
  learning/         learning_progress_provider.dart, ...
  robot/            robot_provider.dart, and any device/connection/
                    telemetry providers
  config/           any ESP32/WebSocket config providers
  shared/           anything genuinely cross-cutting that doesn't belong
                    to one feature (rare — most things belong somewhere)
```

Apply the same **group-by-feature** treatment to any other folder Part 1
flagged as flat (commonly `lib/models/`, `lib/services/`,
`lib/screens/tabs/`, `lib/widgets/`) — mirror the same domain names across
folders where it makes sense, so `lib/providers/learning/` and
`lib/services/learning/` and `lib/models/learning/` line up. Consistent
parallel structure across `providers/`, `models/`, and `services/` is the
main thing that makes this easy to debug later — you should be able to
guess where a file lives from its domain name alone.

### Execution rules — read before touching anything

1. **One folder at a time.** Finish and verify `providers/` completely
   before starting the next folder. Show me a summary after each folder,
   don't batch all folders into one giant diff.
2. **Move, don't rewrite.** Use `git mv` (not delete+recreate) so file
   history is preserved. Do not rename classes, providers, or public
   symbols during this pass — this is a file-location refactor only. If
   you spot a genuinely bad name while you're in there, note it in the
   report instead of fixing it inline; that's a separate task.
3. **Update every import.** After moving a file, grep the entire `lib/`
   (and `test/` if it exists) for the old relative import path and update
   every reference. Do not rely on the IDE catching it — verify with a
   text search that zero old-path imports remain for each moved file.
4. **(Optional, ask me first) barrel files.** If it would reduce import
   noise, you may add a barrel file per new subfolder (e.g.
   `lib/providers/learning/learning.dart` exporting everything in that
   folder) — but only if I confirm I want that pattern; some teams prefer
   explicit imports. Don't do this silently.
5. **Validate before moving on:**
   - Run `flutter pub get`
   - Run `flutter analyze` and confirm no new errors were introduced by
     the move (pre-existing warnings unrelated to this refactor are fine
     to leave, just don't add new ones)
   - Grep for the folder's old flat import paths one more time across the
     whole repo as a final check
6. **If anything doesn't compile after a folder's moves, stop and fix it
   before starting the next folder** — don't let broken imports pile up
   across multiple folders at once, that's what makes this kind of
   refactor hard to debug if something goes wrong.

### Deliverable at the end

- Updated `FILE_MAP.md` reflecting the new structure.
- A `MIGRATION_LOG.md` with a simple table: `Old path | New path` for
  every file that moved, so anything referencing an old path from memory
  (docs, other tools, muscle memory) has one place to check.
- Confirmation that `flutter analyze` is clean relative to before the
  refactor.

---

## What NOT to do

- Don't touch business logic, rename providers, or change how state flows
  between them — this pass is purely about file location and imports.
- Don't delete anything flagged as a possible duplicate in Part 1 — report
  it, let me decide.
- Don't reorganize `lib/screens/tabs/elearning/simulations/` — that
  folder's structure was set deliberately in a prior pass
  (`physics/<module>/`, `screens/tabs/elearning/simulations/{widgets,
  painters}/`) and should stay as-is unless I say otherwise.
