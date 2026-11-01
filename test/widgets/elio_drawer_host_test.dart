import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/auth/auth_widgets.dart' show authPalette;
import 'package:elio/widgets/elio_bottom_nav.dart';
import 'package:elio/widgets/elio_drawer_host.dart';
import 'package:elio/widgets/elio_sidebar.dart';
import 'package:elio/widgets/elio_top_bar.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import '../screens/auth_test_support.dart';

/// N4 top bar + phone drawer (Figma 279:2399), composed as HomeShell does:
/// HomeShell needs Firebase, which tests never initialise.
class _Rig {
  final host = GlobalKey<ElioDrawerHostState>();
  final avatar = FocusNode();
  final selected = <int>[];
}

Future<_Rig> _pump(
  WidgetTester t, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
}) async {
  final r = _Rig();
  addTearDown(r.avatar.dispose);
  await pumpAt(
    t,
    ElioDrawerHost(
      key: r.host,
      onClosed: r.avatar.requestFocus,
      drawer: ElioTheme.wrap(
        Builder(
          builder: (context) => Material(
            color: authPalette(context).surface,
            child: ElioSidebar(
              user: MockUser(isAnonymous: true, photoURL: ''),
              currentIndex: 0,
              phone: true,
              showThemeToggle: false,
              onSelect: (i) {
                r.selected.add(i);
                r.host.currentState!.close();
              },
              onSignOut: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
      child: Scaffold(
        body: Column(
          children: [
            ElioTheme.wrap(
              ElioTopBar(
                title: 'Home',
                avatarFocusNode: r.avatar,
                onOpenProfile: () => r.host.currentState!.open(),
              ),
            ),
            Expanded(
              child: ListView(
                children: [for (var i = 0; i < 40; i++) Text('row $i')],
              ),
            ),
          ],
        ),
      ),
    ),
    size: size,
    brightness: brightness,
    textScale: textScale,
    disableAnimations: disableAnimations,
  );
  await t.pump();
  return r;
}

Finder get _avatar => find.byType(InkResponse).first;
final _open = find.text('NAVIGATE');

Future<void> _openDrawer(WidgetTester t) async {
  await t.tap(_avatar);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadElioFonts);

  testWidgets('avatar tap opens the phone drawer: header, nav, sign out', (
    t,
  ) async {
    await _pump(t);
    expect(_open, findsNothing);
    final bar = t.getSize(find.byType(ElioTopBar));
    expect(bar.height, 56);
    expect(t.getSize(_avatar).shortestSide, 48);

    await _openDrawer(t);
    expect(_open, findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Guest User'), findsOneWidget);
    expect(find.text('ELIOS'), findsNothing); // no brand mark on phones
    expect(find.byTooltip('Close sidebar'), findsNothing); // no collapse button
    expect(t.getSize(find.byType(ElioSidebar)).width, 304);
  });

  testWidgets('scrim tap closes and focus returns to the avatar', (t) async {
    final r = await _pump(t);
    await _openDrawer(t);
    expect(r.avatar.hasFocus, isFalse); // focus moved into the drawer

    await t.tapAt(const Offset(370, 400));
    await t.pumpAndSettle();
    expect(_open, findsNothing);
    expect(r.avatar.hasPrimaryFocus, isTrue);
  });

  testWidgets('360 dp: drawer is 80% wide (288)', (t) async {
    await _pump(t, size: const Size(360, 740));
    await _openDrawer(t);
    expect(t.getSize(find.byType(ElioSidebar)).width, 288);
  });

  testWidgets('text scale 1.3 at 360 dp: no overflow, still opens and closes', (
    t,
  ) async {
    final r = await _pump(t, size: const Size(360, 740), textScale: 1.3);
    await _openDrawer(t);
    expect(_open, findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tapAt(const Offset(350, 400));
    await t.pumpAndSettle();
    expect(_open, findsNothing);
    expect(r.avatar.hasPrimaryFocus, isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('reduced motion: state switches at once', (t) async {
    await _pump(t, disableAnimations: true);
    await t.tap(_avatar);
    await t.pump();
    expect(t.getTopLeft(find.byType(ElioSidebar)).dx, 0);
    await t.tapAt(const Offset(370, 400));
    await t.pump();
    expect(_open, findsNothing);
  });

  testWidgets('open 250 ms, close 200 ms', (t) async {
    final r = await _pump(t);
    await t.tap(_avatar);
    await t.pump();
    await t.pump(const Duration(milliseconds: 240));
    expect(t.getTopLeft(find.byType(ElioSidebar)).dx, lessThan(0));
    await t.pump(const Duration(milliseconds: 15));
    expect(t.getTopLeft(find.byType(ElioSidebar)).dx, 0);

    r.host.currentState!.close();
    await t.pump();
    await t.pump(const Duration(milliseconds: 190));
    expect(_open, findsOneWidget);
    await t.pump(const Duration(milliseconds: 15));
    expect(_open, findsNothing);
  });

  testWidgets('drag: past 40% closes, short drag springs back, fling closes', (
    t,
  ) async {
    await _pump(t);
    await _openDrawer(t);

    await t.drag(find.byType(ElioSidebar), const Offset(-60, 0));
    await t.pumpAndSettle();
    expect(_open, findsOneWidget);

    await t.drag(find.byType(ElioSidebar), const Offset(-140, 0));
    await t.pumpAndSettle();
    expect(_open, findsNothing);

    await _openDrawer(t);
    await t.fling(find.byType(ElioSidebar), const Offset(-100, 0), 1500);
    await t.pumpAndSettle();
    expect(_open, findsNothing);
  });

  testWidgets('drag is 1:1 with the finger', (t) async {
    await _pump(t);
    await _openDrawer(t);
    final g = await t.startGesture(const Offset(200, 400));
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-50, 0));
    await t.pump();
    expect(t.getTopLeft(find.byType(ElioSidebar)).dx, closeTo(-70, 1));
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('vertical drag scrolls the menu and never closes it', (t) async {
    await _pump(t, size: const Size(390, 300));
    await _openDrawer(t);
    await t.drag(find.text('NAVIGATE'), const Offset(-6, -120));
    await t.pumpAndSettle();
    expect(find.text('Sign Out'), findsOneWidget);
    expect(t.getTopLeft(find.byType(ElioSidebar)).dx, 0);
  });

  testWidgets('Escape closes', (t) async {
    final r = await _pump(t);
    await _openDrawer(t);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(_open, findsNothing);
    expect(r.avatar.hasPrimaryFocus, isTrue);
  });

  testWidgets('Back closes the drawer', (t) async {
    await _pump(t);
    await _openDrawer(t);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_open, findsNothing);
  });

  testWidgets('choosing a destination closes it', (t) async {
    final r = await _pump(t);
    await _openDrawer(t);
    await t.tap(find.text('Learn'));
    await t.pumpAndSettle();
    expect(r.selected, [1]);
    expect(_open, findsNothing);
  });

  testWidgets('no edge swipe opens it; the title is not a button', (t) async {
    await _pump(t);
    await t.dragFrom(const Offset(2, 400), const Offset(200, 0));
    await t.pumpAndSettle();
    expect(_open, findsNothing);
    await t.tap(find.text('Home'));
    await t.pumpAndSettle();
    expect(_open, findsNothing);
  });

  testWidgets('avatar semantics: "Open profile menu", button', (t) async {
    final h = t.ensureSemantics();
    await _pump(t);
    expect(find.bySemanticsLabel('Open profile menu'), findsOneWidget);
    final n = t.getSemantics(find.bySemanticsLabel('Open profile menu'));
    expect(n.flagsCollection.isButton, isTrue);
    h.dispose();
  });

  testWidgets('bottom nav has no Profile item', (t) async {
    await pumpAt(
      t,
      ElioTheme.wrap(
        Scaffold(
          bottomNavigationBar: ElioBottomNav(
            currentIndex: 0,
            onSelectTab: (_) {},
            onControl: () {},
          ),
        ),
      ),
      brightness: Brightness.light,
    );
    expect(find.text('Profile'), findsNothing);
    for (final l in ['Home', 'Learn', 'Control', 'Config', 'History']) {
      expect(find.text(l), findsOneWidget);
    }
  });
}
