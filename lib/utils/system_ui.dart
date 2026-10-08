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
