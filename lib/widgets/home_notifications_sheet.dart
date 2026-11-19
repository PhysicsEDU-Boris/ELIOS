// Notifications panel opened by the Home bell. Moved unchanged from the old
// home_screen.dart (H1v4, decision 0144); H2 (#70) will replace it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_notification.dart';
import '../providers/app_notification_provider.dart';
import '../providers/navigation_provider.dart';
import 'elio_colors.dart';
import 'package:elio/l10n/l10n.dart';

const _ink = Color(0xFF191C1C);
const _muted = Color(0xFF6D7A73);
const _border = Color(0xFFE4EAE6);
const _cyan = Color(0xFF00647C);
const _amber = Color(0xFFBA7517);

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final VoidCallback? onAction;

  const _NotificationTile({required this.item, this.onAction});

  @override
  Widget build(BuildContext context) {
    final color = _notificationColor(item.type);
    final actionLabel = item.actionLabel ?? _notificationActionLabel(item);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_notificationIcon(item.type), color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.manrope(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.message} • ${_relativeTime(item.createdAt)}',
                  style: GoogleFonts.manrope(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: elioGreen,
                      visualDensity: VisualDensity.compact,
                      textStyle: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(Icons.notifications_none_rounded, color: _muted, size: 30),
          const SizedBox(height: 10),
          Text(
            l10n.notifNone,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.notifEmptyHint,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: _muted,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

void showNotificationsSheet({
  required BuildContext context,
  required VoidCallback onOpenLearning,
}) {
  final rootContext = context;

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l10n.notifDismiss,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Material(
                  color: Colors.transparent,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final items = ref.watch(appNotificationProvider);
                      final notificationNotifier = ref.read(
                        appNotificationProvider.notifier,
                      );

                      return Container(
                        constraints: BoxConstraints(
                          maxWidth: 720,
                          maxHeight:
                              MediaQuery.of(dialogContext).size.height * 0.78,
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 42,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD8DEDB),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.notifTitle,
                                    style: GoogleFonts.sora(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: _ink,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: l10n.notifClose,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.notifSubtitle,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                height: 1.4,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Flexible(
                              child: SingleChildScrollView(
                                child: items.isEmpty
                                    ? const _NotificationsEmptyState()
                                    : Column(
                                        children: [
                                          for (
                                            var i = 0;
                                            i < items.length;
                                            i++
                                          ) ...[
                                            _NotificationTile(
                                              item: items[i],
                                              onAction:
                                                  _notificationActionLabel(
                                                        items[i],
                                                      ) ==
                                                      null
                                                  ? null
                                                  : () =>
                                                        _openNotificationAction(
                                                          rootContext:
                                                              rootContext,
                                                          sheetContext:
                                                              dialogContext,
                                                          ref: ref,
                                                          notification:
                                                              items[i],
                                                          onOpenLearning:
                                                              onOpenLearning,
                                                        ),
                                            ),
                                            if (i != items.length - 1)
                                              const Divider(
                                                height: 1,
                                                color: _border,
                                              ),
                                          ],
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (items.isNotEmpty) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          notificationNotifier.markAllRead,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: elioGreen,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        l10n.notifMarkAllRead,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: notificationNotifier.clearAll,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFBA1A1A,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        l10n.notifClearAll,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: elioGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: Text(
                                  l10n.notifDone,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _openNotificationAction({
  required BuildContext rootContext,
  required BuildContext sheetContext,
  required WidgetRef ref,
  required AppNotification notification,
  required VoidCallback onOpenLearning,
}) {
  ref.read(appNotificationProvider.notifier).markRead(notification.id);
  Navigator.of(sheetContext).pop();

  Future<void>(() {
    if (!rootContext.mounted) return;

    switch (notification.routeHint) {
      case 'learning':
      case 'quiz':
      case 'quizReview':
        onOpenLearning();
        return;
      case 'robot':
        ref.read(navigationIndexProvider.notifier).state = 2;
        return;
      default:
        return;
    }
  });
}

String? _notificationActionLabel(AppNotification notification) {
  if (notification.actionLabel != null) return notification.actionLabel;

  switch (notification.routeHint) {
    case 'learning':
    case 'quiz':
    case 'quizReview':
      return l10n.notifOpenLearning;
    case 'robot':
      return l10n.notifOpenConfig;
    default:
      return null;
  }
}

IconData _notificationIcon(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.success:
      return Icons.check_circle_outline_rounded;
    case AppNotificationType.warning:
      return Icons.warning_amber_rounded;
    case AppNotificationType.error:
      return Icons.error_outline_rounded;
    case AppNotificationType.robot:
      return Icons.smart_toy_outlined;
    case AppNotificationType.learning:
      return Icons.menu_book_outlined;
    case AppNotificationType.quiz:
      return Icons.fact_check_outlined;
    case AppNotificationType.info:
      return Icons.info_outline_rounded;
  }
}

Color _notificationColor(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.success:
    case AppNotificationType.robot:
    case AppNotificationType.learning:
      return elioGreen;
    case AppNotificationType.warning:
      return _amber;
    case AppNotificationType.error:
      return const Color(0xFFBA1A1A);
    case AppNotificationType.quiz:
      return _cyan;
    case AppNotificationType.info:
      return elioGreen;
  }
}

String _relativeTime(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);
  if (difference.isNegative || difference.inMinutes < 1) return l10n.timeJustNow;
  if (difference.inMinutes < 60) return l10n.timeMinutesAgo(difference.inMinutes);
  if (difference.inHours < 24) return l10n.timeHoursAgo(difference.inHours);
  if (difference.inDays < 7) return l10n.timeDaysAgo(difference.inDays);
  if (difference.inDays < 30) return l10n.timeWeeksAgo(difference.inDays ~/ 7);
  if (difference.inDays < 365) return l10n.timeMonthsAgo(difference.inDays ~/ 30);
  return l10n.timeYearsAgo(difference.inDays ~/ 365);
}
