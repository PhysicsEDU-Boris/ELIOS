# 0150 Notifications alert and panel from Figma H2

Status: accepted for the H2 draft PR; owner review pending.

## Decision
- Figma page "H2 Notifications" (257:2358): Notification / Alert 257:2518, Notification / Item 257:2559, phone frames 258:2433 (light) and 258:2573 (dark), panel 259:2654, 259:2805, empty 259:2764, 259:2915.
- `lib/widgets/app_notification_widgets.dart` holds `ElioAlert` (toast) and `ElioNotificationItem` (panel row) plus `NotificationTone` (green for success, robot, learning; cyan for quiz, info; amber warning; red error). `AppNotificationBannerHost` shows `ElioAlert` inside `ElioTheme.wrap`, so the toast follows the saved light or dark mode. The panel in `home_screen.dart` (`_showNotificationsSheet`) uses the same widgets.
- Behaviour is unchanged: one banner at a time, 4 s auto-dismiss, dismiss button, Mark all read, Clear all, per-item action (Open Learning, Open Config), Done, tap on an action marks it read.
- New in the panel (from the design): "NEW · n" and "EARLIER" groups, an unread dot, Mark all read and Clear all stay visible but disabled when the list is empty. Scrim is black 32 % light and 56 % dark. Alert and panel use the overlay shadow from `ElioGlow.overlay`; no other glow.
- 48 dp targets for dismiss, close, pills, action links and Done.

## Not done
The quiz-review banners and other places that push notifications are unchanged (they only produce data). Alerts were not triggered on a phone: they need robot or learning events; only the empty panel was checked on the device.
