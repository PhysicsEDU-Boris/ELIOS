import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:elio/providers/auth_provider.dart';
import 'package:elio/theme/elio_theme.dart';
import 'package:elio/theme/elio_tokens.dart';
import 'package:elio/widgets/auth/auth_widgets.dart';
import 'package:elio/widgets/splash/elio_leaf.dart';

import 'home_shell.dart';
import 'package:elio/l10n/l10n.dart';

class LoginScreen extends StatefulWidget {
  final FirebaseAuth auth;

  const LoginScreen({super.key, required this.auth});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ── Form ──────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  // ── State ─────────────────────────────────────────────────
  bool _isSignUp = false;
  bool _isForgot = false;
  bool _resetSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Cleanup ───────────────────────────────────────────────
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // ── Navigation helper ─────────────────────────────────────
  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();

    if (mounted) {
      FocusScope.of(context).unfocus();
    }

    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  void _goHome() {
    _dismissKeyboard();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HomeShell(auth: widget.auth),
        transitionsBuilder: (context, anim, secondaryAnimation, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ── Snackbar helper ───────────────────────────────────────
  // ponytail: the snackbar shows in the Home scaffold after the route change, so it
  // takes the app theme, not the ELIOS one. Restyle it with HomeShell.
  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Builder(
              builder: (context) => Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: DefaultTextStyle.of(context).style.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Error mapping ─────────────────────────────────────────
  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return l10n.authUserNotFound;
      case 'wrong-password':
        return l10n.authWrongPassword;
      case 'email-already-in-use':
        return l10n.authEmailInUse;
      case 'weak-password':
        return l10n.authWeakPassword;
      case 'invalid-email':
        return l10n.authInvalidEmail;
      case 'too-many-requests':
        return l10n.authTooMany;
      case 'network-request-failed':
        return l10n.authNoInternet;
      case 'missing-google-id-token':
        return l10n.authGoogleConfig;
      case 'account-exists-with-different-credential':
        return l10n.authOtherMethod;
      case 'credential-already-in-use':
        return l10n.authGoogleLinked;
      case 'invalid-credential':
        return l10n.authGoogleInvalid;
      case 'operation-not-allowed':
        return l10n.authGoogleDisabled;
      default:
        return l10n.authGeneric;
    }
  }

  // ── Set loading / error state ─────────────────────────────
  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() {
      _isLoading = value;
      if (value) _errorMessage = null;
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  // ── EMAIL SIGN IN ─────────────────────────────────────────
  Future<void> _handleEmailAuth() async {
    _dismissKeyboard();

    if (!_formKey.currentState!.validate()) return;
    _setLoading(true);
    try {
      await widget.auth.signInWithEmailOrUsername(
        _emailController.text,
        _passwordController.text,
      );
      _showSnack(l10n.authWelcomeBack);
      _goHome();
    } on FirebaseAuthException catch (e) {
      _setError(_mapError(e.code));
    } catch (_) {
      _setError(l10n.authSignInFailed);
    }
  }

  // ── EMAIL SIGN UP ─────────────────────────────────────────
  Future<void> _signUpWithEmail() async {
    _dismissKeyboard();

    if (!_formKey.currentState!.validate()) return;
    _setLoading(true);
    try {
      final cred = await widget.auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await cred.user?.updateDisplayName(_nameController.text.trim());
      _showSnack(l10n.authAccountCreated);
      _goHome();
    } on FirebaseAuthException catch (e) {
      _setError(_mapError(e.code));
    } catch (_) {
      _setError(l10n.authCreateFailed);
    }
  }

  // ── GOOGLE SIGN IN ────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    _dismissKeyboard();
    _setLoading(true);

    try {
      debugPrint('[AuthDiag] Google sign-in started');

      const iosGoogleClientId =
          '250721309748-q0mqs9dbs9r0b39onjs89mpkkf5up8rq.apps.googleusercontent.com';

      final googleSignIn = GoogleSignIn(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? iosGoogleClientId
            : null,
        serverClientId:
            '250721309748-la1mikrov7nhdno6d55389l0du6p457f.apps.googleusercontent.com',
        scopes: const ['email', 'profile'],
      );

      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('[AuthDiag] Google sign-in cancelled by user');
        _setLoading(false);
        return;
      }

      debugPrint(
        '[AuthDiag] Google user selected: '
        'email=${googleUser.email}, id=${googleUser.id}',
      );

      final googleAuth = await googleUser.authentication;

      debugPrint(
        '[AuthDiag] Google tokens: '
        'accessToken=${googleAuth.accessToken != null}, '
        'idToken=${googleAuth.idToken != null}',
      );

      if (googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message:
              l10n.authNoIdToken,
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await widget.auth.signInWithCredential(credential);

      debugPrint(
        '[AuthDiag] Firebase Google sign-in success: '
        'uid=${userCredential.user?.uid}, '
        'email=${userCredential.user?.email}',
      );

      _showSnack(l10n.authWelcomeBack);
      _goHome();
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint(
        '[AuthDiag] FirebaseAuthException: '
        'code=${e.code}, message=${e.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      _setError(_mapError(e.code));
    } on PlatformException catch (e, stackTrace) {
      debugPrint(
        '[AuthDiag] PlatformException: '
        'code=${e.code}, message=${e.message}, details=${e.details}',
      );
      debugPrintStack(stackTrace: stackTrace);
      _setError(l10n.authGoogleFailedCode(e.code));
    } catch (e, stackTrace) {
      debugPrint('[AuthDiag] Unknown Google sign-in error: $e');
      debugPrintStack(stackTrace: stackTrace);
      _setError(l10n.authGoogleFailed);
    }
  }

  // ── GUEST MODE ────────────────────────────────────────────
  Future<void> _signInAsGuest() async {
    _dismissKeyboard();
    _setLoading(true);
    try {
      await widget.auth.signInAnonymously();
      _showSnack(l10n.authGuestEntered);
      _goHome();
    } on FirebaseAuthException catch (e) {
      _setError(_mapError(e.code));
    } catch (_) {
      _setError(l10n.authGuestFailed);
    }
  }

  // ── FORGOT PASSWORD ───────────────────────────────────────
  Future<void> _resetPassword() async {
    _dismissKeyboard();

    final email = _emailController.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnack(l10n.authEmailFirst, isError: true);
      return;
    }
    try {
      await widget.auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() {
        _resetSent = true;
        _errorMessage = null;
      });
      _showSnack(l10n.authResetSent);
    } on FirebaseAuthException catch (e) {
      _setError(_mapError(e.code));
    } catch (_) {
      _setError(l10n.authResetFailed);
    }
  }

