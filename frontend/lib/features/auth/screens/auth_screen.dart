// KAMOS — Auth screen with login + register tabs (AuthScreen.jsx parity).
//
// Google handoff: server-verified OAuth (SPEC §3.1). The Flutter app only
// transmits the Google ID token, never the client secret (brief §6.10).
//
// Activation is gated by `kIsGoogleConfigured` (see
// `core/auth/google_signin_service.dart`). When the dart-define is absent the
// button renders disabled with a tooltip; when present the button drives the
// platform SDK and on success calls `signInWithGoogle(idToken: ...)`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/auth/google_signin_service.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/auth_controller.dart';

enum _Mode { signIn, signUp, forgot }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _Mode _mode = _Mode.signIn;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: KamosSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: KamosSpacing.xxl),
              _Header(),
              const SizedBox(height: KamosSpacing.xl),
              if (_mode == _Mode.forgot)
                _ForgotBody(
                  controller: _email,
                  onBack: () => setState(() => _mode = _Mode.signIn),
                )
              else
                _SignInOrUp(
                  isSignUp: _mode == _Mode.signUp,
                  email: _email,
                  password: _password,
                  username: _username,
                  controllerState: controller,
                  onForgot: () => setState(() => _mode = _Mode.forgot),
                  onToggleMode: () => setState(
                    () => _mode = _mode == _Mode.signIn
                        ? _Mode.signUp
                        : _Mode.signIn,
                  ),
                  onSubmit: () async {
                    if (_mode == _Mode.signIn) {
                      await ref
                          .read(authControllerProvider.notifier)
                          .signIn(
                            email: _email.text.trim(),
                            password: _password.text,
                          );
                    } else {
                      // Capture the router synchronously so the post-await
                      // navigation doesn't have to re-touch `context`.
                      final router = GoRouter.of(context);
                      final email = _email.text.trim();
                      await ref
                          .read(authControllerProvider.notifier)
                          .signUp(
                            username: _username.text.trim(),
                            email: email,
                            password: _password.text,
                            locale: Localizations.localeOf(
                              context,
                            ).languageCode,
                          );
                      // After signup, land on the dedicated "check your
                      // mail" pending screen. Verification is now fully
                      // server-side (mail link → backend HTML page) so
                      // the mobile app's only job is to tell the user
                      // to open the mail and detect when verification
                      // lands.
                      if (mounted &&
                          ref.read(authControllerProvider).error == null) {
                        router.go('/auth/verify-pending', extra: email);
                      }
                    }
                  },
                  onGoogleHandoff: () async {
                    if (!kIsGoogleConfigured) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final locale = Localizations.localeOf(context).languageCode;
                    final l = AppLocalizations.of(context);
                    final idToken = await ref
                        .read(googleSignInServiceProvider)
                        .signInAndGetIdToken();
                    if (idToken == null) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text(l.authGoogleSignInFailed)),
                      );
                      return;
                    }
                    await ref
                        .read(authControllerProvider.notifier)
                        .signInWithGoogle(idToken: idToken, locale: locale);
                  },
                ),
              const SizedBox(height: KamosSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Image.asset('assets/images/logo.png', width: 56, height: 56),
        const SizedBox(height: 8),
        Text(
          l.appName,
          style: TextStyle(
            fontFamily: 'ShipporiMincho',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: t.kon,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l.authTagline,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: t.fg3),
        ),
      ],
    );
  }
}

class _SignInOrUp extends StatelessWidget {
  const _SignInOrUp({
    required this.isSignUp,
    required this.email,
    required this.password,
    required this.username,
    required this.controllerState,
    required this.onForgot,
    required this.onToggleMode,
    required this.onSubmit,
    required this.onGoogleHandoff,
  });

  final bool isSignUp;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController username;
  final AuthControllerState controllerState;
  final VoidCallback onForgot;
  final VoidCallback onToggleMode;
  final VoidCallback onSubmit;
  final VoidCallback onGoogleHandoff;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;

    final usernameInvalid =
        isSignUp &&
        username.text.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_]{3,30}$').hasMatch(username.text);

    final passwordTooShort =
        password.text.isNotEmpty && password.text.length < 8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isSignUp ? l.authSignUp : l.authSignIn,
          style: TextStyle(
            fontFamily: 'ShipporiMincho',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: t.fg1,
          ),
        ),
        const SizedBox(height: 14),
        if (isSignUp) ...[
          _FieldLabel(l.authUsernameLabel),
          TextField(
            controller: username,
            decoration: InputDecoration(
              hintText: 'yamamoto',
              errorText: usernameInvalid ? l.authUsernameInvalid : null,
            ),
            maxLength: 30,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              l.authUsernameHelper,
              style: TextStyle(fontSize: 12, color: t.fg3),
            ),
          ),
        ],
        _FieldLabel(l.authEmailLabel),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'you@example.com'),
        ),
        const SizedBox(height: KamosSpacing.md),
        _FieldLabel(l.authPasswordLabel),
        TextField(
          controller: password,
          obscureText: true,
          decoration: InputDecoration(
            errorText: passwordTooShort ? l.authPasswordTooShort : null,
          ),
          onChanged: (_) => (context as Element).markNeedsBuild(),
        ),
        if (isSignUp)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.authPasswordHelper,
              style: TextStyle(fontSize: 12, color: t.fg3),
            ),
          ),
        if (!isSignUp)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onForgot,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(l.authForgotPassword),
            ),
          ),
        const SizedBox(height: 8),
        if (controllerState.error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KamosSpacing.md,
              vertical: KamosSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: t.fgDanger.withValues(alpha: 0.10),
              border: Border.all(color: t.fgDanger.withValues(alpha: 0.40)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: t.fgDanger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controllerState.error!,
                    style: TextStyle(
                      color: t.fgDanger,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KamosSpacing.sm),
        ],
        FilledButton(
          onPressed: controllerState.isSubmitting ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: t.ai,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: controllerState.isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(isSignUp ? l.authSignUp : l.authSignIn),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: Container(height: 1, color: t.border1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                l.authOr.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.3,
                  color: t.fg3,
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: t.border1)),
          ],
        ),
        const SizedBox(height: 18),
        Tooltip(
          message: kIsGoogleConfigured ? '' : l.authGoogleDisabled,
          child: OutlinedButton.icon(
            onPressed: kIsGoogleConfigured ? onGoogleHandoff : null,
            icon: const Icon(Icons.g_mobiledata, size: 24),
            label: Text(
              kIsGoogleConfigured
                  ? l.authGoogleSignInButton
                  : l.authGoogleDisabled,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                isSignUp ? l.authHaveAccount : l.authNoAccount,
                style: TextStyle(fontSize: 13, color: t.fg2),
              ),
              TextButton(
                onPressed: onToggleMode,
                child: Text(isSignUp ? l.authSignIn : l.authSignUp),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ForgotBody extends StatelessWidget {
  const _ForgotBody({required this.controller, required this.onBack});
  final TextEditingController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.authForgotTitle,
          style: TextStyle(
            fontFamily: 'ShipporiMincho',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: t.fg1,
          ),
        ),
        const SizedBox(height: 8),
        Text(l.authForgotBody, style: TextStyle(fontSize: 13, color: t.fg3)),
        const SizedBox(height: 14),
        _FieldLabel(l.authEmailLabel),
        TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'you@example.com'),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: onBack,
          style: FilledButton.styleFrom(
            backgroundColor: t.ai,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(l.authForgotSend),
        ),
        TextButton(onPressed: onBack, child: Text(l.authBackToSignIn)),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.3,
          color: t.fg3,
        ),
      ),
    );
  }
}
