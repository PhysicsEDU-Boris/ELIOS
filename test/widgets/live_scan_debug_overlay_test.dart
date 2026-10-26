import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/live_scan_controller.dart';
import 'package:elio/services/websocket_service.dart';
import 'package:elio/widgets/live_scan_debug_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const plastic = Detection(x: 320, y: 240, w: 120, h: 160, label: 'Plastic', score: 0.9);

  Future<LiveScanController> pump(WidgetTester tester, {required bool busy}) async {
    var now = 0;
    late final LiveScanController c;
    c = LiveScanController(
      startQuiz: (_) {
        if (busy) return false;
        c.onQuizPhase(WasteQuizPhase.loadingQuestion);
        return true;
      },
      firstTokenMs: () => 412,
      clock: () => DateTime(2026).add(Duration(milliseconds: now)),
      onEvent: (_, _) {},
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LiveScanDebugOverlay(controller: c))));
    for (now = 0; now <= 1000; now += 250) {
      c.onDetections([plastic]);
    }
    await tester.pump();
    return c;
  }

  testWidgets('shows the state, fps, identify count and first-token time', (tester) async {
    final c = await pump(tester, busy: false);
    expect(find.textContaining('LIVE SCAN  ASKING'), findsOneWidget);
    expect(find.textContaining('fps 4   identify 1'), findsOneWidget);
    c.onQuizPhase(WasteQuizPhase.active);
    await tester.pump();
    expect(find.textContaining('LIVE SCAN  QUIZ'), findsOneWidget);
    // ASKING fired at t=1000 (the lock); now is 1250 here (the loop's last increment).
    expect(find.textContaining('first token 412 ms   question 250 ms'), findsOneWidget);
    expect(find.textContaining('menunggu: kuis masih terbuka'), findsOneWidget);
    c.onQuizPhase(WasteQuizPhase.idle); // closed with the object still in view
    c.onDetections([plastic]);
    await tester.pump();
    expect(find.textContaining('menunggu: jeda setelah kuis 15 s'), findsOneWidget);
  });

  testWidgets('"Reset scan (debug)" is disabled while a quiz is open and re-arms after it (decision 0020)', (tester) async {
    final c = await pump(tester, busy: false); // ASKING
    final button = find.widgetWithText(OutlinedButton, 'Reset scan (debug)');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    c.onQuizPhase(WasteQuizPhase.active);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    c.onQuizPhase(WasteQuizPhase.idle); // COOLDOWN
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(find.textContaining('LIVE SCAN  SEARCHING'), findsOneWidget);
  });

  testWidgets('shows ASK FAILED after a busy ask while that object is still blocked', (tester) async {
    await pump(tester, busy: true);
    expect(find.textContaining('LIVE SCAN  ASK FAILED'), findsOneWidget);
    expect(find.textContaining('identify 0   busy 1'), findsOneWidget);
    expect(find.textContaining('first token -   question -'), findsOneWidget); // busy: no quiz opened
  });
}
