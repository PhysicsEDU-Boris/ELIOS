import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_notification.dart';
import '../providers/app_notification_provider.dart';
import 'package:elio/l10n/l10n.dart';

class AppNotificationBannerHost extends ConsumerStatefulWidget {
  final Widget child;

  const AppNotificationBannerHost({super.key, required this.child});

  @override
  ConsumerState<AppNotificationBannerHost> createState() =>
      _AppNotificationBannerHostState();
}

class _AppNotificationBannerHostState
    extends ConsumerState<AppNotificationBannerHost> {
  Timer? _dismissTimer;
  String? _scheduledNotificationId;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleDismiss(AppNotification notification) {
    if (_scheduledNotificationId == notification.id) return;

    _dismissTimer?.cancel();
    _scheduledNotificationId = notification.id;
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      ref.read(appNotificationProvider.notifier).dismissBanner(notification.id);
      _scheduledNotificationId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final notification = ref.watch(latestBannerNotificationProvider);

    if (notification != null) {
      _scheduleDismiss(notification);
    } else {
      _dismissTimer?.cancel();
      _scheduledNotificationId = null;
    }

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: notification == null,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: AnimatedSlide(
                  offset: notification == null
                      ? const Offset(0, -1.25)
                      : Offset.zero,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: notification == null ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: notification == null
                        ? const SizedBox.shrink()
                        : _AppNotificationBanner(notification: notification),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppNotificationBanner extends ConsumerWidget {
  final AppNotification notification;

  const _AppNotificationBanner({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorFor(notification.type);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(notification.type),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification.title,
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF181D1A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: const Color(0xFF3F4943),
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ref
                    .read(appNotificationProvider.notifier)
                    .dismissBanner(notification.id),
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.dismissNotification,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(AppNotificationType type) {
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

Color _colorFor(AppNotificationType type) {
  switch (type) {
    case AppNotificationType.success:
    case AppNotificationType.robot:
    case AppNotificationType.learning:
      return const Color(0xFF059669);
    case AppNotificationType.warning:
      return const Color(0xFFBA7517);
    case AppNotificationType.error:
      return const Color(0xFFBA1A1A);
    case AppNotificationType.quiz:
      return const Color(0xFF00647C);
    case AppNotificationType.info:
      return const Color(0xFF004F38);
  }
}
