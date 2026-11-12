// ELIOS setup (decisions 0145, 0205; Figma 337:2358, 629:91327).
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
import 'package:elio/services/ai_quiz_service.dart';
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
  AiStatus ai = AiStatus.idle,
  Size size = const Size(400, 2200),
}) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  AiQuizService.instance.status.value = ai;
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

void _expectSteps(SetupStep a, SetupStep b, SetupStep c) {
  for (final (i, s) in [a, b, c].indexed) {
    expect(find.byKey(ValueKey('setup-step-${i + 1}-${s.name}')), findsOneWidget, reason: 'step ${i + 1}');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => AiQuizService.instance.status.value = AiStatus.idle);

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

  test('cable stepper states (0205)', () {
    const d = SetupStep.done, c = SetupStep.current, t = SetupStep.todo, x = SetupStep.problem;
    expect(setupSteps(LinkView.notConnected, found: false), [c, t, t]);
    expect(setupSteps(LinkView.notConnected, found: true), [d, d, c], reason: 'found: connect is next');
    expect(setupSteps(LinkView.connecting, found: false), [d, d, c]);
    expect(setupSteps(LinkView.connected, found: true), [d, d, c]);
    expect(setupSteps(LinkView.failed, found: false), [c, t, x]);
    expect(setupSteps(LinkView.failed, found: true), [d, d, x]);
  });

  test('AiStatus → ELIOS AI card state', () {
    expect({for (final s in AiStatus.values) s: aiCardState(s)}, {
      AiStatus.idle: AiCardState.off,
      AiStatus.ready: AiCardState.active,
      AiStatus.offline: AiCardState.error,
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
        expect(find.text('Battery'), findsNothing, reason: 'the robot reports no battery: never a fake one');
        _expectSteps(SetupStep.current, SetupStep.todo, SetupStep.todo);
        expect(find.text('Join the ELIOS Wi-Fi'), findsOneWidget);
        expect(find.text('Search for ELIOS'), findsOneWidget);
        expect(find.text('Connect'), findsOneWidget);
        expect(find.text('Save as default address'), findsOneWidget);
        expect(_enabled(t, 'Connect now'), isTrue);
        expect(find.text('Disconnect'), findsNothing, reason: 'nothing to disconnect');
        expect(find.text('Gemini · needs internet'), findsOneWidget);
      });

      testWidgets('connecting', (t) async {
        await _pumpConfig(t, dark: dark, status: 'Connecting...');
        _expectPalette(t, dark);
        expect(find.text('Looking for ELIOS…'), findsOneWidget);
        expect(find.text('Connecting'), findsOneWidget);
        _expectSteps(SetupStep.done, SetupStep.done, SetupStep.current);
        expect(_enabled(t, 'Search for ELIOS'), isFalse, reason: 'no search during an attempt');
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
        expect(find.text('Online'), findsNWidgets(2), reason: 'Status bubble and the step 3 pill');
        _expectSteps(SetupStep.done, SetupStep.done, SetupStep.current);
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Found at 192.168.4.1'), findsOneWidget);
        expect(find.text('Search again'), findsOneWidget);
        expect(find.text('Saved as default address'), findsOneWidget);
        expect(_enabled(t, 'Open control'), isTrue, reason: 'ELIOS 3: reopen Control while connected');
        expect(_enabled(t, 'Disconnect'), isTrue);
        await t.tap(find.text('Disconnect'));
        expect(_link.calls, ['disconnect']);
      });

      testWidgets('connection failed', (t) async {
        await _pumpConfig(t, dark: dark, link: const ConfigLink(failure: _timeoutReason));
        _expectPalette(t, dark);
        expect(find.text('Last try failed'), findsOneWidget);
        expect(find.text("Couldn't reach ELIOS"), findsOneWidget);
        _expectSteps(SetupStep.current, SetupStep.todo, SetupStep.problem);
        expect(find.text(_timeoutReason), findsOneWidget, reason: 'the real reason and timeout');
        expect(_enabled(t, 'Try again'), isTrue);
        expect(find.text('Disconnect'), findsNothing, reason: 'nothing to disconnect');
        expect(find.byType(SnackBar), findsNothing, reason: 'the inline alert is on screen');
      });

      testWidgets('a saved phone camera is ignored: robots use MaixCAM2 (ELIOS 3)', (t) async {
        await _pumpConfig(t,
            dark: dark,
            esp: const EspConfig(cameraSource: CameraSource.device),
            ai: AiStatus.offline);
        _expectPalette(t, dark);
        expect(find.text('MaixCAM2'), findsOneWidget);
        expect(find.text('Phone camera'), findsNothing);
        expect(find.text('Start scan'), findsNothing);
        expect(find.text('Robot not used'), findsNothing);
        expect(find.text('Connection'), findsOneWidget);
        expect(find.text('ELIOS AI is not reachable'), findsOneWidget);
      });
    });

    group('ELIOS AI card ($mode)', () {
      Future<void> pumpCard(WidgetTester t, AiStatus status) async {
        AiQuizService.instance.status.value = status;
        await t.pumpWidget(MaterialApp(
          theme: dark ? ElioDarkTheme.data : ElioLightTheme.data,
          home: const Scaffold(body: EliosAiCard()),
        ));
      }

      testWidgets('Off: nothing to activate', (t) async {
        await pumpCard(t, AiStatus.idle);
        expect(find.text('Gemini · needs internet'), findsOneWidget);
        expect(find.textContaining('Identifies scans'), findsOneWidget);
        expect(find.byType(ConfigButton), findsNothing);
      });

      testWidgets('Active names the model that answered', (t) async {
        AiQuizService.instance.lastModel = 'gemini-3.5-flash-lite';
        addTearDown(() => AiQuizService.instance.lastModel = null);
        await pumpCard(t, AiStatus.ready);
        expect(find.text('Active · gemini-3.5-flash-lite'), findsOneWidget);
      });

      testWidgets('Offline says the quiz uses the bank', (t) async {
        await pumpCard(t, AiStatus.offline);
        expect(find.text('ELIOS AI is not reachable'), findsOneWidget);
        expect(find.textContaining('uses the question bank'), findsOneWidget);
      });
    });
  }

  testWidgets('logo orbits only when Active, and never with reduced motion', (t) async {
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
    for (final still in [AiCardState.off, AiCardState.error]) {
      expect(await moving(still), isFalse, reason: '$still');
    }
    expect(await moving(AiCardState.active, reduce: true), isFalse);
    expect(EliosAiLogo.periodFor(AiCardState.active), const Duration(milliseconds: 3600));
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

  testWidgets('Show robot Wi-Fi QR opens the QR sheet', (t) async {
    await _pumpConfig(t, dark: true);
    await t.tap(find.text('Show robot Wi-Fi QR'));
    await t.pumpAndSettle();
    expect(find.text('Robot Wi-Fi QR'), findsOneWidget);
  });

  testWidgets('failure snackbar only when the connection card is scrolled away', (t) async {
    await _pumpConfig(t, dark: false, size: const Size(400, 480));
    _link.fail('first');
    await t.pump();
    expect(find.byType(SnackBar), findsOneWidget, reason: 'card below the fold');
    expect(find.text('Retry'), findsOneWidget);
    ScaffoldMessenger.of(t.element(find.byType(ListView))).removeCurrentSnackBar();
    await t.pumpAndSettle();
    await t.ensureVisible(find.text("Couldn't reach ELIOS"));
    await t.pumpAndSettle();
    _link.fail('second');
    await t.pump();
    expect(find.byType(SnackBar), findsNothing, reason: 'the inline alert says it already');
  });

  testWidgets('robot quiz card: own source and on/off; phone source untouched (0198)', (t) async {
    await _pumpConfig(t, dark: false, ai: AiStatus.offline);
    await t.pump(const Duration(milliseconds: 300)); // section entrance (0216)
    await t.pump(const Duration(milliseconds: 600));
    final container = ProviderScope.containerOf(t.element(find.byType(ConfigScreen)));
    final phone = container.read(appPreferencesProvider).questionSource;
    await t.tap(find.text('Question bank'));
    await t.pump();
    expect(container.read(appPreferencesProvider).robotQuestionSource, QuestionSource.bank);
    await t.tap(find.descendant(of: find.byType(ConfigSegmented), matching: find.text('ELIOS AI')));
    await t.pump();
    expect(container.read(appPreferencesProvider).robotQuestionSource, QuestionSource.ai);
    expect(container.read(appPreferencesProvider).questionSource, phone);
    expect(t.getSemantics(find.bySemanticsLabel('Quiz questions Question bank')).flagsCollection.isSelected, Tristate.isFalse);

    await t.tap(find.text('Quiz after each scan'));
    await t.pump();
    expect(container.read(appPreferencesProvider).robotQuizEnabled, isFalse);
    expect(find.text('Saved to History. The quiz is off for robot scans.'), findsOneWidget);
    // Quiz off: the source switch collapses (decision 0216), the choice is kept.
    expect(find.descendant(of: find.byType(ConfigScreen), matching: find.byType(ConfigSegmented).last), findsOneWidget, reason: 'resolution switch stays');
    expect(find.text('Question bank'), findsNothing);
    expect(container.read(appPreferencesProvider).robotQuestionSource, QuestionSource.ai);
    await t.tap(find.text('Quiz after each scan'));
    await t.pump();
    expect(find.text('Question bank'), findsOneWidget, reason: 'back with the quiz on');
  });

  testWidgets('ELIOS setup saves connection and video inline; no settings sheet (0198)', (t) async {
    await _pumpConfig(t, dark: false, size: const Size(400, 3200));
    expect(find.byTooltip('Settings'), findsNothing);
    for (final moved in ['Sound effects', 'Hard', '90s', 'Allow skipping']) {
      expect(find.text(moved), findsNothing, reason: '$moved is on Profile');
    }
    expect(find.text('Camera: MaixCAM2'), findsOneWidget);
    await t.tap(find.text('Auto-reconnect')); // on → off
    await t.tap(find.text('720p'));
    await t.tap(find.text('Show FPS overlay'));
    await t.pumpAndSettle();

    final esp = jsonDecode((await const FlutterSecureStorage().read(key: 'elio_esp_config'))!);
    expect(esp, containsPair('resolutionPreset', '720p'));
    expect(esp, containsPair('showFpsOverlay', true));
    expect(esp, containsPair('autoReconnect', false));

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    final config = await restarted.read(espConfigProvider.future);
    expect(config.resolutionPreset, '720p');
    expect(config.autoReconnect, isFalse);
  });
}
