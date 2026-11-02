// Decision 0146: the sidebar Dark mode switch is in every build, and the
// Android launcher icon follows the saved theme.
import 'package:elio/providers/elio_theme_mode_provider.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/elio_sidebar.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Object?> calls;
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(appIconChannel, (call) async {
      calls.add('${call.method} ${call.arguments}');
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(appIconChannel, null));

  Future<ProviderContainer> loaded(Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(elioThemeModeProvider);
    await pumpEventQueue();
    return c;
  }

  test('switching the theme switches the launcher icon', () async {
    final c = await loaded({});
    calls.clear();
    c.read(elioThemeModeProvider.notifier).setMode(ElioThemeMode.dark);
    c.read(elioThemeModeProvider.notifier).setMode(ElioThemeMode.light);
    await pumpEventQueue();
    expect(calls, ['setDark true', 'setDark false']);
  });

  test('a saved dark theme puts the dark icon back at launch', () async {
    await loaded({'flutter.elio_theme_mode_v1': 'dark'});
    expect(calls, ['setDark true']);
  });

  test('no platform side (iOS, tests without a handler) never blocks the theme', () async {
    messenger.setMockMethodCallHandler(appIconChannel, null);
    final c = await loaded({});
    c.read(elioThemeModeProvider.notifier).setMode(ElioThemeMode.dark);
    await pumpEventQueue();
    expect(c.read(elioThemeModeProvider), ElioThemeMode.dark);
  });

  testWidgets('the sidebar shows the Dark mode switch without any build flag', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: ElioTheme.wrap(Scaffold(
          body: ElioSidebar(
            user: MockUser(isAnonymous: true, photoURL: ''),
            currentIndex: 0,
            onSelect: (_) {},
            onSignOut: () {},
            onClose: () {},
          ),
        )),
      ),
    ));
    await t.pump();
    expect(find.text('Dark mode'), findsOneWidget);
    await t.tap(find.text('Dark mode'));
    await t.pump();
    expect(calls, contains('setDark true'));
  });
}
