import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio/theme/elio_light_theme.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/theme/elio_tokens.dart';

import 'elio_tokens_test.dart' show contrast;

void main() {
  const l = ElioTokens.light;
  // The addendum table; the first row matching a name is the light value.
  final addendum = File('docs/design.md').readAsStringSync().split('## Light tokens (derived)').last;
  Color hex(String name, {int nth = 0}) {
    final m = RegExp('\\|\\s*$name[^|]*\\|\\s*`#([0-9A-Fa-f]{6})`').allMatches(addendum).elementAt(nth);
    return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
  }

  test('light tokens match the addendum', () {
    expect(l.background, hex('Background'));
    expect(l.surface, hex('Surface'));
    expect(l.surfaceRaised, hex('Surface Raised'));
    expect(l.textPrimary, hex('Text Primary'));
    expect(l.textSecondary, hex('Text Secondary'));
    expect(l.textTertiary, hex('Text Tertiary'));
    expect(l.borderSubtle, hex('Border Subtle'));
    expect(l.borderMedium, hex('Border Medium'));
    expect(l.borderStrong, hex('Border Strong'));
    expect(l.formBorder, hex('Form border'));
    expect(l.primary, hex(r'Primary \(fills'));
    expect(l.primaryText, hex(r'Primary \(text'));
    expect(l.secondaryText, hex(r'Secondary \(amber'));
    expect(l.tertiaryText, hex(r'Tertiary \(cyan'));
    expect(l.error, hex('Error'));
    expect(l.errorText, const Color(0xFFB91C1C));
  });

  test('both palettes expose the same fields (dark primary text is the fill)', () {
    expect(ElioTokens.dark.primaryText, ElioTokens.primary);
    expect(ElioTokens.dark.background, ElioTokens.background);
  });

  group('light contrast', () {
    test('text on background and surface reaches 4.5:1', () {
      final text = [l.textPrimary, l.textSecondary, l.textTertiary, l.primaryText, l.secondaryText, l.tertiaryText, l.errorText];
      for (final t in text) {
        for (final g in [l.background, l.surface]) {
          expect(contrast(t, g), greaterThanOrEqualTo(4.5), reason: '$t on $g');
        }
      }
    });

    test('secondary text reaches 4.5:1 on raised; tertiary does not (addendum)', () {
      expect(contrast(l.textSecondary, l.surfaceRaised), greaterThanOrEqualTo(4.5));
      expect(contrast(l.textTertiary, l.surfaceRaised), lessThan(4.5));
    });

    test('form border reaches 3:1 on field and background', () {
      expect(contrast(l.formBorder, l.field), greaterThanOrEqualTo(3));
      expect(contrast(l.formBorder, l.background), greaterThanOrEqualTo(3));
      expect(contrast(l.primaryText, l.surface), greaterThanOrEqualTo(3));
    });

    test('button and tooltip text', () {
      for (final f in [l.primary, l.primaryHover, l.primaryActive]) {
        expect(contrast(l.onPrimary, f), greaterThanOrEqualTo(4.5));
      }
      for (final f in [l.error, l.destructiveHover, l.destructiveActive]) {
        expect(contrast(l.onError, f), greaterThanOrEqualTo(4.5));
      }
      expect(contrast(l.tooltipText, l.tooltipBg), greaterThanOrEqualTo(4.5));
    });
  });

  Future<ThemeData> pump(WidgetTester tester, Widget child) async {
    late ThemeData theme;
    await tester.pumpWidget(MaterialApp(
      home: ElioLightTheme.wrap(Builder(builder: (c) {
        theme = Theme.of(c);
        return Scaffold(body: Center(child: child));
      })),
    ));
    return theme;
  }

  testWidgets('light theme components', (tester) async {
    final t = await pump(tester, const SizedBox(width: 240, child: TextField()));
    expect(t.brightness, Brightness.light);
    expect(t.useMaterial3, isTrue);
    expect(t.colorScheme.primary, l.primary);
    expect(t.colorScheme.surface, l.background);
    expect(t.scaffoldBackgroundColor, l.background);
    expect(tester.getSize(find.byType(TextField)).height, 40);
    final d = t.inputDecorationTheme;
    expect(d.fillColor, l.surface);
    expect((d.enabledBorder! as OutlineInputBorder).borderSide.color, l.formBorder);
    expect((d.focusedBorder! as OutlineInputBorder).borderSide.color, l.primaryText);
    expect((d.errorBorder! as OutlineInputBorder).borderSide.color, l.error);
    expect(d.errorStyle!.color, l.errorText);

    final card = t.cardTheme;
    expect(card.color, l.surface);
    expect(card.elevation, 0);
    expect((card.shape! as RoundedRectangleBorder).side.color, l.borderMedium);

    expect(ElioLightTheme.primaryButton.foregroundColor!.resolve({}), l.onPrimary);
    expect(ElioLightTheme.primaryButton.backgroundColor!.resolve({}), l.primary);
    expect(ElioLightTheme.destructiveButton.backgroundColor!.resolve({}), l.error);
    expect(ElioLightTheme.destructiveButton.foregroundColor!.resolve({}), l.onError);
    expect(ElioLightTheme.primaryButton.backgroundColor!.resolve({WidgetState.disabled})!.a, closeTo(0.35, 0.005));
    expect(ElioLightTheme.ghostButton.backgroundColor!.resolve({WidgetState.hovered}), l.surface);

    expect(t.chipTheme.backgroundColor, l.surface);
    expect(t.listTileTheme.iconColor, l.primaryText);
    expect(t.listTileTheme.selectedTileColor, l.surfaceRaised);
    final tip = t.tooltipTheme.decoration! as BoxDecoration;
    expect(tip.color, l.tooltipBg);
    expect(tip.boxShadow, isNull);
    final c = t.checkboxTheme;
    final side = (c.side! as WidgetStateProperty<BorderSide?>);
    expect(side.resolve({})!.color, l.formBorder);
    expect(side.resolve({WidgetState.selected})!.color, l.primaryText);
    expect(c.fillColor!.resolve({}), l.surface);
    expect(t.radioTheme.fillColor!.resolve({}), l.formBorder);
    expect(t.radioTheme.fillColor!.resolve({WidgetState.selected}), l.primaryText);
  });

  testWidgets('light: status-bar and nav-bar icons are dark', (tester) async {
    await pump(tester, const SizedBox());
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first);
    expect(region.value.statusBarIconBrightness, Brightness.dark);
    expect(region.value.systemNavigationBarIconBrightness, Brightness.dark);
  });

  testWidgets('light: focus ring and halo, no hover glow', (tester) async {
    await pump(tester, const SizedBox(width: 240, child: ElioGlowBox(child: TextField())));
    List<BoxShadow>? shadows() => ((tester.widget<DecoratedBox>(find.descendant(
            of: find.byType(ElioGlowBox), matching: find.byType(DecoratedBox)).first))
        .decoration as BoxDecoration).boxShadow;
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(shadows(), ElioLightEffects.focus);
    expect(ElioLightEffects.focus.last.color, const Color(0xFF15803D));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: tester.getCenter(find.byType(ElioGlowBox)));
    await tester.pump();
    expect(shadows(), isEmpty);
    await g.removePointer();
  });

  testWidgets('ElioTheme.wrap is light by default, even on a dark phone', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    late ThemeData t;
    await tester.pumpWidget(MaterialApp(
      home: ElioTheme.wrap(Builder(builder: (c) {
        t = Theme.of(c);
        return const SizedBox();
      })),
    ));
    expect(t.brightness, Brightness.light);
  });

  for (final mode in [Brightness.dark, Brightness.light]) {
    testWidgets('ElioTheme.wrap in system mode follows the platform brightness: $mode', (tester) async {
      ElioTheme.mode = ThemeMode.system;
      addTearDown(() => ElioTheme.mode = ThemeMode.light);
      tester.platformDispatcher.platformBrightnessTestValue = mode;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      late ThemeData t;
      await tester.pumpWidget(MaterialApp(
        home: ElioTheme.wrap(Builder(builder: (c) {
          t = Theme.of(c);
          return const SizedBox();
        })),
      ));
      expect(t.brightness, mode);
      expect(t.colorScheme.surface, (mode == Brightness.dark ? ElioTokens.dark : ElioTokens.light).background);
    });
  }
}
