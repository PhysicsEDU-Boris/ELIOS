// Leaving Control with a quiz open must still disconnect (C1 phone check, 2 Nov 2026):
// dispose used to clear the quiz first, Riverpod refused that write while the
// tree was unmounting, and the rest of dispose (the disconnect) never ran.
import 'package:elio/Screens/control_screen.dart';
import 'package:elio/providers/waste_quiz_provider.dart';
import 'package:elio/services/gemma_quiz_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    GemmaQuizService.instance.mockSendExecute =
        (p, {imageBytes, fresh = false, isUser = false, onToken}) async => null;
  });
  tearDown(() => GemmaQuizService.instance.mockSendExecute = null);

  testWidgets(
    'leaving Control with a quiz open clears it and runs the whole dispose',
    (t) async {
      t.view.physicalSize = const Size(2400, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final logs = <String>[];
      final print = debugPrint;
      debugPrint = (m, {wrapWidth}) => logs.add(m ?? '');
      try {
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ControlScreen()),
          ),
        );
        await t.pump();
        container
            .read(wasteQuizProvider.notifier)
            .startForLabel('botol plastik');
        await t.pump(const Duration(milliseconds: 50));
        expect(
          container.read(wasteQuizProvider).phase,
          isNot(WasteQuizPhase.idle),
        );

        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const SizedBox(),
          ),
        );
        await t.pump();
        expect(t.takeException(), isNull);
        expect(
          logs,
          contains('[Control] Leaving robot control, disconnecting WebSocket'),
          reason: 'the disconnect at the end of dispose ran',
        );
        expect(
          container.read(wasteQuizProvider).phase,
          WasteQuizPhase.idle,
          reason: 'quiz still cleared',
        );
        await t.pumpAndSettle(const Duration(seconds: 1));
      } finally {
        debugPrint = print;
      }
    },
  );
}
