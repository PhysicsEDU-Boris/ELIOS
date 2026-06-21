enum AppNotificationType {
  info,
  success,
  warning,
  error,
  robot,
  learning,
  quiz,
}

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? actionLabel;
  final String? routeHint;
  final Map<String, String> metadata;
  final bool read;
  final bool bannerDismissed;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.actionLabel,
    this.routeHint,
    this.metadata = const {},
    this.read = false,
    this.bannerDismissed = false,
  });

  AppNotification copyWith({bool? read, bool? bannerDismissed}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      createdAt: createdAt,
      actionLabel: actionLabel,
      routeHint: routeHint,
      metadata: metadata,
      read: read ?? this.read,
      bannerDismissed: bannerDismissed ?? this.bannerDismissed,
    );
  }
}
