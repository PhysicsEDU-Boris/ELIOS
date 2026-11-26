// Owner, 26 Nov: Control screen notifications appear at the top, not the bottom.
import 'package:elio/Screens/control_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [Size(915, 412), Size(800, 360), Size(1280, 800)]) {
    testWidgets('a SnackBar with the top inset sits in the top band at $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                insetPadding: snackBarFromTop(MediaQuery.sizeOf(context)),
              ),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Arm cannot reach there'))),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      final r = t.getRect(find.text('Arm cannot reach there'));
      expect(r.bottom, lessThan(96));
      expect(r.top, greaterThan(0));
    });
  }
}
