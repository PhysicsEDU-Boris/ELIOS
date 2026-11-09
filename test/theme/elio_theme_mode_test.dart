import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:elio/Screens/config/config_settings_sheet.dart';
import 'package:elio/Screens/login_screen.dart';
import 'package:elio/Screens/splash_screen.dart';
import 'package:elio/Screens/scan_history_screen.dart';
import 'package:elio/services/scan_record_store.dart';
import 'package:elio/main.dart';
import 'package:elio/providers/elio_theme_mode_provider.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/theme/elio_tokens.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/auth_test_support.dart' show loadElioFonts;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadElioFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('default is light under a dark platform, including first frame', (
    t,
  ) async {
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    late ThemeData theme;
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ElioTheme.wrap(
            Builder(
              builder: (context) {
                theme = Theme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(theme.brightness, Brightness.light);
    await t.pumpAndSettle();
    expect(theme.colorScheme.surface, ElioTokens.light.background);
  });

  testWidgets(
    'dark persists after disposing and rebuilding the provider scope',
    (t) async {
      Future<void> mount(Key key) => t.pumpWidget(
        ProviderScope(
          key: key,
          child: MaterialApp(
            home: ElioTheme.wrap(const Scaffold(body: Text('mode'))),
          ),
        ),
      );
      await mount(const ValueKey(1));
      final context = t.element(find.text('mode'));
      ProviderScope.containerOf(
        context,
      ).read(elioThemeModeProvider.notifier).setMode(ElioThemeMode.dark);
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.text('mode'))).brightness,
        Brightness.dark,
      );
      await t.pumpWidget(const SizedBox());
      await mount(const ValueKey(2));
      expect(
        Theme.of(t.element(find.text('mode'))).brightness,
        Brightness.light,
      );
      await t.pumpAndSettle();
      expect(
        Theme.of(t.element(find.text('mode'))).brightness,
        Brightness.dark,
      );
    },
  );

  testWidgets('a user choice while loading wins over the saved value', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({'elio_theme_mode_v1': 'dark'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(elioThemeModeProvider), ElioThemeMode.light);
    container.read(elioThemeModeProvider.notifier).setMode(ElioThemeMode.light);
    await t.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    expect(container.read(elioThemeModeProvider), ElioThemeMode.light);
    expect(
      (await SharedPreferences.getInstance()).getString('elio_theme_mode_v1'),
      'light',
    );
  });

  testWidgets('unknown stored values fall back to light', (t) async {
    SharedPreferences.setMockInitialValues({'elio_theme_mode_v1': 'system'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(elioThemeModeProvider), ElioThemeMode.light);
    await t.runAsync(() => SharedPreferences.getInstance());
    await t.pump();
    expect(container.read(elioThemeModeProvider), ElioThemeMode.light);
  });

  for (final splash in [true, false]) {
    testWidgets(
      '${splash ? 'splash' : 'login'} starts light and follows the provider',
      (t) async {
        t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final auth = MockFirebaseAuth();
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: splash ? SplashScreen(auth: auth) : LoginScreen(auth: auth),
            ),
          ),
        );
        ThemeData theme() => Theme.of(t.element(find.byType(Scaffold).first));
        expect(theme().brightness, Brightness.light);
        container
            .read(elioThemeModeProvider.notifier)
            .setMode(ElioThemeMode.dark);
        await t.pump();
        expect(theme().brightness, Brightness.dark);
        container
            .read(elioThemeModeProvider.notifier)
            .setMode(ElioThemeMode.light);
        await t.pump();
        expect(theme().brightness, Brightness.light);
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('the robot settings sheet has no theme row: theme lives in Profile (0196)', (
    t,
  ) async {
    await t.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: Center(child: ConfigSettingsButton()))),
      ),
    );
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(find.text('Connection and video'), findsOneWidget);
    expect(find.text('Mode tampilan'), findsNothing);
    expect(find.text('Tampilan'), findsNothing);
  });

  testWidgets(
    'legacy Scan History light render is unchanged by scoped mode (fallback)',
    (t) async {
      await t.pumpWidget(ElioApp(auth: MockFirebaseAuth()));
      final app = t.widget<MaterialApp>(find.byType(MaterialApp));
      final oldTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6E56)),
        useMaterial3: true,
      );
      expect(app.theme, oldTheme);
      expect(app.darkTheme, isNull);
      // ElioLightTheme changes inherited styles on legacy screens; keep the root theme.
      expect(ElioLightTheme.data.textTheme, isNot(oldTheme.textTheme));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final dir = Directory.systemTemp.createTempSync('t1-legacy-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = ScanRecordStore(
        customFile: File('${dir.path}/records.json'),
      );
      await t.runAsync(store.load);
      Future<Uint8List> render(ThemeData theme) async {
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: theme,
              home: RepaintBoundary(
                key: const Key('legacy'),
                child: ScanHistoryScreen(store: store),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('legacy')),
        );
        return (await t.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          image.dispose();
          return bytes;
        }))!;
      }

      final before = await render(oldTheme);
      final after = await render(app.theme!);
      expect(after, orderedEquals(before));
      final candidate = await render(ElioLightTheme.data);
      expect(
        candidate,
        isNot(orderedEquals(before)),
        reason: 'Global theme adoption would change Scan History in light mode',
      );
      await t.pumpWidget(const SizedBox());
    },
  );
}
