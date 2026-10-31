import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:elio/models/app_notification.dart';
import 'package:elio/providers/app_notification_provider.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/app_notification_banner.dart';
import 'package:elio/widgets/app_notification_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/auth_test_support.dart';

/// H2 alert and item (Figma 257:2518, 257:2559). Banner host behaviour is unchanged.
AppNotification _n(
  AppNotificationType t, {
  bool read = false,
}) => AppNotification(
  id: t.name,
  type: t,
  title: 'Title ${t.name}',
  message:
      'Robot connection was lost. Check the device or network, then try again.',
  createdAt: DateTime.now(),
  read: read,
);

void main() {
  setUpAll(loadElioFonts);

  for (final b in Brightness.values) {
    testWidgets(
      '${b.name}: all 7 alert types and items render, dismiss works',
      (t) async {
        var dismissed = 0;
        var acted = 0;
        await pumpAt(
          t,
          ElioTheme.wrap(
            Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final type in AppNotificationType.values) ...[
                      ElioAlert(
                        notification: _n(type),
                        onDismiss: () => dismissed++,
                      ),
                      ElioNotificationItem(
                        item: _n(type, read: type.index.isEven),
                        timeLabel: '2h ago',
                        actionLabel: 'Open Config',
                        onAction: () => acted++,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          size: const Size(360, 3000),
          textScale: 1.3,
          brightness: b,
        );
        expect(t.takeException(), isNull);
        expect(find.byType(ElioAlert), findsNWidgets(7));
        expect(find.byTooltip('Dismiss notification'), findsNWidgets(7));
        for (final f in [
          find.byType(IconButton).first,
          find
              .ancestor(
                of: find.text('Open Config').first,
                matching: find.byWidgetPredicate((w) => w is TextButton),
              )
              .first,
        ]) {
          expect(t.getSize(f).height, greaterThanOrEqualTo(48), reason: '$f');
        }
        await t.tap(find.byType(IconButton).first);
        await t.tap(find.text('Open Config').first);
        expect((dismissed, acted), (1, 1));
      },
    );
  }

  testWidgets('unread items show a dot, read items do not; semantics say so', (
    t,
  ) async {
    final h = t.ensureSemantics();
    await pumpAt(
      t,
      ElioTheme.wrap(
        Scaffold(
          body: Column(
            children: [
              ElioNotificationItem(
                item: _n(AppNotificationType.robot),
                timeLabel: 'Just now',
              ),
              ElioNotificationItem(
                item: _n(AppNotificationType.info, read: true),
                timeLabel: 'Just now',
              ),
            ],
          ),
        ),
      ),
    );
    final labels = [
      for (final f in find.byType(ElioNotificationItem).evaluate())
        t.getSemantics(find.byWidget(f.widget)).label,
    ];
    expect(labels[0], contains('Unread.'));
    expect(labels[1], isNot(contains('Unread')));
    h.dispose();
  });

  testWidgets(
    'banner host shows the alert for a pushed notification and dismisses it',
    (t) async {
      await pumpAt(
        t,
        const AppNotificationBannerHost(
          child: Scaffold(body: SizedBox.expand()),
        ),
      );
      final container = ProviderScope.containerOf(
        t.element(find.byType(AppNotificationBannerHost)),
      );
      container
          .read(appNotificationProvider.notifier)
          .push(
            type: AppNotificationType.robot,
            title: 'ELIO connected',
            message: 'Robot connection is ready.',
          );
      await t.pumpAndSettle();
      expect(find.byType(ElioAlert), findsOneWidget);
      await t.tap(find.byType(IconButton));
      await t.pumpAndSettle();
      expect(find.byType(ElioAlert), findsNothing);
      // The timer from the banner host must not outlive the test.
      await t.pump(const Duration(seconds: 5));
    },
  );

  // PNG renders: H2_RENDER=1 flutter test test/widgets/app_notification_widgets_test.dart
  for (final b in Brightness.values) {
    testWidgets('render board ${b.name}', (t) async {
      await pumpAt(
        t,
        RepaintBoundary(
          key: const Key('shot'),
          child: ElioTheme.wrap(
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
                child: Column(
                  children: [
                    for (final type in AppNotificationType.values) ...[
                      ElioAlert(notification: _n(type), onDismiss: () {}),
                      const SizedBox(height: 10),
                    ],
                    ElioNotificationItem(
                      item: _n(AppNotificationType.robot),
                      timeLabel: 'Just now',
                      actionLabel: 'Open Config',
                      onAction: () {},
                    ),
                    const SizedBox(height: 8),
                    ElioNotificationItem(
                      item: _n(AppNotificationType.warning, read: true),
                      timeLabel: 'Yesterday',
                      actionLabel: 'Open Config',
                      onAction: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        size: const Size(390, 1250),
        brightness: b,
      );
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('shot')),
      );
      await t.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ImageByteFormat.png);
        File('docs/test-results/h2-notifications/board-${b.name}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }, skip: Platform.environment['H2_RENDER'] != '1');
  }
}
