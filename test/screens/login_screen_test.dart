import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elio/Screens/login_screen.dart';

import 'auth_test_support.dart';

/// Holds the email sign-in until [release] so the loading state can be seen.
class _SlowAuth extends MockFirebaseAuth {
  final gate = Completer<void>();

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await gate.future;
    return super.signInWithEmailAndPassword(email: email, password: password);
  }
}

/// Throws [code] from the email sign-in and sign-up calls.
class _FailAuth extends MockFirebaseAuth {
  _FailAuth(this.code);
  final String code;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw FirebaseAuthException(code: code);

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw FirebaseAuthException(code: code);
}

class _ResetFails extends MockFirebaseAuth {
  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) => throw FirebaseAuthException(code: 'network-request-failed');
}

Finder _field(int i) => find.byType(TextFormField).at(i);
Finder _filled(String label) => find.widgetWithText(FilledButton, label);
Finder _outlined(String label) => find.widgetWithText(OutlinedButton, label);

Future<RouteSpy> _open(WidgetTester t, FirebaseAuth auth) =>
    pumpAt(t, LoginScreen(auth: auth));

Future<void> _signInForm(
  WidgetTester t, {
  String email = 'a@b.co',
  String pw = 'secret1',
}) async {
  await t.enterText(_field(0), email);
  await t.enterText(_field(1), pw);
}

