import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio/theme/elio_dark_theme.dart';
import 'package:elio/theme/elio_tokens.dart';

void main() {
  Future<ThemeData> pumpThemed(WidgetTester tester, Widget child) async {
    late ThemeData theme;
    await tester.pumpWidget(MaterialApp(
      home: ElioDarkTheme.wrap(Builder(builder: (context) {
        theme = Theme.of(context);
        return Scaffold(body: Center(child: child));
      })),
    ));
    return theme;
  }

  test('built from tokens, not fromSeed', () {
    final cs = ElioDarkTheme.data.colorScheme;
    expect(ElioDarkTheme.data.useMaterial3, isTrue);
    expect(cs.brightness, Brightness.dark);
    expect(cs.primary, ElioTokens.primary);
    expect(cs.surface, ElioTokens.background);
    expect(cs.error, ElioTokens.error);
    expect(cs.outline, ElioTokens.formBorder);
  });

  testWidgets('buttons: colours, radius, disabled 0.35', (tester) async {
    await pumpThemed(
      tester,
      Column(children: [
        ElevatedButton(onPressed: () {}, child: const Text('p')),
        const ElevatedButton(onPressed: null, child: Text('pd')),
        OutlinedButton(onPressed: () {}, child: const Text('s')),
        TextButton(onPressed: () {}, child: const Text('g')),
        ElevatedButton(
            style: ElioDarkTheme.destructiveButton, onPressed: () {}, child: const Text('d')),
      ]),
    );
    Color? bg(ButtonStyle s) => s.backgroundColor!.resolve({});

    final primary = ElioDarkTheme.primaryButton;
    expect(bg(primary), ElioTokens.primary);
    expect(primary.foregroundColor!.resolve({}), ElioTokens.background);
    expect(primary.backgroundColor!.resolve({WidgetState.hovered}), ElioTokens.primaryHover);
    expect(primary.backgroundColor!.resolve({WidgetState.pressed}), ElioTokens.primaryActive);
    expect(primary.backgroundColor!.resolve({WidgetState.disabled})!.a, closeTo(0.35, 0.005));
    expect(primary.shape!.resolve({}), isA<RoundedRectangleBorder>()
        .having((s) => s.borderRadius, 'radius', BorderRadius.circular(4)));
    expect(primary.elevation!.resolve({}), 0);

    expect(bg(ElioDarkTheme.secondaryButton), ElioTokens.surface);
    expect(ElioDarkTheme.secondaryButton.side!.resolve({})!.color, ElioTokens.borderMedium);
    expect(ElioDarkTheme.secondaryButton.side!.resolve({WidgetState.hovered})!.color, ElioTokens.borderStrong);
    expect(bg(ElioDarkTheme.ghostButton), Colors.transparent);
    expect(ElioDarkTheme.ghostButton.foregroundColor!.resolve({}), ElioTokens.textSecondary);
    expect(bg(ElioDarkTheme.destructiveButton), ElioTokens.error);
    expect(ElioDarkTheme.destructiveButton.backgroundColor!.resolve({WidgetState.hovered}),
        ElioTokens.destructiveHover);

    // The themed widgets resolve to the same styles.
    final t = ElioDarkTheme.data;
    expect(t.elevatedButtonTheme.style, ElioDarkTheme.primaryButton);
    expect(t.outlinedButtonTheme.style, ElioDarkTheme.secondaryButton);
    expect(t.textButtonTheme.style, ElioDarkTheme.ghostButton);

    expect(ElioDarkTheme.small.padding!.resolve({}), const EdgeInsets.symmetric(horizontal: 14, vertical: 6));
    expect(ElioDarkTheme.large.padding!.resolve({}), const EdgeInsets.symmetric(horizontal: 28, vertical: 12));
  });

  testWidgets('card: surface, 1 px border, 4 dp, no shadow', (tester) async {
    final theme = await pumpThemed(tester, const Card(child: SizedBox(width: 50, height: 50)));
    final card = tester.widget<Card>(find.byType(Card));
    expect(theme.cardTheme.color, ElioTokens.surface);
    expect(theme.cardTheme.elevation, 0);
    final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(4));
    expect(shape.side.color, ElioTokens.borderMedium);
    expect(card.elevation, isNull);
  });

  testWidgets('text input: 40 dp, border, focus and error', (tester) async {
    final theme = await pumpThemed(
      tester,
      const SizedBox(width: 240, child: TextField(decoration: InputDecoration(hintText: 'h'))),
    );
    final box = tester.getSize(find.byType(TextField));
    expect(box.height, 40);
    final d = theme.inputDecorationTheme;
    expect(d.fillColor, ElioTokens.background);
    expect((d.enabledBorder! as OutlineInputBorder).borderSide.color, ElioTokens.formBorder);
    expect((d.focusedBorder! as OutlineInputBorder).borderSide.color, ElioTokens.primary);
    expect((d.errorBorder! as OutlineInputBorder).borderSide.color, ElioTokens.error);
    expect((d.enabledBorder! as OutlineInputBorder).borderRadius, BorderRadius.circular(4));
    expect(d.hintStyle!.color, ElioTokens.textTertiary);
    expect(d.errorStyle!.color, ElioTokens.error);
  });

  testWidgets('ElioGlowBox: glow only on focus and hover', (tester) async {
    await pumpThemed(
      tester,
      const SizedBox(width: 240, child: ElioGlowBox(child: TextField())),
    );
    List<BoxShadow>? shadows() => ((tester.widget<DecoratedBox>(find.descendant(
            of: find.byType(ElioGlowBox), matching: find.byType(DecoratedBox)).first))
        .decoration as BoxDecoration).boxShadow;
    expect(shadows(), isEmpty);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(shadows(), ElioGlow.inputFocus);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: tester.getCenter(find.byType(ElioGlowBox)));
    await tester.pump();
    expect(shadows(), ElioGlow.subtle);
    await g.removePointer();
  });

  testWidgets('chip: filter and selected', (tester) async {
    final theme = await pumpThemed(
      tester,
      Row(mainAxisSize: MainAxisSize.min, children: [
        FilterChip(label: const Text('a'), selected: false, onSelected: (_) {}),
        FilterChip(label: const Text('b'), selected: true, onSelected: (_) {}),
      ]),
    );
    final c = theme.chipTheme;
    expect(c.backgroundColor, ElioTokens.surface);
    expect(c.selectedColor, ElioTokens.primary);
    expect(c.side!.color, ElioTokens.borderMedium);
    expect((c.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(4));
    expect(c.labelStyle!.color, ElioTokens.textSecondary);
    expect(c.secondaryLabelStyle!.color, ElioTokens.background);
    expect(c.labelStyle!.fontFamily, ElioTokens.fontMono);
  });

  testWidgets('list tile', (tester) async {
    final theme = await pumpThemed(
      tester,
      const SizedBox(
        width: 300,
        child: Material(child: ListTile(leading: Icon(Icons.eco), title: Text('t'), subtitle: Text('s'))),
      ),
    );
    final l = theme.listTileTheme;
    expect(l.iconColor, ElioTokens.primary);
    expect(l.textColor, ElioTokens.textPrimary);
    expect(l.selectedTileColor, ElioTokens.surfaceRaised);
    expect(l.subtitleTextStyle!.color, ElioTokens.textTertiary);
    expect(l.contentPadding, const EdgeInsets.symmetric(horizontal: 16));
    expect(l.minVerticalPadding, 12);
  });

  testWidgets('checkbox and radio', (tester) async {
    final theme = await pumpThemed(
      tester,
      Row(mainAxisSize: MainAxisSize.min, children: [
        Checkbox(value: true, onChanged: (_) {}),
        const Checkbox(value: false, onChanged: null),
        RadioGroup<int>(
          groupValue: 1,
          onChanged: (_) {},
          child: const Row(children: [Radio<int>(value: 1), Radio<int>(value: 2)]),
        ),
      ]),
    );
    final c = theme.checkboxTheme;
    BorderSide side(Set<WidgetState> s) => (c.side! as WidgetStateProperty<BorderSide?>).resolve(s)!;
    expect(c.fillColor!.resolve({WidgetState.selected}), ElioTokens.primary);
    expect(c.fillColor!.resolve({}), ElioTokens.background);
    expect(c.checkColor!.resolve({}), ElioTokens.background);
    expect(side({}).color, ElioTokens.formBorder);
    expect(side({}).width, 1.5);
    expect(side({WidgetState.hovered}).color, ElioTokens.primary);
    expect(side({WidgetState.disabled}).color.a, closeTo(0.35, 0.005));
    expect((c.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(3));
    final r = theme.radioTheme;
    expect(r.fillColor!.resolve({}), ElioTokens.formBorder);
    expect(r.fillColor!.resolve({WidgetState.selected}), ElioTokens.primary);
  });

  testWidgets('tooltip', (tester) async {
    final theme = await pumpThemed(tester, const Tooltip(message: 'tip', child: Text('x')));
    final t = theme.tooltipTheme;
    final deco = t.decoration! as BoxDecoration;
    expect(deco.color, ElioTokens.textPrimary);
    expect(deco.borderRadius, BorderRadius.circular(4));
    expect(deco.boxShadow, ElioGlow.tooltip);
    expect(t.textStyle!.color, ElioTokens.background);
    expect(t.padding, const EdgeInsets.symmetric(horizontal: 12, vertical: 6));
    expect(t.constraints!.maxWidth, 260);
    expect(t.waitDuration, const Duration(milliseconds: 200));
  });

  test('no drop shadows: only glow, and the overlay exception', () {
    expect(ElioDarkTheme.data.cardTheme.elevation, 0);
    expect(ElioDarkTheme.primaryButton.elevation!.resolve({WidgetState.hovered}), 0);
    for (final g in [ElioGlow.subtle, ElioGlow.medium, ElioGlow.large, ElioGlow.inputFocus]) {
      expect(g.single.offset, Offset.zero);
    }
  });

  testWidgets('wrap sets light status-bar and nav-bar icons', (tester) async {
    await pumpThemed(tester, const SizedBox());
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
    expect(region.value.statusBarIconBrightness, Brightness.light);
    expect(region.value.systemNavigationBarIconBrightness, Brightness.light);
  });

  testWidgets('wrap is scoped: the surrounding MaterialApp theme is untouched', (tester) async {
    final app = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6E56)), useMaterial3: true);
    late Color outside, inside;
    await tester.pumpWidget(MaterialApp(
      theme: app,
      home: Column(children: [
        Builder(builder: (c) {
          outside = Theme.of(c).colorScheme.primary;
          return const SizedBox();
        }),
        ElioDarkTheme.wrap(Builder(builder: (c) {
          inside = Theme.of(c).colorScheme.primary;
          return const SizedBox();
        })),
      ]),
    ));
    expect(outside, app.colorScheme.primary);
    expect(inside, ElioTokens.primary);
  });

  test('main.dart still uses its own theme and does not import the DS theme', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('ColorScheme.fromSeed(seedColor: const Color(0xFF0F6E56))'));
    expect(main, isNot(contains('elio_dark_theme')));
    expect(main, isNot(contains('ElioDarkTheme')));
  });

  test('fonts are bundled and declared, no runtime fetching', () {
    final pub = File('pubspec.yaml').readAsStringSync();
    expect(pub, contains('assets/fonts/JetBrainsMono-Variable.ttf'));
    expect(pub, contains('assets/fonts/Inter-Variable.ttf'));
    for (final f in ['JetBrainsMono-Variable.ttf', 'Inter-Variable.ttf', 'OFL-Inter.txt', 'OFL-JetBrainsMono.txt']) {
      expect(File('assets/fonts/$f').existsSync(), isTrue, reason: f);
    }
    final themeSrc = File('lib/theme/elio_dark_theme.dart').readAsStringSync() +
        File('lib/theme/elio_tokens.dart').readAsStringSync();
    expect(themeSrc, isNot(contains('google_fonts')));
  });
}
