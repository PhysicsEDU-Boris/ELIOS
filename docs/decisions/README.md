# Decision records

One short file per decision, numbered in order (`NNNN-title.md`). Each one
has: status, date, context, decision, consequences. A decision is only
written here after the owner has made it. Superseded records stay, with
their status changed.

| No. | Decision | Status |
|---|---|---|
| [0001](0001-no-keys-in-new-repo.md) | No API keys in the new repo, not even in history | Accepted |
| [0002](0002-repo-layout-and-remotes.md) | Base branch, remotes and the stage 0 deletions | Accepted |
| [0003](0003-stop-generation.md) | `stopGeneration` really stops LiteRT-LM, so no fallback | Accepted |
| [0004](0004-stage-2-commit.md) | The stage 2 commit is documented, not split | Accepted |
| [0005](0005-m0-findings.md) | Findings from M0, recorded, not fixed in M0 | Accepted |
| [0006](0006-macos-release-entitlements.md) | macOS release builds may run a local server (for the 3D viewer) | Accepted |
| [0007](0007-stabilizer.md) | Detection stabilizer (stage 3a) | Accepted (parameters provisional) |
| [0008](0008-live-scan-state-machine.md) | Live-scan state machine for the robot path (behind a switch) | Accepted |
| [0009](0009-camera-stays-alive.md) | The camera stays alive during a quiz; Gemma preloads (M2b part 1) | Accepted |
| [0010](0010-tts-single-slot-and-overlay-staleness.md) | One TTS slot, no stale overlay numbers, a monotonic default clock (M2b part 2) | Accepted |
| [0011](0011-quiz-prefetch.md) | Prefetch questions through the single Gemma slot (M2b part 3) | Accepted |
| [0012](0012-crop-identification-and-hazards.md) | Identify the locked crop and confirm hazards (M2c) | Accepted (owner manual acceptance 16 Oct; hardware gaps listed in HANDOFF) |
| [0013](0013-quiz-answer-schema.md) | Multiple-choice schema: one correct answer plus wrong distractors (M3.1) | Accepted |
| [0014](0014-module-chunks.md) | The course module as traceable chunks (M3.2) | Accepted |
| [0015](0015-question-bank-draft.md) | Module-grounded question bank, drafted for owner review (M3.3) | Proposed |
| [0017](0017-object-bank.md) | Pre-written object-specific questions; Gemma identifies only (M3.5); live-scan selection amended by 0025 | Proposed |
| [0018](0018-question-source-toggle.md) | Debug switch between the question bank and Gemma (M3.6); not saved across launches since 24 Oct | Accepted |
| [0019](0019-gemma-question-topics.md) | Gemma questions ask about one physics angle, never LCA (M3.7) | Accepted |
| [0020](0020-lock-rearm-rule.md) | After a quiz a different object may lock; lock diagnostics (M2d); reconnect forgets quizzed objects; J1 guard (24 Oct) | Accepted |
| [0021](0021-manual-driving-orchestration.md) | Manual driving, camera distance and sorting orchestration (P1, R1, R2); amended 24 Oct | Proposed |
| [0022](0022-detection-protocol-distance-tags.md) | Optional `track_id`, `dist_cm`, `lateral_cm`, `arm_tags`; firmware distance spec and topology (P1) | Accepted (app parsing; firmware spec only) |
| [0023](0023-r1-command-link.md) | R1 orchestration and the app-to-MaixCAM2 command link | Accepted (app side; firmware R1-fw pending) |
| [0024](0024-fake-maixcam-sim.md) | Sim-backed fake MaixCAM2 for testing without the robot (T1); photo cards, occlusion, timing rule (T1b) | Accepted |
| [0025](0025-bank-detector-class.md) | In a live scan the detector class picks the bank questions; same-bin class mismatch is logged, no card (B1) | Accepted |
| [0026](0026-emergency-stop-motion-gate.md) | Emergency stop, one motion gate, link loss, heartbeat; firmware watchdog spec (E1); STOP rail layout, no scanning while STOPPED (E1b) | Accepted (app; firmware spec) |
| [0027](0027-arm-serial-protocol.md) | Arm HOME, Cartesian hand axes, ESP32 serial mapping and tag-check poses (G2a) | Accepted (protocol; ESP32 L2 pending) |
| [0028](0028-trophy-rules-and-scan-history.md) | Trophy rules, student levels, and local scan history (H1) | Accepted |
| [0030](0030-result-card-and-scan-history.md) | Result card, trophies, "Scan lagi", and saving into Scan History (U2) | Accepted |
| [0040](0040-android-tester-build.md) | Android tester build: Bank/Gemma switch in tester builds only, sideloaded model, lazy load, thermal gate, kill notice, phone log, YUV stream (A1); amends 0018 | Accepted (phone-verified on the Edge 60 Fusion) |
| [0041](0041-identify-speed-picker-warmup.md) | Faster photo identify (smaller photo, shorter prompt), "Bukan ini?" picker, background Gemma load on the scan screen (E1); amends 0040 | Accepted (phone timings pending) |
| [0060](0060-bank-accepted-only.md) | Owner acceptance and accepted-only bank serving | Accepted |
| [0070](0070-history-crop.md) | Separate History photos from identification crops | Accepted |
| [0091](0091-google-sans-flex-font.md) | Design file font change to Google Sans Flex / Google Sans Code, new status chip spec (design only, amends 0090) | Draft |
| [0140](0140-home-screen.md) | Home screen restyle from Figma H1, light and dark, tokens only, behaviour unchanged | Accepted (look pending review) |
| [0141](0141-sidebar-theme-toggle.md) | Sidebar from Figma N1 with a Dark mode switch behind the option gate | Accepted (review pending) |
| [0143](0143-profile-top-bar-drawer.md) | Profile avatar top bar and phone drawer from Figma N4 (custom drawer host, gestures, focus) | Accepted (review pending) |
| [0144](0144-gamified-home.md) | Gamified Home H1 v4: sections, data rules, residu in Anorganik, quest rewards count toward trophies, tree per level | Accepted (review pending) |
| [0145](0145-config-screen-c1.md) | Config screen C1 from Figma: AI card states, real cancel/failure, saved quiz source, settings audit | Draft |
| [0146](0146-theme-toggle-app-icon.md) | Dark mode switch in every build; Android launcher icon follows the theme (switched on leaving the app) | Draft |
| [0170](0170-learn-v2-layout.md) | Learn tab L1 v2 layout: components, hub, module, lesson, quiz, progress, simulations | Draft |
| [0171](0171-learn-thumbnail-fallback.md) | Learn thumbnails: Firestore URL first, bundled illustration as placeholder and fallback | Draft |
| [0172](0172-learn-offline.md) | Learn loading, error, offline cache and empty states | Draft |
| [0173](0173-r2-control-gamified.md) | R2 gamified Control: joystick quantisation, link views, drive tally, Scan quiz pause, dist_cm-only HUD | Draft |
| [0174](0174-r3-control-phone.md) | R3 Control for phones: one STOP/GO button, no logo in the top bar, Guide, English quiz popups | Draft |
| [0175](0175-q3-quiz-scan-popups.md) | Q3: one R3 quiz popup everywhere, real explanation data, loading/skeleton, R3 phone camera scan | Draft |
| [0176](0176-cloud-ai-benchmark.md) | Cloud AI benchmark spike: Gemini models on free tier, 3.5 Flash-Lite primary + automatic fallback chain | Accepted |
| [0177](0177-dashboard-live-network.md) | MaixCAM2 dashboard shows the live SSID (AP/STA) and IP, re-read every 3 s, display-only | Accepted |
| [0178](0178-robot-wifi-qr-setup.md) | Robot joins a hotspot from a Wi-Fi QR (confirm on screen, 45 s rollback); app QR sheet and Find ELIO | Draft |
| [0179](0179-gemini-cloud-ai.md) | ELIOS AI on the Gemini API through the `ai-backend` Vercel function in Singapore (0176 chain, Firebase token check); on-device Gemma removed, bank is the offline fallback | Accepted |
| [0180](0180-segmentation-and-fps-options.md) | Options for better segmentation and higher camera FPS; built: Gemini returns a tight box with the identify answer and re-crops the locked object | Accepted (B) |
| [0181](0181-lock-button-ai-box.md) | LOCK on phone Control: the AI labels and boxes the item (one call, green box on the video, no quiz); SCAN opens its quiz | Accepted |
| [0182](0182-camera-tracks-lock-box.md) | Camera firmware without the waste model: MixFormerV2 tracks the LOCK box (`track_start`), hands as `Human_Hand`, rough AprilTag `arm_tags`, clean 640x480 frames | Accepted |
| [0183](0183-wide-16-9-stream-measured-fx.md) | Camera streams the wide 16:9 view (640x360, 83° like the sim; 640x480 was a 67° crop); measured fx 362 and id 1 6.17 mm for `arm_tags` | Accepted |
| [0184](0184-history-h3-ai-explanations.md) | H3 History: scan list/detail, per-question explanation route with saved ELIOS AI explanations, TTS and per-question PDF | Accepted |
| [0185](0185-ui-localization-gen-l10n.md) | UI languages: gen-l10n with English ARB as source, Gemini script fills other ARB files, language picker under Dark mode in the sidebar; L2 live switch of all content and ELIO→ELIOS rename | Proposed |
| [0187](0187-h3-history-redesign.md) | H3 History redesign from Figma: trophy hero, category tiles, day groups, result stats, difficulty tabs, gamified explanation (result hero, answer tiles, learn/key idea/mission cards), all strings via ARB | Proposed |
| [0193](0193-daily-guide-feed.md) | Daily bilingual guide feed from GitHub Pages, separate from course totals | Accepted |
- [0194](0194-g4-daily-guides.md) G4 Daily Guides in the app
- [0196](0196-elios3-nav-shell.md) ELIOS 3 navigation: Scan hub, Profile tab, no top bar or sidebar
- [0197](0197-elios3-home-learn.md) ELIOS 3 Home (L4) with resume control, Learn clovers
- [0198](0198-elios3-scan-flows.md) ELIOS 3 scan flows: phone Scan & quiz, contribute, ELIOS setup quiz card
- [0199](0199-elios3-history.md) ELIOS 3 History: compact tab, timeline by device
- [0200](0200-elios3-login.md) ELIOS 3 login (L4 organic header)
- [0201](0201-elios3-sound-haptics.md) ELIOS 3 sound service S1–S10, haptic map, loading states
- [0202](0202-elios3-motion.md) ELIOS 3 motion tokens and micro-interactions
- [0203](0203-elios3-motion-2.md) ELIOS 3 motion part 2
- [0204](0204-elios3-wifi-qr-sheet.md) ELIOS 3 Robot Wi-Fi QR sheet
- [0205](0205-elios3-setup.md) ELIOS 3 ELIOS setup screen (robot stage, cable stepper)
- [0206](0206-learn-l3.md) Learn L3: archive stack, Discover more synced with Explore, L3 sub-pages, robot buddy
- [0207](0207-daily-guides-l3-motion.md) Daily Guides L3 style, motion, sound and haptics
- [0208](0208-guide-polaroid-hero-cast.md) Guide polaroid hero flight cast fix
- [0210](0210-xp-level-retune.md) One XP total for the level, thresholds retuned
- [0211](0211-clovers-completion.md) Clovers count finished learning
- [0212](0212-lesson-xp.md) Videos, module guides and lesson quizzes give XP
- [0213](0213-trophies-to-xp.md) "Trophies" become "XP" everywhere
- [0214](0214-scoring-finish.md) Module % from clovers, one streak
- [0215](0215-history-l4-figma.md) History tab in the Figma L4 style, entrance on every open, nested-screen motion
- [0216](0216-scan-l4-figma.md) Scan flows in the Figma L4 style, full-screen Scan & quiz pages, motion everywhere
- [0217](0217-control-l4-scan-pages.md) Robot control uses the full-screen scan pages; essay page and review; scan-start animation; keyboard-safe
- [0218](0218-language-switch-sync.md) Language switch: saved scans open at once, Today's Guide follows the app language
- [0219](0219-essay-questions-setting.md) Essay questions on/off in Profile
- [0220](0220-trophy-icons-to-xp.md) Trophy icons become the XP icon
- [0221](0221-profile-header-joyful.md) Joyful profile header and settings entry animation
- [0222](0222-hazard-b3-scan-result.md) Hazardous (B3) scan result as a full page
- [0223](0223-essay-explanation-page.md) Essay explanation page
- [0224](0224-robot-bin-check.md) Robot bin check before the quiz
- [0225](0225-explanation-wrong-scan.md) A new scan no longer writes its explanations into the previous scan
- [0226](0226-quiz-review-bugs.md) Quiz review bugs: mute, coach language, back confirm, stable explanation
- [0227](0227-essay-answer-review.md) Essay answer review, with motion, haptics and sound on the explanation pages
- [0228](0228-pdf-export-redesign.md) Quiz PDF export redesign and light / dark PDF theme
- [0230](0230-sync-robotic-hand-sim.md) Sync with robotic_hand_sim 75ab797: stepper base, per-joint speeds, CRC frame, two-way mode, MaixCAM2 UART wiring
- [0231](0231-joystick-control.md) Joystick control: smooth drive and arm-base speed from the sticks (task J1)
- [0232](0232-advanced-settings.md) Advanced settings on the phone Control screen (teacher PIN, arm trims, joystick tuning)