void main() {
  setUpAll(loadElioFonts);
  testWidgets('shows the Figma sign-in copy and no Phone or Remember me', (
    t,
  ) async {
    await _open(t, MockFirebaseAuth());
    for (final s in [
      'ELIOS',
      'Welcome Back',
      'Sign in to control ELIOS',
      'Email / Username',
      'Password',
      'Forgot password?',
      'Sign In',
      'Or',
      'Continue with Google',
      'Continue as Guest',
      'Guest mode saves data locally only. Sign in to sync progress.',
      "Don't have an account? ",
      'Sign Up',
    ]) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.textContaining('Phone'), findsNothing);
    expect(find.textContaining('Remember'), findsNothing);
  });

  testWidgets('email sign in goes Home with the Welcome back snackbar', (
    t,
  ) async {
    final spy = await _open(t, MockFirebaseAuth());
    await _signInForm(t);
    await t.tap(_filled('Sign In'));
    await t.pump();
    expect(spy.wentHome, isTrue);
    expect(find.text('Welcome back!'), findsOneWidget);
    t.takeException(); // HomeShell needs Firebase.initializeApp
  });

  testWidgets(
    'wrong password shows the mapped banner and re-enables the form',
    (t) async {
      final auth = _FailAuth('wrong-password');
      final spy = await _open(t, auth);
      await _signInForm(t);
      await t.tap(_filled('Sign In'));
      await t.pumpAndSettle();
      expect(find.text('Incorrect password.'), findsOneWidget);
      expect(spy.pages, isEmpty);
      expect(t.widget<FilledButton>(_filled('Sign In')).onPressed, isNotNull);
    },
  );

  testWidgets('unknown error code falls back to the generic message', (
    t,
  ) async {
    final auth = _FailAuth('weird');
    await _open(t, auth);
    await _signInForm(t);
    await t.tap(_filled('Sign In'));
    await t.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('empty submit shows the validators and does not sign in', (
    t,
  ) async {
    final spy = await _open(t, MockFirebaseAuth());
    await t.tap(_filled('Sign In'));
    await t.pump();
    expect(find.text('Email or username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(spy.pages, isEmpty);
  });

  testWidgets(
    'loading: spinner replaces the label and every action is disabled',
    (t) async {
      final auth = _SlowAuth();
      await _open(t, auth);
      await _signInForm(t);
      await t.tap(_filled('Sign In'));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        t.widget<OutlinedButton>(_outlined('Continue with Google')).onPressed,
        isNull,
      );
      expect(
        t.widget<OutlinedButton>(_outlined('Continue as Guest')).onPressed,
        isNull,
      );
      expect(
        t.widget<TextField>(find.byType(TextField).first).readOnly,
        isTrue,
      );
      auth.gate.complete();
      await t.pump();
      t.takeException();
    },
  );

  testWidgets('sign in / sign up toggle swaps copy and fields', (t) async {
    await _open(t, MockFirebaseAuth());
    await t.tap(find.text('Sign Up'));
    await t.pump();
    for (final s in [
      'Create Account',
      'Join ELIOS to start sorting',
      'Full Name',
      'Email',
      'Already have an account? ',
    ]) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(find.text('Forgot password?'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(3));
    await t.ensureVisible(find.text('Sign In'));
    await t.tap(find.text('Sign In'));
    await t.pump();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('sign up creates the account, saves the name and goes Home', (
    t,
  ) async {
    final auth = MockFirebaseAuth();
    final spy = await _open(t, auth);
    await t.tap(find.text('Sign Up'));
    await t.pump();
    await t.enterText(_field(0), 'Ada Lovelace');
    await t.enterText(_field(1), 'ada@example.com');
    await t.enterText(_field(2), 'secret1');
    await t.tap(_filled('Create Account'));
    await t.pump();
    await t.pump();
    expect(spy.wentHome, isTrue);
    expect(find.text('Account created!'), findsOneWidget);
    expect(auth.currentUser?.displayName, 'Ada Lovelace');
    t.takeException();
  });

  testWidgets('sign up failure maps email-already-in-use', (t) async {
    final auth = _FailAuth('email-already-in-use');
    await _open(t, auth);
    await t.tap(find.text('Sign Up'));
    await t.pump();
    await t.enterText(_field(0), 'Ada Lovelace');
    await t.enterText(_field(1), 'ada@example.com');
    await t.enterText(_field(2), 'secret1');
    await t.tap(_filled('Create Account'));
    await t.pumpAndSettle();
    expect(find.text('This email is already registered.'), findsOneWidget);
  });

  testWidgets('guest mode signs in anonymously, snackbar text kept', (t) async {
    final auth = MockFirebaseAuth();
    final spy = await _open(t, auth);
    await t.tap(_outlined('Continue as Guest'));
    await t.pump();
    await t.pump();
    expect(spy.wentHome, isTrue);
    expect(auth.currentUser?.isAnonymous, isTrue);
    expect(find.text('Entered guest mode.'), findsOneWidget);
    t.takeException();
  });

  group('Google handler (fake plugin channel, no real sign-in)', () {
    void fakeGoogle(
      WidgetTester t,
      Future<Object?> Function(MethodCall) handler,
    ) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/google_sign_in'),
            handler,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/google_sign_in'),
              null,
            ),
      );
    }

    testWidgets('user cancels: no error, form usable again', (t) async {
      fakeGoogle(t, (_) async => null);
      final spy = await _open(t, MockFirebaseAuth());
      await t.tap(_outlined('Continue with Google'));
      await t.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Google sign-in failed'), findsNothing);
      expect(spy.pages, isEmpty);
    });

    testWidgets('platform error is reported in the banner', (t) async {
      fakeGoogle(t, (call) async {
        if (call.method == 'signIn') {
          throw PlatformException(code: 'sign_in_failed');
        }
        return null;
      });
      await _open(t, MockFirebaseAuth());
      await t.tap(_outlined('Continue with Google'));
      await t.pumpAndSettle();
      expect(
        find.text('Google sign-in failed: sign_in_failed'),
        findsOneWidget,
      );
      expect(
        t.widget<OutlinedButton>(_outlined('Continue with Google')).onPressed,
        isNotNull,
      );
    });
  });

  group('forgot password', () {
    testWidgets('link opens the reset form; Sign In returns', (t) async {
      await _open(t, MockFirebaseAuth());
      await t.tap(find.text('Forgot password?'));
      await t.pump();
      expect(find.text('Send reset link'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
      await t.tap(find.text('Sign In'));
      await t.pump();
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('invalid email keeps the old snackbar', (t) async {
      await _open(t, MockFirebaseAuth());
      await t.tap(find.text('Forgot password?'));
      await t.pump();
      await t.enterText(_field(0), 'nope');
      await t.tap(_filled('Send reset link'));
      await t.pump();
      expect(find.text('Enter a valid email first.'), findsOneWidget);
    });

    testWidgets(
      'valid email: banner and snackbar, button off until the email changes',
      (t) async {
        await _open(t, MockFirebaseAuth());
        await t.tap(find.text('Forgot password?'));
        await t.pump();
        await t.enterText(_field(0), 'ada@example.com');
        await t.tap(_filled('Send reset link'));
        await t.pumpAndSettle();
        expect(find.text('Reset link sent to your email.'), findsNWidgets(2));
        expect(
          t.widget<FilledButton>(_filled('Send reset link')).onPressed,
          isNull,
        );
        await t.enterText(_field(0), 'ada@example.co');
        await t.pump();
        expect(
          t.widget<FilledButton>(_filled('Send reset link')).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('failure shows the mapped error banner', (t) async {
      await _open(t, _ResetFails());
      await t.tap(find.text('Forgot password?'));
      await t.pump();
      await t.enterText(_field(0), 'ada@example.com');
      await t.tap(_filled('Send reset link'));
      await t.pumpAndSettle();
      expect(find.text('No internet connection.'), findsOneWidget);
    });
  });

  testWidgets('password visibility toggle has a label and flips obscureText', (
    t,
  ) async {
    await _open(t, MockFirebaseAuth());
    bool obscured() =>
        t.widget<EditableText>(find.byType(EditableText).at(1)).obscureText;
    expect(obscured(), isTrue);
    await t.tap(find.byTooltip('Show password'));
    await t.pump();
    expect(obscured(), isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('tap targets are at least 48 dp', (t) async {
    await _open(t, MockFirebaseAuth());
    for (final f in [
      find.byType(FilledButton),
      find.widgetWithText(OutlinedButton, 'Continue with Google'),
      find.widgetWithText(OutlinedButton, 'Continue as Guest'),
      find.widgetWithText(TextButton, 'Forgot password?'),
      find.widgetWithText(TextButton, 'Sign Up'),
      find.byTooltip('Show password'),
    ]) {
      final s = t.getSize(f);
      expect(s.height, greaterThanOrEqualTo(48), reason: '$f');
    }
  });
}
