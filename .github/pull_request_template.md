## Milestone

<!-- One of M0 to M7. One milestone per pull request. -->
M?

## Notion item

<!-- Link the plan item(s) this closes, e.g. section 1.1 "Add a real cancel test". -->
- 

## Figma node

<!-- Chart or design node, e.g. chart 5 (85:305), overlay 96:130. "None" if not UI or pipeline work. -->
- 

## What changed

- 

## How it was tested

<!-- Every check: passed (command + key output), failed, or not run (reason). Mock-only results do not count as proof. -->

| Check | Command | Result |
|---|---|---|
|  |  | passed / failed / not run (why) |

## Acceptance checks touched

<!-- From Notion section 3 "Acceptance checks". -->
- [ ] Same object held 60 s: exactly 1 AI identify and 1 TTS line
- [ ] Object removed, different one shown: new lock and one new identify
- [ ] Two scans back to back: second rejected as busy, no queue, no crash
- [ ] Quiz opens: camera preview keeps running
- [ ] Cancel mid-generation: tokens stop, next request works
- [ ] Chat message during a scan: scan cancelled, chat answers
- [ ] Unclear item: app asks to retake, no quiz
- [ ] Hazardous item: app asks the user to confirm
- [ ] Old firmware without `track_id`: still works
- [ ] 30 minute soak on Android
- [ ] None

## Risks

- 

## Checklist

- [ ] No keys, `.env` files, Firebase config files or signing files in the diff
- [ ] No model file and no file over 50 MB
- [ ] `flutter analyze` run
- [ ] `CHANGELOG.md` updated
