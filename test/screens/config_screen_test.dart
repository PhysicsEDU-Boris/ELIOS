// C1 Config screen and Settings sheet (decision 0145, Figma page 337:2358).
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:elio/Screens/config/config_parts.dart';
import 'package:elio/Screens/config/config_settings_sheet.dart';
import 'package:elio/Screens/config_screen.dart';
import 'package:elio/models/config_model.dart';
import 'package:elio/providers/app_preferences_provider.dart';
import 'package:elio/providers/config_link_provider.dart';
import 'package:elio/providers/elio_theme_mode_provider.dart';
import 'package:elio/providers/esp_config_provider.dart';
import 'package:elio/providers/robot_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/theme/elio_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Mode extends ElioThemeModeNotifier {
  _Mode(this.mode);
  final ElioThemeMode mode;
  @override
  ElioThemeMode build() => mode;
}

class _Esp extends EspConfigNotifier {
  _Esp(this.initial);
  final EspConfig initial;
  @override
  Future<EspConfig> build() async => initial;
}

class _Link extends ConfigLinkNotifier {
  _Link(this.initial);
  final ConfigLink initial;
  final calls = <String>[];
  @override
  ConfigLink build() => initial;
  @override
  Future<bool> connect(String ip, int port, {required bool autoReconnect}) async {
    calls.add('$ip:$port auto=$autoReconnect');
    return false;
  }

  @override
  Future<void> disconnect() async => calls.add('disconnect');
  void fail(String reason) => state = ConfigLink(failure: reason);
}

const _timeoutReason =
    'No answer from 192.168.4.1:8765 after 10 s. Check that this phone is on the ELIOS Wi-Fi and the robot is on.';

late _Link _link;

Future<void> _pumpConfig(
  WidgetTester t, {
  required bool dark,
  String status = 'Disconnected',
  ConfigLink link = const ConfigLink(),
  EspConfig esp = const EspConfig(),
  GemmaProgress gemma = const GemmaProgress(GemmaStatus.idle),
  Size size = const Size(400, 2200),
}) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  GemmaQuizService.instance.progress.value = gemma;
  _link = _Link(link);
  await t.pumpWidget(ProviderScope(
    overrides: [
      elioThemeModeProvider.overrideWith(() => _Mode(dark ? ElioThemeMode.dark : ElioThemeMode.light)),
      robotStatusProvider.overrideWith((ref) => Stream.value(status)),
      configLinkProvider.overrideWith(() => _link),
      espConfigProvider.overrideWith(() => _Esp(esp)),
    ],
    child: const MaterialApp(home: ConfigScreen()),
  ));
  // Widget tests have no WebView: use the viewer's own fallback before it builds one.
  t.widget<Flutter3DViewer>(find.byType(Flutter3DViewer)).onError?.call('widget test');
  await t.pump();
  await t.pump();
}

bool _enabled(WidgetTester t, String label) {
  final button = find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
  return t.widget<ButtonStyleButton>(button.first).onPressed != null;
}

