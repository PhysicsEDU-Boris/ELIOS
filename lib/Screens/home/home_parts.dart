// Shared pieces of the H1 v4 Home (decision 0144): card, art, bin colours and
// the two mini charts. Colours come from the palette only; the SVG art is fixed.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/home_stats.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/auth/auth_widgets.dart' show authPalette;

const homeRadiusL = 20.0;
const homeRadiusM = 12.0;

Widget homeArt(String name, {double? width, double? height}) =>
    SvgPicture.asset(
      'assets/illustrations/home/$name.svg',
      width: width,
      height: height,
      excludeFromSemantics: true,
    );

OutlinedBorder homeShape(double radius, [Color? side]) =>
    RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: side == null ? BorderSide.none : BorderSide(color: side),
    );

// Figma's Google Sans Flex is not bundled; titles use the theme sans (Inter).
TextStyle homeTitle(ElioPalette p) => ElioTokens.bodyLarge.copyWith(
  fontSize: 19,
  fontWeight: FontWeight.w600,
  height: 1.3,
  color: p.textPrimary,
);

TextStyle homeOverline(Color color) =>
    ElioTokens.label.copyWith(color: color, letterSpacing: 1.6);

TextStyle homeSmall(ElioPalette p, {Color? color, FontWeight? weight}) =>
    ElioTokens.bodySmall.copyWith(
      color: color ?? p.textSecondary,
      fontWeight: weight,
    );

TextStyle homeNumber(ElioPalette p, double size) => ElioTokens.body.copyWith(
  fontSize: size,
  fontWeight: FontWeight.w700,
  height: 1.15,
  letterSpacing: -0.5,
  color: p.textPrimary,
);

Color binColor(ElioPalette p, HomeBin b) => switch (b) {
  HomeBin.organik => p.primary,
  HomeBin.anorganik => p.tertiaryText,
  HomeBin.b3 => p.error,
};

/// Text colour on a light tint of [binColor].
Color binText(ElioPalette p, HomeBin b) => switch (b) {
  HomeBin.organik => p.primaryText,
  HomeBin.anorganik => p.tertiaryText,
  HomeBin.b3 => p.errorText,
};

class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.child,
    this.padding = 16,
    this.color,
  });

  final Widget child;
  final double padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color ?? p.surface,
        shape: homeShape(homeRadiusL, color == null ? p.borderSubtle : null),
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}

class BinChip extends StatelessWidget {
  const BinChip(this.bin, {super.key});
  final HomeBin bin;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: binColor(p, bin).withValues(alpha: 0.12),
        shape: homeShape(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          bin.label,
          style: homeSmall(p, color: binText(p, bin), weight: FontWeight.w600),
        ),
      ),
    );
  }
}

class TrophyAmount extends StatelessWidget {
  const TrophyAmount(this.text, {super.key, this.chip = false});
  final String text;
  final bool chip;

  @override
  Widget build(BuildContext context) {
    final p = authPalette(context);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.emoji_events_outlined, size: 16, color: p.secondaryText),
        const SizedBox(width: 4),
        Text(
          text,
          style: homeSmall(p, color: p.secondaryText, weight: FontWeight.w600),
        ),
      ],
    );
    if (!chip) return row;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: p.secondaryText.withValues(alpha: 0.08),
        shape: homeShape(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: row,
      ),
    );
  }
}

/// Rounded horizontal progress bar.
class HomeBar extends StatelessWidget {
  const HomeBar({
    super.key,
    required this.value,
    required this.color,
    required this.track,
    this.height = 8,
  });
  final double value;
  final Color color, track;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: track),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0, 1).toDouble(),
            // A dot shows on an empty bar, like Figma.
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
          if (value <= 0)
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox.square(
                dimension: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Monday-first stacked bars of this week's scans, split by bin.
class WeekBarsPainter extends CustomPainter {
  WeekBarsPainter(this.week, this.colors);
  final List<Map<HomeBin, int>> week;
  final Map<HomeBin, Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final maxDay = week
        .map((d) => d.values.fold(0, (a, b) => a + b))
        .fold(0, math.max);
    if (maxDay == 0) return;
    final slot = size.width / 7;
    final barW = math.min(14.0, slot * 0.6);
    for (var i = 0; i < 7; i++) {
      var y = size.height;
      final x = slot * i + (slot - barW) / 2;
      final parts = [
        for (final b in HomeBin.values)
          if (week[i][b]! > 0) (b, week[i][b]!),
      ];
      for (var k = 0; k < parts.length; k++) {
        final h = size.height * parts[k].$2 / maxDay;
        final rect = Rect.fromLTWH(x, y - h, barW, h);
        final top = k == parts.length - 1
            ? const Radius.circular(3)
            : Radius.zero;
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect, topLeft: top, topRight: top),
          Paint()..color = colors[parts[k].$1]!,
        );
        y -= h;
      }
    }
  }

  @override
  bool shouldRepaint(WeekBarsPainter old) =>
      old.week != week || old.colors != colors;
}

/// Quiz % per scan (0..100), oldest first, with a soft fill under the line.
class SparklinePainter extends CustomPainter {
  SparklinePainter(this.points, this.line, this.fill);
  final List<int> points;
  final Color line, fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    Offset at(int i) => Offset(
      points.length == 1
          ? size.width / 2
          : size.width * i / (points.length - 1),
      size.height - size.height * points[i] / 100,
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(path)
      ..lineTo(at(points.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    if (points.length == 1) canvas.drawCircle(at(0), 3, Paint()..color = line);
  }

  @override
  bool shouldRepaint(SparklinePainter old) =>
      old.points != points || old.line != line;
}
