# 0184: H3 History and saved ELIOS AI explanations

- Status: Accepted for implementation (Task H3; owner reviews the PR).
- Date: 2026-11-05
- Base: `feature/live-scan`; branch: `feat/history-h3`; no merge.
- Design: Figma `J2jSbARJSyJCStNFeWkWDj`, H3 page `433:2358`, supplied light/dark frames and components.
- Builds on: 0179 (Gemini backend), 0175 (reviewed bank grounding), 0031 (records, PDF, TTS).

## Decision

History uses the existing theme palettes and bundled Inter for the Figma sans text styles, as Home already does. The phone list pushes a scan-detail route; wide windows keep two panes. Both use saved crops with containment, real store trophies, category filters, and the same question cards. Empty History starts a scan. No History records are invented or restored. Debug sample creation is absent from the UI and guarded against release/tester builds.

A question has a full-screen explanation with its saved answers, score, explanation sections, category buddy, small listen controls, next-question action and per-question export sheet. Source metadata remains stored but is absent from this route and its PDF. The existing whole-record PDF API remains available.

`AiQuizService.explainAnswer` submits a structured user request through the existing Gemini slot. It sends the exact stored answer, options, correct answer, item, category, difficulty and reviewed bank grounding. The response must echo the unchanged correct option, contain nonempty `why_correct` and `key_idea`, and respect caps (1800/1800/600 characters, up to five 240-character steps). Invalid responses get one retry. The bank loader marks accepted items; debug draft reasons/wrongWhy cannot become an offline explanation or answer announcement. Reviewed `wrongWhy` overrides the model for the picked option; right answers have no wrong-answer feedback. The prompt requires Indonesian suitable for SMP students and forbids contradicting reviewed grounding. Semantic grounding remains a model constraint; the parser cannot prove arbitrary prose agrees with a reference.

Quiz-time generation runs only when the slot is free, preserving next-question prefetch. Otherwise History generates on first open. Identical concurrent explanation requests share a future, including the legacy/History category aliases. Results are saved into the answered question, even if the quiz advances or finishes before the response arrives. The existing quiz overlay uses the same explanation fields.

Schema 4 adds question options/grounding and explanation `keyIdea`, `steps`, `source` (`ai`, `bank`, `aiWithBank`), `generatedAt`, and `model`. Old records load without losing answers, trophies, photos or source metadata. Old local classification reasons/takeaways/tables are removed from migrated explanation content; reviewed bank reasons remain. Migration is serialized on the next normal save. A failed explanation write restores the previous in-memory record and reports failure.

Offline/error responses retain reviewed bank text only, or show unavailable. A completed attempt, including an unavailable result, is saved. Reopening, listening and PDF export do not generate again. Only the explicit **Coba lagi** action retries an incomplete explanation; there is no regenerate action for complete results. No local educational templates are generated.

Each explanation request has a 20-second slot deadline and at most two attempts. List/detail loading has a 15-second UI deadline; explanation loading has a 45-second UI deadline, including time waiting for another user request. Errors expose retry. One shared 1.2-second sweep supplies list/detail/explanation skeleton layouts and stops its ticker for reduced motion. Existing Home/Learn/Quiz skeletons keep their appearance.

TTS uses the existing service. A request epoch prevents delayed setup from speaking after a newer request or stop. Whole-question playback progresses through the saved sections; a section button speaks only that section. Switching, pause, route exit, export and app backgrounding stop playback. The current section receives a success tint and “Sedang dibacakan”. No read-aloud card/switch is added.

Per-question PDFs use saved text only and honor independent answer/explanation/photo/notes options. They are A4, named `ELIOS_<item>_Q<n>.pdf`, and contain no source/module/guide/simulation metadata. On Android, Save publishes through MediaStore to Download/ELIOS without storage permission; failed writes remove only their own incomplete file. Other platforms retain the application reports directory. Share uses the platform share sheet. The sheet preview is the design's compact A4 file thumbnail, not a second generated explanation.

## Verification and limits

See [H3 validation](../test-results/0184-history-h3.md) for checks, break-checks and phone steps. Explanation screenshots use isolated test fixtures and never seed the owner's store. No Mac app bundle, registration, runtime model, credentials or private configuration is changed by this task. USB acceptance on Motorola Edge 60 Fusion / Android 16 exercised live Gemini, offline retry/cache, native id-ID TTS lifecycle and Android PDF save/share. Device-only styling inheritance was fixed with explicit rounded chips/actions and sans detail titles; PDF notes use the installed pdf package’s Inseparable widget to keep the heading and lines together. iOS, audible pronunciation quality and robot operation remain unverified. See the phone report.