void _expectPalette(WidgetTester t, bool dark) {
  final scaffold = t.widget<Scaffold>(find.descendant(of: find.byType(ConfigScreen), matching: find.byType(Scaffold)));
  expect(scaffold.backgroundColor, (dark ? ElioTokens.dark : ElioTokens.light).background);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => GemmaQuizService.instance.progress.value = const GemmaProgress(GemmaStatus.idle));

  test('field validation', () {
    expect(validateIp('192.168.4.1'), isNull);
    expect(validateIp(' 10.0.0.255 '), isNull);
    for (final bad in ['', '192.168.4', '192.168.4.256', '1..2.3', 'a.b.c.d', '1.2.3.4.5']) {
      expect(validateIp(bad), isNotNull, reason: bad);
    }
    expect(validatePort('8765'), isNull);
    for (final bad in ['', '0', '65536', 'x']) {
      expect(validatePort(bad), isNotNull, reason: bad);
    }
  });

  test('GemmaStatus → ELIOS AI card state', () {
    expect({for (final s in GemmaStatus.values) s: aiCardState(s)}, {
      GemmaStatus.idle: AiCardState.off,
      GemmaStatus.installing: AiCardState.loading,
      GemmaStatus.loading: AiCardState.loading,
      GemmaStatus.ready: AiCardState.active,
      GemmaStatus.error: AiCardState.error,
      GemmaStatus.missing: AiCardState.error,
      GemmaStatus.killed: AiCardState.error,
      GemmaStatus.paused: AiCardState.paused,
    });
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    group('screen states ($mode)', () {
      testWidgets('not connected', (t) async {
        await _pumpConfig(t, dark: dark);
        _expectPalette(t, dark);
        expect(find.text('Not connected yet'), findsOneWidget);
        expect(find.text('Offline'), findsOneWidget);
        expect(find.text('—'), findsOneWidget, reason: 'no robot battery value: never a fake one');
        expect(find.text('Join the ELIOS Wi-Fi on this phone first, then tap Connect now.'), findsOneWidget);
        expect(_enabled(t, 'Connect now'), isTrue);
        expect(_enabled(t, 'Disconnect'), isFalse);
        expect(find.text('Activate ELIOS AI'), findsOneWidget);
        expect(find.text('Needs ELIOS AI active'), findsOneWidget);
      });

      testWidgets('connecting', (t) async {
        await _pumpConfig(t, dark: dark, status: 'Connecting...');
        _expectPalette(t, dark);
        expect(find.text('Looking for ELIO…'), findsOneWidget);
        expect(find.text('Connecting'), findsOneWidget);
        expect(_enabled(t, 'Connecting…'), isFalse);
        expect(_enabled(t, 'Cancel'), isTrue);
        final fields = t.widgetList<TextField>(find.byType(TextField));
        expect(fields.every((f) => f.enabled == false), isTrue, reason: 'fields locked while connecting');
        await t.tap(find.text('Cancel'));
        expect(_link.calls, ['disconnect']);
      });

      testWidgets('connected', (t) async {
        await _pumpConfig(t, dark: dark, status: 'Connected');
        _expectPalette(t, dark);
        expect(find.text('192.168.4.1 : 8765 · MaixCAM2'), findsOneWidget);
        expect(find.text('Online'), findsOneWidget);
        expect(_enabled(t, 'Connected'), isFalse);
        expect(_enabled(t, 'Disconnect'), isTrue);
        await t.tap(find.text('Disconnect'));
        expect(_link.calls, ['disconnect']);
      });

      testWidgets('connection failed', (t) async {
        await _pumpConfig(t, dark: dark, link: const ConfigLink(failure: _timeoutReason));
        _expectPalette(t, dark);
        expect(find.text('Last try failed'), findsOneWidget);
        expect(find.text("Couldn't reach ELIO"), findsOneWidget);
        expect(find.text(_timeoutReason), findsOneWidget, reason: 'the real reason and timeout');
        expect(_enabled(t, 'Try again'), isTrue);
        expect(_enabled(t, 'Disconnect'), isFalse);
        expect(find.byType(SnackBar), findsNothing, reason: 'the inline alert is on screen');
      });

      testWidgets('phone camera, AI paused', (t) async {
        await _pumpConfig(t,
            dark: dark,
            esp: const EspConfig(cameraSource: CameraSource.device),
            gemma: const GemmaProgress(GemmaStatus.paused));
        _expectPalette(t, dark);
        expect(find.text('Robot not used'), findsOneWidget);
        expect(find.text('Not used'), findsOneWidget);
        expect(find.text('Phone'), findsOneWidget);
        expect(find.text('Start scan'), findsOneWidget);
        expect(find.text('Connection'), findsNothing, reason: 'phone mode hides the connection card');
        expect(find.text('Paused, the phone is too hot'), findsOneWidget);
      });
    });

    group('ELIOS AI card ($mode)', () {
      late int activations;
      Future<void> pumpCard(WidgetTester t, GemmaProgress progress) async {
        activations = 0;
        GemmaQuizService.instance.progress.value = progress;
        await t.pumpWidget(MaterialApp(
          theme: dark ? ElioDarkTheme.data : ElioLightTheme.data,
          home: Scaffold(body: EliosAiCard(onActivate: () async => activations++)),
        ));
      }

      testWidgets('Off', (t) async {
        await pumpCard(t, const GemmaProgress(GemmaStatus.idle));
        expect(find.text('Turn it on to identify scans and write new quiz questions.'), findsOneWidget);
        await t.tap(find.text('Activate ELIOS AI'));
        expect(activations, 1);
      });

      testWidgets('Loading (copy with its real percent, then engine load)', (t) async {
        await pumpCard(t, const GemmaProgress(GemmaStatus.installing, installPercent: 62));
        expect(find.text('62%'), findsOneWidget);
        expect(t.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.62);
        GemmaQuizService.instance.progress.value = const GemmaProgress(GemmaStatus.loading);
        await t.pump();
        expect(find.text('Loading AI into memory…'), findsOneWidget);
        expect(find.textContaining('%'), findsNothing, reason: 'the engine reports no percent');
        expect(t.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, isNull);
      });

      testWidgets('Active', (t) async {
        await pumpCard(t, const GemmaProgress(GemmaStatus.ready));
        expect(find.text('Active · offline'), findsOneWidget);
        expect(find.text('Activate ELIOS AI'), findsNothing);
      });

      testWidgets('Error shows the real message and retries', (t) async {
        await pumpCard(t, const GemmaProgress(GemmaStatus.error, error: 'Memori (RAM) perangkat tidak cukup.'));
        expect(find.text('ELIOS AI could not start'), findsOneWidget);
        expect(find.textContaining('Memori (RAM) perangkat tidak cukup.'), findsOneWidget);
        await t.tap(find.text('Try again'));
        expect(activations, 1);
      });

      testWidgets('Paused shows the blocked reason', (t) async {
        await pumpCard(t, const GemmaProgress(GemmaStatus.paused));
        expect(find.text('Paused, the phone is too hot'), findsOneWidget);
        expect(find.text(GemmaQuizService.instance.blockedReason!), findsOneWidget);
      });
    });
  }

  testWidgets('logo orbits only when Active or Loading, and never with reduced motion', (t) async {
    Future<bool> moving(AiCardState state, {bool reduce = false}) async {
      await t.pumpWidget(MaterialApp(
        theme: ElioLightTheme.data,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Center(child: EliosAiLogo(state: state)),
        ),
      ));
      await t.pump(const Duration(milliseconds: 100));
      return t.hasRunningAnimations;
    }

    expect(await moving(AiCardState.active), isTrue);
    expect(await moving(AiCardState.loading), isTrue);
    for (final still in [AiCardState.off, AiCardState.error, AiCardState.paused]) {
      expect(await moving(still), isFalse, reason: '$still');
    }
    expect(await moving(AiCardState.active, reduce: true), isFalse);
    expect(EliosAiLogo.periodFor(AiCardState.active), const Duration(milliseconds: 3600));
    expect(EliosAiLogo.periodFor(AiCardState.loading), const Duration(milliseconds: 1200));
  });

  testWidgets('Connect validates first, then uses the auto-reconnect setting', (t) async {
    await _pumpConfig(t, dark: false, esp: const EspConfig(autoReconnect: false));
    await t.enterText(find.byType(TextField).first, '192.168.4');
    await t.tap(find.text('Connect now'));
    await t.pump();
    expect(find.text('Enter an IP like 192.168.4.1'), findsOneWidget);
    expect(_link.calls, isEmpty);
    await t.enterText(find.byType(TextField).first, '10.0.0.5');
    await t.tap(find.text('Connect now'));
    await t.pump();
    expect(_link.calls, ['10.0.0.5:8765 auto=false']);
  });

  testWidgets('failure snackbar only when the connection card is scrolled away', (t) async {
    await _pumpConfig(t, dark: false, size: const Size(400, 700));
    _link.fail('first');
    await t.pump();
    expect(find.byType(SnackBar), findsOneWidget, reason: 'card below the fold');
    expect(find.text('Retry'), findsOneWidget);
    ScaffoldMessenger.of(t.element(find.byType(ListView))).removeCurrentSnackBar();
    await t.pumpAndSettle();
    await t.ensureVisible(find.text("Couldn't reach ELIO"));
    await t.pumpAndSettle();
    _link.fail('second');
    await t.pump();
    expect(find.byType(SnackBar), findsNothing, reason: 'the inline alert says it already');
  });

  testWidgets('camera tiles save the source; phone mode shows Start scan', (t) async {
    await _pumpConfig(t, dark: false);
    await t.tap(find.text('Phone camera'));
    await t.pump();
    final container = ProviderScope.containerOf(t.element(find.byType(ConfigScreen)));
    expect(container.read(espConfigProvider).valueOrNull?.cameraSource, CameraSource.device);
    expect(find.text('Start scan'), findsOneWidget);
  });

  testWidgets('ELIOS AI quiz tile needs a ready model; saved choice survives a failure', (t) async {
    await _pumpConfig(t, dark: false, gemma: const GemmaProgress(GemmaStatus.ready));
    expect(find.text('New questions each scan, 20 to 40 s'), findsOneWidget);
    await t.tap(find.text('ELIOS AI').last);
    await t.pump();
    final container = ProviderScope.containerOf(t.element(find.byType(ConfigScreen)));
    expect(container.read(appPreferencesProvider).questionSource, QuestionSource.gemma);

    GemmaQuizService.instance.progress.value = const GemmaProgress(GemmaStatus.error, error: 'x');
    await t.pump();
    expect(find.text('Needs ELIOS AI active'), findsOneWidget);
    final bank = t.getSemantics(find.text('Question bank'));
    expect(bank.flagsCollection.isSelected, Tristate.isTrue, reason: 'quizzes use the bank meanwhile');
    expect(container.read(appPreferencesProvider).questionSource, QuestionSource.gemma);
  });

  testWidgets('settings sheet saves every value and they load after a restart', (t) async {
    t.view.physicalSize = const Size(800, 4400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: Center(child: ConfigSettingsButton()))),
    ));
    await t.tap(find.byTooltip('Settings'));
    await t.pumpAndSettle();
    expect(find.text('Tampilan'), findsNothing);
    Future<void> toggle(String title) async {
      final row = find.ancestor(of: find.text(title), matching: find.byType(MergeSemantics));
      await t.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await t.pumpAndSettle();
    }

    await toggle('Auto-reconnect'); // on → off
    await t.tap(find.text('720p'));
    await toggle('Show FPS overlay');
    await toggle('Sound effects'); // on → off
    await t.tap(find.text('Hard'));
    await t.tap(find.text('90s'));
    await toggle('Allow skipping');
    await t.pumpAndSettle();
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(find.text('Connection, video, sound and quiz'), findsNothing);

    final prefs = jsonDecode((await SharedPreferences.getInstance()).getString('app_preferences_v1')!);
    expect(prefs, containsPair('quizDifficulty', 'Hard'));
    expect(prefs, containsPair('quizTimer', '90s'));
    expect(prefs, containsPair('skipAllowed', true));
    expect(prefs, containsPair('soundEffects', false));
    final esp = jsonDecode((await const FlutterSecureStorage().read(key: 'elio_esp_config'))!);
    expect(esp, containsPair('resolutionPreset', '720p'));
    expect(esp, containsPair('showFpsOverlay', true));
    expect(esp, containsPair('autoReconnect', false));

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    final config = await restarted.read(espConfigProvider.future);
    expect(config.resolutionPreset, '720p');
    expect(config.autoReconnect, isFalse);
    restarted.read(appPreferencesProvider);
    await t.pump();
    expect(restarted.read(appPreferencesProvider).quizTimer, '90s');
  });
}