  // ── Validators ────────────────────────────────────────────
  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) {
      return _isSignUp ? l10n.authEmailRequired : l10n.authEmailOrUserRequired;
    }

    final value = v.trim();
    if (_isSignUp || value.contains('@')) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
        return l10n.authValidEmail;
      }
    }
    return null;
  }

  String? _passwordValidator(String? v) {
    if (v == null || v.isEmpty) return l10n.authPasswordRequired;
    if (v.length < 6) return l10n.authMin6;
    return null;
  }

  String? _nameValidator(String? v) {
    if (!_isSignUp) return null;
    if (v == null || v.trim().isEmpty) return l10n.authNameRequired;
    if (v.trim().length < 2) return l10n.authMin2;
    return null;
  }

  // ── Mode switches ─────────────────────────────────────────
  void _toggleSignUp() => setState(() {
    _isSignUp = !_isSignUp;
    _errorMessage = null;
  });

  void _setForgot(bool value) => setState(() {
    _isForgot = value;
    _resetSent = false;
    _errorMessage = null;
  });

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ElioTheme.wrap(
      Builder(
        builder: (context) {
          final p = authPalette(context);
          // Figma 1366x768: brand panel plus a 400 dp form column; phones 390x844: full-height form.
          final wide = MediaQuery.sizeOf(context).width >= 900;
          final form = _buildForm(p, wide);
          return Scaffold(
            body: wide
                ? Row(
                    children: [
                      const AuthBrandPanel(),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(ElioTokens.space24),
                            child: SizedBox(width: 400, child: form),
                          ),
                        ),
                      ),
                    ],
                  )
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        24,
                        32,
                        24,
                        24,
                      ),
                      child: form,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildForm(ElioPalette p, bool wide) {
    final title = _isForgot
        ? l10n.authForgot
        : _isSignUp
        ? l10n.authCreateAccount
        : l10n.authWelcomeTitle;
    final subtitle = _isForgot
        ? null
        : _isSignUp
        ? l10n.authJoin
        : l10n.authSignInSub;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: ElioTokens.space24,
        children: [
          if (!wide)
            Row(
              spacing: 12,
              children: [
                ElioMark(size: 48, color: p.primaryText),
                Text('ELIOS', style: authBrandStyle(p, large: false)),
              ],
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: ElioTokens.space4,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: ElioTokens.headline.copyWith(color: p.textPrimary),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
                ),
            ],
          ),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _isForgot ? _forgotFields(p) : _signFields(p),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: ElioTokens.space16,
            children: _isForgot ? _forgotActions() : _signActions(p),
          ),
        ],
      ),
    );
  }

  bool get _emailHasError =>
      _errorMessage == _mapError('user-not-found') ||
      _errorMessage == _mapError('invalid-email');

  bool get _passwordHasError => _errorMessage == _mapError('wrong-password');

  Widget _emailField() => AuthField(
    controller: _emailController,
    validator: _isForgot ? null : _emailValidator,
    label: _isSignUp || _isForgot ? l10n.authEmail : l10n.authEmailOrUser,
    hint: _isSignUp || _isForgot
        ? 'you@example.com'
        : l10n.authEmailOrUserHint,
    icon: Icons.mail_outline,
    keyboardType: TextInputType.emailAddress,
    focusNode: _emailFocusNode,
    autofillHints: _isSignUp || _isForgot
        ? const [AutofillHints.email]
        : const [AutofillHints.username, AutofillHints.email],
    textInputAction: _isForgot ? TextInputAction.done : TextInputAction.next,
    onChanged: _isForgot ? (_) => setState(() => _resetSent = false) : null,
    onFieldSubmitted: (_) => _isForgot
        ? _resetPassword()
        : FocusScope.of(context).requestFocus(_passwordFocusNode),
    onTapOutside: (_) => _dismissKeyboard(),
    hasError: _emailHasError,
    dimmed: _isLoading,
  );

  List<Widget> _forgotFields(ElioPalette p) => _gaps([
    if (_errorMessage != null)
      AuthBanner(kind: AuthBannerKind.error, message: _errorMessage!)
    else if (_resetSent)
      AuthBanner(
        kind: AuthBannerKind.success,
        message: l10n.authResetSent,
      ),
    _emailField(),
  ]);

  List<Widget> _forgotActions() => [
    AuthPrimaryButton(
      label: l10n.authSendReset,
      onPressed: _resetSent ? null : _resetPassword,
    ),
    Center(
      child: AuthLink(label: l10n.authSignIn, onPressed: () => _setForgot(false)),
    ),
  ];

  List<Widget> _signFields(ElioPalette p) => _gaps([
    if (_errorMessage != null)
      AuthBanner(kind: AuthBannerKind.error, message: _errorMessage!),
    if (_isSignUp)
      AuthField(
        controller: _nameController,
        validator: _nameValidator,
        label: l10n.authFullName,
        hint: l10n.authFullNameHint,
        icon: Icons.person_outline,
        keyboardType: TextInputType.name,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
        onTapOutside: (_) => _dismissKeyboard(),
        dimmed: _isLoading,
      ),
    _emailField(),
    // The "Forgot password?" link sits on the label row (Figma 196:724), so it
    // shares a Stack with the field: 16 dp above the label to 32 dp into it.
    Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: _isSignUp ? 0 : 16),
          child: AuthField(
            controller: _passwordController,
            validator: _passwordValidator,
            label: l10n.authPassword,
            hint: l10n.authPasswordHint,
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
            focusNode: _passwordFocusNode,
            autofillHints: _isSignUp
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) =>
                _isSignUp ? _signUpWithEmail() : _handleEmailAuth(),
            onTapOutside: (_) => _dismissKeyboard(),
            hasError: _passwordHasError,
            dimmed: _isLoading,
            suffix: AuthVisibilityToggle(
              obscured: _obscurePassword,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        if (!_isSignUp)
          PositionedDirectional(
            top: 0,
            end: 0,
            child: Opacity(
              opacity: _isLoading ? ElioTokens.disabledOpacity : 1,
              child: AuthLink(
                label: l10n.authForgot,
                onPressed: _isLoading ? null : () => _setForgot(true),
              ),
            ),
          ),
      ],
    ),
  ], skipBeforeLast: !_isSignUp);

  /// 16 dp between fields. The sign-in password group already holds that gap
  /// (the "Forgot password?" link sits in it), so no gap goes before it there.
  List<Widget> _gaps(List<Widget> items, {bool skipBeforeLast = false}) => [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0 && !(skipBeforeLast && i == items.length - 1))
        const SizedBox(height: ElioTokens.space16),
      items[i],
    ],
  ];

  List<Widget> _signActions(ElioPalette p) => [
    AuthPrimaryButton(
      label: _isSignUp ? l10n.authCreateAccount : l10n.authSignIn,
      loading: _isLoading,
      onPressed: _isSignUp ? _signUpWithEmail : _handleEmailAuth,
    ),
    const AuthDivider(),
    AuthSecondaryButton(
      google: true,
      label: l10n.authGoogle,
      onPressed: _isLoading ? null : _signInWithGoogle,
    ),
    AuthSecondaryButton(
      label: l10n.authGuest,
      onPressed: _isLoading ? null : _signInAsGuest,
    ),
    Text(
      l10n.authGuestNote,
      textAlign: TextAlign.center,
      style: ElioTokens.caption.copyWith(color: p.textTertiary),
    ),
    Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _isSignUp ? l10n.authHaveAccount : l10n.authNoAccount,
          style: ElioTokens.bodySmall.copyWith(color: p.textSecondary),
        ),
        AuthLink(
          label: _isSignUp ? l10n.authSignIn : l10n.authSignUp,
          onPressed: _isLoading ? null : _toggleSignUp,
        ),
      ],
    ),
  ];
}
