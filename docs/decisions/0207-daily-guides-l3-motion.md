# 0207 — Daily Guides in the L3 style, with motion, sound and haptics

Date: 11 November 2026. Same branch as 0206 (PR #117). Owner request: animate Continue and
everything inside Daily Guides (issue, Quick quiz, Mini lab, guide feed) like the Learn hub, and
restyle what does not match the L3 look.

## Style changes

- `GuideTopBar` is now the L3 curved green header: round back / close button, title with a
  squiggle, caption subtitle, tilted surface sticker on the right (XP, EN · ID). Used by the guide
  feed, issue, Quick quiz and Mini lab.
- Leaf shapes: issue hero 30/10/30/10, quest stops and rows 22/8/22/8, quiz cards 30/10/30/10,
  lab cards and results leaf; L3 pill buttons (`L3Button`) everywhere; language and topic
  filters are tab pills.
- The ELIO robot buddy replaces the old mascot with moods: Thinking on the front quiz card (Excited
  / Sad once checked), Excited / Sad on the quiz result, Talking on "Did you know", Searching on
  "ELIOS AI will look for" and while the lab is checked, Sad on "Almost".
- Mini lab hero uses the exported thermometer art; mission pills carry the quiz paper and
  thermometer art.

## Motion, sound, haptics

| Where | Motion | Sound | Haptic |
|---|---|---|---|
| Continue (hub ticket, Today card, issue bar) | press squeeze, then the guide polaroid flies into the issue hero and turns from its tilt to the hero's (Hero, route timing) | S2 | medium |
| Issue | stickers pop (bounce), content rises (rule 7), quest line draws down, done markers pop, current marker breathes (8 s), action bar slides up | S4 when a stop is newly done, S9 when the guide is finished | success / celebrate |
| Quick quiz | cards dealt in from the right; Q chips flip with a pop; feedback box pops; buddy reacts | S1 pick, S4 right, S5 wrong, S1 next card, S9 on a pass | select, success, error, select, celebrate (warning on a miss) |
| Mini lab | brief steps pop in turn, thermometer hops; REC dot pulses; white shutter flash; review frames pop; buddy searches while checking; approved = badge drops in over turning rays + the celebration overlay; almost = card shakes, verdict marks tick in | S8 start / stop, S7 shutter, S2 camera, S9 approved, S5 almost | medium, light, light, celebrate, warning |
| Guide feed | streak days pop left to right, cards rise in pairs (again on a topic change) | S1 on filter, S2 on a card | select, light |

`L3Button(feedback: false)` lets a button play only its own result sound (the press pop would
otherwise swallow it within the 120 ms gap). This also fixes the Kuis fisika Check chime (0206).
Reduced motion: entrances become fades or rest, no shake, no rays, no flight turn.

## Tests

`test/guides/g4_screens_test.dart`: new "L3 feedback" tests (quiz tick / chime / knock, lab
shutter and record, Continue pop), each break-checked; older tests updated for L3 buttons, tab
pills and the longer issue page. Renders in `docs/test-results/g4-guides/app/` regenerated.
Not phone-tested by me (owner tests).
