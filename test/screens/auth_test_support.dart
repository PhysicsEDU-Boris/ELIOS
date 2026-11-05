import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:elio/providers/elio_theme_mode_provider.dart';
import 'package:elio/Screens/home_shell.dart';
import 'package:elio/Screens/login_screen.dart';

/// Records which page a replacement route would show, without building it:
/// HomeShell needs Firebase.initializeApp, which tests never call.
class RouteSpy extends NavigatorObserver {
  final pages = <Type>[];

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is PageRouteBuilder) {
      final page = newRoute.pageBuilder(
        navigatorKey!.currentContext!,
        kAlwaysCompleteAnimation,
        kAlwaysCompleteAnimation,
      );
      pages.add(page.runtimeType);
    }
  }

  GlobalKey<NavigatorState>? navigatorKey;
  bool get wentHome => pages.contains(HomeShell);
  bool get wentLogin => pages.contains(LoginScreen);
}

class _ChosenThemeMode extends ElioThemeModeNotifier {
  _ChosenThemeMode(this.mode);
  final ElioThemeMode mode;
  @override
  ElioThemeMode build() => mode;
}

/// Pumps [home] at [size], explicitly selecting the mode matching [brightness].
/// Platform-default behavior is tested separately in elio_theme_mode_test.dart.
Future<RouteSpy> pumpAt(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  bool disableAnimations = false,
  EdgeInsets viewInsets = EdgeInsets.zero,
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher
    ..platformBrightnessTestValue = brightness
    ..textScaleFactorTestValue = textScale
    ..accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
      disableAnimations: disableAnimations,
    );
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  final key = GlobalKey<NavigatorState>();
  final spy = RouteSpy()..navigatorKey = key;
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        ...overrides,
        elioThemeModeProvider.overrideWith(
          () => _ChosenThemeMode(
            brightness == Brightness.dark
                ? ElioThemeMode.dark
                : ElioThemeMode.light,
          ),
        ),
      ],
      child: MaterialApp(
        navigatorKey: key,
        navigatorObservers: [spy],
        builder: (context, child) => viewInsets == EdgeInsets.zero
            ? child!
            : MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(viewInsets: viewInsets, padding: EdgeInsets.zero),
                child: child!,
              ),
        home: home,
      ),
    ),
  );
  return spy;
}

class FailAuth extends MockFirebaseAuth {
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw FirebaseAuthException(code: 'wrong-password');
}

class SlowAuth extends MockFirebaseAuth {
  final gate = Completer<void>();
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await gate.future;
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}

/// The five Figma login states. Returns the auth to release for "loading".
Future<void> openLoginState(
  WidgetTester t,
  String state,
  FirebaseAuth auth,
) async {
  Future<void> tapText(String s) async {
    await t.ensureVisible(find.text(s));
    await t.tap(find.text(s));
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> submit() async {
    await t.enterText(find.byType(TextFormField).at(0), 'a@b.co');
    await t.enterText(find.byType(TextFormField).at(1), 'secret1');
    final b = find.widgetWithText(FilledButton, 'Sign In');
    await t.ensureVisible(b);
    await t.tap(b);
    await t.pump(const Duration(milliseconds: 100));
  }

  switch (state) {
    case 'signup':
      await tapText('Sign Up');
    case 'forgot':
      await tapText('Forgot password?');
    case 'error':
    case 'loading':
      await submit();
  }
}

const states = ['signin', 'signup', 'forgot', 'error', 'loading'];

/// Loads the bundled Google Sans Flex and Google Sans Code (and the SDK's Material Icons) so
/// layout and renders use the real glyph widths instead of the Ahem test font.
Future<void> loadElioFonts() async {
  Future<void> load(String family, String path) async {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  await load('Google Sans Flex', 'assets/fonts/GoogleSansFlex-Variable.ttf');
  await load('Google Sans Code', 'assets/fonts/GoogleSansCode-Variable.ttf');
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    await load(
      'MaterialIcons',
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
  }
}
