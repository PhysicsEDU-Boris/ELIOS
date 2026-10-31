import 'dart:io';
import 'dart:ui' show ImageByteFormat, Tristate;

import 'package:elio/providers/elio_theme_mode_provider.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/widgets/elio_sidebar.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/auth_test_support.dart';

/// N1 sidebar (Figma 244:2561 light, 244:2625 dark). PNGs: N1_RENDER=1.
final _render = Platform.environment['N1_RENDER'] == '1';

class _Calls {
  final selected = <int>[];
  int signOut = 0, close = 0;
}

Future<_Calls> _pump(
  WidgetTester t, {
  Brightness brightness = Brightness.light,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool toggle = true,
  bool guest = true,
}) async {
  final calls = _Calls();
  final user = guest
      ? MockUser(isAnonymous: true, photoURL: '')
      : MockUser(
          displayName: 'Boris Agung',
          email: 'boris@example.com',
          photoURL: '',
        );
  await pumpAt(
    t,
    RepaintBoundary(
      key: const Key('shot'),
      child: ElioTheme.wrap(
        Scaffold(
          body: ElioSidebar(
            user: user,
            currentIndex: 0,
            onSelect: calls.selected.add,
            onSignOut: () => calls.signOut++,
            onClose: () => calls.close++,
            showThemeToggle: toggle,
          ),
        ),
      ),
    ),
    size: size,
    brightness: brightness,
    textScale: textScale,
  );
  await t.pump(const Duration(milliseconds: 50));
  return calls;
}

void main() {
  setUpAll(loadElioFonts);

  for (final b in Brightness.values) {
    testWidgets('${b.name}: items, footer and actions', (t) async {
      final calls = await _pump(t, brightness: b);
      expect(t.takeException(), isNull);
      for (final s in [
        'ELIOS',
        'NAVIGATE',
        'Home',
        'Learn',
        'Configure',
        'Control',
        'Guest User',
        'GUEST',
        'Sign Out',
        'Dark mode',
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      await t.tap(find.text('Learn'));
      await t.tap(find.text('Configure'));
      await t.tap(find.text('Control'));
      await t.tap(find.text('Home'));
      expect(calls.selected, [1, 2, 3, 0]);
      await t.tap(find.text('Sign Out'));
      await t.tap(find.byTooltip('Close sidebar'));
      expect((calls.signOut, calls.close), (1, 1));
    });

    testWidgets('${b.name}: narrow 360 at text scale 1.3 does not overflow', (
      t,
    ) async {
      await _pump(
        t,
        brightness: b,
        size: const Size(304, 640),
        textScale: 1.3,
        guest: false,
      );
      expect(t.takeException(), isNull);
      expect(find.text('boris@example.com'), findsOneWidget);
      expect(find.text('GUEST'), findsNothing);
    });
  }

  testWidgets('tap targets are at least 48 dp', (t) async {
    await _pump(t);
    for (final f in [
      find.ancestor(of: find.text('Home'), matching: find.byType(InkWell)),
      find.ancestor(of: find.text('Control'), matching: find.byType(InkWell)),
      find.byTooltip('Close sidebar'),
      find.byType(SwitchListTile),
      find.widgetWithText(TextButton, 'Sign Out'),
    ]) {
      expect(t.getSize(f.first).height, greaterThanOrEqualTo(48), reason: '$f');
    }
  });

  testWidgets('dark mode toggle switches the saved mode both ways', (t) async {
    await _pump(t);
    final container = ProviderScope.containerOf(
      t.element(find.byType(ElioSidebar)),
    );
    expect(container.read(elioThemeModeProvider), ElioThemeMode.light);
    await t.tap(find.byType(SwitchListTile));
    await t.pump();
    expect(container.read(elioThemeModeProvider), ElioThemeMode.dark);
    await t.tap(find.byType(SwitchListTile));
    await t.pump();
    expect(container.read(elioThemeModeProvider), ElioThemeMode.light);
  });

  testWidgets('toggle is hidden behind the option gate', (t) async {
    await _pump(t, toggle: false);
    expect(find.text('Dark mode'), findsNothing);
  });

  testWidgets('semantics: selected item and labels', (t) async {
    final h = t.ensureSemantics();
    await _pump(t);
    expect(
      find.bySemanticsLabel('Learn, Waste types & quizzes'),
      findsOneWidget,
    );
    expect(
      t.getSemantics(find.bySemanticsLabel('Home')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    h.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets('render sidebar ${b.name}', (t) async {
      await _pump(t, brightness: b);
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('shot')),
      );
      await t.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ImageByteFormat.png);
        File('docs/test-results/n1-sidebar/sidebar-${b.name}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }, skip: !_render);
  }
}
