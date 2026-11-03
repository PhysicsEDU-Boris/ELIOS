# 0172 Learn loading, error and offline behaviour

Status: draft PR (L1).

## Decision
- While a Firestore stream has no first value the screen shows a skeleton (hub, My progress, module lessons) or a spinner (lesson list, PDF, quiz questions). The spinner is static under reduced motion.
- A module stream error shows "Learning modules could not be loaded." with "Try again" (re-subscribes the streams) and "Open offline lessons".
- "Open offline lessons" lists published guides and videos from the Firestore local cache only (`ElearningContentService.fetchCachedLessons`, `Source.cache`). Guides whose PDF is in the PDF cache open offline; videos need the internet.
- No published modules: "No learning modules available yet." First launch (no progress at all): the hero becomes "Welcome to Learn / Start module 1" and Continue learning shows a hint. My progress with no progress shows an empty state.
- Content is read through `elearningContentServiceProvider` so tests run against fake_cloud_firestore.
