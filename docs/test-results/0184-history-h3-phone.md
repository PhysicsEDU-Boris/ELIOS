# H3 USB phone acceptance — 5 Nov 2026

Device: Motorola Edge 60 Fusion, Android 16 / API 36. Same debug application ID, data-preserving install. No emulator or seeded History.

| Check | Result |
| --- | --- |
| Existing data | 40 records, 120 saved answers, crop paths and 442 total trophies preserved; schema migrated from 2/3 to 4. Separate R3 test records untouched. |
| Light/dark History and detail | Saved photos, score tint and question cards render; only Riwayat selected. B3 filter shows the expected 11 records. |
| Live explanation | Actual Gemini responses saved to the existing buck-converter record, not local educational templates. Q1: 3.5 Flash-Lite 503 → 3.1 Flash-Lite success in 5.86 s. |
| Offline cached open | Saved Q1 opens with its explanation, without loading or changing generatedAt. |
| Offline uncached open | Q2 shows unavailable + Coba lagi in 2.9 s, with no invented reason. Mobile data restored before retry. |
| Retry online | Q2 saved a complete explanation from Gemini 3.5 Flash-Lite. |
| TTS | Native id-ID playback, one service instance; whole-question sequence, section switching, pause, Back and background stops verified using native callbacks/VM state and button/highlight states. Pronunciation quality not independently heard. |
| Question PDF | File saved inside app reports, actual A4 PDF pulled and rendered; saved explanation, chosen photo and notes present. |
| Share and whole-record PDF | Correct filenames reach Android's share chooser; dismissed without selecting a recipient. |
| Device QA fixes | Rounded/sans filter chips, sans detail title, rounded empty action; PDF note heading stays with writing lines. Six styling tests and the pagination regression failed before the fixes. |

No owner record was added, deleted or reconstructed. Only explanation cache/schema fields changed. Network state is restored after each offline test. Empty state, essay-specific review and forced list/detail timeouts remain covered by automated tests rather than altering owner data to manufacture those states on the phone. No robot motion or iOS test.

See [local build notes](../local-build-notes.md) for retained app/build details. Final refinement APK and evidence are recorded after the rerun.
