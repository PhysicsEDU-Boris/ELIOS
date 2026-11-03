import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elio/theme/elio_tokens.dart';

double _lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double _lum(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
double contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  // Only the owner's DevLog section: stop at the addendum.
  final doc = File('docs/design.md').readAsStringSync().split('# ELIOS addendum').first;

  Color owner(String name) {
    final m = RegExp('\\|\\s*$name\\s*\\|\\s*`#([0-9A-Fa-f]{6})`').firstMatch(doc);
    expect(m, isNotNull, reason: 'no $name in docs/design.md');
    return Color(0xFF000000 | int.parse(m!.group(1)!, radix: 16));
  }

  group('colours match docs/design.md', () {
    final cases = <String, Color>{
      'Primary': ElioTokens.primary,
      'Secondary': ElioTokens.secondary,
      'Tertiary': ElioTokens.tertiary,
      'Background': ElioTokens.background,
      'Surface': ElioTokens.surface,
      'Surface Raised': ElioTokens.surfaceRaised,
      'Text Primary': ElioTokens.textPrimary,
      'Text Secondary': ElioTokens.textSecondary,
      'Border Subtle': ElioTokens.borderSubtle,
      'Border Medium': ElioTokens.borderMedium,
      'Border Strong': ElioTokens.borderStrong,
      'Success': ElioTokens.success,
      'Warning': ElioTokens.warning,
      'Error': ElioTokens.error,
      'Info': ElioTokens.info,
    };
    cases.forEach((name, token) => test(name, () => expect(token, owner(name))));

    test('Text Tertiary is the documented deviation', () {
      expect(owner('Text Tertiary'), const Color(0xFF64748B));
      expect(ElioTokens.textTertiary, const Color(0xFF8392A8));
    });
  });

  test('type scale matches the table', () {
    final styles = {
      'Display': ElioTokens.display,
      'Headline': ElioTokens.headline,
      'Subhead': ElioTokens.subhead,
      'Body Large': ElioTokens.bodyLarge,
      'Body': ElioTokens.body,
      'Body Small': ElioTokens.bodySmall,
      'Caption': ElioTokens.caption,
      'Overline': ElioTokens.overline,
      'Code': ElioTokens.code,
    };
    styles.forEach((name, s) {
      final m = RegExp('\\|\\s*$name\\s*\\|\\s*([A-Za-z ]+?)\\s*\\|\\s*(\\d+)px\\s*\\|\\s*(\\d+)\\s*\\|\\s*([\\d.]+)\\s*\\|\\s*(-?[\\d.]+)(?:em)?\\s*\\|')
          .firstMatch(doc);
      expect(m, isNotNull, reason: name);
      expect(s.fontFamily, m!.group(1), reason: name);
      expect(s.fontSize, double.parse(m.group(2)!), reason: name);
      expect(s.fontVariations!.single.value, double.parse(m.group(3)!), reason: name);
      expect(s.height, double.parse(m.group(4)!), reason: name);
      expect(s.letterSpacing, closeTo(double.parse(m.group(5)!) * s.fontSize!, 1e-9), reason: name);
    });
  });

  test('spacing scale and radii match the tables', () {
    final scale = RegExp(r'\| Scale\s*\|\s*([\d, ]+)\|').firstMatch(doc)!.group(1)!;
    expect(ElioTokens.spaceScale, scale.split(',').map((e) => double.parse(e.trim())).toList());
    double radius(String n) =>
        double.parse(RegExp('\\|\\s*$n\\s*\\|\\s*(\\d+)px').firstMatch(doc)!.group(1)!);
    expect(ElioTokens.radiusNone, radius('None'));
    expect(ElioTokens.radiusSmall, radius('Small'));
    expect(ElioTokens.radiusMedium, radius('Medium'));
    expect(ElioTokens.radiusLarge, radius('Large'));
    expect(ElioTokens.radiusXl, radius('XL'));
    expect(ElioTokens.radiusFull, 9999);
  });

  test('glow: blur and alpha match the shadow table, colour is the accent', () {
    void check(List<BoxShadow> g, double blur, double alpha) {
      expect(g.single.blurRadius, blur);
      expect(g.single.color.a, closeTo(alpha, 0.005));
      expect(g.single.offset, Offset.zero);
    }

    check(ElioGlow.subtle, 8, 0.08);
    check(ElioGlow.medium, 16, 0.12);
    check(ElioGlow.large, 32, 0.16);
    check(ElioGlow.cyan, 20, 0.15);
    check(ElioGlow.amber, 16, 0.12);
    check(ElioGlow.inputFocus, 12, 0.15);
  });

  group('contrast (WCAG AA)', () {
    final grounds = {'background': ElioTokens.background, 'surface': ElioTokens.surface};

    test('text tokens reach 4.5:1 on background and surface', () {
      final text = {
        'textPrimary': ElioTokens.textPrimary,
        'textSecondary': ElioTokens.textSecondary,
        'textTertiary': ElioTokens.textTertiary,
        'primary': ElioTokens.primary,
        'secondary': ElioTokens.secondary,
        'tertiary': ElioTokens.tertiary,
        'error': ElioTokens.error,
      };
      for (final t in text.entries) {
        for (final g in grounds.entries) {
          expect(contrast(t.value, g.value), greaterThanOrEqualTo(4.5), reason: '${t.key} on ${g.key}');
        }
      }
    });

    test('form border reaches 3:1 on the field fill', () {
      expect(contrast(ElioTokens.formBorder, ElioTokens.background), greaterThanOrEqualTo(3));
    });

    test('button text', () {
      for (final fill in [ElioTokens.primary, ElioTokens.error, ElioTokens.primaryHover, ElioTokens.destructiveHover]) {
        expect(contrast(ElioTokens.background, fill), greaterThanOrEqualTo(4.5));
      }
    });

    test('quiz answer fills have AA text', () {
      final pairs = [
        (ElioTokens.answerRed, ElioTokens.onAnswerRed),
        (ElioTokens.answerBlue, ElioTokens.onAnswerBlue),
        (ElioTokens.answerYellow, ElioTokens.onAnswerYellow),
        (ElioTokens.answerGreen, ElioTokens.onAnswerGreen),
      ];
      for (final p in pairs) {
        expect(contrast(p.$1, p.$2), greaterThanOrEqualTo(4.5), reason: '${p.$1}');
      }
    });

    test('the owner values do fail (why the deviations exist)', () {
      const rawTertiary = Color(0xFF64748B);
      expect(contrast(rawTertiary, ElioTokens.background), closeTo(3.75, 0.01));
      expect(contrast(rawTertiary, ElioTokens.surface), closeTo(3.07, 0.01));
      expect(contrast(const Color(0xFF334155), ElioTokens.background), closeTo(1.72, 0.01));
      expect(contrast(const Color(0xFF475569), ElioTokens.background), closeTo(2.36, 0.01));
      expect(contrast(const Color(0xFFFFFFFF), const Color(0xFFD89E00)), closeTo(2.38, 0.01));
    });
  });

  test('old quiz colour names keep the same hues', () {
    expect(ElioTokens.answerRed, const Color(0xFFE21B3C));
    expect(ElioTokens.answerBlue, const Color(0xFF1368CE));
    expect(ElioTokens.answerYellow, const Color(0xFFD89E00));
    expect(ElioTokens.answerGreen, const Color(0xFF26890C));
  });
}
