// R3 on the real ControlScreen (no robot: the link is down): the phone layout
// is chosen by size, the Guide opens by itself once per device, and tablets keep R2.
import 'package:elio/Screens/control_screen.dart';
import 'package:elio/services/ai_quiz_service.dart';
import 'package:elio/widgets/control/phone/phone_control.dart';
import 'package:elio/widgets/control/phone/phone_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ControlScreen()),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
  return container;
}

Future<void> _leave(WidgetTester t, ProviderContainer c) async {
  await t.pumpWidget(
    UncontrolledProviderScope(container: c, child: const SizedBox()),
  );
  await t.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AiQuizService.instance.mockSendExecute =
        (p, {imageBytes, isUser = false}) async => null;
  });
  tearDown(() => AiQuizService.instance.mockSendExecute = null);

  testWidgets(
    'a phone in landscape gets the R3 layout; STOP is live while it loads',
    (t) async {
      SharedPreferences.setMockInitialValues({controlGuideShownKey: true});
      final c = await _pump(t, const Size(915, 412));
      expect(find.byType(PhoneControlLayout), findsOneWidget);
      expect(find.byKey(const ValueKey('phone_stop')), findsOneWidget);
      await _leave(t, c);
    },
  );

  testWidgets(
    'the Guide opens by itself the first time and the flag is saved',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final c = await _pump(t, const Size(915, 412));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('guide_step_1')), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool(controlGuideShownKey),
        isTrue,
      );
      await t.tap(find.byKey(const ValueKey('guide_skip')));
      await t.pump();
      expect(find.byKey(const ValueKey('guide_step_1')), findsNothing);
      // From the Guide button, as often as wanted.
      await t.tap(find.byKey(const ValueKey('phone_guide')));
      await t.pump();
      expect(find.byKey(const ValueKey('guide_step_1')), findsOneWidget);
      await _leave(t, c);
    },
  );

  testWidgets('it does not open again once shown', (t) async {
    SharedPreferences.setMockInitialValues({controlGuideShownKey: true});
    final c = await _pump(t, const Size(915, 412));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('guide_step_1')), findsNothing);
    await _leave(t, c);
  });

  testWidgets('a tablet keeps the R2 layout', (t) async {
    SharedPreferences.setMockInitialValues({});
    final c = await _pump(t, const Size(1366, 768));
    expect(find.byType(PhoneControlLayout), findsNothing);
    await _leave(t, c);
  });
}
