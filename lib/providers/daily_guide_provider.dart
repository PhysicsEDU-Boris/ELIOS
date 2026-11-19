import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../models/app_notification.dart';
import '../services/daily_guide_service.dart';
import 'app_notification_provider.dart';

/// The guide catalogue, checked on app start, on resume, when Learn opens and on pull to refresh.
final dailyGuideFeedProvider =
    AsyncNotifierProvider<DailyGuideFeedNotifier, DailyGuideFeed>(
      DailyGuideFeedNotifier.new,
    );

class DailyGuideFeedNotifier extends AsyncNotifier<DailyGuideFeed> {
  static const _notifiedKey = 'daily-guide-notified';

  @override
  Future<DailyGuideFeed> build() async {
    final listener = AppLifecycleListener(onResume: () => unawaited(refresh()));
    ref.onDispose(listener.dispose);
    return _load();
  }

  Future<DailyGuideFeed> _load() async {
    final feed = await ref.read(dailyGuideServiceProvider).load();
    unawaited(_announce(feed));
    return feed;
  }

  /// Keeps the shown feed while loading; a failure keeps it too when there is one.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_load);
    state = next.hasError && state.hasValue ? state : next;
  }

  /// One "New guide" notification per issue date.
  Future<void> _announce(DailyGuideFeed feed) async {
    final newest = feed.guides.firstOrNull;
    if (newest == null || feed.offline) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getString(_notifiedKey) ?? '').compareTo(newest.date) >= 0) {
        return;
      }
      await prefs.setString(_notifiedKey, newest.date);
      ref
          .read(appNotificationProvider.notifier)
          .push(
            type: AppNotificationType.learning,
            title: l10n.g4NewGuide,
            message: newest.title[newest.lang(l10n.localeName)]!,
            routeHint: 'learning',
          );
    } catch (e) {
      debugPrint('[DailyGuide] notify failed: $e');
    }
  }
}
