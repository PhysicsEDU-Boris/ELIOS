// Joyful profile header and the settings entry animation (decision 0221,
// Figma 629:100965 / 629:101230, dark 629:101350). PROFILE_RENDER=<dir> also
// writes PNGs with the real fonts.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:elio/Screens/profile/profile_screen.dart';
import 'package:elio/l10n/l10n.dart';
import 'package:elio/providers/app_locale_provider.dart';
import 'package:elio/providers/elio_theme_mode_provider.dart';
import 'package:elio/services/elio_feedback.dart';
import 'package:elio/theme/elio_motion.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_support.dart' show loadElioFonts;

final _out = Platform.environment['PROFILE_RENDER'];
final _boundary = GlobalKey();

Widget _app(User? user, {bool reduceMotion = false}) => ProviderScope(
  child: Consumer(
    builder: (context, ref, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: ref.watch(appLocaleProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        updateCurrentL10n(context);
        // Read so the saved theme loads, as ElioApp does.
        ref.watch(elioThemeModeProvider);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            padding: const EdgeInsets.only(top: 40), // status bar
          ),
          child: RepaintBoundary(key: _boundary, child: child!),
        );
      },
      home: Scaffold(body: ProfileScreen(user: user, onSignOut: () {})),
    ),
  ),
);

final _signedIn = MockUser(
  isAnonymous: false,
  uid: 'u1',
  displayName: 'Boris Agung',
  email: 'zazzikun@gmail.com',
);

Future<void> _setUp(
  WidgetTester t, {
  Size size = const Size(390, 844),
  bool dark = false,
  String lang = 'en',
}) async {
  SharedPreferences.setMockInitialValues({
    'elio_theme_mode_v1': dark ? 'dark' : 'light',
    'elio_locale_v1': lang,
  });
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('elio/app_icon'),
    (_) async => null,
  );
}

double _avatarOpacity(WidgetTester t) => t
    .widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const Key('profile-avatar')),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

void main() {
  final sounds = <ElioSfx>[];
  setUpAll(loadElioFonts);
  setUp(() {
    sounds.clear();
    var now = DateTime(2026);
    ElioSound.instance
      ..sink = ((s, _) => sounds.add(s))
      ..isSilent = (() async => false)
      ..clock = () => now = now.add(const Duration(seconds: 1));
  });
  tearDown(() => debugSetL10n(const Locale('en')));

  for (final dark in [false, true]) {
    for (final lang in ['en', 'id']) {
      for (final (shape, size) in [
        ('portrait', const Size(390, 844)),
        ('landscape', const Size(844, 390)),
      ]) {
        for (final (who, user) in <(String, User?)>[
          ('signed in', _signedIn),
          ('guest', null),
        ]) {
          testWidgets(
            'header fits: ${dark ? 'dark' : 'light'} $lang $shape $who',
            (t) async {
              await _setUp(t, size: size, dark: dark, lang: lang);
              await t.pumpWidget(_app(user));
              await t.pumpAndSettle();
              expect(t.takeException(), isNull);
              // Leaf avatar: 120 dp picture + 5 dp ring outside.
              expect(
                t.getSize(find.byKey(const Key('profile-avatar'))),
                const Size(130, 130),
              );
              // The decoration is invisible to screen readers and to taps.
              final decor = find.byKey(const Key('profile-header-decor'));
              expect(
                find.descendant(
                  of: decor,
                  matching: find.byType(ExcludeSemantics),
                ),
                findsWidgets,
              );
              // The curve reaches the top edge, behind the status bar.
              expect(t.getTopLeft(decor).dy, 40);
              expect(
                find.text(
                  who == 'guest'
                      ? (lang == 'en' ? 'Guest' : 'Tamu')
                      : 'Boris Agung',
                ),
                findsOneWidget,
              );
              if (_out != null) {
                final image = await t.runAsync(
                  () => (_boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2),
                );
                final bytes = await t.runAsync(
                  () => image!.toByteData(format: ui.ImageByteFormat.png),
                );
                final name =
                    '${dark ? 'dark' : 'light'}-$lang-$shape-${who.replaceAll(' ', '-')}.png';
                File('$_out/$name')
                  ..createSync(recursive: true)
                  ..writeAsBytesSync(bytes!.buffer.asUint8List());
              }
            },
          );
        }
      }
    }
  }

  testWidgets('entry: the avatar pops in, then the sections rise in', (t) async {
    await _setUp(t);
    await t.pumpWidget(_app(_signedIn));
    await t.pump(); // saved theme and language load
    await t.pump();
    expect(_avatarOpacity(t), lessThan(1), reason: 'starts hidden');
    await t.pump(const Duration(milliseconds: 120));
    final title = find.text('Appearance');
    final sectionFade = t.widget<Opacity>(
      find.ancestor(of: title, matching: find.byType(Opacity)).first,
    );
    expect(
      sectionFade.opacity,
      lessThan(_avatarOpacity(t)),
      reason: 'sections come after the header',
    );
    await t.pumpAndSettle();
    expect(_avatarOpacity(t), 1);
  });

  testWidgets('reduce motion: a short fade, no pop', (t) async {
    await _setUp(t);
    await t.pumpWidget(_app(_signedIn, reduceMotion: true));
    await t.pump();
    await t.pump();
    await t.pump(ElioMotion.fast + const Duration(milliseconds: 20));
    expect(_avatarOpacity(t), 1);
    expect(
      find.ancestor(
        of: find.byKey(const Key('profile-avatar')),
        matching: find.byWidgetPredicate(
          (w) => w is Transform && w.transform.getMaxScaleOnAxis() != 1,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('scrolled settings never show under the status bar', (t) async {
    await _setUp(t);
    await t.pumpWidget(_app(_signedIn));
    await t.pumpAndSettle();
    double scrim() => t
        .widget<AnimatedOpacity>(find.byKey(const Key('profile-status-scrim')))
        .opacity;
    expect(scrim(), 0, reason: 'at rest the green curve shows there');
    await t.drag(find.byType(ListView), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(scrim(), 1);
    await t.drag(find.byType(ListView), const Offset(0, 600));
    await t.pumpAndSettle();
    expect(scrim(), 0);
  });

  testWidgets('the avatar still opens the account menu with its sound', (
    t,
  ) async {
    await _setUp(t);
    await t.pumpWidget(_app(_signedIn));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('profile-avatar')));
    await t.pumpAndSettle();
    expect(sounds, contains(ElioSfx.pop));
    expect(find.text('Switch account'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });
}
