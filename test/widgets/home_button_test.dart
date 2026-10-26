import 'package:elio/widgets/control_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeButton: hold 1 s to confirm (decision 0027)', (tester) async {
    var confirmed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HomeButton(
              onConfirmed: () => confirmed++,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(HomeButton), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);

    // 1. Hold for 500 ms (less than 1s) and release: should NOT confirm
    final gesture1 = await tester.startGesture(tester.getCenter(find.byType(HomeButton)));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture1.up();
    await tester.pumpAndSettle();
    expect(confirmed, 0, reason: 'release before 1s cancels confirmation');

    // 2. Hold for full 1000 ms: confirms
    final gesture2 = await tester.startGesture(tester.getCenter(find.byType(HomeButton)));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    expect(confirmed, 1, reason: 'holding for 1s triggers confirmation');
    await gesture2.up();
    await tester.pumpAndSettle();
    expect(confirmed, 1, reason: 'release after confirmation does not duplicate call');

    // 3. When disabled: hold does nothing
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HomeButton(
              enabled: false,
              onConfirmed: () => confirmed++,
            ),
          ),
        ),
      ),
    );
    final gesture3 = await tester.startGesture(tester.getCenter(find.byType(HomeButton)));
    await tester.pump(const Duration(milliseconds: 1200));
    await gesture3.up();
    await tester.pumpAndSettle();
    expect(confirmed, 1, reason: 'disabled button does not confirm');
  });
}
