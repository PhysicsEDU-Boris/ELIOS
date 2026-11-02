# 0171 Learn thumbnail fallback

Status: draft PR (L1).

## Decision
- Real thumbnails stay the Firestore URLs (Cloudinary): `VideoLesson.thumbnailUrl`, `GuideLesson.coverUrl`, `ElearningModule.thumbnailUrl`, loaded through `CachedNetworkImage` (`LearnThumbnail`).
- The bundled SVG illustration (`assets/illustrations/learn/`, exported from Figma 293:2359) is shown only as the placeholder while loading and as the error widget when the URL is empty or fails. It is bundled because the robot Wi-Fi has no internet.
- Mapping (`LearnArt.cover`, `LearnLesson.fallbackArt`): organic → Organik or Biogas, inorganic → Anorganik or Reuse, hazardous → B3 or Safe handling (alternating by lesson order); lessons whose section or level says "foundation" → Intro.
- `VideoLesson.resolvedYoutubeId`: `youtubeId`, else the id parsed from `videoUrl` (watch?v=, youtu.be, embed, shorts, live). No Firestore field changed.

## Tests
`test/screens/learn_v2_test.dart`: failing download shows the fallback (break-checked), empty URL shows it, mapping, URL parsing (break-checked).
