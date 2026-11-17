import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The XP sprout sticker. Replaces every trophy icon (decision 0220); it is
/// full colour, so it takes no tint. The text beside it says "XP".
class XpIcon extends StatelessWidget {
  const XpIcon(this.size, {super.key});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/illustrations/history/icon_xp.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}
