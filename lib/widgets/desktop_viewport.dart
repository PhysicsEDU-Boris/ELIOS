import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Set by landscape-only screens (robot control, device scan) while visible.
/// Phones rotate for these; on desktop the viewport switches shape instead.
final desktopLandscape = ValueNotifier<bool>(false);

/// Safe to call from initState/dispose: applied after the current frame so
/// the viewport above the Navigator isn't rebuilt mid-build.
void setDesktopLandscape(bool value) {
  WidgetsBinding.instance.addPostFrameCallback((_) => desktopLandscape.value = value);
}

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Renders the app inside a phone-sized viewport on desktop so screens
/// designed for Android never stretch across a large window (Figma:
/// "ELIOS · Camera Source + macOS Layout"). Portrait screens get a 412dp
/// column at full window height; landscape screens get at most 960×540.
/// On phones and tablets this is a no-op.
class DesktopViewport extends StatelessWidget {
  const DesktopViewport({super.key, required this.child, this.forceDesktop = false});

  final Widget child;

  @visibleForTesting
  final bool forceDesktop;

  static const portraitWidth = 412.0;
  static const landscapeMax = Size(960, 540);

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop && !forceDesktop) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: desktopLandscape,
      builder: (context, landscape, _) => ColoredBox(
        color: const Color(0xFF1C1F1D),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = landscape
                ? Size(
                    math.min(landscapeMax.width, constraints.maxWidth),
                    math.min(landscapeMax.height, constraints.maxHeight),
                  )
                : Size(math.min(portraitWidth, constraints.maxWidth), constraints.maxHeight);
            final framed = size.width < constraints.maxWidth || size.height < constraints.maxHeight;
            final media = MediaQuery.of(context);
            return Center(
              child: SizedBox.fromSize(
                size: size,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(framed && landscape ? 16 : 0),
                  child: MediaQuery(
                    data: media.copyWith(size: size),
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
