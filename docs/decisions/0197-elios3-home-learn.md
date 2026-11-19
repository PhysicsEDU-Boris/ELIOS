# 0197 — ELIOS 3 Home (L4) with resume control, Learn clovers

Date: 10 November 2026

Second PR of the ELIOS 3 series, stacked on `feat/elios3-nav-shell` (0196). Figma
J2jSbARJSyJCStNFeWkWDj: Home `629:80734` (resume), `629:80377`; Learn `629:82489`.

- Home header: ELIOS leaf logo, "Hello, name", bell only. The trophy total moved from the header
  pill onto the hero as a tilted "598 trophies" sticker.
- Resume control card (629:81091) under the search: "ELIOS robot · Still connected · Continue",
  only while `robotStatusProvider` is `connected`. Continue sets navigation index 3 (opens Control).
- To make that card reachable, leaving Control now keeps a live robot link: it stops the stream
  (the motion gate already sent motor 0,0; the camera's watchdog holds wheels/arm after 1 s) and
  only disconnects if the link is not up, so no reconnect loop is left running. The session ends
  with Disconnect on ELIOS setup. The Control screen itself is unchanged.
- Hero: half-circle level dial (track, progress to the next level, knob) with the existing tree /
  sprout art, "Lv n" ends, LEVEL n overline, level title, "N trophies to Level n+1 · your tree grows
  with every trophy". Numbers come from the existing trophy rules; no new data.
- Stats as three staggered pebbles (scans, quiz accuracy, day streak). Daily quests as three tilted
  pop cards with an art bubble (scan, target, B3 bin), reward chip and a ring that fills with the
  quest's progress (the old progress bar). "Scan an item" (empty state) now opens the Scan hub.
- Learn: the header sticker shows the Daily Guides reading streak as clovers ("1 clover"; the
  Figma component says the clover is the guide-streak sticker), the XP pill is replaced by
  "N XP · n clovers · from Daily Guides" under the module legend, and the Archive bubble uses the
  clover art. Same numbers as before (`guideProgressProvider`).

Not done here: Scan activity / Bin buddies / This week / Medals keep the H1 v4 card style (layout
and data unchanged); the Figma "Recent scans → History" strip on Home; the floating "260 XP" chip.
