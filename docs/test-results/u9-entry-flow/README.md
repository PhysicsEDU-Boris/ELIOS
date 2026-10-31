# U9 entry flow: renders and Figma comparison

32 PNGs, rendered by `test/screens/u9_render_test.dart` (`U9_RENDER=1`) at the Figma frame sizes (390x844 phone, 1366x768 desktop), bundled Inter and JetBrains Mono, device pixel ratio 1.
- `splash-{F0,F7,F11}-{dark,light}-{phone,desktop}.png`
- `login-{signin,signup,forgot,error,loading}-{dark,light}-{phone,desktop}.png`
- "forgot" is the form before sending; "error" is a wrong password from a fake auth; "loading" is a held fake sign-in. No real Firebase or Google call was made.

## Compared with Figma `get_screenshot` / design context (by eye)
Compared pair by pair: phone dark sign in, sign up, forgot, error, loading (196:689, 747, 811, 842, 908); desktop dark sign in (196:1249); desktop light sign in (196:1544); splash dark phone F2, F7, F11 (208:860, 1010, 1130); light F11 (208:1502); reduced motion desktop dark (214:1160). Positions match within 1 to 3 px. Not compared one by one: the remaining light and desktop variants of sign up, forgot, error and loading (same code path, token swap only), and splash desktop F0 and F7.

## Visible differences
1. Icons (mail, lock, eye, user, alert, check) are Material outline icons; Figma has its own SVG icons.
2. The loading spinner is Flutter's `CircularProgressIndicator` (22 dp); Figma has a fixed ring arc.
3. Hint text starts about 1 px right of Figma.
4. Desktop is Figma's split layout (520 dp brand panel plus 400 dp form column), not a "centred card" as the brief and the Notion page say. Frame 196:1249 shows the split layout, so the code follows the frame. Below 900 dp width the phone layout is used.
5. Splash F3: Figma resets stem and buds to their starting size. The code keeps them at full size while they fade out (the spec says "fade out").
6. Light success banner border (35 % of the green) is assumed; Figma's value was not in the context I read. Error banner values come from Figma.
7. Brand "ELIOS" on phone uses weight 700 (Figma Bold); the `subhead` token is 600.

## Differences from the old screens (strings and behaviour)
- Wordmark ELIO to ELIOS (splash, login, "Sign in to control ELIOS", "Join ELIOS to start sorting"). Old subtitle "Smart Waste Sorting Robot" removed from both screens; splash tagline is now "Environment Learning Intelligent Object Sorter".
- Divider "OR" to "Atau". Guest button lost its person icon; the guest note lost its info icon and fixed 240 dp width.
- Forgot password is its own mode with a "Send reset link" button and a success banner; the old snackbar texts are kept ("Enter a valid email first.", "Reset link sent to your email.").
- The error banner has no close button (Figma). The password visibility toggle is now focusable.
- Sign-up email label stays "Email"; hints are unchanged ("John Doe", "you@example.com").
- `main.dart` starts on the splash. Old splash image (`ELIO_ICON.png`), green background and spinner are gone.

## Contrast (pairs used on these screens; WCAG 2.x, text 4.5:1, non-text 3:1)
All text pairs pass in light and dark (lowest: light guest note 4.55, light link 4.79, light hint 4.76; dark hint 5.65). Failures, none fixed here (tokens are out of scope):
- Light: primary fill `#4ADE80` on bg `#F8FAFC` = 1.67:1 (non-text). The button label (10.25:1) identifies it. Same as the Figma contrast page (198:1385).
- Light and dark: `border/medium` on bg = 1.42:1 and 1.72:1. Used only on the Google and Guest outlines and dividers (decorative). The inputs use `border/form` (4.76 and 3.75).
- Loading state: hint on raised fill is 3.28 dark and 4.34 light; disabled controls are exempt (Figma note).
- The Figma page's other two FAILs (tertiary on raised, secondary on raised) do not occur here.

## Figma problems found
- `get_motion_context` returned no timeline for the splash section (null); the text table in 208:1551 was the only motion source.
- The temporary asset URLs in `get_design_context` returned 404 when downloaded; the vectors came from `download_assets`.
- No Figma state for a field validation error, for "Send reset link" before sending, or for a Google error.
- The `figma-design-to-code` skill named in the brief is not installed here, so it was not loaded.
