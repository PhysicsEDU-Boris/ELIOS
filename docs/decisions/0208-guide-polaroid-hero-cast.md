# 0208 — Guide polaroid hero: fix the flight cast

Date: 11 November 2026. Fix for 0207 (PR #117). Owner video 2026-11-11 20:13.

## Problem

Going back from the guide issue page (and from Daily Guides) to Learn showed the red error
screen `type 'GuidePolaroid' is not a subtype of type 'GuidePolaroidHero' in type cast`.

## Cause

`GuidePolaroidHero`'s `flightShuttleBuilder` read the polaroid from each end with
`(hero.child as GuidePolaroidHero).polaroid`, but the `Hero`'s child is the `GuidePolaroid`
itself. Every flight of that hero threw.

## Decision

Read `hero.child as GuidePolaroid`. No style or motion change: the polaroid still flies and
turns from one tilt to the other (0207).

## Test

`test/guides/guide_polaroid_hero_test.dart` pushes and pops a route with the hero and checks
every flight frame for exceptions. Break-checked: fails with the old cast, passes with the fix.
