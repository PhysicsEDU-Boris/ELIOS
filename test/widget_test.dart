import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:elio/Screens/login_screen.dart';
import 'package:elio/main.dart';

// Replaces the two stale tests that expected the old splash text ("ELIO") and
// placeholder routes ("Login — coming soon"). The app now boots into the U9
// splash; routing detail is covered in test/screens/splash_screen_test.dart.
void main() {
  testWidgets(
    'app starts on the ELIOS splash and routes signed-out users to login',
    (WidgetTester tester) async {
      await tester.pumpWidget(ElioApp(auth: MockFirebaseAuth(signedIn: false)));
      expect(find.text('ELIOS'), findsNothing); // letters rise in one by one
      expect(find.text('E'), findsOneWidget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3402));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );
}
