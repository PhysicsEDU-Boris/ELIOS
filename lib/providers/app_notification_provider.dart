import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';

final appNotificationProvider =
    NotifierProvider<AppNotificationNotifier, List<AppNotification>>(
      AppNotificationNotifier.new,
    );

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref
      .watch(appNotificationProvider)
      .where((notification) => !notification.read)
      .length;
});

final latestBannerNotificationProvider = Provider<AppNotification?>((ref) {
  final notifications = ref.watch(appNotificationProvider);
  for (final notification in notifications) {
    if (!notification.bannerDismissed) return notification;
  }
  return null;
});

class AppNotificationNotifier extends Notifier<List<AppNotification>> {
  static const _maxNotifications = 50;
  static const _duplicateWindow = Duration(seconds: 3);

  @override
  List<AppNotification> build() => const [];

  void push({
    required AppNotificationType type,
    required String title,
    required String message,
    String? actionLabel,
    String? routeHint,
    Map<String, String> metadata = const {},
  }) {
    final now = DateTime.now();
    final duplicate = state.any((notification) {
      return notification.type == type &&
          notification.title == title &&
          notification.message == message &&
          now.difference(notification.createdAt) <= _duplicateWindow;
    });

    if (duplicate) return;

    final notification = AppNotification(
      id: '${now.microsecondsSinceEpoch}-$title',
      type: type,
      title: title,
      message: message,
      createdAt: now,
      actionLabel: actionLabel,
      routeHint: routeHint,
      metadata: metadata,
    );

    state = [notification, ...state].take(_maxNotifications).toList();
  }

  void markRead(String id) {
    state = [
      for (final notification in state)
        notification.id == id
            ? notification.copyWith(read: true)
            : notification,
    ];
  }

  void markAllRead() {
    state = [
      for (final notification in state) notification.copyWith(read: true),
    ];
  }

  void dismissBanner(String id) {
    state = [
      for (final notification in state)
        notification.id == id
            ? notification.copyWith(bannerDismissed: true)
            : notification,
    ];
  }

  void clearAll() {
    state = const [];
  }
}
