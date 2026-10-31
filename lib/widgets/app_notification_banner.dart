import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../providers/app_notification_provider.dart';
import '../theme/elio_theme.dart';
import 'app_notification_widgets.dart';

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
    return ElioTheme.wrap(
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ElioAlert(
            notification: notification,
            onDismiss: () => ref
                .read(appNotificationProvider.notifier)
                .dismissBanner(notification.id),
          ),
        ),
      ),
    );
  }
}
