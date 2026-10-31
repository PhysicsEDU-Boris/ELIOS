// Notification alert and list item from Figma page "H2 Notifications"
// (257:2358): Notification / Alert 257:2518, Notification / Item 257:2559,
// phone light 258:2433, dark 258:2573, panel 259:2654 / 259:2805.
import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../theme/elio_tokens.dart';
import 'auth/auth_widgets.dart' show authPalette;

const _minTap = 48.0;

IconData notificationIcon(AppNotificationType type) => switch (type) {
  AppNotificationType.success => Icons.check_circle_outline_rounded,
  AppNotificationType.warning => Icons.warning_amber_rounded,
  AppNotificationType.error => Icons.error_outline_rounded,
  AppNotificationType.robot => Icons.smart_toy_outlined,
  AppNotificationType.learning => Icons.menu_book_outlined,
  AppNotificationType.quiz => Icons.fact_check_outlined,
  AppNotificationType.info => Icons.info_outline_rounded,
};

/// Text/icon colour, tint fill and border of a type: green for success, robot
/// and learning, cyan for quiz and info, amber for warning, red for error.
class NotificationTone {
  const NotificationTone(this.color, this.fill, this.border);

  final Color color, fill, border;

  factory NotificationTone.of(ElioPalette p, AppNotificationType type) {
    final (color, light) = switch (type) {
      AppNotificationType.success ||
      AppNotificationType.robot ||
      AppNotificationType.learning => (p.primaryText, 0.06),
      AppNotificationType.quiz ||
      AppNotificationType.info => (p.tertiaryText, 0.06),
      AppNotificationType.warning => (p.secondaryText, 0.04),
      AppNotificationType.error => (p.errorText, 0.08),
    };
    return NotificationTone(
      color,
      color.withValues(alpha: p.isDark ? 0.12 : light),
      color.withValues(alpha: p.isDark ? 0.25 : 0.35),
    );
  }
}

ShapeBorder _shape(double radius, Color side) => RoundedSuperellipseBorder(
  borderRadius: BorderRadius.circular(radius),
  side: BorderSide(color: side),
);

class _IconTile extends StatelessWidget {
  const _IconTile(this.type, this.size);

  final AppNotificationType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = NotificationTone.of(authPalette(context), type);
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: tone.fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Icon(notificationIcon(type), size: 20, color: tone.color),
    );
  }
}

/// The toast banner (Figma Notification / Alert).
class ElioAlert extends StatelessWidget {
  const ElioAlert({
    super.key,
    required this.notification,
    required this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final tone = NotificationTone.of(p, notification.type);
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: p.surface,
          shape: _shape(16, tone.border),
          shadows: ElioGlow.overlay,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconTile(notification.type, 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification.title,
                      style: ElioTokens.button.copyWith(color: p.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: ElioTokens.bodySmall.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                tooltip: 'Dismiss notification',
                constraints: const BoxConstraints.tightFor(
                  width: _minTap,
                  height: _minTap,
                ),
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of the notifications panel (Figma Notification / Item).
class ElioNotificationItem extends StatelessWidget {
  const ElioNotificationItem({
    super.key,
    required this.item,
    required this.timeLabel,
    this.actionLabel,
    this.onAction,
  });

  final AppNotification item;
  final String timeLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return Semantics(
      container: true,
      label:
          '${item.title}. ${item.message}. $timeLabel.${item.read ? '' : ' Unread.'}',
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: p.surface,
          shape: _shape(16, p.borderMedium),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ExcludeSemantics(
            excluding: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconTile(item.type, 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: ElioTokens.button.copyWith(
                                    color: p.textPrimary,
                                  ),
                                ),
                              ),
                              if (!item.read) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: p.primaryText,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Text(
                                timeLabel,
                                style: ElioTokens.caption.copyWith(
                                  color: p.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.message,
                            style: ElioTokens.bodySmall.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (actionLabel != null && onAction != null)
                  TextButton.icon(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: p.primaryText,
                      minimumSize: const Size(_minTap, _minTap),
                      padding: EdgeInsets.zero,
                      textStyle: ElioTokens.button,
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(actionLabel!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
