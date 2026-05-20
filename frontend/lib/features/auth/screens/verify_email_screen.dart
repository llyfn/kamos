// KAMOS — Email verification landing screen.
//
// Path: `/auth/verify-email?token=<verification_token>`
// Reads the `token` query parameter and calls `AuthRepository.verifyEmail`.
// Renders loading → success / failure states. On success, briefly shows a
// snackbar and redirects to `/` (the feed; the router will send unauth users
// back to `/auth`). On failure, shows the error message and a "Back to sign
// in" link.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../repository/auth_repository.dart';

enum _VerifyStatus { loading, success, failure }

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.token,
    this.onSuccessRedirect,
  });
  final String token;

  /// Override for tests: called instead of `context.go('/')` after a brief
  /// snackbar delay. Production passes `null` and the screen uses go_router.
  final void Function(BuildContext context)? onSuccessRedirect;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  _VerifyStatus _status = _VerifyStatus.loading;

  @override
  void initState() {
    super.initState();
    // Schedule the call out of the initState frame so any `ProviderScope`
    // overrides (used by tests) are settled before we touch the repository.
    Future.microtask(_verify);
  }

  Future<void> _verify() async {
    if (widget.token.isEmpty) {
      if (mounted) setState(() => _status = _VerifyStatus.failure);
      return;
    }
    try {
      final ok = await ref
          .read(authRepositoryProvider)
          .verifyEmail(widget.token);
      if (!mounted) return;
      setState(() => _status = ok ? _VerifyStatus.success : _VerifyStatus.failure);
      if (ok) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.verifyEmailSuccess)),
        );
        // Allow the snackbar to render briefly, then bounce. The router's
        // redirect logic will land the user on `/auth` if they are not
        // authenticated, and on `/` if they are.
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        final redirect = widget.onSuccessRedirect;
        if (redirect != null) {
          redirect(context);
        } else {
          context.go('/');
        }
      }
    } catch (_) {
      if (mounted) setState(() => _status = _VerifyStatus.failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    '封',
                    style: TextStyle(
                      fontFamily: 'ShipporiMincho',
                      fontSize: 48,
                      color: t.gray300,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    l.verifyEmailTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ShipporiMincho',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: t.fg1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_status == _VerifyStatus.loading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(t.ai),
                          backgroundColor: t.gray200,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          l.verifyEmailLoading,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: t.fg2),
                        ),
                      ),
                    ],
                  )
                else if (_status == _VerifyStatus.success)
                  Center(
                    child: Text(
                      l.verifyEmailSuccess,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: t.fgSuccess),
                    ),
                  )
                else ...[
                  Center(
                    child: Text(
                      l.verifyEmailFailure,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: t.fgDanger),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/auth'),
                    child: Text(l.verifyEmailBackToAuth),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
