import 'package:elio/providers/elio_theme_mode_provider.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decision 0160: the saved mode is read before runApp and mirrored to Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('elio/appearance');
  final calls = <Object?>[];

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setDark') calls.add(call.arguments);
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('readSaved returns dark only for a saved dark choice', () async {
    expect(await ElioThemeModeNotifier.readSaved(), ElioThemeMode.light);
    SharedPreferences.setMockInitialValues({'elio_theme_mode_v1': 'dark'});
    expect(await ElioThemeModeNotifier.readSaved(), ElioThemeMode.dark);
    SharedPreferences.setMockInitialValues({'elio_theme_mode_v1': 'nonsense'});
    expect(await ElioThemeModeNotifier.readSaved(), ElioThemeMode.light);
  });

  test('setMode tells Android on Android only', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(elioThemeModeProvider.notifier).setMode(ElioThemeMode.dark);
    c.read(elioThemeModeProvider.notifier).setMode(ElioThemeMode.light);
    await Future<void>.delayed(Duration.zero);
    expect(calls, [true, false]);

    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    c.read(elioThemeModeProvider.notifier).setMode(ElioThemeMode.dark);
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
  });

  testWidgets('a preloaded dark mode paints the very first frame dark', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          elioThemeModeProvider.overrideWith(
            () => ElioThemeModeNotifier(ElioThemeMode.dark),
          ),
        ],
        child: MaterialApp(
          home: ElioTheme.wrap(
            Builder(
              builder: (c) => Scaffold(body: Text(Theme.of(c).brightness.name)),
            ),
          ),
        ),
      ),
    );
    expect(find.text('dark'), findsOneWidget);
  });
}
