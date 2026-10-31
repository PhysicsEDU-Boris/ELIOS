# 0110 — Option B app icon and native F0 launch screens

Date: 31 Oct 2026. Task I1. Base: `feature/live-scan` d201cfb.

Use the chosen leaf + terminal cursor in Figma file `J2jSbARJSyJCStNFeWkWDj`,
page U9 Entry flow, section 199:888. Notion source:
https://app.notion.com/p/40a9675ed4f381bd9e75fdfbddece1e0.
Figma was read only.

Android uses dark foreground 199:921 on `#0F172A`. The bright `#4ADE80`
mark has strong contrast against its own navy background in either system theme;
Android does not switch launcher artwork with brightness. The 432px foreground
maps to 108dp, preserving the design's padding (no extra generator inset).
199:931 supplies the monochrome alpha mask in the API 33 adaptive icon resource.
API 26 keeps the two-layer resource; legacy launcher PNGs use master dark.

The iOS catalog retains legacy device sizes from the unrounded light frame,
and adds 1024px universal any/light, dark and grayscale tinted appearances.
Xcode 27 accepts all three with actool. iOS applies the icon mask.
macOS uses dark 199:909: the full 1024px canvas includes the 824px body and
100px transparent margins. The light alternative is retained as a source export.

The Figma export service includes ancestor section backgrounds in transparent
frame exports. Raw PNG/SVG exports are retained. `*-isolated.svg` contains only
the named frame group and original filter definitions; `*-transparent.png`
rasterizes that group without altering its paths, coordinates or effects.
The Android monochrome mask and macOS margins must have zero-alpha corners.

Owner decision, 31 Oct 2026: native launch screens are light only because light
is the primary/default app mode; dark is an in-app choice. Use F0 light 208:1172
(`#F8FAFC`). The original 10dp seed pixels are retained at viewport centre +22.5dp.
Android 12 uses a transparent 288dp canvas; older Android and the existing iOS
centred LaunchImage view use a transparent 390x844dp canvas. Android night launch
resources and iOS dark launch appearances are removed. OS icon appearances remain.
The existing storyboard and all Dart files remain untouched.

Integration dependency: d201cfb still renders the previous Flutter splash.
U9 must supply the new Flutter F0 before the native-to-Flutter transition matches.
The owner-authorized native-splash generator block is light only and color-only.
The launch resources are committed; the generator is not part of the build.
Running the generator manually would replace the committed seed artwork.
The launcher generator alone cannot reproduce API 33 monochrome, Apple appearances
or macOS exports; retain the checked-in native catalogs/resources.

Validation and remaining device checks are recorded in `docs/handoff/lane-i.md`.
No Mac application was built, run, installed or registered.
