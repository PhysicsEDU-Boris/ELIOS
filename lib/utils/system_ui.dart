import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void applyTransparentSystemBars({Brightness iconBrightness = Brightness.dark}) {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

/// Pushes a landscape screen (Control, phone scan) and puts the app back in
/// portrait with transparent bars when it closes.
Future<void> pushLandscapeScreen(BuildContext context, Widget screen) async {
  try {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen, fullscreenDialog: true),
    );
  } finally {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      applyTransparentSystemBars();
    } catch (error) {
      debugPrint('Unable to restore portrait mode: $error');
    }
  }
}
